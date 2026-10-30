while true do
    if Config and Config.Speedcam then break end
    Citizen.Wait(500)
end

if not Config.Speedcam.enabled then return end

Speedcam = {}
Speedcam.cameras = {}
Speedcam.placing = false

-- ============================================================
--  Access check (job + grade)
-- ============================================================

local function hasJobAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    local minGrade = job and Config.Jobs[job.name]
    if not minGrade then
        Bridge.Notify.showNotify(locale("no_access"), "error")
        return false
    end
    -- grade must be >= minGrade (original condition: not (grade < minGrade))
    if (job.grade or 0) < minGrade then
        Bridge.Notify.showNotify(locale("no_access"), "error")
        return false
    end
    return true
end

-- ============================================================
--  Speed unit multiplier (m/s → KMH or MPH)
-- ============================================================

local function getSpeedMultiplier()
    return Config.Speedcam.Unit == "KMH" and 3.6 or 2.236936
end

-- ============================================================
--  Normalise a sensor coordinate: vector3 / table / array
-- ============================================================

local function normaliseSensorCoord(raw)
    if type(raw) == "vector3" then return raw end
    local x = raw.x or raw[1]
    local y = raw.y or raw[2]
    local z = raw.z or raw[3]
    return vec3(x, y, z)
end

-- ============================================================
--  Destroy a camera entry (entity + blip + lib.points)
-- ============================================================

local function destroyCamera(camName)
    local cam = Speedcam.cameras[camName]
    if not cam then return end

    if cam.camObject and DoesEntityExist(cam.camObject) then
        DeleteEntity(cam.camObject)
    end

    if cam.blip and DoesBlipExist(cam.blip) then
        RemoveBlip(cam.blip)
    end

    if cam.sensorPoints then
        for _, point in ipairs(cam.sensorPoints) do
            point:remove()
        end
    end

    Speedcam.cameras[camName] = nil
end

-- ============================================================
--  Spawn a camera from its data table
-- ============================================================

local function spawnCamera(data)
    -- Normalise coords and sensors to plain tables so JSON encoding sends {x,y,z} objects
    -- (native vector3 types may serialise as arrays in some FiveM builds, causing coords.x == null in JS)
    if data.coords then
        data.coords = { x = data.coords.x + 0.0, y = data.coords.y + 0.0, z = data.coords.z + 0.0 }
    end
    if data.sensors then
        local normSensors = {}
        for _, s in ipairs(data.sensors) do
            normSensors[#normSensors + 1] = {
                x = (s.x or s[1]) + 0.0,
                y = (s.y or s[2]) + 0.0,
                z = (s.z or s[3]) + 0.0,
            }
        end
        data.sensors = normSensors
    end

    -- Guard: abort if another spawn of the same name already replaced this one
    local entry = {
        data         = data,
        sensorPoints = {},
    }
    Speedcam.cameras[data.camName] = entry

    -- Load model and spawn prop
    local model = lib.requestModel(data.modelName)

    -- Re-check we weren't replaced while loading
    if Speedcam.cameras[data.camName] ~= entry then return end

    local camObj = CreateObject(model, data.coords.x, data.coords.y, data.coords.z, 0, 1, 1)
    FreezeEntityPosition(camObj, true)
    PlaceObjectOnGroundProperly(camObj)
    SetEntityHeading(camObj, data.heading)
    SetModelAsNoLongerNeeded(model)
    entry.camObject = camObj

    -- Optional map blip
    if data.blipEnabled then
        local blipCfg = Config.Speedcam.Blip
        local blip    = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
        SetBlipSprite(blip, blipCfg.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, blipCfg.scale)
        SetBlipColour(blip, blipCfg.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(blipCfg.label)
        EndTextCommandSetBlipName(blip)
        entry.blip = blip
    end

    -- Per-camera cooldown (prevents double-triggering the same camera too fast)
    local recentlyCaught = false

    -- Called when triggered: play effects, report to server
    local function onCaught()
        if recentlyCaught then return end
        recentlyCaught = true

        -- Screen flash
        if data.screenEffect then
            Citizen.CreateThread(function()
                StartScreenEffect("DefaultFlash", 0, false)
                Citizen.Wait(500)
                StopScreenEffect("DefaultFlash")
            end)
        end

        -- Sound (delayed 500ms so flash is visible first)
        if Config.Speedcam.Sound.enabled then
            Citizen.SetTimeout(500, function()
                Sounds:playSound("speedcam", Config.Speedcam.Sound.volume)
            end)
        end

        -- Report to server
        local mult        = getSpeedMultiplier()
        local currentSpeed = math.floor(GetEntitySpeed(cache.vehicle) * mult)
        TriggerServerEvent("p_policejob/server/speedcam/playerCaught", {
            cameraData   = data,
            speed        = currentSpeed,
            playerCoords = GetEntityCoords(cache.ped),
        })

        -- Re-arm after 30 s
        SetTimeout(30000, function() recentlyCaught = false end)
    end

    -- Returns true when the player should be detected by this sensor
    local function shouldDetect()
        if recentlyCaught then return false end
        if not cache.vehicle or cache.vehicle == 0 then return false end
        if cache.seat ~= -1 then return false end  -- must be the driver

        local mult         = getSpeedMultiplier()
        local currentSpeed = math.floor(GetEntitySpeed(cache.vehicle) * mult)
        if currentSpeed < data.speedLimit then return false end

        -- Check job ignore list
        local job = Bridge.Framework.fetchPlayerJob()
        if job and Config.Speedcam.IgnoredJobs[job.name] then return false end

        return true
    end

    -- Attach lib.points proximity detection for each sensor
    for _, rawCoord in ipairs(data.sensors) do
        local coord = normaliseSensorCoord(rawCoord)
        local point = lib.points.new({ coords = coord, distance = data.camDistance })

        function point.nearby()
            if shouldDetect() then onCaught() end
        end

        entry.sensorPoints[#entry.sensorPoints + 1] = point
    end
end

-- ============================================================
--  Creator command  (/speedcam_creator)
-- ============================================================

local function openCreator()
    if Speedcam.placing then return end
    if not hasJobAccess() then return end

    -- Build model options list
    local modelOptions = {}
    for modelName, label in pairs(Config.Speedcam.Models) do
        modelOptions[#modelOptions + 1] = { value = modelName, label = label }
    end

    -- Input dialog
    local result = lib.inputDialog(locale("speed_cam_creator"), {
        { type = "select",   label = "Camera Model",       options = modelOptions, required = true  },
        { type = "input",    label = "Camera Name",                                required = true  },
        { type = "number",   label = "Speed Limit (KMH)",  min = 1,    default = 100, required = true },
        { type = "number",   label = "Detection Distance", min = 1,    default = 50,  required = true },
        { type = "number",   label = "Fine Amount",        min = 0,    default = 500, required = true },
        { type = "checkbox", label = "Fine Multiplier"                                               },
        { type = "checkbox", label = "Show Blip"                                                     },
        { type = "checkbox", label = "Screen Flash",       checked = true                            },
        { type = "checkbox", label = "Light Effect",       checked = true                            },
    })
    if not result then return end

    local modelName, camName, speedLimit, camDistance, fine,
          fineMultiplier, blipEnabled, screenEffect, lightEffect =
        result[1], result[2], result[3], result[4], result[5],
        result[6], result[7], result[8], result[9]

    -- Require object_gizmo for placement
    if GetResourceState("object_gizmo") ~= "started" then
        Bridge.Notify.showNotify("object_gizmo resource is not started", "error")
        return
    end

    -- Spawn preview object
    local previewModel = lib.requestModel(modelName)
    local previewCoords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.0, 0.0)
    local previewObj    = CreateObject(previewModel, previewCoords.x, previewCoords.y, previewCoords.z, false, false, false)
    SetEntityHeading(previewObj, GetEntityHeading(cache.ped))
    SetEntityCollision(previewObj, false, false)
    PlaceObjectOnGroundProperly(previewObj)
    SetModelAsNoLongerNeeded(previewModel)

    -- Let officer position with gizmo
    Speedcam.placing = true
    local confirmed  = exports.object_gizmo:useGizmo(previewObj)
    Speedcam.placing = false

    if not confirmed or not DoesEntityExist(previewObj) then
        if DoesEntityExist(previewObj) then DeleteEntity(previewObj) end
        return
    end

    local finalCoords  = GetEntityCoords(previewObj)
    local finalHeading = GetEntityHeading(previewObj)
    DeleteEntity(previewObj)
    Citizen.Wait(500)

    -- Sensor placement loop
    local sensorResult = lib.inputDialog("Set Sensors", {
        { type = "number", label = "Number of Sensors", min = 1, default = 1, required = true },
    })
    if not sensorResult then return end

    local numSensors = sensorResult[1]
    local sensors    = {}

    Speedcam.placing = true

    -- Shows the textUI hint while placing sensors
    local function updateHint()
        lib.showTextUI(locale("speedcam_sensor_help", #sensors + 1, numSensors), {
            position = "top-center",
            icon     = "road",
        })
    end

    updateHint()

    while Speedcam.placing and numSensors > #sensors do
        Citizen.Wait(0)

        local hit, _, hitCoords = lib.raycast.fromCamera(511)
        if hit then
            -- Draw line from ped to hit point
            local pedCoords = GetEntityCoords(cache.ped)
            DrawLine(pedCoords, hitCoords, 255, 255, 255, 100)
            -- Draw placement marker
            DrawMarker(28, hitCoords, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                0.1, 0.1, 0.1, 2, 255, 255, 255, false, true, 2, nil, nil, false)

            -- E (control 38) to confirm sensor position
            if IsControlJustPressed(0, 38) then
                sensors[#sensors + 1] = hitCoords
                Bridge.Notify.showNotify(locale("speedcam_sensor_placed", #sensors, numSensors), "success")

                if numSensors <= #sensors then break end
                updateHint()
                Citizen.Wait(500)
            end
        end

        -- Backspace (control 73) to cancel
        if IsControlJustPressed(0, 73) then
            Speedcam.placing = false
            lib.hideTextUI()
            Bridge.Notify.showNotify(locale("speedcam_placement_cancelled"), "error")
            return
        end
    end

    Speedcam.placing = false
    lib.hideTextUI()

    TriggerServerEvent("p_policejob/server/speedcam/createSpeedcam", {
        coords        = finalCoords,
        heading       = finalHeading,
        modelName     = modelName,
        camName       = camName,
        speedLimit    = speedLimit,
        camDistance   = camDistance,
        fine          = fine,
        fineMultiplier = fineMultiplier,
        blipEnabled   = blipEnabled,
        screenEffect  = screenEffect,
        lightEffect   = lightEffect,
        sensors       = sensors,
    })
end

RegisterCommand("speedcam_creator", openCreator)

-- ============================================================
--  Manager command  (/speedcam_manager)
-- ============================================================

RegisterCommand("speedcam_manager", function()
    if not hasJobAccess() then return end
    SendNUIMessage({ action = "setVisibleSpeedcamManager", data = true })
    SetNuiFocus(true, true)
end)

-- ============================================================
--  Net events
-- ============================================================

-- Full sync: destroy all local cameras and respawn from server list.
RegisterNetEvent("p_policejob/client/speedcam/loadCameras", function(cameraList)
    -- Collect existing names and destroy them
    local existing = {}
    for name in pairs(Speedcam.cameras) do existing[#existing + 1] = name end
    for _, name in ipairs(existing) do destroyCamera(name) end

    Speedcam.cameras = {}

    for _, data in ipairs(cameraList) do
        spawnCamera(data)
    end
end)

-- New camera added by an officer
RegisterNetEvent("p_policejob/client/speedcam/newCamera", spawnCamera)

-- Camera removed
RegisterNetEvent("p_policejob/client/speedcam/removeCamera", function(camName)
    destroyCamera(camName)
end)

-- Light effect: flash a spotlight from camera toward the player's position
RegisterNetEvent("p_policejob/client/speedcam/syncLight", function(data)
    Citizen.Wait(1)

    local camCoords    = vec3(data.cameraData.coords.x, data.cameraData.coords.y, data.cameraData.coords.z)
    local playerCoords = vec3(data.playerCoords.x, data.playerCoords.y, data.playerCoords.z)
    local direction    = playerCoords - camCoords

    -- Phase 1: 50 frames of spotlight
    local frame1 = 0
    Citizen.CreateThread(function()
        while frame1 < 50 do
            Citizen.Wait(1)
            DrawSpotLight(
                camCoords.x, camCoords.y, camCoords.z + 2.0,
                direction.x, direction.y, direction.z,
                221, 221, 221, 70.0, 100.0, 4.3, 25.0, 28.6)
            frame1 = frame1 + 1
        end

        Citizen.Wait(10)

        -- Phase 2: 10 more frames (brief fade)
        local frame2 = 0
        Citizen.CreateThread(function()
            while frame2 < 10 do
                Citizen.Wait(1)
                DrawSpotLight(
                    camCoords.x, camCoords.y, camCoords.z + 2.0,
                    direction.x, direction.y, direction.z,
                    221, 221, 221, 70.0, 100.0, 4.3, 25.0, 28.6)
                frame2 = frame2 + 1
            end
        end)
    end)
end)

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("speedcam/close", function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibleSpeedcamManager", data = false })
    cb("ok")
end)

RegisterNUICallback("speedcam/getAll", function(_, cb)
    local list = {}
    for _, cam in pairs(Speedcam.cameras) do
        local d = cam.data
        -- Ensure coords and sensors are plain tables (not native vector types)
        -- so they serialise correctly for the JS UI
        local safe = {}
        for k, v in pairs(d) do safe[k] = v end
        if safe.coords then
            safe.coords = {
                x = (safe.coords.x or safe.coords[1] or 0) + 0.0,
                y = (safe.coords.y or safe.coords[2] or 0) + 0.0,
                z = (safe.coords.z or safe.coords[3] or 0) + 0.0,
            }
        end
        if safe.sensors then
            local ns = {}
            for _, s in ipairs(safe.sensors) do
                ns[#ns + 1] = {
                    x = (s.x or s[1] or 0) + 0.0,
                    y = (s.y or s[2] or 0) + 0.0,
                    z = (s.z or s[3] or 0) + 0.0,
                }
            end
            safe.sensors = ns
        end
        list[#list + 1] = safe
    end
    cb(list)
end)

RegisterNUICallback("speedcam/remove", function(data, cb)
    TriggerServerEvent("p_policejob/server/speedcam/removeSpeedcam", data.camName)
    cb(true)
end)

RegisterNUICallback("speedcam/teleport", function(data, cb)
    local cam = Speedcam.cameras[data.camName]
    if cam then
        local coords = cam.data.coords
        SetEntityCoords(cache.ped, coords.x, coords.y, coords.z + 1.0)
        SetEntityHeading(cache.ped, 0.0)
    end
    cb(true)
end)

RegisterNUICallback("speedcam/updateSpeedcam", function(data, cb)
    TriggerServerEvent("p_policejob/server/speedcam/updateSpeedcam", data)
    cb(true)
end)

-- ============================================================
--  On load: request cameras from server
-- ============================================================

Citizen.CreateThread(function()
    TriggerServerEvent("p_policejob/server/speedcam/loadCameras")
end)

-- ============================================================
--  Export
-- ============================================================

exports("GetSpeedCams", function()
    local list = {}
    for _, cam in pairs(Speedcam.cameras) do
        list[#list + 1] = cam.data
    end
    return list
end)
