-- /police_tablet — put one down where you stand. "/police_tablet undo" removes the last one.
-- Added by THE ORB Studio's 3D Model → FiveM. Delete this file (and the
-- client_script line in fxmanifest.lua) if you place props another way.
local placed = {}

RegisterCommand("police_tablet", function(_, args)
    if args[1] == "undo" then
        local last = table.remove(placed)
        if last and DoesEntityExist(last) then DeleteEntity(last) end
        return
    end
    local model = `police_tablet`
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 200 do Wait(10) tries = tries + 1 end
    if not HasModelLoaded(model) then return end
    local ped = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    local obj = CreateObject(model, pos.x, pos.y, pos.z, true, false, false)
    PlaceObjectOnGroundProperly(obj)
    SetEntityHeading(obj, GetEntityHeading(ped))
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(model)
    placed[#placed + 1] = obj
end, false)

-- /<prop>_view: look at the prop up close. Drag with the left mouse button
-- (or W/A/S/D) to rotate it, mouse wheel to zoom, Esc or Backspace to leave.
-- G opens the web model (.glb) next to it, to compare.
local viewing = false
local glbOpen = false

local function viewProp(name)
    if viewing then return end
    local model = GetHashKey(name)
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 300 do Wait(10) tries = tries + 1 end
    if not HasModelLoaded(model) then
        print(("[%s] the model %s did not load"):format(GetCurrentResourceName(), name))
        return
    end
    local ped = PlayerPedId()
    local heading = math.rad(GetEntityHeading(ped))
    local fwd = vector3(-math.sin(heading), math.cos(heading), 0.0)
    local min, max = GetModelDimensions(model)
    local size = math.max(max.x - min.x, max.y - min.y, max.z - min.z, 0.05)
    local center = vector3((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
    -- In the air in front of the player, high enough to clear the ground.
    local at = GetEntityCoords(ped) + fwd * (1.2 + size) + vector3(0.0, 0.0, 0.6 + size / 2)
    local obj = CreateObject(model, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityHeading(obj, GetEntityHeading(ped) + 180.0)
    local yaw, pitch = GetEntityHeading(ped) + 180.0, 0.0
    local dist = size * 1.8
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamFov(cam, 40.0)
    RenderScriptCams(true, false, 0, true, true)
    viewing = true
    -- The ORB panel with the controls (html/index.html), instead of GTA's help box.
    SendNUIMessage({ action = "hud", name = name, glb = true })
    CreateThread(function()
        while viewing do
            DisableAllControlActions(0)
            HideHudAndRadarThisFrame()
            if not glbOpen then
                if IsDisabledControlPressed(0, 24) then
                    yaw = yaw + GetDisabledControlNormal(0, 1) * 12.0
                    pitch = math.max(-89.0, math.min(89.0, pitch + GetDisabledControlNormal(0, 2) * 12.0))
                end
                if IsDisabledControlPressed(0, 34) then yaw = yaw - 1.5 end
                if IsDisabledControlPressed(0, 35) then yaw = yaw + 1.5 end
                if IsDisabledControlPressed(0, 32) then pitch = math.min(89.0, pitch + 1.5) end
                if IsDisabledControlPressed(0, 33) then pitch = math.max(-89.0, pitch - 1.5) end
                if IsDisabledControlJustPressed(0, 241) then dist = math.max(size * 0.35, dist * 0.88) end
                if IsDisabledControlJustPressed(0, 242) then dist = math.min(size * 8.0, dist * 1.14) end
                if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 202) or IsDisabledControlJustPressed(0, 177) then viewing = false end
                if IsDisabledControlJustPressed(0, 47) then
                    glbOpen = true
                    SetNuiFocus(true, true)
                    SendNUIMessage({ action = "open" })
                end
            end
            SetEntityRotation(obj, pitch, 0.0, yaw, 2, true)
            local target = GetOffsetFromEntityInWorldCoords(obj, center.x, center.y, center.z)
            local pos = target - fwd * dist + vector3(0.0, 0.0, dist * 0.15)
            SetCamCoord(cam, pos.x, pos.y, pos.z)
            PointCamAtCoord(cam, target.x, target.y, target.z)
            Wait(0)
        end
        if glbOpen then SetNuiFocus(false, false) glbOpen = false end
        SendNUIMessage({ action = "hud_off" })
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end)
end

RegisterNUICallback("close", function(_, cb)
    glbOpen = false
    SetNuiFocus(false, false)
    cb("ok")
end)

RegisterCommand("police_tablet_view", function() viewProp("police_tablet") end, false)
