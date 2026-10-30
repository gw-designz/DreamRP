--[[
    The Camera app's photo mode. The laptop closes, the player raises a
    camera and looks through it; a click asks the server to take the screen
    and upload it to their memory card (server/news.lua). The viewfinder is
    hidden until the server answers, so it is never in the photo.
]]

Camera = {}

local HINTS = { { 24, 'Take photo' }, { 241, 'Zoom' }, { 200, 'Put the camera away' } }
local DICT, CLIP, PROP = 'amb@world_human_paparazzi@male@base', 'base', 'prop_pap_camera_01'
local active, capturing = false, nil

local function notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function load(request, loaded, name)
    request(name)
    local deadline = GetGameTimer() + 4000
    while not loaded(name) and GetGameTimer() < deadline do Wait(20) end
    return loaded(name)
end

--- Corner marks and a centre cross, like a camera's viewfinder.
local function viewfinder()
    local w, h, t, l = 0.06, 0.1, 0.002, 0.15
    for _, c in ipairs({ { l, l }, { 1 - l, l }, { l, 1 - l }, { 1 - l, 1 - l } }) do
        local sx, sy = c[1] < 0.5 and 1 or -1, c[2] < 0.5 and 1 or -1
        DrawRect(c[1] + sx * w / 2, c[2], w, t * 1.6, 255, 255, 255, 200)
        DrawRect(c[1], c[2] + sy * h / 2, t, h, 255, 255, 255, 200)
    end
    DrawRect(0.5, 0.5, 0.012, t * 1.6, 255, 255, 255, 160)
    DrawRect(0.5, 0.5, t, 0.02, 255, 255, 255, 160)
end

function Camera.active() return active end

function Camera.start()
    if active then return end
    active = true
    CreateThread(function()
        local ped = PlayerPedId()
        local prop
        if load(RequestAnimDict, HasAnimDictLoaded, DICT) then
            TaskPlayAnim(ped, DICT, CLIP, 3.0, 3.0, -1, 49, 0, false, false, false)
            RemoveAnimDict(DICT)
        end
        local model = GetHashKey(PROP)
        if IsModelInCdimage(model) and load(RequestModel, HasModelLoaded, model) then
            local at = GetEntityCoords(ped)
            prop = CreateObject(model, at.x, at.y, at.z, false, false, false)
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(model)
        end

        local rot = GetGameplayCamRot(2)
        local pitch, heading, fov = rot.x, rot.z, 50.0
        local eye = GetPedBoneCoords(ped, 31086, 0.1, 0.05, 0.0)
        local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', eye.x, eye.y, eye.z, pitch, 0.0, heading, fov, true, 2)
        RenderScriptCams(true, false, 0, true, true)

        local cooldown = 0
        while active do
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true) -- push to talk
            HideHudAndRadarThisFrame()
            SetEntityLocallyInvisible(ped)
            if prop then SetEntityLocallyInvisible(prop) end

            local turn = fov / 50.0
            heading = heading - GetDisabledControlNormal(0, 1) * 8.0 * turn
            pitch = math.max(-70.0, math.min(70.0, pitch - GetDisabledControlNormal(0, 2) * 8.0 * turn))
            if IsDisabledControlJustPressed(0, 241) then fov = math.max(12.0, fov - 4.0) end
            if IsDisabledControlJustPressed(0, 242) then fov = math.min(70.0, fov + 4.0) end
            SetEntityHeading(ped, heading)
            eye = GetPedBoneCoords(ped, 31086, 0.1, 0.05, 0.0)
            SetCamCoord(cam, eye.x, eye.y, eye.z)
            SetCamRot(cam, pitch, 0.0, heading, 2)
            SetCamFov(cam, fov)

            if not capturing then
                viewfinder()
                Hints.draw(HINTS)
                if IsDisabledControlJustPressed(0, 24) and GetGameTimer() > cooldown then
                    local token = GetGameTimer()
                    capturing, cooldown = token, token + 1500
                    Hints.hide()
                    PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_Soundset_Franklin', true)
                    -- A clean frame or two first, without the viewfinder.
                    SetTimeout(120, function() TriggerServerEvent('nova_laptop:server:photo') end)
                    SetTimeout(10000, function() if capturing == token then capturing = nil end end)
                end
            end

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202) or IsDisabledControlJustPressed(0, 177)
                or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
                active = false
            end
            Wait(0)
        end

        Hints.swallowPause()
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
        StopAnimTask(ped, DICT, CLIP, 2.0)
        capturing = nil
    end)
end

function Camera.stop() active = false end

RegisterNetEvent('nova_laptop:client:photoTaken', function(ok, message)
    capturing = nil
    notify(ok and 'Saved to your memory card.' or (message or 'The photo did not save.'))
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and active then
        active = false
        RenderScriptCams(false, false, 0, true, true)
    end
end)
