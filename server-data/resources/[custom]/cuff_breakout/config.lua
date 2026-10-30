Config = {}

Config.Debug = false              -- prints stroke values in F8 to help tune MinStroke / MaxStrokeTime

Config.Command = 'breakcuffs'     -- also bound to Config.Key (players can rebind in Settings > Key Bindings > FiveM)
Config.Key = 'G'

Config.Cooldown = 60              -- seconds before another attempt after a failure
Config.MaxAttempts = 3            -- attempts per cuffing (resets when the player is cuffed again), 0 = unlimited

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
    cuffs      = { duration = 6000, shakes = 70, decay = 12 },
    cable_ties = { duration = 7000, shakes = 44, decay = 8 },
}

-- Resisting while an officer is putting the cuffs on. p_policejob runs this through its
-- Config.Interactions.Cuffs.cuffGame hook (see modules/interactions/config.lua).
-- Shorter window than a breakout, hard cuffs need HardMultiplier times the shakes.
Config.OnCuff = {
    HardMultiplier = 1.5,
    cuffs      = { duration = 3500, shakes = 39, decay = 10 },
    cable_ties = { duration = 4000, shakes = 28, decay = 8 },
}

Config.Text = {
    title       = 'Break Free',
    subtitle    = 'Restrained',
    resist_title    = 'Resist',
    resist_subtitle = 'Being restrained',
    instruction = 'Shake your mouse',
    ui_success  = 'Free',
    ui_fail     = 'Too slow',

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
