

Config = {}

Config.DEBUG = false

-- auto | qbcore | esx | qbox
Config.Framework = "auto"

-- auto | qb-clothing | tgiann-clothing | illenium-appearance | fivem-appearance | bl_appearance | crm-appearance | rcore_clothing | codem-appearance | skinchanger
Config.Appearance = "auto"

-- none | auto | qb-houses | qbx-apartments | rcore_housing
Config.Housing = "none"

-- Routing bucket for the character-selection scene so players don't see each
-- other (or the live world) while picking a character. The player is moved
-- back to bucket 0 when they spawn into the world.
--   false    = disabled (stay in the default world bucket)
--   true     = isolate each player in a bucket equal to their server id
--   <number> = put everyone in this fixed bucket (e.g. 99)
Config.RoutingBucket = true

-- Where freshly-created characters land before the spawn selector runs.
Config.SpawnCoords = {
    coords  = vector3(-1041.2592, -2744.5063, 21.3594),
    heading = 332.1771,
}

Config.PostCreate = {
    TeleportToSpawn  = true,  -- teleport to Config.SpawnCoords after create
    UseClothingTimer = true,  -- show find-a-spot countdown before clothing editor
    ClothingTimerMs  = 15000, -- countdown duration in ms
}

-- en-US | sv-SE (add more in locales/<locale>.lua)
Config.Locale = "en-US"

-- UI accent color. Hex string only (#RRGGBB). Applied everywhere the
-- UI uses the brand highlight: PLAY button, hover pills, character
Config.Theme = {
    accent   = '#3fdcf2',
    accentFg = '#0b0b0b',
}

-- Title screen + main menu. Images are paths relative to src/web/dist/
-- (drop your own screenshots in src/web/dist/img/ and point at them).
Config.Branding = {
    title      = 'YOUR CITY',
    subtitle   = 'ROLEPLAY',
    background = 'img/bg.png',  -- blurred backdrop behind the title screen
    panels     = {
        continue   = { image = 'img/bg.png', caption = 'START YOUR JOURNEY IN LOS SANTOS' },
        characters = { image = 'img/bg.png', caption = 'CHOOSE WHO YOU WANT TO BE' },
        options    = { image = 'img/bg.png', caption = 'ADJUST YOUR GAME SETTINGS' },
    },
}

-- Cards shown after creating a character when the player picks "View Tutorial".
-- position: center | top-left | top-right | bottom-left | bottom-right
-- key (optional): keycap shown next to the hint, e.g. 'M' with hint 'OPEN MAP'.
Config.Tutorial = {
    steps = {
        { title = 'WELCOME TO YOUR CITY', position = 'center',
          body = "This short guide introduces the city's interface and the basics of starting your story." },
        { title = 'CHARACTER STATUS', position = 'bottom-left',
          body = 'Keep an eye on your health, armor, hunger, and thirst. Eat, drink, and seek medical help when needed.' },
        { title = 'NAVIGATION', position = 'top-right', key = 'M', hint = 'OPEN MAP',
          body = 'Use your map to find jobs, shops, and points of interest around the city. Set a waypoint to plan your journey.' },
        { title = 'INVENTORY', position = 'center', key = 'TAB', hint = 'INVENTORY',
          body = 'Your pockets hold everything you carry. Keep your ID and phone on you at all times.' },
        { title = 'YOUR STORY', position = 'center',
          body = 'Find a job, meet people, and make a name for yourself. The city is yours.' },
    },
}

-- Money formatting. pattern uses %s as the number placeholder.
-- Examples: '$ %s' → "$ 1,234"   |   '%s eur' → "1 234 kr"
Config.Currency = {
    pattern   = '$ %s',
    thousands = ',',
}

-- Character-detail panel: toggle which info chips + money chips appear
-- Custom entries with your own fetcher:
--   {
--     kind  = 'custom',
--     id    = 'reputation',       -- unique id (used as React key + lookup)
--     icon  = 'Star',             -- Lucide icon name in PascalCase. See https://lucide.dev/icons
--     label = 'REPUTATION',       -- locale key OR raw display string
--     fetch = function(character) -- runs client-side, receives raw character table
--       return (character.metadata and character.metadata.reputation) or 0
--     end,
--   }
-- For money custom entries, fetch must return a number — it's formatted through Config.Currency.
-- For info custom entries, fetch can return anything (it's tostring'd for display).
Config.CharacterDetail = {
    bio    = true,
    fields = {
        { kind = 'dob',      enabled = true },
        { kind = 'gender',   enabled = true },
        { kind = 'job',      enabled = true },
        { kind = 'playtime', enabled = true },
    },
    money  = {
        { kind = 'cash', enabled = true },
        { kind = 'bank', enabled = true },
    },
}

-- Allow players to delete their own characters from the selection screen.
-- When false the delete button is hidden AND the server refuses delete
-- requests, so a tampered UI can't bypass it. Default: true.
Config.AllowCharacterDeletion = true

-- Kill FiveM's loading screen + any NUI loading screen on mount.
Config.ShutdownLoadingScreen = true

-- Global multiplier for the DUI nameplate size above peds. 1.0 = default.
Config.NameplateScale = 1.0

-- Wall-mounted server logo. Image lives in the resource root. Width/height in metres.
Config.ServerLogo = {
    enabled = true,
    debug   = false, -- show a red marker at the centre + green/blue corner markers + a 3D text label
    image   = 'logo_example.png',
    coords  = { x = -600.2876, y = -711.4252, z = 114.6053 },
    heading = 90.0564,
    width   = 1.5,
    height  = 1.5,
    opacity = 0.4, -- 0.0 = fully transparent, 1.0 = fully opaque
}

-- Built-in kinds: discord, youtube, twitter, tiktok, twitch, website, store, info, map, music, custom
Config.Socials = {
    { kind = 'discord', enabled = true,  url = 'https://discord.gg/your-server' },
    { kind = 'youtube', enabled = true,  url = 'https://www.youtube.com/@your-channel' },
    { kind = 'website', enabled = true,  url = 'https://your-server.com' },
    { kind = 'tiktok',  enabled = false, url = 'https://www.tiktok.com/@your-handle' },
    { kind = 'twitter', enabled = false, url = 'https://twitter.com/your-handle' },
    { kind = 'twitch',  enabled = false, url = 'https://twitch.tv/your-channel' },
    -- { kind = 'custom', enabled = true, icon = 'Newspaper', label = 'Rules', url = 'https://your-server.com/rules' },
}

-- Defaults for the in-game settings dialog. Player overrides persist via KVP.
Config.Settings = {
    defaultTheme = 'dark', -- 'dark' | 'light'
    music = {
        enabled = true,
        -- Direct audio stream (.mp3/.ogg/icecast) OR a YouTube link.
        -- NOTE: many big 24/7 YouTube live streams block embedded playback
        -- (player error 150 / "auth"). Use a regular (non-live) uploaded
        -- video that allows embedding, or a direct stream URL.
        url     = 'https://www.youtube.com/watch?v=AJgE_dLWsuQ',
        volume  = 0.01, -- 1% volume. 1.0 = full volume, 0.5 = half, etc.
    },
    blur = {
        fps       = 60,
        intensity = 3,
    },
}

-- Studio lineup: characters stand side by side in front of a cyan-lit rock
-- backdrop with a tiled floor. The set is drawn in-world (no MLO needed) and
-- floats high above the ocean so nothing from the map leaks into the shot.
-- When enabled it REPLACES Config.Locations below.
Config.Studio = {
    enabled  = true,
    origin   = vector4(111.181, -573.802, 17.828, 146.63), -- centre slot position (ped root) + heading the peds face
    slots    = 5,
    spacing  = 1.55,                                   -- metres between characters
    camera   = { distance = 4.6, height = 0.6, pitch = -2.0, fov = 50.0 }, -- lineup overview
    detail   = { distance = 2.2, aside = 0.75, fov = 45.0 },              -- close-up; aside > 0 puts the ped right of the menu
    backdrop = {
        enabled      = true,  -- false = don't draw the rock wall/floor (use when origin is inside your own MLO/room)
        wallDistance = 2.4,   -- metres behind the lineup
        width        = 22.0,
        height       = 9.0,
        floorDepth   = 9.0,   -- metres of floor in front of the wall
        floorOffset  = -1.0,  -- floor height relative to the ped root
        glow         = '#2fd3e8',
    },
    lights    = true,         -- scripted key/rim lights so peds read well day or night
    silhouettes = true,       -- empty slots render as a dark silhouette (false = show the bare freemode ped)
    animation = false,        -- false = natural idle, or { type = "animation", lib = "...", anim = "..." }
    locked    = {},           -- premium slots, e.g. { [5] = true }
}

-- Camera + ped scenes. One Location is picked at random on Init.
-- Optional per-scene fields: `pedModel = '<name>'`, `locked = true`.
Config.Locations = {
    {
        defaultCamera = {
            coords = vector3(-586.2933, -706.5692, 114.0051),
            rotation = vector3(-3.0022, -0.0049, 123.6820),
            fov = 57.0,
        },
        scenes = {
            {
                coords = vector4(-596.7833, -707.2360, 114.3052, 262.1913),
                offset = {
                    x = 10,
                    y = 65,
                },
                camera = {
                    coords = vector3(-596.7833, -707.2360, 114.3052),
                    rotation = vector3(-3.0022, -0.0049, 123.6820),
                    fov = 57.0,
                },
                animation = {
                    type = "animation", lib = "timetable@ron@ig_3_couch", anim = "base"
                },
                -- pedModel = 'a_m_y_business_01', -- model used when slot is empty / locked. defaults to mp_*_freemode_01
            },
            {
                coords = vector4(-600.9791, -709.5421, 116.8003, 274.6356),
                offset = {
                    x = 15,
                    y = 115,
                },
                camera = {
                    coords = vector3(-600.9791, -709.5421, 116.8003),
                    rotation = vector3(-3.0022, -0.0049, 123.6820),
                    fov = 57.0,
                },
                animation = {
                    type = "animation", lib = "anim@amb@nightclub@peds@", anim = "rcmme_amanda1_stand_loop_cop"
                },
            },
            {
                coords = vector4(-591.6877, -713.9263, 113.0053, 318.3587),
                offset = {
                    x = 0,
                    y = 100,
                },
                camera = {
                    coords = vector3(-591.6877, -713.9263, 113.0053),
                    rotation = vector3(-3.0022, -0.0049, 123.6820),
                    fov = 57.0,
                },
                animation = {
                    type = "animation", lib = "timetable@ron@ig_5_p3", anim = "ig_5_p3_base"
                },
                -- locked = true, -- Slot 3 — premium, unlock via /openslot
            },
            {
                coords = vector4(-595.1445, -710.9232, 113.0053, 255.1106),
                offset = {
                    x = 25,
                    y = 125,
                },
                camera = {
                    coords = vector3(-595.1445, -710.9232, 113.0053),
                    rotation = vector3(-3.0022, -0.0049, 123.6820),
                    fov = 57.0,
                },
                animation = {
                    type = "animation", lib = "anim@heists@prison_heistig1_p1_guard_checks_bus", anim = "loop"
                },
                -- locked = true, -- Slot 4 — premium, unlock via /openslot
            },

        }
    }
}

-- Admin commands for granting / revoking premium-slot access (rows in the
-- bablo_multicharacter_unlockedslots table). Gated by Framework:IsAdmin.
--   /openslot  <serverId|license:...> <slotIndex>
--   /closeslot <serverId|license:...> <slotIndex>
Config.SlotCommands = {
    open  = 'openslot',
    close = 'closeslot',
}

-- `/relog` style command: unloads the player's current character and re-opens
-- the multichar selector without disconnecting them. Available on QBCore,
-- Qbox, and ESX. Set `adminOnly = true` to gate it behind Framework:IsAdmin.
Config.RelogCommand = {
    enabled   = true,
    command   = 'relog',
    adminOnly = false,
}

-- Spawn-selection menu. When true, after choosing a character the player
-- sees the map with selectable spawn points (and last location / houses).
-- When false the menu is skipped and the player spawns straight at their
-- last saved location.
Config.EnableSpawnMenu = true

-- Hand off to your OWN spawn system when the built-in menu is off.
-- Only used when Config.EnableSpawnMenu = false. On character select the
-- multichar tears down its scene, resets the routing bucket, marks the
-- character loaded, then triggers `event` (a client event) with the character
-- id. It does NOT spawn/teleport — your resource owns positioning + camera.
--   fadeIn = false → screen left black for your resource to fade in itself
--   fadeIn = true  → the multichar fades in after the handoff
Config.CustomSpawn = {
    enabled = false,
    event   = 'my-resource:client:openSpawn', -- receives (characterId)
    fadeIn  = false,
}

-- Optional `job = "police"` or `jobs = { "police", "sheriff" }` restricts the entry to those jobs.
-- Optional `description` (text on the spawn card) and `image` (path under src/web/dist/).
-- icon: pin | parking | plane | house | shield | heart
Config.SpawnPositions = {
    { label = "Legion Park",  icon = "pin", coords = vector3(233.2560, -896.9683, 30.6921),
      description = "The heart of downtown. Grab a coffee and see where the day takes you." },
    { label = "Sandy Shores", icon = "pin", coords = vector3(1678.6544189453, 3765.6867675781, 34.564262390137),
      description = "Dust, heat and a lot of open road. Not everyone out here asks questions." },
    { label = "Paleto Bay",   icon = "pin", coords = vector3(-62.587245941162, 6426.8833007812, 31.486654281616),
      description = "A quiet coastal town at the top of the map." },
    -- { label = "Mission Row PD", icon = "shield",     coords = vector3(441.79, -981.94, 30.69), job  = "police" },
    -- { label = "Pillbox EMS",    icon = "heart",      coords = vector3(307.7, -595.0, 43.3),    jobs = { "ambulance", "doctor" } },
}

-- ESX only. Keep false for stock es_extended (it appends ":license" to the
-- char prefix itself). Set true ONLY if your es_extended is an edited build
-- that stores the identifier exactly as passed - symptom: users rows saved
-- as plain "char1" (no license) and "Duplicate entry 'char1'" on create.
Config.ESXPassFullIdentifier = false

