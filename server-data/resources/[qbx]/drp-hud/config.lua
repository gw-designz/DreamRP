Config = {}

-- 'auto' | 'qbox' | 'qb' | 'esx' | 'standalone'
-- Auto-detection reads resource states at start, so ensure your framework before my-hud.
Config.Framework = 'qbox'

-- Print bridge / minimap diagnostics to the F8 console.
Config.Debug = false

-- How often (ms) the status loop samples values. Only changed values reach the NUI.
Config.Tick = {
    status = 250,   -- health, armor, needs, stamina, oxygen
    voice = 100,    -- talking indicator
    compass = 50,   -- heading (only sent when the rounded degree changes)
    location = 750, -- zone / street names / waypoint distance
    vehicle = 100,  -- speed, rpm, gear, fuel, seatbelt while in a vehicle
    ammo = 200,     -- clip / reserve while holding a gun
}

-- Defaults for the per-player settings menu (/hud). Saved per client with KVP.
Config.Defaults = {
    -- general
    hudStyle = 'circuit',   -- 'circuit' (bars + arc gauge) | 'classic' (ring gauges + needle speedometer)
    -- Per-module looks. 'auto' follows hudStyle (circuit / classic), so nothing changes until picked.
    statusStyle = 'bars',   -- 'bars' | 'hex' | 'square' | 'circle'
    mapStyle = 'auto',      -- 'auto' | 'brackets' | 'clean' | 'minimal' | 'circle'
    locationStyle = 'auto', -- 'auto' | 'bar' | 'pills' | 'compass' | 'minimal'
    -- speedometer per vehicle class: 'modern' (Modern Pro) | 'analog' (Classic Analog) | 'linear' (Digital Linear)
    -- | 'ev' (Tesla Style) | 'dual' (Classic Dual) | 'watch' (Fitness Watch)
    speedoStyle = 'modern', -- cars and motorbikes
    speedoBicycle = 'watch',
    speedoBoat = 'analog',
    speedoAir = 'modern',
    speedoTrain = 'linear',
    scale = 1.0,            -- 0.75 - 1.25, scales every widget together
    performance = 'performance', -- 'performance' | 'balanced' | 'quality': how often the HUD updates
    distanceUnit = 'feet',  -- 'feet' | 'meters': waypoint distance and altitude
    ultrawide = false,      -- true anchors the HUD to the real screen edges; false keeps it in a 16:9 area
    -- cars & bikes
    limitStyle = 'us',      -- speed limit sign: 'us' | 'minimal'
    flashLimit = true,      -- flash the sign while speeding
    indicatorSounds = true,
    beltSound = true,       -- chime while driving unbuckled
    beltPlugSound = true,   -- click when buckling / unbuckling
    -- bicycles
    bikeUnit = 'mph',       -- 'mph' | 'kmh'
    bikeSpeed = true,       -- show the speedometer on bicycles
    bellSounds = true,      -- false mutes the bicycle bell (horn)
    showCadence = true,
    showHeart = true,
    -- boats / aircraft / trains
    boatUnit = 'knots',     -- 'knots' | 'mph' | 'kmh'
    showBoatHeading = true,
    showTrim = true,
    airUnit = 'knots',      -- 'knots' | 'mph' | 'kmh'
    showAttitude = true,
    showAltitude = true,
    showAirHeading = true,
    trainUnit = 'kmh',      -- 'mph' | 'kmh'
    showTrainSpeed = true,
    doorStatus = false,
    brakeIndicator = false,
    -- player info, weapons, vehicle controls
    showAvatar = true,
    showRadioChannel = true,
    voiceAlign = 'right',   -- avatar on the 'left' | 'right' of the voice box
    voiceRadius = 'slight', -- border radius: 'slight' | 'rounded' | 'full'
    infoRadius = 'slight',
    weaponRadius = 'slight',
    vcRadius = 'slight',
    colors = {},            -- { [key] = '#rrggbb' } set in the menu; keys are listed in html/ui.js (COLOR_DEFAULTS)
    hidden = {},            -- { [widget] = true } hidden with the eye in edit mode
    showStamina = true,     -- stamina in the status row
    showAmmo = true,
    showToasts = true,      -- item / weapon cards, right side
    -- player status
    showStatus = true,      -- health / armor icons and bars under the minimap
    showVoice = true,
    showNeeds = true,       -- hunger / thirst icons and bars
    hideFullNeeds = false,  -- hide hunger / thirst icons while at 100%
    hideArmorAtZero = false,
    lowWarnings = true,     -- red fill on low health / armor, orange/red on low needs and fuel
    showCircles = true,     -- dev mode / radio / stress / oxygen icons, shown while active
    showBars = false,       -- stamina / oxygen bars, bottom center, shown while draining
    stressShake = true,
    -- map & compass
    showMinimap = true,
    minimapOnFoot = true,
    showCompass = true,     -- direction (N / NE / E ...) in the top location bar
    showHeading = false,    -- heading degrees next to the direction
    showLocation = true,
    showWaypoint = true,
    map3d = true,           -- draw the 3D minimap (Config.Map3D) in place of the game radar
    mapZoom = 0,            -- SetRadarZoom level 0 - 1400; 0 lets the game decide
    mapOffsetX = 0,         -- calibration in px (1080p) if the radar sits off-centre inside the frame
    mapOffsetY = 0,
    -- vehicle
    showVehicle = true,
    speedUnit = 'mph',      -- 'mph' | 'kmh' (also used for the waypoint distance)
    beltWarning = true,     -- blink the belt icon while driving unbuckled
    showControls = true,    -- controls bar: vehicle key hints + prompts pushed with ShowPrompts
    -- layout editor: { [widget] = { x = px, y = px, s = size } }, offsets in 1080p px
    layout = {},
    snapGrid = true,        -- editor drags snap the element's corner to a 16px grid
}

Config.SettingsCommand = 'hud'

-- Dev tab in the /hud menu: preview HUD states (override values, force widgets on) and set
-- your own health / armor / hunger / thirst / stress. Only shown to players who pass one of
-- the ACE checks (e.g. `add_ace group.admin my-hud.dev allow`) or, on ESX, have a listed group.
Config.Dev = {
    enabled = true,
    command = 'huddev',                 -- opens /hud straight on the Dev tab
    aces = { 'my-hud.dev', 'admin' },   -- 'admin' is the permission Qbox / QBCore admins have
    esxGroups = { admin = true, superadmin = true },
}

-- Widgets the layout editor can move. Unknown keys in saved layouts are dropped.
Config.Widgets = {
    'minimap', 'status', 'bars', 'speedo', 'location', 'ammo', 'controls', 'toasts',
    'voicebox', 'job', 'money', 'pid', 'radio', 'limit', 'boat', 'air', 'vcontrols',
}

-- Settings menu: blur the game behind it (not while the layout editor is open).
Config.MenuBlur = true

-- Icons under the tabs. When a tab hides, its icons move to the previous visible tab.
-- The bars under the tabs are fixed: hunger under health, thirst under armor.
Config.SubIcons = {
    health = { 'hunger' },
    armor = { 'thirst', 'stress' },
}

Config.Thresholds = {
    lowHealth = 25,  -- health fill turns red at or below this %
    lowArmor = 25,   -- armor fill turns red at or below this % (while above 0)
    needWarn = 30,   -- orange below
    needCrit = 15,   -- red blink below
    fuelWarn = 20,   -- fuel arc turns red at or below
    oxygenCrit = 25, -- oxygen bar turns red at or below
}

-- Default GTA HUD components hidden every frame.
-- 14 (reticle) and 19 (weapon wheel) are left alone so aiming and weapon selection keep working.
Config.HiddenHudComponents = { 1, 2, 3, 4, 6, 7, 8, 9, 13, 17, 20, 21, 22 }

Config.Minimap = {
    width = 295,         -- map size in px at 1080p and scale 1.0 (the dark frame sits on its edge)
    height = 193,
    marginLeft = 10,     -- px from the left safezone edge to the map
    marginBottom = 86,   -- px from the bottom safezone edge (leaves room for the status tiles)
    -- Per HUD style overrides of the four values above (the classic ring gauges are taller).
    styles = {
        classic = { width = 295, height = 194, marginLeft = 38, marginBottom = 84 },
    },
    -- The round map (mapStyle 'circle'): a square with a circular radar mask. Replaces the
    -- four values above while picked, whatever the HUD style.
    circle = { width = 205, height = 205, marginLeft = 24, marginBottom = 86 },
    cornerRadius = 10,   -- corner rounding of the mask texture, in px of its 256px square
    clipType = 0,        -- 0 = square clip, 1 = round clip (golf style)
    hideNorthBlip = false,
    disableBigmap = true, -- block the expanded radar (Z / d-pad down) because it ignores the custom layout
    hideHealthArmour = true, -- strip the default health/armour bars from the radar scaleform
    -- Calibration for the three radar components, relative to the map rectangle.
    -- scale multiplies the rectangle size; x / y shift in px at 1080p (positive = right / down).
    -- The defaults stack all three on the rectangle; adjust here if your game build renders
    -- the radar slightly inside or outside the frame. /hud > Map & Compass > Calibrate minimap
    -- adjusts the whole radar per player instead.
    components = {
        minimap = { scale = 1.0, x = 0, y = 0 },      -- player arrow and blips
        minimap_mask = { scale = 1.0, x = 0, y = 0 }, -- blip clipping area
        minimap_blur = { scale = 1.0, x = 0, y = 0 }, -- map terrain
    },
}

-- The 3D minimap (client/map3d.lua + html/map3d.js, from vice_hud): the island drawn at a
-- slant with its buildings standing, in place of the game radar and inside the same frame.
-- Players switch it on / off in /hud > Minimap (Config.Defaults.map3d); the game radar comes
-- back on its own indoors and if the page cannot load the world (html/map3d/, ~9 MB, only
-- downloaded by players who have it on).
Config.Map3D = {
    -- Inside a building's interior the engine's radar shows its floor plan, which the
    -- drawn map has no version of. true hands the map back to the engine indoors.
    engineIndoors = true,

    buildings = true,       -- false: footprints only, nothing standing
    blips = true,           -- draw the game's blips (false: none at all)

    -- Blip sprites left off the drawn minimap (the pause map still has them all):
    -- 24/7s, barbers, Los Santos Customs, clothes stores, tattoo parlours, bars,
    -- car washes, Ammu-Nation, the strip club, cinemas and gas stations. Empty it
    -- to have them all back.
    hiddenBlips = { 52, 71, 72, 73, 75, 93, 100, 110, 121, 135, 361 },
    route = { length = 500.0 },     -- metres of GPS line to draw; false for none

    view = {
        zoom = 2.58,        -- map pixels per metre across, at the player, on a panel 115 pixels tall
        speedZoom = 0.25,   -- how far the view pulls back at speed (0 = never)
        -- The camera looks down past the player from behind and above. `pitch` is degrees
        -- below the horizon (higher looks more nearly straight down), `focal` its lens in
        -- panel heights (longer flattens the perspective).
        camera = { pitch = 27, focal = 1.38 },
        anchor = 0.71,      -- the player marker, as a fraction down the panel
        opacity = 1.0,      -- of the map itself
        north = true,       -- the N badge
    },

    -- The camera rides at the player's height: on a roof the city falls away below,
    -- in an aircraft it shrinks. false keeps it on the ground.
    altitude = true,

    -- Wanted flood (red while police see you, blue while searching). my-hud has no
    -- wanted readout yet, so this only matters if something calls ViceMap3D.police().
    police = {},
    policeBlips = false,    -- true also draws the blips for officers, police cars and helis

    -- Rings out from the player's marker while sprinting. false switches them off.
    ripple = {},

    -- A dark map after dark: true follows the game clock (changing over at dusk / dawn),
    -- false is the daytime map always, 'always' the night one always.
    night = true,
    nightHours = { dusk = 19.5, dark = 21.0, dawn = 5.0, light = 6.5 },

    -- Colours, 0-255 (lane's 4th value and shadow are 0-1 opacity). Left out, each keeps
    -- the value in html/map3d.js. Day is a light red to match the HUD, night near-black with
    -- a red cast; water stays a cool grey in both so it still reads as water.
    -- (html/script.js's browser demo mirrors these two lists.)
    paint = {
        land = { 214, 172, 174 }, road = { 234, 202, 204 }, lot = { 224, 188, 190 },
        sand = { 226, 196, 190 }, footprint = { 200, 152, 156 }, rail = { 192, 148, 152 },
        lane = { 176, 122, 128, 0.3 }, water = { 124, 120, 130 }, shallow = { 150, 144, 154 },
        roof = { 198, 130, 136 }, wall = { 170, 98, 106 }, haze = { 238, 212, 214 },
    },
    paintNight = {
        land = { 20, 18, 20 }, road = { 58, 42, 46 }, lot = { 30, 26, 28 },
        sand = { 34, 28, 30 }, footprint = { 28, 24, 26 }, rail = { 44, 34, 36 },
        lane = { 150, 60, 70, 0.25 }, water = { 10, 11, 14 }, shallow = { 16, 17, 22 },
        roof = { 46, 32, 36 }, wall = { 24, 16, 18 }, haze = { 38, 24, 28 },
    },
}

Config.Vehicle = {
    -- 'auto' tries ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, lj-fuel then falls back to the native fuel level.
    fuel = 'auto',
    seatbeltKey = 'B',
    seatbeltCommand = 'seatbelt',
    -- Classes without seatbelts: motorcycles, cycles, boats, helicopters, planes, trains.
    noBeltClasses = { [8] = true, [13] = true, [14] = true, [15] = true, [16] = true, [21] = true },
    eject = {
        enabled = true,
        minSpeed = 45,   -- mph the vehicle must have been doing before the impact
        minDelta = 25,   -- mph lost within one vehicle tick to count as a crash
        ragdollMs = 4000,
    },
    blinkSpeed = 5,      -- mph above which an unbuckled belt icon blinks red
    disableExitWhenBelted = true,
    -- Models drawn with the electric gauge (cyan segments, plug icon). Add your addon EVs here.
    electric = {
        'airtug', 'caddy', 'caddy2', 'caddy3', 'cyclone', 'cyclone2', 'dilettante', 'dilettante2',
        'imorgon', 'iwagen', 'khamelion', 'neon', 'omnisegt', 'powersurge', 'raiden', 'surge',
        'tezeract', 'virtue', 'voltic', 'voltic2', 'envisage',
    },
    -- Key hint bar shown when getting in as the driver (see client/controls.lua for item fields).
    -- `command` shows the key the player actually bound for another script's key mapping, so
    -- rebinds show up; `key` is only the fallback when that command is not registered.
    -- `resource` hides an item unless that script is running. WHEELUP / WHEELDOWN draw the mouse wheel.
    hints = {
        duration = 0,    -- 0 keeps the bar up until you leave the driver seat; or ms to auto-hide
        items = {
            { command = 'togglelocks', key = 'L', label = 'Lock' },      -- qbx / qb vehiclekeys
            { command = 'engine', key = 'G', label = 'Engine' },         -- qbx / qb vehiclekeys
            -- { key = 'WHEELUP', label = 'Engine on', resource = 'my-engine' },
            -- { key = 'WHEELDOWN', label = 'Engine off', resource = 'my-engine' },
            { command = 'seatbelt', key = 'B', label = 'Seatbelt' },
            { control = 74, key = 'H', pad = 'RB', label = 'Lights' },
            { control = 75, key = 'F', pad = 'Y', label = 'Exit' },
        },
    },
}

-- Speed limit sign (cars and motorbikes). Limits are in mph and looked up by street name;
-- km/h players see them rounded to the nearest 10. Streets not listed use `default`.
Config.SpeedLimits = {
    enabled = true,
    default = 35,
    streets = {
        ['Del Perro Fwy'] = 65, ['Los Santos Freeway'] = 65, ['Olympic Fwy'] = 65, ['La Puerta Fwy'] = 65,
        ['Elysian Fields Fwy'] = 65, ['Palomino Fwy'] = 65, ['Senora Fwy'] = 65, ['Great Ocean Hwy'] = 55,
        ['Route 68'] = 55, ['Route 68 Approach'] = 45, ['Senora Rd'] = 50, ['Joshua Rd'] = 50,
        ['Calafia Rd'] = 45, ['Marina Dr'] = 45, ['Niland Ave'] = 40, ['Panorama Dr'] = 45,
        ['Baytree Canyon Rd'] = 45, ['Tongva Dr'] = 45, ['North Calafia Way'] = 45, ['Cat-Claw Ave'] = 40,
        ['Paleto Blvd'] = 40, ['Procopio Dr'] = 40, ['Vinewood Blvd'] = 40, ['Del Perro Blvd'] = 40,
        ['Elgin Ave'] = 40, ['Alta St'] = 35, ['Strawberry Ave'] = 35, ['San Andreas Ave'] = 40,
    },
}

-- Vehicle control panel (engine, lock, indicators, doors, windows, seats, hood, trunk,
-- lights, cruise, neon). Opens with the command / key while in a vehicle.
Config.VehicleControls = {
    enabled = true,
    command = 'vehcontrols',
    key = 'F6',
    -- Lock button: runs this command if it exists (vehicle keys scripts), else toggles the native lock.
    lockCommand = 'togglelocks',
}

-- Item toasts under the minimap. Weapon equip / holster toasts are automatic; inventories can
-- push their own with exports['my-hud']:ShowItemToast(label, status, image).
Config.Toasts = {
    weapons = true,     -- automatic "Equipped" / "Holstered" cards
    duration = 4000,
    -- Fallback weapon names when the framework has no weapon list (ESX / standalone).
    weaponLabels = {
        [`WEAPON_PISTOL`] = 'Pistol', [`WEAPON_COMBATPISTOL`] = 'Combat Pistol',
        [`WEAPON_APPISTOL`] = 'AP Pistol', [`WEAPON_PISTOL50`] = 'Pistol .50',
        [`WEAPON_HEAVYPISTOL`] = 'Heavy Pistol', [`WEAPON_STUNGUN`] = 'Taser',
        [`WEAPON_SMG`] = 'SMG', [`WEAPON_MICROSMG`] = 'Micro SMG',
        [`WEAPON_ASSAULTRIFLE`] = 'Assault Rifle', [`WEAPON_CARBINERIFLE`] = 'Carbine Rifle',
        [`WEAPON_PUMPSHOTGUN`] = 'Pump Shotgun', [`WEAPON_SNIPERRIFLE`] = 'Sniper Rifle',
        [`WEAPON_KNIFE`] = 'Knife', [`WEAPON_BAT`] = 'Bat', [`WEAPON_FLASHLIGHT`] = 'Flashlight',
        [`WEAPON_NIGHTSTICK`] = 'Nightstick',
    },
}

Config.Stress = {
    enabled = true,
    -- Jobs that do not gain stress (QBCore / Qbox / ESX job names).
    whitelistedJobs = { police = true, ambulance = true },
    shooting = {
        enabled = true,
        chance = 0.15,    -- chance per shot to gain stress
        min = 1,
        max = 3,
        ignoredWeapons = {
            `WEAPON_STUNGUN`, `WEAPON_PETROLCAN`, `WEAPON_FIREEXTINGUISHER`, `WEAPON_SNOWBALL`,
            `WEAPON_BALL`, `WEAPON_FLARE`, `WEAPON_HAZARDCAN`,
        },
    },
    speeding = {
        enabled = true,
        buckled = 110,    -- mph
        unbuckled = 65,   -- mph
        interval = 10000, -- ms between gains while over the limit
        min = 1,
        max = 2,
    },
    syncInterval = 5000,   -- client batches gains and sends them this often
    maxPerEvent = 25,      -- server clamp for a single client-reported gain
    decayPerMinute = 0,    -- passive relief while not gaining; 0 = only events relieve stress
    shake = {
        { min = 90, intensity = 0.30, interval = 3500 },
        { min = 75, intensity = 0.18, interval = 6000 },
        { min = 50, intensity = 0.08, interval = 12000 },
    },
}

-- Controls bar (bottom right): ShowPrompts from scripts and the vehicle hints. It can also
-- mirror prompts other scripts already draw themselves ("[E] - Open garage"), but those are
-- off by default so the same keys are not shown twice. Turn a source on only if you hide
-- that script's own prompt.
Config.Controls = {
    capture = {
        ox_lib = false,       -- lib.showTextUI, which Qbox's DrawText also uses
        qb = false,           -- qb-core DrawText *event* (the export cannot be observed)
        esx = false,          -- ESX.TextUI / esx_textui
        cd_drawtextui = false,
        interact = false,     -- mirror interact's floating "E" prompts in the bar too; needs the
                              -- small hook in interact/client/interacts.lua, see README
    },
}

-- Glyph shapes for controller keys. Anything not listed renders as a rounded square.
Config.CircleKeys = { A = true, B = true, X = true, Y = true }

-- Keyboard labels for GetControlInstructionalButton codes that are icons rather than text (b_*).
Config.KeyLabels = {
    b_100 = 'LMB',
    b_101 = 'RMB',
    b_102 = 'MMB',
    b_115 = 'WHEEL',
    b_116 = 'WHEEL',
    b_2000 = 'SPACE',
}
