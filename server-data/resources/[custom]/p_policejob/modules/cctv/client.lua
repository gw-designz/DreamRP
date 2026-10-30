-- Wait for Config.CCTV to be available
while true do
    if Config and Config.CCTV then break end
    Citizen.Wait(1)
end

if not Config.CCTV.enabled then return end

-- Global CCTV object shared across the resource
CCTV = {}
CCTV.cameras  = {}   -- [id] = camData
CCTV.points   = {}   -- [id] = lib.points handle
CCTV.objects  = {}   -- [id] = entity handle
CCTV.watching = false
CCTV.curCam   = nil
CCTV.rotX     = 0.0
CCTV.rotZ     = 0.0

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Returns true if the local player's job name is in the given jobs list
function PlayerJobInList(jobsList)
    local playerJob = Bridge.Framework.fetchPlayerJob()
    if not playerJob then return false end

    for _, jobName in ipairs(jobsList) do
        if playerJob.name == jobName then return true end
    end

    return false
end

-- Returns the street name string for the given vector3 coords
function GetStreetAtCoords(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(streetHash)
end

-- Converts a rotation vector3 (in degrees) to a normalised forward direction vector3
function RotationToForwardVector(rotation)
    local radX = math.rad(rotation.x)
    local radZ = math.rad(rotation.z)
    local cosX  = math.cos(radX)
    return vector3(
        -math.sin(radZ) * cosX,
         math.cos(radZ) * cosX,
         math.sin(radX)
    )
end

-- ─── Prop / Point Management ─────────────────────────────────────────────────

-- Spawns (or respawns) the physical camera prop for camData.
-- Deletes any existing prop for that id first, then creates, rotates, and freezes it.
function SpawnCameraObject(camData)
    -- Delete existing prop for this camera id if present
    local existingEntity = CCTV.objects[camData.id]
    if existingEntity and DoesEntityExist(existingEntity) then
        DeleteEntity(existingEntity)
    end

    if not lib.requestModel(camData.model, 5000) then return nil end

    local entity = CreateObject(
        camData.model,
        camData.coords.x, camData.coords.y, camData.coords.z,
        false, false, false
    )

    SetEntityRotation(entity, camData.rotation.x, camData.rotation.y, camData.rotation.z, 2, true)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, true, false)
    SetModelAsNoLongerNeeded(camData.model)

    CCTV.objects[camData.id] = entity
    return entity
end

-- Deletes the prop entity for the given camera id and removes it from the table
function DeleteCameraObject(cameraId)
    local entity = CCTV.objects[cameraId]
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
        CCTV.objects[cameraId] = nil
    end
end

-- Creates a lib.points proximity point for camData.
-- Spawns the prop on enter and deletes it on exit.
function RegisterCameraPoint(camData)
    -- Remove existing point if any
    local existing = CCTV.points[camData.id]
    if existing then existing:remove() end

    local point = lib.points.new({
        coords   = vector3(camData.coords.x, camData.coords.y, camData.coords.z),
        distance = Config.CCTV.loadDistance,
        camData  = camData,
    })

    point.onEnter = function(self)
        SpawnCameraObject(self.camData)
    end

    point.onExit = function(self)
        DeleteCameraObject(self.camData.id)
    end

    CCTV.points[camData.id] = point
end

-- Removes the proximity point and prop for the given camera id
function RemoveCameraPoint(cameraId)
    local point = CCTV.points[cameraId]
    if point then
        point:remove()
        CCTV.points[cameraId] = nil
    end
    DeleteCameraObject(cameraId)
end

-- ─── CCTV Methods ────────────────────────────────────────────────────────────

-- Registers all cameras in the provided list into CCTV.cameras and creates their points
function CCTV:LoadCameras(cameraList)
    for _, camData in pairs(cameraList) do
        self.cameras[camData.id] = camData
        RegisterCameraPoint(camData)
    end
end

-- Adds a single camera to the local registry and registers its proximity point
function CCTV:AddCamera(camData)
    self.cameras[camData.id] = camData
    RegisterCameraPoint(camData)
end

-- Removes a single camera from the local registry and cleans up its point and prop
function CCTV:RemoveCamera(cameraId)
    self.cameras[cameraId] = nil
    RemoveCameraPoint(cameraId)
end

-- Updates a camera's data in the local registry.
-- Also updates the stored camData on the point so the next enter/exit uses fresh data.
function CCTV:UpdateCamera(camData)
    self.cameras[camData.id] = camData
    local point = self.points[camData.id]
    if point then
        point.camData = camData
    end
end

-- Opens the camera creator dialog: prompts for name, model, and job access,
-- spawns a preview object, lets the player position it with object_gizmo,
-- then fires a server event to persist the camera.
function CCTV:Creator()
    if not PlayerJobInList(Config.CCTV.creatorAccess) then
        lib.notify({ title = locale("camera_no_access"), type = "error" })
        return
    end

    -- Build model dropdown options
    local modelOptions = {}
    for _, modelEntry in ipairs(Config.CCTV.models) do
        table.insert(modelOptions, { value = modelEntry.model, label = modelEntry.label })
    end

    -- Build job multi-select options
    local jobOptions = {}
    for _, jobName in ipairs(Config.CCTV.defaultJobs) do
        table.insert(jobOptions, { value = jobName, label = jobName:upper() })
    end

    local input = lib.inputDialog(locale("camera_creator"), {
        { type = "input",        label = locale("camera_name"),  placeholder = locale("camera_name_info"), required = true },
        { type = "select",       label = locale("camera_model"), options = modelOptions,                   required = true },
        { type = "multi-select", label = locale("camera_job"),   options = jobOptions,                     required = true },
    })

    if not input then return end

    local cameraName  = input[1]
    local cameraModel = input[2]
    local cameraJobs  = input[3]

    -- Place preview prop 3 units in front and 2 units above the player
    local ped           = cache.ped
    local pedCoords     = GetEntityCoords(ped)
    local pedHeading    = GetEntityHeading(ped)
    local forwardVec    = GetEntityForwardVector(ped)
    local spawnCoords   = vector3(
        (pedCoords + forwardVec * 3.0).x,
        (pedCoords + forwardVec * 3.0).y,
        pedCoords.z + 2.0
    )

    if not lib.requestModel(cameraModel, 5000) then
        lib.notify({ title = locale("camera_model_info"), type = "error" })
        return
    end

    local previewEntity = CreateObject(cameraModel, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false)
    SetEntityHeading(previewEntity, pedHeading)
    SetEntityCollision(previewEntity, false, false)
    FreezeEntityPosition(previewEntity, true)
    SetModelAsNoLongerNeeded(cameraModel)

    -- Let the player position the object with the gizmo
    local confirmed = exports.object_gizmo:useGizmo(previewEntity)

    if not confirmed then
        if DoesEntityExist(previewEntity) then DeleteEntity(previewEntity) end
        return
    end

    local finalCoords   = GetEntityCoords(previewEntity)
    local finalRotation = GetEntityRotation(previewEntity, 2)

    if DoesEntityExist(previewEntity) then DeleteEntity(previewEntity) end

    TriggerServerEvent("p_policejob/server/cctv/create", {
        name     = cameraName,
        model    = cameraModel,
        coords   = { x = finalCoords.x,   y = finalCoords.y,   z = finalCoords.z   },
        rotation = { x = finalRotation.x, y = finalRotation.y, z = finalRotation.z },
        jobs     = cameraJobs,
    })
end

-- Activates the scripted CCTV camera view for the given camData table { id }.
-- Handles job checking, broken-state guard, optional ped teleport (for distant cameras),
-- camera creation, rotation input loop, then full cleanup on exit.
function CCTV:WatchCamera(camData)
    if not (camData and camData.id) then return end

    local cam = self.cameras[camData.id]
    if not cam then
        lib.notify({ title = locale("cctv_not_found"), type = "error" })
        return
    end

    if not PlayerJobInList(cam.jobs) then
        lib.notify({ title = locale("camera_no_access"), type = "error" })
        return
    end

    if cam.broken then
        lib.notify({ title = locale("cctv_no_signal"), type = "error" })
        return
    end

    -- Set watching state
    self.watching = true
    self.curCam   = cam
    self.rotX     = 0.0
    self.rotZ     = 0.0

    -- Compute forward direction from the camera's rotation
    local forwardDir = RotationToForwardVector(vector3(cam.rotation.x, cam.rotation.y, cam.rotation.z))

    -- Calculate camera placement offset based on model dimensions
    local cameraOffset = Config.CCTV.cameraOffset or 0.5

    local modelHash
    if type(cam.model) == "number" then
        modelHash = cam.model
    else
        modelHash = GetHashKey(cam.model)
    end

    -- Request model to read dimensions (with 2 second timeout)
    if not HasModelLoaded(modelHash) then
        RequestModel(modelHash)
        local elapsed = 0
        while not HasModelLoaded(modelHash) and elapsed < 2000 do
            Wait(50)
            elapsed = elapsed + 50
        end
    end

    if HasModelLoaded(modelHash) then
        local _, maxDim = GetModelDimensions(modelHash)
        cameraOffset = maxDim.y - 0.5
    end

    local camCoords    = vec3(cam.coords.x, cam.coords.y, cam.coords.z)
    local scriptCamPos = camCoords + forwardDir * cameraOffset

    local ped          = cache.ped
    local pedCoords    = GetEntityCoords(ped)
    local distanceToCam = #(pedCoords - vector3(cam.coords.x, cam.coords.y, cam.coords.z))
    local teleportDistance = Config.CCTV.teleportDistance or 100.0
    local didTeleport  = false

    DoScreenFadeOut(500)
    Wait(500)

    -- If far away, hide and teleport the ped under the camera
    if distanceToCam > teleportDistance then
        didTeleport = true
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        SetLocalPlayerInvisibleLocally(true)
        SetPlayerInvincible(cache.playerId, true)
        NetworkSetEntityInvisibleToNetwork(ped, true)

        SetEntityCoords(ped, cam.coords.x, cam.coords.y, cam.coords.z - 1.0, false, false, false, false)
        RequestCollisionAtCoord(cam.coords.x, cam.coords.y, cam.coords.z)

        local collisionWait = 0
        while not HasCollisionLoadedAroundEntity(ped) and collisionWait < 5000 do
            Wait(50)
            collisionWait = collisionWait + 50
        end
    end

    -- Create and configure the scripted camera
    local scriptCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(scriptCam, scriptCamPos.x, scriptCamPos.y, scriptCamPos.z)
    SetCamRot(scriptCam, cam.rotation.x, cam.rotation.y, cam.rotation.z - 180.0, 2)
    SetCamFov(scriptCam, 70.0)
    RenderScriptCams(true, false, 0, true, true)

    StartScreenEffect(Config.CCTV.screenEffect.name, 0, Config.CCTV.screenEffect.looped)

    -- Send camera info to NUI
    SendNUIMessage({
        action = "setCCTVData",
        data   = {
            name   = cam.name,
            street = GetStreetAtCoords(vector3(cam.coords.x, cam.coords.y, cam.coords.z)),
            locales = {
                rec    = locale("cctv_rec"),
                cam    = locale("cctv_cam"),
                loc    = locale("cctv_loc"),
                signal = locale("cctv_signal"),
                live   = locale("cctv_live"),
                up     = locale("cctv_up"),
                down   = locale("cctv_down"),
                left   = locale("cctv_left"),
                right  = locale("cctv_right"),
                exit   = locale("cctv_exit"),
            },
        },
    })
    SendNUIMessage({ action = "setVisibleCCTV", data = true })
    DoScreenFadeIn(500)

    -- Base rotation values (camera's own rotation, Z offset by -180)
    local baseRotX    = cam.rotation.x
    local baseRotZ    = cam.rotation.z - 180.0
    local rotConfig   = Config.CCTV.cameraRotation

    -- ── Input Loop ────────────────────────────────────────────────────────────
    while self.watching do
        Wait(0)
        HideHudAndRadarThisFrame()
        DisableAllControlActions(0)

        -- Up arrow: tilt up (increase pitch)
        if IsDisabledControlPressed(0, 172) then
            self.rotX = math.min(self.rotX + rotConfig.speed, rotConfig.maxPitch)
            SetCamRot(scriptCam, baseRotX + self.rotX, cam.rotation.y, baseRotZ + self.rotZ, 2)
        end

        -- Down arrow: tilt down (decrease pitch)
        if IsDisabledControlPressed(0, 173) then
            self.rotX = math.max(self.rotX - rotConfig.speed, rotConfig.minPitch)
            SetCamRot(scriptCam, baseRotX + self.rotX, cam.rotation.y, baseRotZ + self.rotZ, 2)
        end

        -- Left arrow: pan left (increase Z offset); wrap at +180
        if IsDisabledControlPressed(0, 174) then
            self.rotZ = self.rotZ + rotConfig.speed
            if self.rotZ > 180.0 then self.rotZ = self.rotZ - 360.0 end
            SetCamRot(scriptCam, baseRotX + self.rotX, cam.rotation.y, baseRotZ + self.rotZ, 2)
        end

        -- Right arrow: pan right (decrease Z offset); wrap at -180
        if IsDisabledControlPressed(0, 175) then
            self.rotZ = self.rotZ - rotConfig.speed
            if self.rotZ < -180.0 then self.rotZ = self.rotZ + 360.0 end
            SetCamRot(scriptCam, baseRotX + self.rotX, cam.rotation.y, baseRotZ + self.rotZ, 2)
        end

        -- Space (control 73): exit
        if IsDisabledControlJustPressed(0, 73) then
            self.watching = false
        end
    end

    -- ── Cleanup ───────────────────────────────────────────────────────────────
    SendNUIMessage({ action = "setVisibleCCTV", data = false })
    StopScreenEffect(Config.CCTV.screenEffect.name)
    DoScreenFadeOut(500)
    Wait(1100)

    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(scriptCam, false)

    -- Restore ped if it was teleported
    if didTeleport then
        SetEntityCoords(ped, pedCoords.x, pedCoords.y, pedCoords.z, false, false, false, false)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        SetLocalPlayerInvisibleLocally(false)
        SetPlayerInvincible(cache.playerId, false)
        NetworkSetEntityInvisibleToNetwork(ped, false)
    end

    DoScreenFadeIn(500)
    self.curCam = nil
end

-- Opens the CCTV selection context menu, listing all cameras the player's job can access.
-- Broken cameras show a warning prefix and a video-slash icon.
function CCTV:OpenMenu()
    if not PlayerJobInList(Config.CCTV.defaultJobs) then
        lib.notify({ title = locale("camera_no_access"), type = "error" })
        return
    end

    local menuOptions = {}
    for cameraId, camData in pairs(self.cameras) do
        if PlayerJobInList(camData.jobs) then
            local streetName  = GetStreetAtCoords(vector3(camData.coords.x, camData.coords.y, camData.coords.z))
            local brokenPrefix = camData.broken and ("~r~[" .. locale("cctv_broken") .. "]~s~ ") or ""
            local icon         = camData.broken and "video-slash" or "video"

            table.insert(menuOptions, {
                title       = brokenPrefix .. camData.name,
                description = locale("watch_camera", camData.name, streetName),
                icon        = icon,
                onSelect    = function()
                    CCTV:WatchCamera({ id = cameraId })
                end,
            })
        end
    end

    if #menuOptions == 0 then
        lib.notify({ title = locale("cctv_no_cameras"), type = "error" })
        return
    end

    lib.registerContext({ id = "cctv_menu", title = locale("cameras_menu"), options = menuOptions })
    lib.showContext("cctv_menu")
end

-- Prompts a creator-access player to confirm deletion of a specific camera,
-- then fires the server delete event
function CCTV:DeleteCamera(cameraId)
    if not PlayerJobInList(Config.CCTV.creatorAccess) then
        lib.notify({ title = locale("camera_no_access"), type = "error" })
        return
    end

    local result = lib.alertDialog({
        header   = locale("cctv_delete_confirm"),
        content  = locale("cctv_delete_confirm_desc"),
        centered = true,
        cancel   = true,
    })

    if result == "confirm" then
        TriggerServerEvent("p_policejob/server/cctv/delete", cameraId)
    end
end

-- ─── Net Events ──────────────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/client/cctv/load", function(cameraList)
    CCTV:LoadCameras(cameraList)
end)

RegisterNetEvent("p_policejob/client/cctv/add", function(camData)
    CCTV:AddCamera(camData)
end)

RegisterNetEvent("p_policejob/client/cctv/remove", function(cameraId)
    CCTV:RemoveCamera(cameraId)
end)

RegisterNetEvent("p_policejob/client/cctv/update", function(camData)
    CCTV:UpdateCamera(camData)
end)

RegisterNetEvent("p_policejob/client/cctv/creator", function()
    CCTV:Creator()
end)

RegisterNetEvent("p_policejob/client/cctv/menu", function()
    CCTV:OpenMenu()
end)

-- Updates the broken state on the local camera record.
-- If the player is currently watching the broken camera, kicks them out.
RegisterNetEvent("p_policejob/client/cctv/broken", function(cameraId, isBroken)
    local cam = CCTV.cameras[cameraId]
    if cam then cam.broken = isBroken end

    if CCTV.watching and CCTV.curCam and CCTV.curCam.id == cameraId and isBroken then
        CCTV.watching = false
        lib.notify({ title = locale("cctv_no_signal"), type = "error" })
    end
end)

-- ─── Weapon Damage Detection Thread ──────────────────────────────────────────

-- Fires when the player equips a weapon. If CCTV damage is enabled, spawns a
-- thread that detects shooting at camera props and reports it to the server.
lib.onCache("weapon", function(weaponHash)
    if not (weaponHash and Config.CCTV.damage and Config.CCTV.damage.enabled) then return end

    Citizen.CreateThread(function()
        while cache.weapon == weaponHash do
            Wait(0)

            if IsPedShooting(cache.ped) then
                local shooterCoords = GetEntityCoords(cache.ped)
                local _, aimedEntity = GetEntityPlayerIsFreeAimingAt(cache.playerId)

                if aimedEntity and DoesEntityExist(aimedEntity) then
                    -- Check if the aimed entity is one of our spawned camera props
                    for cameraId, propEntity in pairs(CCTV.objects) do
                        if propEntity == aimedEntity then
                            local camData = CCTV.cameras[cameraId]
                            if camData and not camData.broken then
                                TriggerServerEvent("p_policejob/server/cctv/damage", cameraId)
                            end
                            break
                        end
                    end
                end
            end

            Wait(100)
        end
    end)
end)

-- ─── Init Thread ─────────────────────────────────────────────────────────────

-- Wait a moment then ask the server to send the full camera list
Citizen.CreateThread(function()
    Wait(1000)
    TriggerServerEvent("p_policejob/server/cctv/request")
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("cctvCreator", function()
    CCTV:Creator()
end)

exports("cctvMenu", function()
    CCTV:OpenMenu()
end)

exports("cctvWatch", function(camData)
    CCTV:WatchCamera(camData)
end)

exports("GetCameras", function()
    return CCTV.cameras
end)

-- Returns false + reason string if the camera doesn't exist or is broken,
-- otherwise starts watching and returns true + "watching"
exports("ActivateCameraSpectator", function(rawId)
    local cameraId = tonumber(rawId)
    if not (cameraId and CCTV.cameras[cameraId]) then
        return false, "camera_not_found"
    end
    if CCTV.cameras[cameraId].broken then
        return false, "camera_broken"
    end
    CCTV:WatchCamera({ id = cameraId })
    return true, "watching"
end)

-- ─── Commands ────────────────────────────────────────────────────────────────

RegisterCommand("cctv_creator", function()
    CCTV:Creator()
end, false)
