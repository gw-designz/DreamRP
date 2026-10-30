



_G.playerCache = {
    states = {},
    lastValues = {},
    interval = 1000,
}

function playerCache.watch(key, getter, opts)
    Ensure(key, "string")
    Ensure(getter, "function")
    Ensure(opts, "table", "nil")

    if opts then
        Ensure(opts.interval, "number", "nil")
        Ensure(opts.onChange, "function", "nil")
    end

    local state = {
        key = key,
        getter = getter,
        interval = (opts and opts.interval) or playerCache.interval,
        lastTick = 0,
        onChange = opts and opts.onChange,
    }

    playerCache.states[key] = state
    playerCache.lastValues[key] = getter()
    LocalPlayer.state[key] = playerCache.lastValues[key]
end

function playerCache.unwatch(key)
    Ensure(key, "string")

    if playerCache.states[key] then
        playerCache.states[key] = nil
    end
end

function playerCache.get(key)
    return playerCache.lastValues[key]
end

CreateThread(function()
    while true do
        local now = GetGameTimer()

        for _, state in pairs(playerCache.states) do
            if now - state.lastTick >= state.interval then
                local newValue = state.getter()
                local lastValue = playerCache.lastValues[state.key]

                if not tbl.deepEqual(newValue, lastValue) then
                    playerCache.lastValues[state.key] = newValue
                    LocalPlayer.state[state.key] = newValue

                    if state.onChange then
                        state.onChange(newValue, lastValue)
                    end
                end

                state.lastTick = now
            end
        end

        Wait(100)
    end
end)

