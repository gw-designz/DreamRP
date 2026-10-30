Config = {}

Config.Debug = false              -- prints stroke values in F8 to help tune MinStroke / MaxStrokeTime

Config.Command = 'breakcuffs'     -- also bound to Config.Key (players can rebind in Settings > Key Bindings > FiveM)
Config.Key = 'G'

Config.Cooldown = 45              -- seconds before another attempt after a failure
Config.MaxAttempts = 2            -- attempts per cuffing (resets when the player is cuffed again), 0 = unlimited

Config.BlockWhileEscorted = true  -- can't attempt while being dragged / carried
Config.BlockInVehicle = true

-- What counts as one "shake": the mouse changes direction after travelling at least
-- MinStroke (control normal units) within MaxStrokeTime ms. Slow wiggles don't count.
Config.Deadzone = 0.002
Config.MinStroke = 0.04
Config.MaxStrokeTime = 300

-- Anti-cheat: a finish faster than shakes * MinMsPerShake is rejected by the server
Config.MinMsPerShake = 40

-- Per cuff type (matches p_policejob's cuffType state bag). Remove a type to make it unbreakable.
--   duration = time limit (ms), shakes = shakes needed to fill the meter,
--   decay    = meter % lost per second when not shaking
Config.CuffTypes = {
    cuffs      = { duration = 8000, shakes = 85, decay = 14 },
    cable_ties = { duration = 9000, shakes = 55, decay = 10 },
}

-- Resisting while an officer is putting the cuffs on. p_policejob runs this through its
-- Config.Interactions.Cuffs.cuffGame hook (see modules/interactions/config.lua).
-- Shorter window than a breakout, hard cuffs need HardMultiplier times the shakes.
-- MaxResists = resist minigames allowed before the cuffs go on automatically; the count
-- resets once the player actually ends up cuffed. 0 = unlimited.
Config.OnCuff = {
    HardMultiplier = 1.5,
    MaxResists = 3,
    cuffs      = { duration = 6000, shakes = 55, decay = 12 },
    cable_ties = { duration = 6500, shakes = 40, decay = 10 },
}

-- Counter-game for the officer who applied the cuffs: while the suspect resists being cuffed,
-- that officer mashes Key to knock the suspect's meter back. Only kicks in when the officer
-- is within Distance when the resist starts. The G breakout (slipping the cuffs) is never countered.
--   Max pushback = PushPerPress * MaxPressesPerSecond meter %/s (default 3.2%/s)
Config.Counter = {
    Enabled = true,
    Key = 38,                 -- INPUT_PICKUP (E)
    KeyLabel = 'E',
    Distance = 8.0,
    PushPerPress = 0.4,       -- meter % removed from the suspect per press
    MaxPressesPerSecond = 8,  -- server-side cap so macros can't spam it
    RelayInterval = 250,      -- ms between network updates in both directions
}

Config.Text = {
    title       = 'Break Free',
    subtitle    = 'Restrained',
    resist_title    = 'Resist',
    resist_subtitle = 'Being restrained',
    instruction = 'Shake your mouse',
    ui_success  = 'Free',
    ui_fail     = 'Too slow',
    counter_title       = 'Hold Them Down',
    counter_subtitle    = 'Suspect resisting',
    counter_instruction = 'Mash to hold',
    counter_held        = 'Held',
    counter_escaped     = 'Escaped',

    success     = 'You broke free of your restraints!',
    fail        = 'You failed to break free',
    cancelled   = 'Breakout attempt cancelled',
    not_cuffed  = 'You are not restrained',
    cannot_break = 'These restraints are too strong to break',
    cooldown    = 'Your wrists are too sore, wait %s seconds',
    no_attempts = 'You have no strength left to break free',
    busy        = 'You can\'t do that right now',
}

-- SERVER: called after a successful breakout (e.g. alert police / log)
Config.OnBreakout = function(source, cuffType)
    -- local coords = GetEntityCoords(GetPlayerPed(source))
    -- exports['ps-dispatch']:CustomAlert({ ... })
end

-- SERVER: called after a failed attempt
Config.OnFail = function(source, cuffType)
end
