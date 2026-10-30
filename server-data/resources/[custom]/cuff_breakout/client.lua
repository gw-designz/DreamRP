local active = false
local countered = false -- the arresting officer is fighting this attempt
local pushback = 0.0    -- meter % the officer has knocked off since the last frame
local counter = nil     -- officer side: { suspect, duration, started, pending }

local function notify(key, kind, ...)
    lib.notify({ title = Config.Text.title, description = Config.Text[key]:format(...), type = kind or 'error' })
end

local function isIncapacitated()
    local metadata = QBX.PlayerData and QBX.PlayerData.metadata
    if metadata and (metadata.isdead or metadata.inlaststand) then return true end
    return IsEntityDead(cache.ped)
end

local function canAttempt()
    local state = LocalPlayer.state
    if not state.isCuffed then return false, 'not_cuffed' end
    if isIncapacitated() then return false, 'busy' end
    if exports.p_policejob:isInCuffProcess() then return false, 'busy' end
    if Config.BlockWhileEscorted and (state.draggedBy or state.carriedBy) then return false, 'busy' end
    if Config.BlockInVehicle and cache.vehicle then return false, 'busy' end
    return true
end

-- Returns true (success), false (time ran out) or nil (cancelled)
local function runMinigame(profile, title, subtitle)
    local startTime = GetGameTimer()
    local gainPerShake = 100.0 / profile.shakes
    local progress = 0.0
    local lastUpdate = 0
    local lastRelay = 0
    countered, pushback = false, 0.0
    local axes = {
        { control = 1, dir = 0, travel = 0.0, since = startTime }, -- INPUT_LOOK_LR
        { control = 2, dir = 0, travel = 0.0, since = startTime }, -- INPUT_LOOK_UD
    }

    SendNUIMessage({
        action = 'open',
        duration = profile.duration,
        title = title,
        subtitle = subtitle,
        instruction = Config.Text.instruction,
    })

    while true do
        local now = GetGameTimer()

        -- Stop the camera spinning while we read the raw mouse movement
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)

        local shook = false
        for i = 1, #axes do
            local axis = axes[i]
            local delta = GetDisabledControlNormal(0, axis.control)

            if math.abs(delta) > Config.Deadzone then
                local dir = delta > 0 and 1 or -1
                if dir ~= axis.dir then
                    local strokeTime = now - axis.since
                    if axis.dir ~= 0 and axis.travel >= Config.MinStroke and strokeTime <= Config.MaxStrokeTime then
                        shook = true
                    end
                    if Config.Debug then
                        print(('[cuff_breakout] axis %d stroke %.3f in %dms'):format(axis.control, axis.travel, strokeTime))
                    end
                    axis.dir, axis.travel, axis.since = dir, 0.0, now
                end
                axis.travel = axis.travel + math.abs(delta)
            end
        end

        if shook then
            progress = progress + gainPerShake
            ShakeGameplayCam('HAND_SHAKE', 0.4)
        end
        progress = math.max(0.0, progress - profile.decay * GetFrameTime() - pushback)
        pushback = 0.0

        local elapsed = now - startTime
        local result
        if progress >= 100.0 then
            result = true
        elseif elapsed >= profile.duration then
            result = false
        elseif not LocalPlayer.state.isCuffed or isIncapacitated() then
            result = 'cancel'
        end

        if result ~= nil then
            countered = false
            StopGameplayCamShaking(true)
            SendNUIMessage({
                action = 'close',
                success = result == true,
                successText = Config.Text.ui_success,
                failText = Config.Text.ui_fail,
            })
            if result == 'cancel' then return nil end
            return result
        end

        if shook or now - lastUpdate >= 50 then
            lastUpdate = now
            SendNUIMessage({ action = 'update', progress = math.min(progress, 100.0), elapsed = elapsed, shook = shook })
        end

        if countered and now - lastRelay >= Config.Counter.RelayInterval then
            lastRelay = now
            TriggerServerEvent('cuff_breakout:server:progress', math.min(progress, 100.0), elapsed)
        end

        Wait(0)
    end
end

local function attemptBreakout()
    if active then return end

    local ok, reason = canAttempt()
    if not ok then return notify(reason) end

    active = true
    local started, data, extra = lib.callback.await('cuff_breakout:server:start', false)
    if not started then
        active = false
        return notify(data, 'error', extra)
    end

    local result = runMinigame(data, Config.Text.title, Config.Text.subtitle)

    if result == nil then
        lib.callback.await('cuff_breakout:server:finish', false, false)
        notify('cancelled', 'inform')
    elseif lib.callback.await('cuff_breakout:server:finish', false, result) then
        notify('success', 'success')
    else
        notify('fail', 'error')
    end

    active = false
end

lib.addKeybind({
    name = Config.Command,
    description = 'Break out of handcuffs',
    defaultKey = Config.Key,
    onPressed = attemptBreakout,
})

RegisterCommand(Config.Command, attemptBreakout, false)

-- Resist minigame while being cuffed, used by p_policejob's cuffGame hook.
-- cb(true) = escaped the cuffs, cb(false) = got cuffed. Runs in its own thread so
-- the caller can wait on it with a promise.
local resists = 0 -- resist attempts since the player was last actually cuffed

local function cuffGame(isHard, cuffType, cb)
    local base = Config.OnCuff[cuffType or 'cuffs']
    if active or not base then return cb(false) end

    -- Out of resists: the cuffs go on automatically and the count starts over
    if Config.OnCuff.MaxResists > 0 and resists >= Config.OnCuff.MaxResists then
        resists = 0
        return cb(false)
    end
    resists = resists + 1

    CreateThread(function()
        active = true
        local profile = { duration = base.duration, shakes = base.shakes, decay = base.decay }
        if isHard then profile.shakes = math.ceil(profile.shakes * Config.OnCuff.HardMultiplier) end

        TriggerServerEvent('cuff_breakout:server:resistStart', cuffType or 'cuffs')
        local result = runMinigame(profile, Config.Text.resist_title, Config.Text.resist_subtitle)
        TriggerServerEvent('cuff_breakout:server:resistEnd', result == true)
        active = false
        if result ~= true then resists = 0 end
        cb(result == true)
    end)
end

-- Suspect side of the counter-game
RegisterNetEvent('cuff_breakout:client:counterActive', function()
    if active then countered = true end
end)

RegisterNetEvent('cuff_breakout:client:pushback', function(amount)
    if active then pushback = pushback + (tonumber(amount) or 0) end
end)

-- Officer side: mash the key to push the suspect's meter back
local function closeCounter(held)
    if not counter then return end
    if counter.pending > 0 then
        TriggerServerEvent('cuff_breakout:server:counterPress', counter.suspect, counter.pending)
    end
    counter = nil
    SendNUIMessage({
        action = 'close',
        success = held,
        successText = Config.Text.counter_held,
        failText = Config.Text.counter_escaped,
    })
end

RegisterNetEvent('cuff_breakout:client:counterStart', function(suspect, duration)
    if active or counter then return end

    local this = { suspect = suspect, duration = duration, started = GetGameTimer(), pending = 0 }
    counter = this

    SendNUIMessage({
        action = 'open',
        duration = duration,
        title = Config.Text.counter_title,
        subtitle = Config.Text.counter_subtitle,
        instruction = Config.Text.counter_instruction,
        key = Config.Counter.KeyLabel,
    })

    CreateThread(function()
        local lastSend = GetGameTimer()
        while counter == this do
            local now = GetGameTimer()
            DisableControlAction(0, Config.Counter.Key, true)

            if IsDisabledControlJustPressed(0, Config.Counter.Key) then
                this.pending = this.pending + 1
                SendNUIMessage({ action = 'tap' })
            end

            if this.pending > 0 and now - lastSend >= Config.Counter.RelayInterval then
                lastSend = now
                TriggerServerEvent('cuff_breakout:server:counterPress', suspect, this.pending)
                this.pending = 0
            end

            -- Never heard back from the server, don't leave the UI up
            if now - this.started > duration + 3000 then closeCounter(true) end

            Wait(0)
        end
    end)
end)

RegisterNetEvent('cuff_breakout:client:counterUpdate', function(progress, elapsed)
    if not counter then return end
    SendNUIMessage({ action = 'update', progress = progress, elapsed = elapsed })
end)

RegisterNetEvent('cuff_breakout:client:counterStop', function(escaped)
    closeCounter(not escaped)
end)

exports('CuffGame', cuffGame)
exports('StartBreakout', attemptBreakout)
exports('IsActive', function() return active end)
