Config = {}

Config.Notify = false

Config.DrawTextUI = false

Config.DrawSprite = {

    [0] = { 'doors', 'key', 0, 0, 0.021, 0.021, 0, 255, 255,255, 500 },

    [1] = { 'doors', 'key_red', 0, 0, 0.021, 0.021, 0, 255, 255, 255, 500 },

    [2] = { 'doors', 'point', 0, 0, 0.021, 0.021, 0, 255, 255, 255, 500 },
}

Config.Pin = {
    distance = 6.0,
    size     = 0.012,
    zOffset  = 0.0,
}

-- Prompt look matches my-hud; labels/colours live in tools/hud/render.html (rebuild with: node tools/hud/build.mjs)
Config.HUD = {
    enabled      = true,
    promptScale  = 0.75, -- 1.0 = same size as my-hud's controls bar
    ringScale    = 0.75,
    ringAlpha    = 230,
    centerSize   = 0.0035,
    ringDistance = 6.0,
    zOffset      = 0.0,
}

Config.CommandPrincipal = 'group.admin'

Config.PlayerAceAuthorised = false

Config.LockDifficulty = { 'easy', 'easy', 'medium' }

Config.CanPickUnlockedDoors = false

-- Only the sophisticated lockpick opens building doors. Keep this in step with
-- buildingDoors in lockpick_minigame/config.lua. A door still has to have
-- "lockpick" ticked in the /doorlock editor to be pickable at all.
Config.LockpickItems = {
    'sophisticated_lockpick'
}

Config.NativeAudio = true
