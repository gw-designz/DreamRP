return {

    jobs = {
        ['police'] = 0,
        ['sheriff'] = 0,
    },

    blips = {
        { label = 'LSPD Dept.', coords = vec3(622.9393, 7.3440, 83.6221), sprite = 60, color = 29, scale = 0.95 },
    },
    -- Trash bins. Each entry creates a sphere zone with "Open Trash" (a shared
    -- disposal stash you can drop items into) and "Empty Trash" (wipes it).

    trashes = {
        { coords = vec3(615.39, -3.05, 83.30), radius = 1.0, distance = 2.0 },
    },

    lockers = {
        { coords = vec3(607.99, 9.14, 88.09), radius = 1.0, distance = 2.0 },
    },

    -- Wardrobe access points. Each entry creates a sphere zone with an "Open
    -- Wardrobe" target that opens the department wardrobe UI (apply/manage
    -- shared outfits). Requires Config.Wardrobe.Enabled. Adjust coords to
    -- your locker room.
    wardrobes = {
        { coords = vec3(608.99, 12.08, 87.83), radius = 1.0, distance = 2.0 },
    },

    -- CCTV control point(s). Each entry creates a sphere-zone target with a
    -- "Watch cameras" option that opens the CCTV viewing menu. This replaces the
    -- old /cctv and /cctv_menu chat commands. Access is still gated by
    -- Config.CCTV.defaultJobs. Adjust coords to your CCTV room.
    cctv = {
        { coords = vec3(617.97, 9.20, 83.45), radius = 1.0, distance = 2.0, label = 'Watch cameras' },
    },

    duty = {
        {
            coords = vec4(616.18, 6.59, 83.64, 238.00),
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
            coords = vec4(603.7579, 6.2230, 87.8020, 257.0000),
            ped = {
                model = 's_m_y_cop_01',
                scenario = 'WORLD_HUMAN_GUARD_STAND',
                onCreate = function(ped) end
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
        },
    },

    extras = {
        { coords = vec3(564.3, 9.81, 69.61), size = 10.0, label = 'MRPD Garage' },
    },

    garages = {
        ['garage_1'] = {
            label = 'Police Garage',
            blip = {
                enabled = true,
                coords  = vector3(582.2520, 2.5579, 73.9268),
                sprite  = 357,
                color   = 3,
                scale   = 0.75,
                label   = 'Police Garage',
            },
            ped = {
                model    = 's_m_y_cop_01',
                coords   = vec4(573.8953, 5.6272, 73.9268, 250.0000),
                anim     = { dict = 'amb@world_human_cop_idles@male@idle_b', clip = 'idle_e' },
                onCreate = function(ped) end,
            },
            allowedJobs = {
                ['police'] = 0,
                ['sheriff'] = 0,
            },
            spawnPoints = {
                vector4(574.3470, -1.0600, 73.9268, 253.0000),
                vector4(575.1455, 3.0225, 73.9268, 253.0000),
                vector4(576.0066, 6.9807, 73.9268, 256.0000),
                vector4(577.9570, 10.8400, 73.9268, 253.0000),
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
            coords  = vec3(613.4377, 4.1639, 84.9547),
            heading = 0.0000,
            label   = 'LSPD Crime Lab',
            jobs    = { ['police'] = 0, ['sheriff'] = 0 },
            blip    = { sprite = 458, color = 38, scale = 0.7, label = 'Crime Lab' },
        },
    },

    vehicleShops = {
        ['vshop_1'] = {
            label         = 'Police Vehicle Shop',
            blip          = {
                enabled = true,
                coords  = vector3(597.8469, -6.8977, 74.0046),
                sprite  = 326,
                color   = 29,
                scale   = 0.8,
                label   = 'Police Vehicle Shop',
            },
            ped           = {
                model    = 's_m_y_cop_01',
                coords   = vec4(597.9276, -6.7872, 74.0046, 70.0000),
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
            camera        = {
                coords  = vec3(600.03, -3.68, 77.32),
                pointAt = vector3(587.72, 0.58, 73.93),
                fov     = 60.0000,
            },
            vehicleSpawn  = vec4(587.72, 0.58, 73.93, 344.00),
            purchaseSpawn = vector4(600.3843, 11.5675, 73.9268, 164.0000),
            allowedJobs   = {
                ['police'] = 0,
                ['sheriff'] = 0,
            },
        },
    },

    mugshots = {
        ['mugshot_1'] = {
            coords       = vector3(614.0656, 13.2763, 75.0448),
            photoCoords  = vector3(617.3663, 11.7398, 76.5505),
            cameraCoords = vector3(613.5629, 13.4359, 76.4170),
            cameraFov    = 40.0000,
            jobs         = {
                ['police'] = 0,
            },
        },
    },

    bodycams = {
        ['bodycam_1'] = {
            coords = vector3(617.9785, 9.1685, 84.4479),
            radius = 0.5000,
            jobs = {
                ['police'] = 0,
                ['sheriff'] = 0,
            },
        },
    },
}
