-- Wait for Config.Impound to be available
while not (Config and Config.Impound) do Citizen.Wait(500) end

if not Config.Impound.Enabled then return end

-- Global Impound object shared across the resource
Impound = { records = {} }

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Trims leading/trailing whitespace and optionally truncates to maxLen characters
local function SanitiseString(value, maxLen)
    if type(value) ~= "string" then return "" end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if maxLen and #value > maxLen then
        value = value:sub(1, maxLen)
    end
    return value
end

-- Trims whitespace only (no length cap)
local function TrimString(value)
    if type(value) ~= "string" then return "" end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Validates a photo URL: must be non-empty and start with http(s)://
local function ValidatePhotoUrl(rawUrl)
    local url = SanitiseString(rawUrl, 512)
    if url ~= "" and url:match("^https?://") then
        return url
    end
    return nil
end

-- Returns true if the player's job meets the Config.Jobs threshold
local function PlayerHasImpoundAccess(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end

    local threshold = Config.Jobs[job.name]
    if not threshold then return false end

    return job.grade >= threshold
end

-- Applies VehicleState change (impounded or released) based on Config.Impound.VehicleState
local function SetVehicleImpoundState(plate, isImpounded)
    local stateConfig = Config.Impound.VehicleState
    local mode        = (stateConfig and stateConfig.mode) or "auto"

    if mode == "none" then return end

    if mode == "custom" then
        local callback = isImpounded
            and (stateConfig.onImpound)
            or  (stateConfig.onRelease)

        if type(callback) == "function" then
            local ok, err = pcall(callback, plate)
            if not ok then
                Bridge.Debug(string.format("[Impound] VehicleState.%s failed: %s",
                    isImpounded and "onImpound" or "onRelease", tostring(err)))
            end
        end

        return
    end

    -- "auto" mode: delegate to the framework bridge
    Bridge.Framework.setVehicleImpounded(plate, isImpounded)
end

-- Pushes impound data to the MDT resource if configured
local function PushToMDT(impoundData)
    local mdtConfig = Config.Impound.MDT
    if not (mdtConfig and mdtConfig.enabled and type(mdtConfig.push) == "function") then return end

    local resourceName = mdtConfig.resource or "p_mdt"
    if GetResourceState(resourceName) ~= "started" then return end

    local ok, err = pcall(mdtConfig.push, impoundData)
    if not ok then
        Bridge.Debug(string.format("[Impound] MDT push failed: %s", tostring(err)))
    end
end

-- ─── Database Init ────────────────────────────────────────────────────────────

CreateThread(function()
    while not MySQL do Wait(50) end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `police_impound` (
            `id`           INT AUTO_INCREMENT PRIMARY KEY,
            `plate`        VARCHAR(20)  NOT NULL UNIQUE,
            `owner`        VARCHAR(50)  NOT NULL,
            `vehicle`      LONGTEXT     NOT NULL,
            `location`     VARCHAR(50)  NOT NULL,
            `reason`       TEXT         NOT NULL,
            `notes`        LONGTEXT     NULL,
            `photo`        TEXT         NULL,
            `price`        INT          NOT NULL DEFAULT 0,
            `duration`     INT          NOT NULL,
            `officer_name` VARCHAR(100) NOT NULL,
            `officer_id`   VARCHAR(50)  NOT NULL,
            `impounded_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    -- Ensure optional columns added in later versions exist
    local function EnsureColumn(columnName, columnDef)
        local count = MySQL.scalar.await([[
            SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'police_impound' AND COLUMN_NAME = ?
        ]], { columnName })

        if not count or count == 0 then
            MySQL.query.await(string.format("ALTER TABLE `police_impound` ADD COLUMN %s", columnDef))
            Bridge.Debug(string.format("[Impound] Added missing column `%s`", columnName))
        end
    end

    EnsureColumn("notes", "`notes` LONGTEXT NULL AFTER `reason`")
    EnsureColumn("photo", "`photo` TEXT NULL AFTER `notes`")

    Bridge.Debug("[Impound] Database table created or verified")
end)

-- ─── Callbacks ────────────────────────────────────────────────────────────────

-- Verifies the officer has access and that the vehicle (by plate) is registered to an owner
lib.callback.register("p_policejob/server/impound/checkOwnedVehicle", function(playerSource, plate, netId)
    if not plate then return false end

    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end

    local threshold = Config.Jobs[job.name]
    if not (threshold and job.grade >= threshold) then return false end

    local normalisedPlate = TrimString(plate)
    local vehicleData     = Bridge.Framework.getOwnedVehicle(normalisedPlate)
    return vehicleData ~= nil
end)

-- Returns the impounded vehicles for a given location owned by the requesting player
lib.callback.register("p_policejob/server/impound/getImpoundedVehicles", function(playerSource, locationId)
    if not locationId then return {} end

    local uniqueId = Bridge.Framework.getUniqueId(playerSource)

    local rows = MySQL.query.await([[
        SELECT * FROM police_impound WHERE location = ? AND owner = ? ORDER BY impounded_at DESC
    ]], { locationId, uniqueId })

    if not (rows and #rows > 0) then return {} end

    local now = os.time()
    for _, row in pairs(rows) do
        row.timeLeft = math.max(0, row.duration - now)
    end

    return rows
end)

-- Handles payout (retrieval) of a vehicle from impound
lib.callback.register("p_policejob/server/impound/payoutVehicle", function(playerSource, payload)
    if not (type(payload) == "table" and payload.plate and payload.location) then
        return false
    end

    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    local plate    = TrimString(payload.plate)

    local rows = MySQL.query.await([[
        SELECT * FROM police_impound WHERE plate = ? AND location = ? AND owner = ? LIMIT 1
    ]], { plate, payload.location, uniqueId })

    local record = rows and rows[1]
    if not record then
        Bridge.Notify.showNotify(playerSource, locale("impound_vehicle_not_found"), "error")
        return false
    end

    local now = os.time()

    -- Vehicle has not yet served its impound duration: check funds
    if record.duration > now then
        local money       = Bridge.Framework.getMoney(playerSource)
        local bankBalance = (money and money.bank) or 0

        if bankBalance < record.price then
            Bridge.Notify.showNotify(playerSource, locale("impound_not_enough_money"), "error")
            return false
        end

        if record.price > 0 then
            Bridge.Framework.removeMoney(playerSource, "bank", record.price)
        end
    end

    local affected = MySQL.update.await("DELETE FROM police_impound WHERE plate = ?", { plate })
    if not (affected and affected > 0) then
        Bridge.Notify.showNotify(playerSource, locale("impound_payment_failed"), "error")
        return false
    end

    SetVehicleImpoundState(plate, false)
    Bridge.Notify.showNotify(playerSource, locale("impound_buyout_vehicle", plate, record.price), "success")

    if type(Config.Impound.OnVehiclePayedOut) == "function" then
        Config.Impound.OnVehiclePayedOut(playerSource, plate, record.price)
    end

    if Config.Webhooks and Config.Webhooks.impound then
        Bridge.Logs.Send(playerSource, "Impound",
            string.format("Vehicle %s paid out and retrieved", plate),
            Config.Webhooks.impound)
    end

    return true
end)

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Client → server: remove an unowned vehicle from the world
RegisterNetEvent("p_policejob/server/impound/removeUnownedVehicle", function(netId)
    local playerSource  = source
    local unownedConfig = Config.Impound.UnownedVehicles

    if not (unownedConfig and unownedConfig.remove) then return end

    if not PlayerHasImpoundAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not (entity and entity ~= 0 and DoesEntityExist(entity)) then
        return Bridge.Notify.showNotify(playerSource, locale("impound_vehicle_error"), "error")
    end

    local plate       = TrimString(GetVehicleNumberPlateText(entity))
    local vehicleData = Bridge.Framework.getOwnedVehicle(plate)

    if vehicleData then return end  -- vehicle has an owner, abort

    DeleteEntity(entity)
    Bridge.Notify.showNotify(playerSource, locale("impound_unowned_removed", plate), "success")

    if Config.Webhooks and Config.Webhooks.impound then
        Bridge.Logs.Send(playerSource, "Impound",
            string.format("Unowned vehicle %s removed", plate),
            Config.Webhooks.impound)
    end
end)

-- Client → server: officer submitted the impound form
RegisterNetEvent("p_policejob/server/impound/startImpound", function(payload)
    local playerSource = source

    if not (type(payload) == "table"
        and payload.netId
        and payload.reason
        and payload.location)
    then return end

    local entity = NetworkGetEntityFromNetworkId(payload.netId)
    if not (entity and entity ~= 0 and DoesEntityExist(entity)) then
        return Bridge.Notify.showNotify(playerSource, locale("impound_vehicle_error"), "error")
    end

    if not PlayerHasImpoundAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    local plate = TrimString(GetVehicleNumberPlateText(entity))
    local vehicleData = Bridge.Framework.getOwnedVehicle(plate)

    if not vehicleData then
        DeleteEntity(entity)
        return Bridge.Notify.showNotify(playerSource, locale("impound_vehicle_not_owned"), "error")
    end

    local now      = os.time()
    local price    = math.max(0, math.floor(tonumber(payload.price) or 0))

    -- Compute release timestamp
    local releaseAt
    local releaseAtRaw = tonumber(payload.releaseAt)
    if releaseAtRaw and now < releaseAtRaw then
        releaseAt = math.floor(releaseAtRaw)
    else
        local hours = tonumber(payload.time)
        if not (hours and hours > 0) then
            hours = Config.Impound.Time
        end
        releaseAt = now + hours * 3600
    end

    -- Sanitise text fields
    local reason     = SanitiseString(payload.reason,          255)
    local notes      = SanitiseString(payload.notes,          1000)
    local photo      = ValidatePhotoUrl(payload.photo)
    local modelLabel = SanitiseString(payload.model,           100)

    -- Enforce photo requirement
    local photoConfig = Config.Impound.Photo
    if photoConfig and photoConfig.enabled and photoConfig.required and not photo then
        return Bridge.Notify.showNotify(playerSource, locale("impound_photo_required"), "error")
    end

    DeleteEntity(entity)
    SetVehicleImpoundState(plate, true)

    local officerName = Bridge.Framework.getPlayerName(playerSource)
    local officerId   = Bridge.Framework.getUniqueId(playerSource)

    local insertId = MySQL.insert.await([[
        INSERT INTO police_impound
            (plate, owner, vehicle, location, reason, notes, photo, price, duration, officer_name, officer_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        plate,
        vehicleData.owner,
        vehicleData.props or "{}",
        payload.location,
        reason,
        notes,
        photo,
        price,
        releaseAt,
        officerName,
        officerId,
    })

    if not insertId then
        return Bridge.Notify.showNotify(playerSource, locale("impound_failed"), "error")
    end

    Bridge.Notify.showNotify(playerSource, locale("impound_success", plate), "success")

    if type(Config.Impound.OnVehicleImpounded) == "function" then
        Config.Impound.OnVehicleImpounded(playerSource, plate, reason)
    end

    local mdtData = {
        plate       = plate,
        owner       = vehicleData.owner,
        model       = modelLabel,
        officerName = officerName,
        officerId   = officerId,
        offence     = reason,
        notes       = notes,
        price       = price,
        impoundedAt = now,
        releaseAt   = releaseAt,
        photo       = photo,
        location    = payload.location,
    }

    PushToMDT(mdtData)

    if Config.Webhooks and Config.Webhooks.impound then
        local notesLine = (notes ~= "") and ("\n\nNotes: " .. notes) or ""
        local photoLine = photo and ("\n\nPhoto: " .. photo) or ""
        local message   = string.format(
            "Vehicle %s (%s) impounded by %s\nOffence: %s\nFine: $%s\nRelease: %s%s%s",
            plate,
            (modelLabel ~= "") and modelLabel or "Unknown",
            officerName,
            (reason ~= "") and reason or "N/A",
            price,
            os.date("%Y-%m-%d %H:%M", releaseAt),
            notesLine,
            photoLine
        )

        Bridge.Logs.Send(playerSource, "Impound", message, Config.Webhooks.impound)
    end
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

-- Returns all impounded vehicles with time-left computed
exports("GetImpoundedVehicles", function()
    local rows = MySQL.query.await("SELECT * FROM police_impound ORDER BY impounded_at DESC") or {}
    local now  = os.time()

    for _, row in ipairs(rows) do
        row.timeLeft = math.max(0, (tonumber(row.duration) or 0) - now)
    end

    return rows
end)

-- Releases a vehicle from impound by plate; optionally validates officer access
exports("ReleaseFromImpound", function(playerSource, rawPlate)
    local plate = TrimString(rawPlate)
    if plate == "" then return false, "invalid_plate" end

    if playerSource then
        if not PlayerHasImpoundAccess(playerSource) then
            return false, "no_permission"
        end
    end

    -- Try exact plate match first, then uppercase
    local affected = MySQL.update.await("DELETE FROM police_impound WHERE plate = ?", { plate })

    if not (affected and affected > 0) then
        local upper = plate:upper()
        if upper ~= plate then
            affected = MySQL.update.await("DELETE FROM police_impound WHERE plate = ?", { upper })
            if affected and affected > 0 then plate = upper end
        end
    end

    if not (affected and affected > 0) then
        return false, "not_impounded"
    end

    SetVehicleImpoundState(plate, false)

    if playerSource and Config.Webhooks and Config.Webhooks.impound then
        Bridge.Logs.Send(playerSource, "Impound",
            string.format("Vehicle %s released from impound (export)", plate),
            Config.Webhooks.impound)
    end

    return true, "released"
end)

-- ─── Admin Command ────────────────────────────────────────────────────────────

lib.addCommand("removeimpound", {
    help       = "Remove a vehicle from impound (admin only)",
    params     = { { name = "plate", help = "Vehicle plate" } },
    restricted = "group.admin",
}, function(playerSource, args)
    if not args.plate then
        return Bridge.Notify.showNotify(playerSource, "Usage: /removeimpound [plate]", "error")
    end

    local plate = TrimString(args.plate)
    MySQL.update.await("DELETE FROM police_impound WHERE plate = ?", { plate })
    SetVehicleImpoundState(plate, false)

    Bridge.Notify.showNotify(playerSource,
        string.format("Vehicle %s removed from impound", plate),
        "success")
end)
