-- Wait for Config to be available
while true do
    if Config and Config.Camera then break end
    Citizen.Wait(500)
end

if not Config.Camera.Enabled then return end

Camera = {}
Camera.isActive    = false
Camera.cameraProp  = nil
Camera.cameraState = false
Camera.antiSpam    = 0

-- ============================================================
--  Exports
-- ============================================================

exports("isCameraActive", function()
    return Camera.isActive
end)

-- ============================================================
--  Screenshot / capture helpers
--  (file-local; used by PolicePhotoCapture)
-- ============================================================

-- Asks the server how to upload (client-side or server-side).
-- Returns the resolved public URL string, or nil on failure.
local function capturePhoto()
    local uploadTarget = lib.callback.await("p_policejob/server/screenshot/uploadTarget", false)

    -- Server-side capture path (no ClientUpload configured)
    if not uploadTarget or not uploadTarget.clientUpload then
        return lib.callback.await("p_policejob/server/screenshotCapture", false)
    end

    -- Client-side upload path via screenshot-basic
    if GetResourceState("screenshot-basic") ~= "started" then
        print("[^1ERROR^7] [Camera] screenshot-basic is not started - photos cannot be captured. Install/start screenshot-basic or configure a server-side media provider.")
        return nil
    end

    local p      = promise.new()
    local settled = false

    local function resolve(value)
        if settled then return end
        settled = true
        p:resolve(value)
    end

    exports["screenshot-basic"].requestScreenshotUpload(
        uploadTarget.url,
        uploadTarget.field or "file",
        {
            encoding = uploadTarget.encoding or "jpg",
            quality  = uploadTarget.quality  or 0.85,
            headers  = uploadTarget.headers  or {},
        },
        function(rawResult)
            resolve(rawResult)
        end
    )

    -- 30-second timeout safety net
    SetTimeout(30000, function() resolve(nil) end)

    local rawUrl = Citizen.Await(p)
    if type(rawUrl) ~= "string" or rawUrl == "" then return nil end

    -- Ask server to validate / unwrap the upload response into a clean URL
    return lib.callback.await("p_policejob/server/screenshot/resolveUrl", false, rawUrl)
end

-- Public global used by the camera loop to take a photo safely.
function PolicePhotoCapture()
    local ok, result = pcall(capturePhoto)
    if not ok then
        print(("[^1ERROR^7] [Camera] Photo capture failed: %s"):format(tostring(result)))
        return nil
    end
    return result
end

-- ============================================================
--  Prop management
-- ============================================================

local function spawnCameraProp(show)
    if show then
        local model    = lib.requestModel("ch_prop_ch_camera_01")
        local animDict = lib.requestAnimDict("amb@world_human_paparazzi@male@base")

        TaskPlayAnim(cache.ped, animDict, "base", -8.0, 8.0, -1, 49, 1)

        local prop = CreateObject(model, GetEntityCoords(cache.ped), true, true, true)
        Camera.cameraProp = prop

        SetEntityAsMissionEntity(prop, true, true)

        local boneIndex = GetPedBoneIndex(cache.ped, 18905)
        AttachEntityToEntity(
            prop, cache.ped, boneIndex,
            0.03, -0.15, 0.13,
            24.8, 0.0, 132.0,
            true, true, false, false, 1, true
        )

        SetModelAsNoLongerNeeded(model)
        RemoveAnimDict(animDict)
    else
        ClearPedTasks(cache.ped)

        if Camera.cameraProp and DoesEntityExist(Camera.cameraProp) then
            -- Spin until we have network control, then delete
            while DoesEntityExist(Camera.cameraProp) do
                Citizen.Wait(1)
                NetworkRequestControlOfEntity(Camera.cameraProp)
                DeleteEntity(Camera.cameraProp)
                DeleteObject(Camera.cameraProp)
            end
        end
        Camera.cameraProp = nil
    end
end

-- ============================================================
--  Camera use (open viewfinder, handle input loop)
-- ============================================================

function Camera.use(self)
    -- Anti-spam guard
    if self.antiSpam > GetGameTimer() then return end

    -- Job access check (mirrors server-side CameraAccess config)
    local job = Bridge.Framework.fetchPlayerJob()
    if Config.Jobs then
        local minGrade = Config.Jobs[job.name]
        if minGrade and minGrade > job.grade then
            Bridge.Notify.showNotify(locale("camera_item_no_access"), "error")
            return
        end
    end

    self.antiSpam    = GetGameTimer() + 1000
    self.cameraState = true
    self.isActive    = true

    spawnCameraProp(true)
    Citizen.Wait(1500)

    -- Wait up to 10 s for the prop to exist (network lag)
    local attempts = 0
    while not (Camera.cameraProp and DoesEntityExist(Camera.cameraProp)) and attempts < 100 do
        Citizen.Wait(100)
        attempts = attempts + 1
    end

    if not (Camera.cameraProp and DoesEntityExist(Camera.cameraProp)) then
        self.cameraState = false
        self.isActive    = false
        return
    end

    -- Create scripted camera attached to the prop
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    AttachCamToEntity(cam, Camera.cameraProp, 0.0, -0.4, 0.0, true)
    SetCamRot(cam, GetEntityRotation(cache.ped, 2), 2)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    Config.Camera.onCameraStart()

    -- Input/render loop
    Citizen.CreateThread(function()
        while Camera.cameraState do
            -- Block movement and look inputs while in camera mode
            for _, control in ipairs({ 1, 2, 14, 15, 16, 17, 81, 82 }) do
                DisableControlAction(0, control, true)
            end

            local lookX   = GetDisabledControlNormal(0, 1)
            local lookY   = GetDisabledControlNormal(0, 2)
            local camRot  = GetCamRot(cam, 2)
            local pedHead = GetEntityHeading(cache.ped)

            -- Rotate camera and ped based on mouse input
            SetCamRot(cam, camRot.x - lookY * 3.0, 0.0, camRot.z - lookX * 3.0, 2)
            SetEntityHeading(cache.ped, pedHead - lookX * 1.5)

            -- Zoom in: scroll up / DPad up / W key
            local zoomIn = IsDisabledControlPressed(0, 15)
                or IsDisabledControlPressed(0, 241)
                or IsControlPressed(0, 172)
                or IsDisabledControlPressed(0, 172)

            -- Zoom out: scroll down / DPad down / S key
            local zoomOut = IsDisabledControlPressed(0, 14)
                or IsDisabledControlPressed(0, 242)
                or IsControlPressed(0, 173)
                or IsDisabledControlPressed(0, 173)

            if zoomIn then
                SetCamFov(cam, math.max(GetCamFov(cam) - 2.0, 10.0))
            elseif zoomOut then
                SetCamFov(cam, math.min(GetCamFov(cam) + 2.0, 65.0))
            end

            -- X / INPUT_FRONTEND_CANCEL — close camera without photo
            if IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73) then
                Camera.cameraState = false
                spawnCameraProp(false)
                RenderScriptCams(false, false, 0, true, true)
                DestroyCam(cam, false)
                Config.Camera.onCameraStop()
                Camera.isActive = false
            end

            -- ENTER / INPUT_FRONTEND_ACCEPT — take photo
            if IsControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 191) then
                Camera.cameraState = false
                local photoUrl = PolicePhotoCapture()
                if photoUrl then
                    TriggerServerEvent("p_policejob/server/camera/TakePhoto", photoUrl)
                    Bridge.Notify.showNotify(locale("photo_taken"), "success")
                else
                    Bridge.Notify.showNotify(locale("photo_failed"), "error")
                end
                RenderScriptCams(false, false, 0, true, true)
                DestroyCam(cam, false)
                spawnCameraProp(false)
                Config.Camera.onCameraStop()
                Camera.isActive = false
            end

            Citizen.Wait(0)
        end
    end)
end

-- ============================================================
--  Photo viewer
-- ============================================================

RegisterNetEvent("p_policejob/client/camera/ShowPhoto", function(photoUrl)
    SendNUIMessage({ action = "setPhotoData",    data = photoUrl })
    SendNUIMessage({ action = "setVisiblePhoto", data = true })
    SetNuiFocus(true, true)
end)

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if data and data.name == "setVisiblePhoto" then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = "setVisiblePhoto", data = false })
    end
end)

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("camera/copyPhoto", function(data, cb)
    if data and data.url then
        lib.setClipboard(data.url)
        Bridge.Notify.showNotify(locale("photo_copied"), "success")
    end
    cb("ok")
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/client/camera/CopyPhoto", function(photoUrl)
    lib.setClipboard(photoUrl)
    Bridge.Notify.showNotify(locale("photo_copied"), "success")
end)

RegisterNetEvent("p_policejob/client/camera/use", function()
    Camera:use()
end)
