local active = false

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
        progress = math.max(0.0, progress - profile.decay * GetFrameTime())

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
local function cuffGame(isHard, cuffType, cb)
    local base = Config.OnCuff[cuffType or 'cuffs']
    if active or not base then return cb(false) end

    CreateThread(function()
        active = true
        local profile = { duration = base.duration, shakes = base.shakes, decay = base.decay }
        if isHard then profile.shakes = math.ceil(profile.shakes * Config.OnCuff.HardMultiplier) end

        local result = runMinigame(profile, Config.Text.resist_title, Config.Text.resist_subtitle)
        active = false
        cb(result == true)
    end)
end

exports('CuffGame', cuffGame)
exports('StartBreakout', attemptBreakout)
exports('IsActive', function() return active end)
