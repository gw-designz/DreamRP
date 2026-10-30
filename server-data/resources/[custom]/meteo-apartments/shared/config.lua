Apartments = require 'shared.main'
Config = {}

Config.framework = 'auto' -- 'auto', 'qbox', 'qbcore'
Config.target = 'auto' -- 'qb-target' or 'ox_target'
Config.inventory = 'auto' -- 'qb-inventory' or 'ox_inventory'
Config.garage = 'auto' -- 'auto', 'meteo-garages', 'jg-advancedgarages', 'qbx_garages', 'op-garages'
Config.radialMenu = 'qbx_radialmenu' -- 'qbx_radialmenu', 'qb-radialmenu', 'ox_lib', false (to disable)
Config.minigame = 'auto' -- 'auto', 'meteo-circlepick', 'ox_lib'
Config.radialManageProperty = false -- Enable/disable the "Manage Property" radial menu option

-- Currency
Config.currencySymbol = '$'

-- Starter Apartments (CURRENTLY ONLY SUPPORTS FOR DEFAULT QBX ONLY)
-- See https://docs.meteofivem.net/paid-scripts/meteo-walkable-apartments-creator/configuration-guide/qbx-starter-apartments for setup instructions
Config.starterApartments = {
    enabled = true, -- Set to true to enable starter apartment selection
    defaultSpawn = vec4(-829.00, -700.12, 28.06, 96.24), -- Spawn location when select defalt spawn on ui
}

-- Default blip settings
Config.defaultBlip = {
    sprite = 475,
    color = 0,       -- White (default for everyone)
    ownedColor = 2,  -- Green (when player owns 1+ rooms)
    scale = 0.7
}

-- Room types with pricing
Config.roomTypes = {
    ['modern'] = {
        label = 'Modern Apartment',
        price = 50000,
        description = 'A sleek modern apartment'
    },
    ['classic'] = {
        label = 'Classic Apartment',
        price = 35000,
        description = 'A traditional classic apartment'
    },
    ['luxury'] = {
        label = 'Luxury Penthouse',
        price = 150000,
        description = 'Top-floor luxury penthouse'
    }
}

Config.defaultFurnitureLimit = 150 -- For meteo-furnishing

-- Default permissions for new members
Config.defaultMemberPermissions = {
    door = false,
    garage = false,
    stash = false,
    wardrobe = false,
    upgrades = false,
    furnish = false
}

-- Member roles with their permissions and limits
Config.memberRoles = {
    ['manager'] = {
        label = 'Manager',
        permissions = { door = true, garage = true, stash = true, wardrobe = true, upgrades = true, furnish = true },
        defaultLimit = 1,  -- Default max managers per apartment
        color = '#FF657A'  -- UI badge color (red/pink)
    },
    ['keyholder'] = {
        label = 'Key Holder',
        permissions = { door = true, garage = true, stash = true, wardrobe = true, upgrades = false, furnish = false },
        defaultLimit = 2,  -- Default max keyholders per apartment
        color = '#57EFAF'  -- UI badge color (green)
    },
    ['guest'] = {
        label = 'Guest',
        permissions = { door = true, garage = false, stash = false, wardrobe = false, upgrades = false, furnish = false },
        defaultLimit = 2,  -- Default max guests per apartment
        color = '#4A90E2'  -- UI badge color (blue)
    }
}

-- Apartment Upgrades
Config.upgrades = {
    -- Door Security Upgrades
    doorSecurity = {
        enabled = true,
        levels = {
            -- level 1 is default, no purchase needed
            [2] = { label = 'Standard Security', price = 5000 },
            [3] = { label = 'Advanced Security', price = 15000 },
            [4] = { label = 'High Security', price = 30000 },
            [5] = { label = 'Anti-Burglary', price = 50000 },
            [6] = { label = 'Maximum Security', price = 100000 }
        }
    },

    -- Member Limit Upgrades (per role)
    memberLimit = {
        enabled = true,
        perRole = true,  -- Limits apply per role, not total members
        tiers = {
            -- Each tier upgrades limits for ALL roles
            {
                label = 'Small Group',
                price = 10000,
                limits = {
                    manager = 2,
                    keyholder = 5,
                    guest = 5
                }
            },
            {
                label = 'Medium Group',
                price = 25000,
                limits = {
                    manager = 3,
                    keyholder = 10,
                    guest = 10
                }
            },
            {
                label = 'Large Group',
                price = 50000,
                limits = {
                    manager = 5,
                    keyholder = 20,
                    guest = 20
                }
            },
            {
                label = 'Unlimited',
                price = 100000,
                limits = {
                    manager = 999,
                    keyholder = 999,
                    guest = 999
                }
            }
        }
    }
}

-- Door Lock System
Config.doorlock = {
    enabled = true,
    maxDistance = 1.0,           -- Interaction distance for E key

    -- Distance to activate door point (loads door entity + sprite)
    -- WARNING: Higher values = higher resmon (resource usage)
    -- Recommended: 2.0 (balanced between usability and performance)
    pointDistance = 2.0,

    -- Lockpick settings
    lockpick = {
        enabled = true,
        alertOwner = true,           -- Notify owner on lockpick attempt
        requireOwned = true,         -- Can only lockpick doors that have an owner (no vacant apartments)
        requireOwnerOnline = true,   -- Owner must be online to lockpick their door
        maxAttempts = 3,             -- Base attempts before cooldown kicks in
        items = {
            ['lockpick'] = {
                label = 'Lockpick',
                breakChance = 15,    -- 15% break chance on fail
                breakChanceSuccess = 2  -- 2% break even on success
            },
            ['advancedlockpick'] = {
                label = 'Advanced Lockpick',
                breakChance = 5,     -- 5% break chance on fail
                breakChanceSuccess = 0  -- Never breaks on success
            }
        },
        cooldown = 30000             -- 30 second cooldown after all attempts exhausted
    },

    -- Police Stormram (raid) settings
    stormram = {
        enabled = true,
        item = 'police_stormram',    -- Item name
        removeOnUse = true,          -- Remove item after use (success or fail)
        alertOwner = true,           -- Notify owner on raid attempt
        requireOwned = true,         -- Can only raid doors that have an owner
        requireOwnerOnline = true,   -- Owner must be online to raid
        jobs = {                     -- Allowed jobs (false to disable job check)
            ['police'] = 0,          -- job = minGrade (0 = any grade)
        },
        cooldown = 60000             -- 60 second cooldown after failed attempt per door
    },

    -- Burglar alarm settings
    alarm = {
        enabled = true,
        audioBank = 'Alarms',        -- Audio bank name
        soundName = 'Burglar_Bell',  -- Sound name from the audio bank
        soundSet = 'Generic_Alarms', -- Sound set name
        duration = 60000,            -- Alarm duration in milliseconds (60 seconds)
        range = 50.0,                -- Range in which players can hear the alarm
        triggerOnLockpick = true,    -- Play alarm when successfully lockpicked
        triggerOnStormram = false,   -- Don't play alarm for police raids
    },

    -- Higher level = harder lockpick minigame
    -- antiBurglary = true prevents lockpick
    -- antiRaid = true prevents stormram (police raid)
    -- alertPolice = true notifies online police when lockpick attempted
    securityLevels = {
        [1] = {
            label = 'Basic',
            difficulty = { 'easy', 'easy' },              -- ox_lib skillCheck
            circlepickDifficulty = 'easy',                 -- meteo-circlepick difficulty
            autoLockTime = nil,      -- No auto-lock
            antiBurglary = false,
            antiRaid = false,
            -- alertPolice = false
            alertPolice = true
        },
        [2] = {
            label = 'Standard',
            difficulty = { 'easy', 'medium', 'easy' },    -- ox_lib skillCheck
            circlepickDifficulty = 'easy',                 -- meteo-circlepick difficulty
            autoLockTime = 300,      -- 5 minutes
            antiBurglary = false,
            antiRaid = false,
            alertPolice = false
        },
        [3] = {
            label = 'Advanced',
            difficulty = { 'medium', 'medium', 'hard' },  -- ox_lib skillCheck
            circlepickDifficulty = 'medium',               -- meteo-circlepick difficulty
            autoLockTime = 180,      -- 3 minutes
            antiBurglary = false,
            antiRaid = false,
            alertPolice = true       -- Silent alarm to police
        },
        [4] = {
            label = 'High Security',
            difficulty = { 'hard', 'hard', 'hard', 'hard' }, -- ox_lib skillCheck
            circlepickDifficulty = 'hard',                 -- meteo-circlepick difficulty
            autoLockTime = 60,       -- 1 minute
            antiBurglary = false,
            antiRaid = false,
            alertPolice = true       -- Silent alarm to police
        },
        [5] = {
            label = 'Anti-Burglary',
            difficulty = { 'hard', 'hard', 'hard', 'hard' }, -- ox_lib skillCheck
            circlepickDifficulty = 'hard',                 -- meteo-circlepick difficulty
            autoLockTime = 30,       -- 30 seconds
            antiBurglary = true,     -- Cannot be lockpicked
            antiRaid = false,        -- Can still be raided by police
            alertPolice = false      -- No need, can't be lockpicked anyway
        },
        [6] = {
            label = 'Maximum Security',
            difficulty = { 'hard', 'hard', 'hard', 'hard' }, -- ox_lib skillCheck
            circlepickDifficulty = 'hard',                 -- meteo-circlepick difficulty
            autoLockTime = 30,
            antiBurglary = true,     -- Cannot be lockpicked
            antiRaid = true,         -- Cannot be raided
            alertPolice = false      -- No need, can't be lockpicked anyway
        }
    },

    -- Jobs to alert when alertPolice is triggered
    alertPoliceJobs = {
        ['police'] = 0,              -- All police officers
    },

    -- Alert system configuration
    alerts = {
        -- Dispatch system: 'auto', 'default', 'meteo-dispatch', 'ps-dispatch', 'tk_dispatch'
        -- 'auto' = auto-detect started resources
        -- 'default' = QBCore:Notify to all online officers
        dispatchSystem = 'default',

        -- Phone system for owner/member notifications: 'auto', 'default', 'meteo-phone', 'high-phone', 'qb-phone' (qbox npwd support)
        -- 'auto' = auto-detect started resources
        -- 'default' = QBCore:Notify
        phoneSystem = 'default',
    },

    defaultSecurityLevel = 1     -- Default for new apartments
}

-- lib.locale('fr')