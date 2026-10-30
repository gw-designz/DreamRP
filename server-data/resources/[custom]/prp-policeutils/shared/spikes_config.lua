Spikes = {}

Spikes.DestroyWeapons = {
    [`WEAPON_HAMMER`] = true,
    [`WEAPON_BAT`] = true,
    [`WEAPON_CROWBAR`] = true,
    [`WEAPON_GOLFCLUB`] = true,
    [`WEAPON_WRENCH`] = true,
    [`WEAPON_MACHETE`] = true,
    [`WEAPON_SWITCHBLADE`] = true,
    [`WEAPON_BATTLEAXE`] = true,
    [`WEAPON_POOLCUE`] = true,
    [`WEAPON_PIPEWRENCH`] = true
}

Spikes.RequiredJobs = {
    'police'
}

Spikes.Items = {
    box = 'spikesbox',
    pilot = 'spikebox_pilot'
}

Spikes.Range = {
    detectionZone = 300.0, -- radius around spike that activates collision detection
    pilotControl = 200.0,  -- max distance to toggle spike via pilot item
}