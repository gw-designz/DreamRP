local Injuries = {}
local lastHealth
local limping = false

function dprint(text)
    if Config.Debug == true then
        print(string.format('[royal-health] %s', text))
    end
end

local function syncInjuries()
    LocalPlayer.state:set('injuries', Injuries, true)
end

local function getInjuries()
    return Injuries
end
exports('GetInjuries', getInjuries)

local function isInjured()
    return next(Injuries) ~= nil
end
exports('IsInjured', isInjured)

local function clearInjuries()
    Injuries = {}
    limping = false
    ResetPedMovementClipset(cache.ped, 0.0)
    syncInjuries()
    dprint('All injuries cleared.')
end
exports('ClearInjuries', clearInjuries)

AddEventHandler('royal-health:client:clearInjuries', clearInjuries)

local function healBones(amount)
    if amount == 'all' then
        clearInjuries()
        return
    end

    for part, injury in pairs(Injuries) do
        injury.damage = injury.damage - amount
        if injury.damage <= 0 then
            Injuries[part] = nil
        end
    end
    syncInjuries()
end
exports('HealBones', healBones)

local function stopBleeding(amount)
    for _, injury in pairs(Injuries) do
        if injury.bleeding and injury.bleeding > 0 then
            injury.bleeding = amount == 'all' and 0 or math.max(0, injury.bleeding - amount)
        end
    end
    syncInjuries()
end
exports('StopBleeding', stopBleeding)

local function injurePart(part, damage)
    local partData = Config.BodyParts[part]
    if not partData then return end

    local injury = Injuries[part] or { damage = 0, bleeding = 0 }
    injury.damage = math.min(100, injury.damage + math.floor(damage))

    if Config.Effects.bleed and math.random(100) <= Config.BleedChance then
        injury.bleeding = (injury.bleeding or 0) + 1
    end

    Injuries[part] = injury
    syncInjuries()
    dprint(('Injured %s (dmg %d, bleed %d)'):format(part, injury.damage, injury.bleeding or 0))
end
exports('Injure', injurePart)

CreateThread(function()
    lastHealth = GetEntityHealth(cache.ped)

    while true do
        Wait(Config.CheckInterval)

        local playerPed = cache.ped
        local health = GetEntityHealth(playerPed)

        if not lastHealth then lastHealth = health end

        if health < lastHealth and not IsEntityDead(playerPed) then
            local damageDone = (lastHealth - health) * Config.DamageMultiplier

            if damageDone >= Config.MinDamage then
                local hit, bone = GetPedLastDamageBone(playerPed)
                local part = hit and Config.Bones[bone]

                if part and part ~= 'NONE' then
                    injurePart(part, damageDone)
                end
            end
        end

        lastHealth = health
        ClearPedLastDamageBone(playerPed)
    end
end)

CreateThread(function()
    while true do
        if Config.Effects.limp then
            local shouldLimp = false
            for part, injury in pairs(Injuries) do
                local partData = Config.BodyParts[part]
                if partData and partData.limp and injury.damage >= Config.Effects.limpThreshold then
                    shouldLimp = true
                    break
                end
            end

            if shouldLimp and not limping then
                limping = true
                if lib.requestAnimSet then lib.requestAnimSet('move_m@injured') end
                SetPedMovementClipset(cache.ped, 'move_m@injured', 1.0)
            elseif not shouldLimp and limping then
                limping = false
                ResetPedMovementClipset(cache.ped, 0.0)
            end
        end

        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        Wait(Config.Effects.bleedTickInterval)

        if Config.Effects.bleed then
            local totalBleed = 0
            for _, injury in pairs(Injuries) do
                totalBleed = totalBleed + (injury.bleeding or 0)
            end

            if totalBleed > 0 then
                local playerPed = cache.ped
                if not IsEntityDead(playerPed) then
                    local drain = totalBleed * Config.Effects.bleedDamagePerTick
                    local health = GetEntityHealth(playerPed)
                    local newHealth = math.max(Config.Effects.bleedMinHealth, health - drain)
                    if newHealth < health then
                        SetEntityHealth(playerPed, newHealth)
                    end
                    lastHealth = GetEntityHealth(playerPed)
                end
            end
        end
    end
end)
