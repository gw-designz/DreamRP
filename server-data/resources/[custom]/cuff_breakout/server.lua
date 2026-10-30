local sessions = {}  -- [source] = { started, cuffType, profile }
local cooldowns = {} -- [source] = os.time() when allowed again
local attempts = {}  -- [source] = attempts used this cuffing

local LATENCY_GRACE = 2000

lib.callback.register('cuff_breakout:server:start', function(source)
    local state = Player(source).state
    if not state.isCuffed then return false, 'not_cuffed' end
    if sessions[source] then return false, 'busy' end

    local cuffType = state.cuffType or 'cuffs'
    local profile = Config.CuffTypes[cuffType]
    if not profile then return false, 'cannot_break' end

    local now = os.time()
    if cooldowns[source] and cooldowns[source] > now then
        return false, 'cooldown', cooldowns[source] - now
    end

    local used = attempts[source] or 0
    if Config.MaxAttempts > 0 and used >= Config.MaxAttempts then return false, 'no_attempts' end
    attempts[source] = used + 1

    sessions[source] = { started = GetGameTimer(), cuffType = cuffType, profile = profile }
    return true, profile
end)

lib.callback.register('cuff_breakout:server:finish', function(source, success)
    local session = sessions[source]
    if not session then return false end
    sessions[source] = nil

    local elapsed = GetGameTimer() - session.started
    local profile = session.profile
    local legit = elapsed >= profile.shakes * Config.MinMsPerShake
        and elapsed <= profile.duration + LATENCY_GRACE

    if not success or not legit or not Player(source).state.isCuffed then
        if success and not legit then
            lib.print.warn(('Player %s finished cuff breakout in an impossible %dms'):format(source, elapsed))
        end
        cooldowns[source] = os.time() + Config.Cooldown
        Config.OnFail(source, session.cuffType)
        return false
    end

    CreateThread(function()
        exports.p_policejob:forceUncuff(source)
    end)
    Config.OnBreakout(source, session.cuffType)
    return true
end)

-- Fresh attempts every time a player gets cuffed
AddStateBagChangeHandler('isCuffed', nil, function(bagName, _, value)
    if not value then return end
    local source = GetPlayerFromStateBagName(bagName)
    if source and source ~= 0 then attempts[source] = nil end
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    cooldowns[source] = nil
    attempts[source] = nil
end)
