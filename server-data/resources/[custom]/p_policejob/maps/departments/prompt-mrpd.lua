return {
    jobs = {
        ['police'] = 0,
        ['sheriff'] = 0,
    },
    blips = {
        { label = 'LSPD Dept.',     coords = vec3(441.82, -990.1, 28.11),   sprite = 60,  color = 29, scale = 0.95 },
        { label = 'Police Armoury', coords = vec3(462.63, -1011.88, 28.13), sprite = 110, color = 29, scale = 0.95, jobOnly = true },
    },
    -- Trash bins. Each entry creates a sphere zone with "Open Trash" (a shared
    -- disposal stash you can drop items into) and "Empty Trash" (wipes it).
    trashes = {
        { coords = vec3(462.33, -1011.88, 23.51), radius = 1.0, distance = 2.0 },
    },

    -- Locker access points. Each entry creates a sphere zone with an "Open
    -- Locker" target that opens the locker input dialog (type your locker ID).
    lockers = {
        { coords = vec3(456.67, -1012.48, 29.20), radius = 1.0, distance = 2.0 },
    },

    -- Wardrobe access points. Each entry creates a sphere zone with an "Open
    -- Wardrobe" target that opens the department wardrobe UI (apply/manage
    -- shared outfits). Requires Config.Wardrobe.Enabled. Adjust coords to
    -- your locker room.
    wardrobes = {
        { coords = vec3(460.86, -1010.59, 29.22), radius = 1.0, distance = 2.0 },
    },

    -- CCTV control point(s). Each entry creates a sphere-zone target with a
    -- "Watch cameras" option that opens the CCTV viewing menu. This replaces the
    -- old /cctv and /cctv_menu chat commands. Access is still gated by
    -- Config.CCTV.defaultJobs. Adjust coords to your CCTV room.
    cctv = {
        { coords = vec3(455.93, -981.49, 29.32), radius = 1.0, distance = 2.0, label = 'Watch cameras' },
    },

    duty = {
        {
            coords = vec4(457.24, -1004.31, 29.11, 176.59),
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
            coords = vec4(462.63, -1011.88, 29.13, 320.81),
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
        { coords = vec3(450.21, -1020.21, 27.9), size = 10.0, label = 'MRPD Garage' },
    },

    garages = {
        ['mrpd'] = {
            label = 'Mission Row Garage',
            blip = { enabled = true, coords = vec3(447.48, -971.9, 22.37), sprite = 357, color = 3, scale = 0.75, label = 'Police Garage' },
            ped = {
                model = 's_m_y_cop_01',
                coords = vec4(447.48, -971.9, 23.37, 174.07),
                anim = { dict = 'amb@world_human_cop_idles@male@idle_b', clip = 'idle_e' },
                onCreate = function(
                    ped)
                end
            },
            allowedJobs = { ['police'] = 0, ['sheriff'] = 0 },
            spawnPoints = {
                vec4(451.87, -975.17, 22.13, 90.98),
                vec4(452.02, -978.37, 22.13, 85.85),
                vec4(451.64, -982.41, 22.13, 93.34),
                vec4(451.6, -985.54, 22.13, 86.68),
                vec4(440.72, -978.35, 22.13, 270.33),
                vec4(440.59, -982.43, 22.13, 268.69),
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
            coords = vec3(439.00, -1023.08, 23.73),
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
                coords = vec3(442.9, -1008.95, 22.37),
                sprite = 326,
                color = 29,
                scale = 0.8,
                label = 'Police Vehicle Shop',
            },
            ped = {
                model = 's_m_y_cop_01',
                coords = vec4(442.9, -1008.95, 23.37, 358.32),
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
            camera = {
                coords = vec3(440.18, -1009.90, 24.81),
                pointAt = vec3(440.61, -1004.33, 22.13),
                fov = 60.0,
            },
            vehicleSpawn = vec4(440.34, -1004.18, 22.13, 269.35),
            purchaseSpawn = vec4(440.56, -999.9, 22.13, 267.21),
            allowedJobs = {
                ['police']  = 0,
                ['sheriff'] = 0,
            },
        },
    },

    mugshots = {
        ['Mission_Row'] = {
            coords = vec3(465.03, -991.40, 29.06),
            photoCoords = vec3(468.7, -993.29, 28.13),
            cameraCoords = vec3(466.51, -993.29, 29.49),
            cameraFov = 40.0,
            jobs = {
                ['police'] = 0,
            },
        },
    },

    bodycams = {
        ['Mission_Row'] = {
            coords = vec3(455.97, -983.08, 29.45),
            radius = 0.5,
            jobs = {
                ['police']  = 0,
                ['sheriff'] = 0,
            },
        },
    },
}
