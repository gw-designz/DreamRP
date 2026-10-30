Config = {}

-- How the game plays: the lock has a row of pins. A marker sweeps back and forth along
-- the track under the current pin, and a sweet spot is lit somewhere on that track.
-- Press Key while the marker is inside the sweet spot to set the pin, then the next pin
-- gets a new sweet spot. Set every pin before the time runs out to open the lock.
-- Pressing outside the sweet spot is a miss. Run out of misses or time and the pick slips.

Config.Key = 38                   -- INPUT_CONTEXT (E / D-pad right). Sets the pin
Config.KeyLabel = 'E'
Config.CancelKey = 177            -- INPUT_CELLPHONE_CANCEL (Backspace / right mouse). Gives up, no break roll
Config.DisableMovement = true     -- stand still while picking

-- Hidden leeway on each side of the sweet spot, as a fraction of the track. Covers the
-- one-frame gap between what's drawn and the key press. 0.01 = 1% of the track.
Config.Grace = 0.01

-- Tier used by things that pick for you (cuffs) when you carry several picks:
-- 'best' uses your best pick, 'worst' saves your best one for when it matters.
Config.AutoTierPreference = 'best'

-- Per-tier settings. Regular is the hardest, sophisticated the easiest.
--   item         = ox_inventory item name for this tier
--   pins         = pins to set
--   zone         = sweet-spot width as a fraction of the track (0.12 = 12%)
--   speed        = how many track-lengths the marker covers per second on the first pin
--   speedStep    = extra speed per pin after the first (0.08 = each pin 8% faster than the first)
--   maxMisses    = misses that end the attempt (2 = one free mistake)
--   dropPinOnMiss= a miss also knocks the last set pin back down
--   time         = time limit for the whole lock (ms)
--   breakChance  = chance the pick snaps on a FAILED attempt (0.35 = 35%). Never on success or cancel
--   buildingDoors= can open building doors (ox_doorlock). Keep this in step with
--                  Config.LockpickItems in ox_doorlock/config.lua, which is what the server checks
--
-- Rough feel: the marker spends zone / speed seconds inside the sweet spot on each pass.
--   regular       0.12 / 1.15 = ~0.10s window, gets tighter as pins speed up
--   advanced      0.16 / 1.00 = ~0.16s window
--   sophisticated 0.20 / 0.90 = ~0.22s window
-- Widen zone or lower speed to make a tier easier; the other way round to make it harder.
Config.Tiers = {
    regular = {
        label = 'Regular Lockpick',
        item = 'lockpick',
        pins = 5,
        zone = 0.12,
        speed = 1.15,
        speedStep = 0.08,
        maxMisses = 2,
        dropPinOnMiss = true,
        time = 14000,
        breakChance = 0.35,
        buildingDoors = false,
    },
    advanced = {
        label = 'Advanced Lockpick',
        item = 'advancedlockpick',
        pins = 4,
        zone = 0.16,
        speed = 1.0,
        speedStep = 0.06,
        maxMisses = 3,
        dropPinOnMiss = true,
        time = 15000,
        breakChance = 0.20,
        buildingDoors = false,
    },
    sophisticated = {
        label = 'Sophisticated Lockpick',
        item = 'sophisticated_lockpick',
        pins = 4,
        zone = 0.20,
        speed = 0.9,
        speedStep = 0.05,
        maxMisses = 4,
        dropPinOnMiss = false,
        time = 16000,
        breakChance = 0.10,
        buildingDoors = true,
    },
}

-- Best first. Used to pick a tier when a script doesn't say which one.
Config.TierOrder = { 'sophisticated', 'advanced', 'regular' }

Config.Text = {
    title       = 'Pick the Lock',
    instruction = 'Set pin',
    misses      = 'Misses',
    ui_success  = 'Unlocked',
    ui_fail     = 'Slipped',
    ui_cancel   = 'Stopped',
    broke       = 'Your lockpick snapped',
    busy       = 'You are already picking a lock',
}
