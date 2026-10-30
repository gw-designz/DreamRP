Bridge = Bridge or {}

local function clearInjuries(src)
    TriggerClientEvent('royal-health:client:clearInjuries', src)
end
exports('ClearInjuries', clearInjuries)

local function revive(src)
    src = tonumber(src)
    if not src then return false end

    Bridge.Revive(src)
    clearInjuries(src)
    return true
end
exports('Revive', revive)
