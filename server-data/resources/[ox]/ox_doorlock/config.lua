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

Config.HUD = {
    enabled      = true,
    labels       = { [0] = 'UNLOCKED', [1] = 'LOCKED' },
    colors       = { [0] = { 255, 255, 255, 255 }, [1] = { 255, 255, 255, 255 } },
    keyColor     = { 255, 255, 255, 255 },
    keySize      = 0.0125,
    textSize     = 0.0115,
    textGap      = 0.0045,
    tracking     = -3,
    spaceWidth   = 12,
    ringSize     = 0.0095,
    ringAlpha    = 195,
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
