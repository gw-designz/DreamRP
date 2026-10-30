if Config.Framework == nil or Config.Framework == '' then
    error('Please pick a framework in the config')
end

Bridge = Bridge or {}

local inv = exports[Config.Inventory]

local function applyEffects(effect)
    local ped = cache.ped

    if effect.setHealth then
        SetEntityHealth(ped, math.floor(effect.setHealth))
    elseif effect.health then
        local max = GetEntityMaxHealth(ped)
        local current = GetEntityHealth(ped)
        SetEntityHealth(ped, math.min(max, current + math.floor(effect.health)))
    end

    if effect.setArmor then
        SetPedArmour(ped, math.min(100, math.floor(effect.setArmor)))
    elseif effect.armor then
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + math.floor(effect.armor)))
    end

    if effect.stopBleed then
        exports['royal-health']:StopBleeding(effect.stopBleed)
    end

    if effect.bones then
        exports['royal-health']:HealBones(effect.bones)
    end

    if effect.notify then
        lib.notify({ description = locale(effect.notify), type = 'success' })
    end
end

local function useItem(_, data)
    if not data or not data.name then return end

    local effect = Config.Items[data.name]
    if not effect then return end

    if effect.cancelOnDeath ~= false and Bridge.IsDead() then
        return lib.notify({ description = locale('notify.cant_use_downed'), type = 'error' })
    end

    inv:useItem(data, function(result)
        if result then
            applyEffects(effect)
        end
    end)
end

exports('useItem', useItem)

RegisterNetEvent('royal-health:client:revive', function()
    local ped = cache.ped
    local coords = GetEntityCoords(ped)

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetPlayerInvincible(PlayerId(), false)

    TriggerEvent('royal-health:client:clearInjuries')
    lib.notify({ description = locale('notify.revived'), type = 'success' })
end)
