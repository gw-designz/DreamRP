-- Dev tab access (decided by the server, see server/dev.lua) and "Apply to character".
-- Previews (override values, forced widgets) live entirely in the NUI; only Apply reaches here.

Hud.devAccess = false

RegisterNetEvent('my-hud:client:devAccess', function(ok)
    Hud.devAccess = ok == true
end)

RegisterNetEvent('my-hud:client:openDev', function()
    Hud.openSettings('dev')
end)

CreateThread(function() TriggerServerEvent('my-hud:server:devAccess') end)
Bridge.onLoaded(function() TriggerServerEvent('my-hud:server:devAccess') end)

local function clamp(v) return Hud.clamp(tonumber(v) or 0, 0, 100) end

RegisterNUICallback('devApply', function(data, cb)
    cb(1)
    if not Hud.devAccess or type(data) ~= 'table' then return end
    local ped = PlayerPedId()
    -- GTA health runs 100 (dead) to max; the HUD shows the part above 100 as 0-100%.
    local max = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.floor(100 + (max - 100) * clamp(data.health) / 100 + 0.5))
    SetPedArmour(ped, math.floor(clamp(data.armor)))
    TriggerServerEvent('my-hud:server:devApply', { hunger = data.hunger, thirst = data.thirst, stress = data.stress })
end)
