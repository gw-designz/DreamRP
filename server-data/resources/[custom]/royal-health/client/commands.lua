if not Config.EnableTestCommand then return end

local partKeys = {}
for part in pairs(Config.BodyParts) do
    partKeys[#partKeys + 1] = part
end

RegisterCommand('hurtbone', function(_, args)
    local part = args[1]
    local amount = tonumber(args[2]) or 25

    if not part or part == 'random' then
        part = partKeys[math.random(#partKeys)]
    end

    if not Config.BodyParts[part] then
        lib.notify({ description = locale('notify.invalid_part', part), type = 'error' })
        print('[royal-health] Valid parts: ' .. table.concat(partKeys, ', '))
        return
    end

    exports['royal-health']:Injure(part, amount)
    lib.notify({ description = locale('notify.injured_part', part, amount), type = 'inform' })
end, false)

RegisterCommand('showinjuries', function()
    local injuries = exports['royal-health']:GetInjuries()

    if not next(injuries) then
        return lib.notify({ description = locale('notify.no_injuries'), type = 'success' })
    end

    print('[royal-health] Current injuries:')
    for part, injury in pairs(injuries) do
        local label = locale('parts.' .. part)
        print(string.format('  %s -> damage %d, bleeding %d', part, injury.damage, injury.bleeding or 0))
        lib.notify({ description = locale('notify.injury_status', label, injury.damage, injury.bleeding or 0), type = 'inform' })
    end
end, false)

RegisterCommand('clearinjuries', function()
    exports['royal-health']:ClearInjuries()
    lib.notify({ description = locale('notify.injuries_cleared'), type = 'success' })
end, false)

TriggerEvent('chat:addSuggestion', '/hurtbone', 'Injure a body part (test)', {
    { name = 'part', help = 'body part key or "random" (optional)' },
    { name = 'amount', help = 'damage 0-100 (optional, default 25)' },
})
TriggerEvent('chat:addSuggestion', '/showinjuries', 'Show current bone injuries (test)')
TriggerEvent('chat:addSuggestion', '/clearinjuries', 'Clear all bone injuries (test)')
