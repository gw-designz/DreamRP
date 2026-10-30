return {
    jobs = {
        ['police'] = 0,
        ['sheriff'] = 0,
    },
    blips = {
        {label = 'LSPD Dept.', coords = vec3(430.28, -981.30, 30.71), sprite = 60, color = 29, scale = 0.95},
        {label = 'Police Armoury', coords = vec3(452.28, -980.30, 30.71), sprite = 110, color = 29, scale = 0.95, jobOnly = true},
    },
    -- Reception bells. Anyone can ring them; every job listed in `jobs` gets a
    -- dispatch alert. Optional per-bell `cooldown` in seconds (default 30).
    bells = {
        {
            coords = vec3(445.73, -990.36, 30.75), radius = 0.75, distance = 2.0,
            jobs = { ['police'] = true, ['sheriff'] = true },
        },
    },

    -- Trash bins. Each entry creates a sphere zone with "Open Trash" (a shared
    -- disposal stash you can drop items into) and "Empty Trash" (wipes it).
    trashes = {
        { coords = vec3(446.34, -1004.23, 30.77), radius = 1.0, distance = 2.0 },
    },

    -- Locker access points. Each entry creates a sphere zone with an "Open
    -- Locker" target that opens the locker input dialog (type your locker ID).
    lockers = {
        { coords = vec3(449.91, -997.79, 30.97), radius = 1.0, distance = 2.0 },
    },

    -- Wardrobe access points. Each entry creates a sphere zone with an "Open
    -- Wardrobe" target that opens the department wardrobe UI (apply/manage
    -- shared outfits). Requires Config.Wardrobe.Enabled. Adjust coords to
    -- your locker room.
    wardrobes = {
        { coords = vec3(465.57, -1008.13, 30.91), radius = 1.0, distance = 2.0 },
    },

    -- CCTV control point(s). Each entry creates a sphere-zone target with a
    -- "Watch cameras" option that opens the CCTV viewing menu. This replaces the
    -- old /cctv and /cctv_menu chat commands. Access is still gated by
    -- Config.CCTV.defaultJobs. Adjust coords to your CCTV room.
    cctv = {
        { coords = vec3(441.88, -974.39, 30.84), radius = 1.0, distance = 2.0, label = 'Watch cameras' },
    },

    duty = {
        {
            coords = vec4(449.92, -987.29, 30.71, 183.00),
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
            coords = vec4(449.33, -1005.42, 30.71, 0.00),
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
                -- optional per-item fields:
                --   license = 'weapon'                 [player must hold this license to see/buy the item]
                --   licenses = { 'weapon', 'drive' }   [same, but requires all listed licenses]
                --   stock = 50                         [initial stock when Config.Armoury.UseStock is enabled]
                --   minGrade = 3                       [minimum job grade to buy the item; lower grades see it locked]
                -- example: {name = 'WEAPON_CARBINERIFLE', price = 1000, category = 'weapons', license = 'weapon', minGrade = 3},
                {name = 'WEAPON_COMBATPISTOL', minGrade = 1, price = 100, category = 'weapons'},
                {name = 'WEAPON_PUMPSHOTGUN', minGrade = 3, price = 100, category = 'weapons'},
                {name = 'WEAPON_CARBINERIFLE', minGrade = 3, price = 1000, category = 'weapons'},
                {name = 'WEAPON_STUNGUN', minGrade = 1, price = 100, category = 'weapons'},
                {name = 'WEAPON_FLASHLIGHT', price = 0, category = 'weapons'},
                {name = 'WEAPON_NIGHTSTICK', price = 100, category = 'weapons'},
                {name = 'WEAPON_RADAR', price = 200, category = 'weapons'},
                {name = 'WEAPON_FLASHBANG', minGrade = 2, price = 250, category = 'weapons'},
                {name = 'vest_normal', price = 250, category = 'equipment'},
                {name = 'vest_strong', price = 500, category = 'equipment'},
                {name = 'police_shield', price = 750, category = 'equipment'},
                {name = 'nightvision', price = 300, category = 'equipment'},
                {name = 'thermalvision', price = 500, category = 'equipment'},
                {name = 'rappel_kit', price = 250, category = 'equipment'},
                {name = 'battering_ram', price = 500, category = 'equipment'},
                {name = 'police_diving_suit', price = 300, category = 'equipment'},
                {name = 'body_cam', price = 100, category = 'equipment'},
                {name = 'breathalyzer', price = 150, category = 'equipment'},
                {name = 'drug_test_kit', price = 150, category = 'equipment'},
                {name = 'fingerprint_scanner', price = 200, category = 'equipment'},
                {name = 'camera', price = 150, category = 'equipment'},
                {name = 'gps', price = 100, category = 'equipment'},
                {name = 'megaphone', price = 100, category = 'equipment'},
                {name = 'spikestrip', price = 200, category = 'equipment'},
                {name = 'wheel_clamp', price = 250, category = 'equipment'},
                {name = 'roadcone', price = 10, category = 'equipment'},
                {name = 'barrier', price = 25, category = 'equipment'},
                {name = 'consign', price = 25, category = 'equipment'},
                {name = 'tracking_band', price = 150, category = 'equipment'},
                {name = 'tracking_vehicle', price = 200, category = 'equipment'},
                {name = 'evidence_kit', price = 100, category = 'equipment'},
                {name = 'swab_kit', price = 50, category = 'equipment'},
                {name = 'fingerprint_kit', price = 75, category = 'equipment'},
                {name = 'cleaning_kit', price = 100, category = 'equipment'},
                {name = 'broom', price = 25, category = 'equipment'},
                {name = 'evidence_reconstructor', price = 500, category = 'equipment'},
                {name = 'handcuffs', price = 100, category = 'misc'},
                {name = 'cuffs_key', price = 25, category = 'misc'},
                {name = 'cable_ties', price = 50, category = 'misc'},
                {name = 'mouthtape', price = 25, category = 'misc'},
                {name = 'headbag', price = 50, category = 'misc'},
                {name = 'radio', price = 50, category = 'misc'},
            }
        }
    },

    extras = {
        {coords = vector3(419.6291, -1020.9120, 29.0104), size = 10.0, label = 'MRPD Garage'},
    },

    garages = {
        ['mrpd'] = {
            label = 'Mission Row Garage',
            blip = { enabled = true, coords = vector3(434.68, -1029.12, 28.99), sprite = 357, color = 3, scale = 0.75, label = 'Police Garage' },
            ped = { model = 's_m_y_cop_01', coords = vec4(434.6770, -1029.1232, 28.9886, 0.0), anim = { dict = 'amb@world_human_cop_idles@male@idle_b', clip = 'idle_e' }, onCreate = function(ped) end },
            allowedJobs = { ['police'] = 0, ['sheriff'] = 0 },
            spawnPoints = {
                vector4(431.7113, -1027.2172, 28.9471, 179.8748),
                vector4(427.6960, -1027.6909, 28.9821, 182.6840),
                vector4(424.0269, -1028.0519, 29.0469, 184.6641),
                vector4(420.0333, -1028.3597, 29.1166, 186.3764),
                vector4(416.5734, -1028.6340, 29.1769, 185.2027),
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
            coords = vec3(467.16, -1001.60, 34.25),
            heading = 180.0,
            label = 'LSPD Crime Lab',
            jobs = {['police'] = 0, ['sheriff'] = 0},
            blip = {sprite = 458, color = 38, scale = 0.7, label = 'Crime Lab'},
        },
    },

    vehicleShops = {
        ['mrpd'] = {
            label = 'MRPD Fleet Management',
            blip = {
                enabled = true,
                coords = vector3(458.5, -1017.5, 28.0),
                sprite = 326,
                color = 29,
                scale = 0.8,
                label = 'Police Vehicle Shop',
            },
            ped = {
                model = 's_m_y_cop_01',
                coords = vec4(456.87, -1005.11, 24.45, 79.00),
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
            camera = {
                coords = vector3(452.8807, -1008.0911, 25.4525),
                pointAt = vector3(447.0822, -1007.7623, 24.2025),
                fov = 60.0,
            },
            vehicleSpawn = vector4(447.0822, -1007.7623, 24.4525, 232.5105),
            purchaseSpawn = vector4(447.1640, -1019.9455, 24.4525, 355.5745),
            allowedJobs = {
                ['police']  = 0,
                ['sheriff'] = 0,
            },
        },
    },

    mugshots = {
        ['Mission_Row'] = {
            coords = vector3(454.47, -980.56, 27.5),
            photoCoords = vector3(451.0381, -980.3453, 27.8340),
            cameraCoords = vector3(452.9016, -980.3027, 28.3120),
            cameraFov = 40.0,
            jobs = {
                ['police'] = 0,
            },
        },
    },

    bodycams = {
        ['Mission_Row'] = {
            coords = vector3(447.39, -992.86, 30.69),
            radius = 0.5,
            jobs = {
                ['police']  = 0,
                ['sheriff'] = 0,
            },
        },
    },
}