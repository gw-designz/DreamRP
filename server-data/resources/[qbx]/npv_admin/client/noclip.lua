Noclip = { active = false }

local speed = 1.0
local SPEEDS = { 0.25, 0.5, 1.0, 2.5, 6.0 }
local speedIdx = 3

local function rotationToDirection(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local cx = math.abs(math.cos(x))
    return vec3(-math.sin(z) * cx, math.cos(z) * cx, math.sin(x))
end

function Noclip.Toggle()
    Noclip.active = not Noclip.active
    local ped = PlayerPedId()
    local ent = GetVehiclePedIsIn(ped, false)
    if ent == 0 then ent = ped end
    if Noclip.active then
        SetEntityCollision(ent, false, false)
        FreezeEntityPosition(ent, true)
        SetEntityInvincible(ent, true)
        CreateThread(function()
            while Noclip.active do
                local e = GetVehiclePedIsIn(PlayerPedId(), false)
                if e == 0 then e = PlayerPedId() end
                DisableControlAction(0, 30, true) DisableControlAction(0, 31, true)
                DisableControlAction(0, 32, true) DisableControlAction(0, 33, true)
                DisableControlAction(0, 34, true) DisableControlAction(0, 35, true)
                DisableControlAction(0, 44, true) DisableControlAction(0, 38, true)
                DisableControlAction(0, 21, true) DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true) DisableControlAction(0, 36, true)

                -- Scroll changes speed.
                if IsDisabledControlJustPressed(0, 15) then speedIdx = math.min(#SPEEDS, speedIdx + 1) end
                if IsDisabledControlJustPressed(0, 14) then speedIdx = math.max(1, speedIdx - 1) end
                speed = SPEEDS[speedIdx]

                local camRot = GetGameplayCamRot(2)
                local dir = rotationToDirection(camRot)
                local right = vec3(dir.y, -dir.x, 0.0)
                local pos = GetEntityCoords(e)
                local move = vec3(0, 0, 0)
                if IsDisabledControlPressed(0, 32) then move = move + dir end
                if IsDisabledControlPressed(0, 33) then move = move - dir end
                if IsDisabledControlPressed(0, 35) then move = move + right end
                if IsDisabledControlPressed(0, 34) then move = move - right end
                if IsDisabledControlPressed(0, 38) then move = move + vec3(0, 0, 1) end -- E up
                if IsDisabledControlPressed(0, 44) then move = move - vec3(0, 0, 1) end -- Q down
                local mult = IsDisabledControlPressed(0, 21) and 3.0 or 1.0
                pos = pos + move * speed * mult * 0.5

                SetEntityCoordsNoOffset(e, pos.x, pos.y, pos.z, true, true, true)
                SetEntityHeading(e, camRot.z)
                Wait(0)
            end
        end)
    else
        SetEntityCollision(ent, true, true)
        FreezeEntityPosition(ent, false)
        SetEntityInvincible(ent, false)
        -- Land on the ground rather than inside a building.
        local c = GetEntityCoords(ent)
        local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z, false)
        if ok and c.z - gz < 2.0 then SetEntityCoords(ent, c.x, c.y, gz + 0.5, false, false, false, false) end
    end
    lib.notify({ description = Noclip.active and 'Noclip on (scroll = speed, Shift = boost)' or 'Noclip off', type = 'inform' })
end

AddEventHandler('npv_admin:client:adminModeOff', function()
    if Noclip.active then Noclip.Toggle() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not Noclip.active then return end
    local ped = PlayerPedId()
    local ent = GetVehiclePedIsIn(ped, false)
    if ent == 0 then ent = ped end
    SetEntityCollision(ent, true, true)
    FreezeEntityPosition(ent, false)
    SetEntityInvincible(ent, false)
end)
