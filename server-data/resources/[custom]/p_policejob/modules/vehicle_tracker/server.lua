if not Config.VehicleTracker.Enabled then return end

VehicleTracker = {}
VehicleTracker.trackedVehicles = {}   -- [plate] = { plate, netId, coords, heading, exists }

-- Publish initial (empty) tracker map to GlobalState so clients can read it immediately.
GlobalState.p_policejob_vehicleTrackers = VehicleTracker.trackedVehicles

-- ============================================================
--  Plate normalisation
-- ============================================================

local function normalisePlate(raw)
    if not raw then return nil end
    local s = tostring(raw):gsub("^%s*(.-)%s*$", "%1"):gsub("%s+", ""):upper()
    return s ~= "" and s or nil
end

-- ============================================================
--  Helpers
-- ============================================================

-- Returns true if the player's job is in Config.Jobs and their grade meets the minimum.
function VehicleTracker.hasPoliceAccess(self, playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end
    local minGrade = Config.Jobs[job.name]
    if minGrade == nil then return false end
    return (tonumber(job.grade) or 0) >= minGrade
end

-- Finds a vehicle entity by iterating all server vehicles, matched by normalised plate.
function VehicleTracker.getVehicleByPlate(self, plate)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if normalisePlate(GetVehicleNumberPlateText(vehicle)) == plate then
            return vehicle
        end
    end
    return 0
end

-- Resolves an entity handle from a netId; falls back to plate scan if the entity doesn't exist.
function VehicleTracker.getVehicleEntity(self, netId, plate)
    local entity = 0
    if netId then
        entity = NetworkGetEntityFromNetworkId(netId)
    end
    if entity == 0 or not DoesEntityExist(entity) then
        entity = self:getVehicleByPlate(plate)
    end
    return entity
end

-- Returns true if the player ped is within `maxDist` metres of the vehicle entity.
function VehicleTracker.isPlayerNearVehicle(self, playerSource, vehicle, maxDist)
    if not vehicle or vehicle == 0 then return false end
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return false end
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(vehicle))
    return dist <= (maxDist or 4.0)
end

-- Pushes the current trackedVehicles table into GlobalState.
function VehicleTracker.updateGlobalState(self)
    GlobalState.p_policejob_vehicleTrackers = self.trackedVehicles
end

-- ============================================================
--  Install
-- ============================================================

function VehicleTracker.install(self, playerSource, data)
    -- Access check
    if not self:hasPoliceAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    -- Resolve entity
    local vehicle = self:getVehicleEntity(data.netId, data.plate)
    if vehicle == 0 then
        return Bridge.Notify.showNotify(playerSource, locale("vehicle_tracker_not_found"), "error")
    end

    -- Distance check
    if not self:isPlayerNearVehicle(playerSource, vehicle, Config.VehicleTracker.InstallDistance) then
        return Bridge.Notify.showNotify(playerSource, locale("you_cant_do_it"), "error")
    end

    -- Re-read plate from entity (authoritative)
    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then
        return Bridge.Notify.showNotify(playerSource, locale("vehicle_tracker_not_found"), "error")
    end

    -- Already tracked?
    if self.trackedVehicles[plate] then
        return Bridge.Notify.showNotify(playerSource, locale("vehicle_tracker_already_on_vehicle"), "error")
    end

    -- Consume item
    Bridge.Inventory.removeItem(playerSource, Config.VehicleTracker.ItemName, 1)

    -- Build tracker record
    local coords  = GetEntityCoords(vehicle)
    local heading = nil
    if Config.VehicleTracker.Blip.heading then
        heading = GetEntityHeading(vehicle)
    end

    self.trackedVehicles[plate] = {
        plate   = plate,
        netId   = NetworkGetNetworkIdFromEntity(vehicle),
        coords  = vector3(coords.x, coords.y, coords.z),
        heading = heading,
        exists  = true,
    }

    -- State bag so other resources can query it
    Entity(vehicle).state:set("hasVehicleTracker", true, true)

    self:updateGlobalState()

    Bridge.Notify.showNotify(playerSource, locale("vehicle_tracker_installed"), "success")
    Bridge.Logs.Send(playerSource, "VehicleTracker",
        ("Installed vehicle tracker on %s"):format(plate),
        Config.Webhooks.interactions)

    Config.VehicleTracker.onInstall_Server(playerSource, plate)
    Bridge.Debug(("[VehicleTracker] Player %s installed tracker on %s"):format(playerSource, plate))
end

-- ============================================================
--  Remove
-- ============================================================

function VehicleTracker.remove(self, playerSource, data)
    local reason = data.reason or "police"

    -- Police-only access guard
    if reason == "police" and not self:hasPoliceAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    -- Validate plate
    local plate = normalisePlate(data.plate)
    if not plate or not self.trackedVehicles[plate] then
        return Bridge.Notify.showNotify(playerSource, locale("vehicle_tracker_not_found"), "error")
    end

    local record  = self.trackedVehicles[plate]
    local netId   = data.netId or record.netId
    local vehicle = self:getVehicleEntity(netId, plate)

    -- Distance check when vehicle is present on the server
    if vehicle ~= 0 then
        if not self:isPlayerNearVehicle(playerSource, vehicle, Config.VehicleTracker.RemoveDistance) then
            return Bridge.Notify.showNotify(playerSource, locale("you_cant_do_it"), "error")
        end
        -- Clear state bag
        Entity(vehicle).state:set("hasVehicleTracker", false, true)
    end

    -- Remove from tracker map
    self.trackedVehicles[plate] = nil
    self:updateGlobalState()

    -- Optionally return item on police removal
    if reason == "police" and Config.VehicleTracker.ReturnItemOnPoliceRemove then
        Bridge.Inventory.addItem(playerSource, Config.VehicleTracker.ItemName, 1)
    end

    -- Notifications
    if reason == "hack" then
        Bridge.Notify.showNotify(playerSource, locale("vehicle_tracker_removed"), "success")
        -- Alert all police players
        for _, serverId in ipairs(GetPlayers()) do
            serverId = tonumber(serverId)
            if serverId and self:hasPoliceAccess(serverId) then
                local alertMsg = ("%s (%s)"):format(locale("vehicle_tracker_hack_alert"), plate)
                Bridge.Notify.showNotify(serverId, alertMsg, "error")
            end
        end
    else
        Bridge.Notify.showNotify(playerSource, locale("vehicle_tracker_removed"), "success")
    end

    -- Broadcast blip removal to all clients
    TriggerClientEvent("p_policejob:vehicleTracker:removeBlip", -1, { plate = plate })

    Bridge.Logs.Send(playerSource, "VehicleTracker",
        ("Removed vehicle tracker from %s (%s)"):format(plate, reason),
        Config.Webhooks.interactions)

    Config.VehicleTracker.onRemove_Server(playerSource, plate, reason)
    Bridge.Debug(("[VehicleTracker] Player %s removed tracker from %s (%s)"):format(playerSource, plate, reason))
end

-- ============================================================
--  Coordinate update loop (server-side, runs on UpdateCoordsRate)
-- ============================================================

function VehicleTracker.updateCoords(self)
    local changed = false

    for plate, record in pairs(self.trackedVehicles) do
        local vehicle = self:getVehicleEntity(record.netId, plate)

        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local coords  = GetEntityCoords(vehicle)
            record.coords = vector3(coords.x, coords.y, coords.z)
            record.netId  = NetworkGetNetworkIdFromEntity(vehicle)
            record.exists = true

            if Config.VehicleTracker.Blip.heading then
                record.heading = GetEntityHeading(vehicle)
            end

            -- Keep state bag current
            Entity(vehicle).state:set("hasVehicleTracker", true, true)
            changed = true
        else
            record.exists = false
            changed = true
        end
    end

    if changed then self:updateGlobalState() end
end

-- ============================================================
--  Exports
-- ============================================================

exports("SetVehicleTracker", function(playerSource, netId, plate, install)
    if install then
        VehicleTracker:install(playerSource, { netId = netId, plate = plate })
    else
        VehicleTracker:remove(playerSource, { netId = netId, plate = plate, reason = "police" })
    end
end)

exports("HasVehicleTracker", function(rawPlate)
    local plate = normalisePlate(rawPlate)
    return plate ~= nil and VehicleTracker.trackedVehicles[plate] ~= nil
end)

exports("GetTrackedVehicles", function()
    return VehicleTracker.trackedVehicles
end)

-- Item usage hook (called by inventory system)
exports("tracking_vehicle", function(event, item, itemData, slot)
    if event == "usingItem" then
        TriggerClientEvent("p_policejob:vehicleTracker:useItem", itemData.id)
    end
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob:vehicleTracker:install", function(data)
    VehicleTracker:install(source, data or {})
end)

RegisterNetEvent("p_policejob:vehicleTracker:remove", function(data)
    VehicleTracker:remove(source, data or {})
end)

-- ============================================================
--  Startup: wait for Bridge, then run coordinate update loop
-- ============================================================

CreateThread(function()
    Wait(1000)
    while not (Bridge and Bridge.Framework) do
        Wait(500)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.VehicleTracker.UpdateCoordsRate)
        VehicleTracker:updateCoords()
    end
end)
