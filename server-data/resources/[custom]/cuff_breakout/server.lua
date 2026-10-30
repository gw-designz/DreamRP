local sessions = {}  -- [source] = { started, cuffType, profile }
local cooldowns = {} -- [source] = os.time() when allowed again
local attempts = {}  -- [source] = attempts used this cuffing
local counters = {}  -- [suspect] = { officer, started, presses, recent } while the arresting officer is countering

local LATENCY_GRACE = 2000

-- Hand the arresting officer a counter-game if they're close enough to the suspect
local function startCounter(suspect, duration)
    if not Config.Counter.Enabled or counters[suspect] then return end

    local officer = Player(suspect).state.cuffedBy
    if not officer or officer == suspect or not GetPlayerName(officer) then return end
    if Player(officer).state.isCuffed then return end

    local distance = #(GetEntityCoords(GetPlayerPed(suspect)) - GetEntityCoords(GetPlayerPed(officer)))
    if distance > Config.Counter.Distance then return end

    counters[suspect] = { officer = officer, started = GetGameTimer(), presses = 0, recent = {} }
    TriggerClientEvent('cuff_breakout:client:counterStart', officer, suspect, duration)
    TriggerClientEvent('cuff_breakout:client:counterActive', suspect)
end

local function stopCounter(suspect, escaped, finalProgress)
    local counter = counters[suspect]
    if not counter then return end
    counters[suspect] = nil
    TriggerClientEvent('cuff_breakout:client:counterStop', counter.officer, escaped)

    if Config.Debug then
        local seconds = math.max(0.001, (GetGameTimer() - counter.started) / 1000)
        local rate = counter.presses / seconds
        print(('[cuff_breakout] resist %s vs officer %s: %s, meter %s%%, officer %.1f presses/s (%d%% pressure)'):format(
            suspect, counter.officer, escaped and 'ESCAPED' or 'HELD',
            finalProgress and math.floor(finalProgress) or '?',
            rate, math.floor(math.min(1.0, rate / Config.Counter.FullPressureRate) * 100)))
    end
end

lib.callback.register('cuff_breakout:server:start', function(source)
    local state = Player(source).state
    if not state.isCuffed then return false, 'not_cuffed' end
    if sessions[source] then return false, 'busy' end

    local cuffType = state.cuffType or 'cuffs'
    local profile = Config.CuffTypes[cuffType]
    if not profile then return false, 'cannot_break' end

    local used = attempts[source] or 0
    if Config.MaxAttempts > 0 and used >= Config.MaxAttempts then return false, 'no_attempts' end

    local now = os.time()
    if cooldowns[source] and cooldowns[source] > now then
        return false, 'cooldown', cooldowns[source] - now
    end

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

-- Resist minigame while being cuffed runs on the client, these just drive the officer's side
RegisterNetEvent('cuff_breakout:server:resistStart', function(cuffType)
    local src = source
    local profile = Config.OnCuff[cuffType]
    if type(profile) ~= 'table' or sessions[src] then return end
    startCounter(src, profile.duration)
end)

RegisterNetEvent('cuff_breakout:server:resistEnd', function(escaped, finalProgress)
    stopCounter(source, escaped == true, tonumber(finalProgress))
end)

-- Suspect's meter, relayed so the officer can see how close they are to escaping
RegisterNetEvent('cuff_breakout:server:progress', function(progress, elapsed)
    local counter = counters[source]
    if not counter then return end
    progress, elapsed = tonumber(progress), tonumber(elapsed)
    if not progress or not elapsed then return end
    TriggerClientEvent('cuff_breakout:client:counterUpdate', counter.officer, progress, elapsed)
end)

-- Officer key presses. Pressure = presses in the last second / FullPressureRate, capped at 1,
-- so mashing faster than FullPressureRate (or macroing) gives no extra advantage.
RegisterNetEvent('cuff_breakout:server:counterPress', function(suspect, count)
    local counter = counters[suspect]
    if not counter or counter.officer ~= source then return end

    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return end

    local now = GetGameTimer()
    local recent, inWindow = {}, count
    for i = 1, #counter.recent do
        local batch = counter.recent[i]
        if now - batch.at < 1000 then
            recent[#recent + 1] = batch
            inWindow = inWindow + batch.count
        end
    end
    recent[#recent + 1] = { at = now, count = count }
    counter.recent = recent

    local pressure = math.min(1.0, inWindow / Config.Counter.FullPressureRate)
    counter.presses = counter.presses + count
    TriggerClientEvent('cuff_breakout:client:pressure', suspect, pressure)
end)

-- Fresh attempts every time a player gets cuffed
AddStateBagChangeHandler('isCuffed', nil, function(bagName, _, value)
    local source = GetPlayerFromStateBagName(bagName)
    if not source or source == 0 then return end
    if value then
        attempts[source] = nil
    else
        stopCounter(source, true)
    end
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    cooldowns[source] = nil
    attempts[source] = nil
    stopCounter(source, false)

    for suspect, counter in pairs(counters) do
        if counter.officer == source then counters[suspect] = nil end
    end
end)
