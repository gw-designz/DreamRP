--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@class UiSound
---@field name string
---@field set string

---Default interface sounds, using stock game frontend sounds so no audio bank is required.
---Replace an entry (or set it to `false`) to change or remove a sound.
---@type table<string, UiSound | false>
lib.uiSounds = {
    -- Menus, radial menu, text ui and dialogs
    navigate = { name = 'NAV_UP_DOWN', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    toggle = { name = 'NAV_LEFT_RIGHT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    select = { name = 'SELECT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    back = { name = 'BACK', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    -- Notifications
    info = { name = 'CONFIRM_BEEP', set = 'HUD_MINI_GAME_SOUNDSET' },
    success = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },
    warning = { name = 'TIMER_STOP', set = 'HUD_MINI_GAME_SOUNDSET' },
    error = { name = 'ERROR', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    -- Progress bars and skill checks
    progressStart = { name = 'NAV_LEFT_RIGHT', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    progressComplete = { name = 'CHECKPOINT_NORMAL', set = 'HUD_MINI_GAME_SOUNDSET' },
    progressCancel = { name = 'CANCEL', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    skillCheckSuccess = { name = 'CHECKPOINT_PERFECT', set = 'HUD_MINI_GAME_SOUNDSET' },
    skillCheckFail = { name = 'ERROR', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
}

local enabled = GetConvarInt('ox:uiSounds', 1) == 1

---Plays one of the sounds in `lib.uiSounds`. Disabled with `setr ox:uiSounds 0`.
---@param key string
function lib.playUiSound(key)
    if not enabled then return end

    local sound = lib.uiSounds[key]

    if not sound then return end

    local soundId = GetSoundId()
    PlaySoundFrontend(soundId, sound.name, sound.set, true)
    ReleaseSoundId(soundId)
end
