while true do
    if Config and Config.Speedcam then break end
    Citizen.Wait(500)
end

if not Config.Speedcam.enabled then return end

Speedcam = {}
Speedcam.cameras = {}
Speedcam.hits    = {}
Speedcam.dbReady = false
Speedcam.loaded  = false

-- Rolling hit history cap
local MAX_HITS = 250

-- Per-player+camera cooldown table: [playerSource..":"..camName] = os.time()
local recentHits = {}

-- ============================================================
--  Helpers
-- ============================================================

-- Converts MySQL TINYINT(1) or bool → true/false.
local function toBool(value)
    return value == 1 or value == true
end

-- Normalises a sensors JSON array (mixed vector3/table/array) to plain {x,y,z} tables.
local function normaliseSensors(raw)
    local result = {}
    for _, item in ipairs(raw or {}) do
        local x = item.x or item[1]
        local y = item.y or item[2]
        local z = item.z or item[3]
        if x and y and z then
            result[#result + 1] = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
        end
    end
    return result
end

-- Job + grade access check (same as client).
local function hasJobAccess(playerSource)
    local job      = Bridge.Framework.getPlayerJob(playerSource)
    local minGrade = job and Config.Jobs[job.name]
    if not minGrade then return false end
    return (job.grade or 0) >= minGrade
end

-- ============================================================
--  Database setup
-- ============================================================

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `p_policejob_speedcams` (
            `id`             INT AUTO_INCREMENT PRIMARY KEY,
            `cam_name`       VARCHAR(100) NOT NULL UNIQUE,
            `model_name`     VARCHAR(100) NOT NULL,
            `coords_x`       FLOAT NOT NULL,
            `coords_y`       FLOAT NOT NULL,
            `coords_z`       FLOAT NOT NULL,
            `heading`        FLOAT NOT NULL,
            `speed_limit`    INT NOT NULL,
            `cam_distance`   INT NOT NULL,
            `fine`           INT NOT NULL,
            `fine_multiplier` TINYINT(1) NOT NULL DEFAULT 0,
            `blip_enabled`   TINYINT(1) NOT NULL DEFAULT 1,
            `screen_effect`  TINYINT(1) NOT NULL DEFAULT 1,
            `light_effect`   TINYINT(1) NOT NULL DEFAULT 1,
            `sensors`        LONGTEXT NOT NULL,
            `created_at`     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    Speedcam.dbReady = true
    Bridge.Debug("[Speedcam] Database table verified")
end)

-- ============================================================
--  recordHit: append to rolling hit history and fire global event
-- ============================================================

function Speedcam.recordHit(self, hitData)
    self.hits[#self.hits + 1] = hitData
    if #self.hits > MAX_HITS then
        table.remove(self.hits, 1)
    end
    TriggerEvent("p_policejob:OnRadarHit", {
        plate    = hitData.plate,
        camId    = hitData.camId,
        coords   = hitData.coords,
        speed    = hitData.speed,
        timeUnix = hitData.timeUnix,
    })
end

-- ============================================================
--  Load cameras from DB
-- ============================================================

local function loadFromDb()
    local rows = MySQL.query.await("SELECT * FROM p_policejob_speedcams")
    if rows and #rows > 0 then
        for _, row in ipairs(rows) do
            local sensors = json.decode(row.sensors) or {}
            Speedcam.cameras[row.cam_name] = {
                id             = row.id,
                camName        = row.cam_name,
                modelName      = row.model_name,
                -- Store coords as plain table with explicit float coercion
                -- so json.encode always produces {"x":...,"y":...,"z":...}
                coords         = { x = row.coords_x + 0.0, y = row.coords_y + 0.0, z = row.coords_z + 0.0 },
                heading        = row.heading + 0.0,
                speedLimit     = row.speed_limit,
                camDistance    = row.cam_distance,
                fine           = row.fine,
                fineMultiplier = toBool(row.fine_multiplier),
                blipEnabled    = toBool(row.blip_enabled),
                screenEffect   = toBool(row.screen_effect),
                lightEffect    = toBool(row.light_effect),
                sensors        = normaliseSensors(sensors),
            }
        end
    end
    Speedcam.loaded = true
end

-- ============================================================
--  Broadcast full camera list to all online players
-- ============================================================

local function broadcastAll()
    local list = {}
    for _, cam in pairs(Speedcam.cameras) do list[#list + 1] = cam end
    for _, playerStr in ipairs(GetPlayers()) do
        TriggerClientEvent("p_policejob/client/speedcam/loadCameras", tonumber(playerStr), list)
    end
end

-- ============================================================
--  onResourceStart — load DB then broadcast
-- ============================================================

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    while not Speedcam.dbReady do Citizen.Wait(50) end
    loadFromDb()
    broadcastAll()
end)

-- ============================================================
--  loadCameras event (player requesting sync on join)
-- ============================================================

RegisterNetEvent("p_policejob/server/speedcam/loadCameras", function()
    local playerSource = source
    local attempts     = 0
    while not Speedcam.loaded and attempts < 100 do
        Citizen.Wait(100)
        attempts = attempts + 1
    end

    local list = {}
    for _, cam in pairs(Speedcam.cameras) do list[#list + 1] = cam end
    TriggerClientEvent("p_policejob/client/speedcam/loadCameras", playerSource, list)
end)

-- ============================================================
--  createSpeedcam
-- ============================================================

RegisterNetEvent("p_policejob/server/speedcam/createSpeedcam", function(data)
    local playerSource = source
    if not hasJobAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    if Speedcam.cameras[data.camName] then
        return Bridge.Notify.showNotify(playerSource, "Camera name already exists", "error")
    end

    data.sensors = normaliseSensors(data.sensors)
    local sensorsJson = json.encode(data.sensors)

    MySQL.insert.await(
        "INSERT INTO p_policejob_speedcams (cam_name, model_name, coords_x, coords_y, coords_z, heading, speed_limit, cam_distance, fine, fine_multiplier, blip_enabled, screen_effect, light_effect, sensors) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        {
            data.camName, data.modelName,
            data.coords.x, data.coords.y, data.coords.z,
            data.heading, data.speedLimit, data.camDistance, data.fine,
            data.fineMultiplier and 1 or 0,
            data.blipEnabled   and 1 or 0,
            data.screenEffect  and 1 or 0,
            data.lightEffect   and 1 or 0,
            sensorsJson,
        }
    )

    local camRecord = {
        camName        = data.camName,
        modelName      = data.modelName,
        -- Ensure plain table with floats so clients receive {x,y,z} in JSON, not an array
        coords         = { x = data.coords.x + 0.0, y = data.coords.y + 0.0, z = data.coords.z + 0.0 },
        heading        = data.heading + 0.0,
        speedLimit     = data.speedLimit,
        camDistance    = data.camDistance,
        fine           = data.fine,
        fineMultiplier = data.fineMultiplier,
        blipEnabled    = data.blipEnabled,
        screenEffect   = data.screenEffect,
        lightEffect    = data.lightEffect,
        sensors        = data.sensors,
    }

    Speedcam.cameras[data.camName] = camRecord
    TriggerClientEvent("p_policejob/client/speedcam/newCamera", -1, camRecord)
    Bridge.Notify.showNotify(playerSource, "Speed camera created", "success")
end)

-- ============================================================
--  playerCaught
-- ============================================================

RegisterNetEvent("p_policejob/server/speedcam/playerCaught", function(data)
    local playerSource = source
    local ped          = GetPlayerPed(playerSource)
    local vehicle      = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return end

    -- Per-player+camera 25-second cooldown
    local cooldownKey = ("%s:%s"):format(playerSource, tostring(data.cameraData and data.cameraData.camName))
    local now         = os.time()
    if recentHits[cooldownKey] and (now - recentHits[cooldownKey]) < 25 then return end
    recentHits[cooldownKey] = now

    -- Calculate fine (with optional speed-proportional multiplier)
    local fine = data.cameraData.fine
    if data.cameraData.fineMultiplier then
        fine = math.floor((data.speed / data.cameraData.speedLimit) * fine)
    end

    -- Config callback (issue fine, send notice, etc.)
    if Config.Speedcam.OnSpeedingDetected then
        Config.Speedcam.OnSpeedingDetected(
            playerSource, fine, data.speed, data.cameraData.speedLimit)
    end

    -- Plate (trimmed + uppercased)
    local rawPlate = GetVehicleNumberPlateText(vehicle)
    local plate    = nil
    if rawPlate then
        plate = rawPlate:gsub("%s+$", ""):upper()
        if plate == "" then plate = nil end
    end

    -- Record hit
    Speedcam:recordHit({
        plate     = plate,
        camId     = data.cameraData.camName,
        coords    = data.cameraData.coords,
        speed     = data.speed,
        speedLimit = data.cameraData.speedLimit,
        fine      = fine,
        driver    = Bridge.Framework.getUniqueId(playerSource),
        timeUnix  = now,
    })

    -- Notify speeding player
    local overBy = data.speed - data.cameraData.speedLimit
    Bridge.Notify.showNotify(playerSource,
        ("You were speeding! Fine: $%d (%d km/h over limit)"):format(fine, overBy),
        "error")

    -- Light effect: broadcast to nearby players
    if data.cameraData.lightEffect then
        local pedCoords = GetEntityCoords(ped)
        local nearby    = lib.getNearbyPlayers(pedCoords, 50.0, true)
        for _, entry in ipairs(nearby) do
            TriggerClientEvent("p_policejob/client/speedcam/syncLight", entry.id, data)
        end
    end

    -- Webhook log
    if Config.Webhooks and Config.Webhooks.speedcam then
        Bridge.Logs.Send(playerSource, "Speedcam",
            ("Player caught speeding: $%d fine (%d km/h over)"):format(fine, overBy),
            Config.Webhooks.speedcam)
    end
end)

-- ============================================================
--  removeSpeedcam
-- ============================================================

RegisterNetEvent("p_policejob/server/speedcam/removeSpeedcam", function(camName)
    local playerSource = source
    if not hasJobAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    MySQL.update.await("DELETE FROM p_policejob_speedcams WHERE cam_name = ?", { camName })
    Speedcam.cameras[camName] = nil
    TriggerClientEvent("p_policejob/client/speedcam/removeCamera", -1, camName)
    Bridge.Notify.showNotify(playerSource,
        ('Speed camera "%s" removed'):format(camName), "success")

    if Config.Webhooks and Config.Webhooks.speedcam then
        Bridge.Logs.Send(playerSource, "Speedcam",
            ("Removed speedcam: %s"):format(camName),
            Config.Webhooks.speedcam)
    end
end)

-- ============================================================
--  updateSpeedcam
-- ============================================================

RegisterNetEvent("p_policejob/server/speedcam/updateSpeedcam", function(data)
    local playerSource = source
    if not hasJobAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    data.sensors = normaliseSensors(data.sensors)
    local sensorsJson = json.encode(data.sensors)

    MySQL.update.await(
        "UPDATE p_policejob_speedcams SET model_name = ?, speed_limit = ?, cam_distance = ?, fine = ?, fine_multiplier = ?, blip_enabled = ?, screen_effect = ?, light_effect = ?, sensors = ? WHERE cam_name = ?",
        {
            data.modelName, data.speedLimit, data.camDistance, data.fine,
            data.fineMultiplier and 1 or 0,
            data.blipEnabled    and 1 or 0,
            data.screenEffect   and 1 or 0,
            data.lightEffect    and 1 or 0,
            sensorsJson, data.camName,
        }
    )

    Speedcam.cameras[data.camName] = data
    TriggerClientEvent("p_policejob/client/speedcam/removeCamera", -1, data.camName)
    TriggerClientEvent("p_policejob/client/speedcam/newCamera",    -1, data)
    Bridge.Notify.showNotify(playerSource, "Speed camera updated", "success")
end)

-- ============================================================
--  getSpeedcams callback
-- ============================================================

lib.callback.register("p_policejob/server/speedcam/getSpeedcams", function(playerSource)
    if not hasJobAccess(playerSource) then return {} end
    local list = {}
    for _, cam in pairs(Speedcam.cameras) do list[#list + 1] = cam end
    return list
end)

-- ============================================================
--  playerJoining — send camera list after brief delay
-- ============================================================

AddEventHandler("playerJoining", function()
    local playerSource = source
    Citizen.SetTimeout(500, function()
        local list = {}
        for _, cam in pairs(Speedcam.cameras) do list[#list + 1] = cam end
        TriggerClientEvent("p_policejob/client/speedcam/loadCameras", playerSource, list)
    end)
end)

-- ============================================================
--  Exports
-- ============================================================

exports("GetSpeedCams", function()
    local list = {}
    for _, cam in pairs(Speedcam.cameras) do list[#list + 1] = cam end
    return list
end)

exports("GetSpeedCamHits", function(_, camId, sinceUnix)
    sinceUnix = tonumber(sinceUnix)
    local result = {}
    for _, hit in ipairs(Speedcam.hits) do
        if camId and hit.camId ~= camId then goto continue end
        if sinceUnix and sinceUnix > hit.timeUnix then goto continue end
        result[#result + 1] = hit
        ::continue::
    end
    return result
end)
