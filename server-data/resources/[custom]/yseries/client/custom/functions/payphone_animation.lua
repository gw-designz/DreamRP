--- Payphone booth animation module.
--- Uses Config.Payphones.AnimDict, AnimIntro, AnimIdle, AnimEntityIntro, AnimEntityIdle, AnimExit, IntroToIdleDelayMs.

if not Config.Payphones or not Config.Payphones.Enabled then return end

---@class PayphoneAnimationModule
PayphoneAnimation = {}

---@type table
local Cfg = Config.Payphones

---@return string
local function getAnimDict()
    return Cfg.AnimDict or 'anim@scripted@payphone_hits@male@'
end

---@return string
local function getPedIntro()
    return Cfg.AnimIntro or 'fxfr_phl_1_intro_male'
end

---@return string
local function getPropIntro()
    return Cfg.AnimEntityIntro or 'fxfr_pcn_1_intro_phone'
end

---@return string
local function getPedIdle()
    return Cfg.AnimIdle or 'idle_05_male'
end

---@return string
local function getPropIdle()
    return Cfg.AnimEntityIdle or 'fxfr_pav_1_phone'
end

---@return string
local function getExitAnim()
    return Cfg.AnimExit or 'exit_left_male'
end

--- Plays intro animation (ped + prop). Intro runs fine for ~1 min; after that it ends with a "pick down". Switch to idle before that.
---@param prop number Payphone prop entity
---@return boolean
function PayphoneAnimation.PlayIntro(prop)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return false end
    if not prop or not DoesEntityExist(prop) then return false end

    local animDict = getAnimDict()
    if not lib.requestAnimDict(animDict, 2000) then return false end

    TaskPlayAnim(ped, animDict, getPedIntro(), 8.0, 8.0, -1, 14, 0, false, false, false)
    PlayEntityAnim(prop, getPropIntro(), animDict, 10.0, true, true, true, 0.0, 0)

    return true
end

--- Switches to idle animation (ped + prop) for long calls. Call after IntroToIdleDelayMs.
---@param prop number Payphone prop entity
---@return boolean
function PayphoneAnimation.PlayIdle(prop)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return false end
    if not prop or not DoesEntityExist(prop) then return false end

    local animDict = getAnimDict()
    if not lib.requestAnimDict(animDict, 2000) then return false end

    StopEntityAnim(prop, getPropIntro(), animDict, 1000.0)
    StopAnimTask(ped, animDict, getPedIntro(), 2.5)

    TaskPlayAnim(ped, animDict, getPedIdle(), 8.0, 8.0, -1, 14, 0, false, false, false)
    PlayEntityAnim(prop, getPropIdle(), animDict, 10.0, true, true, true, 0.0, 0)

    return true
end

--- Plays exit animation on ped. Caller must stop prop anims and delete prop.
---@param prop number|nil Payphone prop entity (nil = skip prop stop)
---@param quick boolean|nil If true, skip exit animation
---@return number Exit duration in ms (0 if quick)
function PayphoneAnimation.PlayExit(prop, quick)
    local exitAnimDurationMs = 2800
    if quick then return 0 end

    local ped = PlayerPedId()
    local animDict = getAnimDict()
    local exitAnimName = getExitAnim()
    local hadProp = prop and DoesEntityExist(prop)

    if hadProp and lib.requestAnimDict(animDict, 2000) then
        TaskPlayAnim(ped, animDict, exitAnimName, 8.0, 8.0, exitAnimDurationMs, 0, 0, false, false, false)
        Wait(200)
    end

    if prop and DoesEntityExist(prop) then
        StopEntityAnim(prop, getPropIntro(), animDict, 1000.0)
        StopEntityAnim(prop, getPropIdle(), animDict, 1000.0)
    end

    return exitAnimDurationMs
end

--- Stops ped exit animation if still playing. Call after waiting ExitDurationMs.
function PayphoneAnimation.StopExitAnim()
    local ped = PlayerPedId()
    local animDict = getAnimDict()
    local exitAnimName = getExitAnim()
    if IsEntityPlayingAnim(ped, animDict, exitAnimName, 3) then
        StopAnimTask(ped, animDict, exitAnimName, 2.5)
    end
end

--- Default exit duration in ms. Use for Wait() after PlayExit.
PayphoneAnimation.ExitDurationMs = 2800

--- Starts a thread that switches from intro to idle after IntroToIdleDelayMs.
---@param getProp fun():number|nil Function that returns current payphone prop
---@param onPlayIdle fun(prop:number) Called with prop when switching to idle
function PayphoneAnimation.ScheduleIntroToIdle(getProp, onPlayIdle)
    local delayMs = Cfg.IntroToIdleDelayMs or 60000
    CreateThread(function()
        Wait(delayMs)
        local prop = getProp and getProp()
        if prop and DoesEntityExist(prop) and onPlayIdle then
            onPlayIdle(prop)
        end
    end)
end
