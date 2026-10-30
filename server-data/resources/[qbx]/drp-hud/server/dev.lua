-- Dev tab permission and "Apply to character". Every request is checked here again, so a
-- client that unlocks the tab by itself still cannot change anything.

local function allowed(src)
    if not Config.Dev.enabled then return false end
    for _, ace in ipairs(Config.Dev.aces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    local group = Bridge.getGroup(src)
    return group ~= nil and Config.Dev.esxGroups[group] == true
end

local function clamp(v)
    v = math.floor((tonumber(v) or 0) + 0.5)
    if v < 0 then return 0 elseif v > 100 then return 100 end
    return v
end

RegisterNetEvent('my-hud:server:devAccess', function()
    local src = source
    TriggerClientEvent('my-hud:client:devAccess', src, allowed(src))
end)

RegisterNetEvent('my-hud:server:devApply', function(data)
    local src = source
    if not allowed(src) or type(data) ~= 'table' then return end
    Bridge.setNeeds(src, clamp(data.hunger), clamp(data.thirst))
    exports[GetCurrentResourceName()]:SetStress(src, clamp(data.stress))
end)

RegisterCommand(Config.Dev.command, function(src)
    if src == 0 then return end
    local ok = allowed(src)
    TriggerClientEvent('my-hud:client:devAccess', src, ok)
    if ok then TriggerClientEvent('my-hud:client:openDev', src) end
end, false)
