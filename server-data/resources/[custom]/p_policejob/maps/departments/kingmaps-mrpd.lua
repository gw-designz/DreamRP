return {
    jobs = {
        ['police'] = 0,
        ['sheriff'] = 0,
    },
    blips = {
        { label = 'LSPD Dept.',     coords = vec3(431.05, -987.98, 30.09), sprite = 60,  color = 29, scale = 0.95 },
        { label = 'Police Armoury', coords = vec3(465.83, -984.21, 25.09), sprite = 110, color = 29, scale = 0.95, jobOnly = true },
    },
    -- Trash bins. Each entry creates a sphere zone with "Open Trash" (a shared
    -- disposal stash you can drop items into) and "Empty Trash" (wipes it).
    trashes = {
        { coords = vec3(480.54, -1003.88, 36.28), radius = 1.0, distance = 2.0 },
    },

    -- Locker access points. Each entry creates a sphere zone with an "Open
    -- Locker" target that opens the locker input dialog (type your locker ID).
    lockers = {
        { coords = vec3(482.93, -974.12, 26.16), radius = 1.0, distance = 2.0 },
    },


    -- Wardrobe access points. Each entry creates a sphere zone with an "Open
    -- Wardrobe" target that opens the department wardrobe UI (apply/manage
    -- shared outfits). Requires Config.Wardrobe.Enabled. Adjust coords to
    -- your locker room.
    wardrobes = {
        { coords = vec3(485.43, -970.84, 26.32), radius = 1.0, distance = 2.0 },
    },

    -- CCTV control point(s). Each entry creates a sphere-zone target with a
    -- "Watch cameras" option that opens the CCTV viewing menu. This replaces the
    -- old /cctv and /cctv_menu chat commands. Access is still gated by
    -- Config.CCTV.defaultJobs. Adjust coords to your CCTV room.
    cctv = {
        { coords = vec3(458.56, -985.73, 35.90), radius = 1.0, distance = 2.0, label = 'Watch cameras' },
    },

    duty = {
        {
            coords = vec4(471.59, -980.6, 36.1, 1.16),
            radius = 1.2,
            distance = 2.0,
            ped = {
                model = 's_m_y_cop_01',
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
        },
    },

    armouries = {
        {
            coords = vec4(467.89, -984.25, 26.09, 86.68),
            ped = {
                model = 's_m_y_cop_01',
                scenario = 'WORLD_HUMAN_GUARD_STAND',
                -- anim = {
                --     dict = 'missheistdockssetup1ig_10@idle_a',
                --     name = 'idle_a',
                -- },
                onCreate = function(ped)
                end
            },
            items = {
                { name = 'WEAPON_PISTOL',       price = 100,  category = 'weapons' },
                { name = 'WEAPON_COMBATPISTOL', price = 100,  category = 'weapons' },
                { name = 'WEAPON_PUMPSHOTGUN',  price = 100,  category = 'weapons' },
                { name = 'WEAPON_CARBINERIFLE', price = 1000, category = 'weapons' },
                { name = 'WEAPON_STUNGUN',      price = 100,  category = 'weapons' },
                { name = 'WEAPON_FLASHLIGHT',   price = 0,    category = 'weapons' },
                { name = 'WEAPON_NIGHTSTICK',   price = 100,  category = 'weapons' },
                { name = 'handcuffs',           price = 100,  category = 'misc' },
                { name = 'bodycam',             price = 100,  category = 'misc' },
                { name = 'radio',               price = 50,   category = 'misc' },
            }
        }
    },

    extras = {
        { coords = vec3(439.29, -1020.88, 28.22), size = 10.0, label = 'MRPD Garage' },
    },

    garages = {
        ['mrpd'] = {
            label = 'Mission Row Garage',
            blip = { enabled = true, coords = vector3(466.28, -998.34, 29.29), sprite = 357, color = 3, scale = 0.75, label = 'Police Garage' },
            ped = {
                model = 's_m_y_cop_01',
                coords = vec4(463.11, -1002.54, 30.29, 274.79),
                anim = { dict = 'amb@world_human_cop_idles@male@idle_b', clip = 'idle_e' },
                onCreate = function(
                    ped)
                end
            },
            allowedJobs = { ['police'] = 0, ['sheriff'] = 0 },
            spawnPoints = {
                vec4(465.36, -999.31, 29.29, 267.74),
                vec4(465.93, -995.9, 29.29, 270.09),
                vec4(465.97, -992.47, 29.29, 268.66),
                vec4(466.13, -989.02, 29.29, 274.83),
            },
            -- Optional: spawner mode (no DB / owned vehicles, no store option, only preconfigured below)
            -- spawnerMode = true,

            -- Optional: simple grade-based job vehicles (no mods, just spawn fresh)
            -- vehicles = {
            --     ['police'] = {
            --         [0] = { ['police'] = 'Police Cruiser', ['police2'] = 'Police Cruiser 2' },
            --         [2] = { ['police3'] = 'Police Cruiser 3' },
            --     },
            -- },

            -- Optional: preconfigured vehicles with full mods (any field accepted by lib.setVehicleProperties)
            -- preconfiguredVehicles = {
            --     ['police'] = {
            --         [0] = {
            --             {
            --                 model = 'police',
            --                 label = 'Patrol Cruiser',
            --                 properties = {
            --                     plate         = 'LSPD001',
            --                     color1        = 0,
            --                     color2        = 0,
            --                     pearlescentColor = 0,
            --                     wheelColor    = 0,
            --                     fuelLevel     = 100.0,
            --                     engineHealth  = 1000.0,
            --                     bodyHealth    = 1000.0,
            --                     modArmor      = 4,
            --                     modEngine     = 3,
            --                     modBrakes     = 2,
            --                     modTransmission = 2,
            --                     modSuspension = 3,
            --                     modTurbo      = true,
            --                     modXenon      = true,
            --                     xenonColor    = 1,
            --                     windowTint    = 1,
            --                     wheels        = 7,
            --                     modFrontWheels = 0,
            --                     extras        = { [1] = true, [2] = false },
            --                     livery        = 0,
            --                     modLivery     = 0,
            --                     neonEnabled   = { false, false, false, false },
            --                     neonColor     = { 255, 0, 0 },
            --                 },
            --             },
            --         },
            --         [3] = {
            --             { model = 'police3', label = 'Sergeant Cruiser', properties = { plate = 'SGT001', modArmor = 4, modEngine = 3 } },
            --         },
            --     },
            -- },
        },
    },

    laboratories = {
        {
            coords = vec3(478.57, -992.27, 36.19),
            heading = 180.0,
            label = 'LSPD Crime Lab',
            jobs = { ['police'] = 0, ['sheriff'] = 0 },
            blip = { sprite = 458, color = 38, scale = 0.7, label = 'Crime Lab' },
        },
    },

    vehicleShops = {
        ['mrpd'] = {
            label = 'MRPD Fleet Management',
            blip = {
                enabled = true,
                coords = vec3(472.61, -987.52, 29.29),
                sprite = 326,
                color = 29,
                scale = 0.8,
                label = 'Police Vehicle Shop',
            },
            ped = {
                model = 's_m_y_cop_01',
                coords = vec4(472.61, -987.52, 30.29, 181.17),
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
            camera = {
                coords = vec3(475.42, -986.73, 32.34),
                pointAt = vec3(475.04, -991.13, 29.29),
                fov = 60.0,
            },
            vehicleSpawn = vec4(475.04, -991.13, 29.29, 179.85),
            purchaseSpawn = vec4(471.57, -990.82, 29.29, 177.99),
            allowedJobs = {
                ['police']  = 0,
                ['sheriff'] = 0,
            },
        },
    },

    mugshots = {
        ['Mission_Row'] = {
            coords = vec3(464.51, -1005.55, 26.70),
            photoCoords = vec3(462.26, -1005.67, 25.09),
            cameraCoords = vec3(464.30, -1005.57, 26.89),
            cameraFov = 40.0,
            jobs = {
                ['police'] = 0,
            },
        },
    },

    bodycams = {
        ['Mission_Row'] = {
            coords = vec3(452.51, -985.96, 35.92),
            radius = 0.5,
            jobs = {
                ['police']  = 0,
                ['sheriff'] = 0,
            },
        },
    },
}
