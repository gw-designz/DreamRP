return {
    jobs = {
        police = 0,
        sheriff = 0,
    },

    blips = {
        {label = 'LSPD Dept.', coords = vec3(434.5771, 0.0000, 0.0000), sprite = 60, color = 29, scale = 0.95},
    },

    trashes = {
    },

    lockers = {
        { coords = vec3(478.4122, 0.0000, 0.0000), radius = 1.0000, distance = 2.0000 },
        { coords = vec3(477.1176, 0.0000, 0.0000), radius = 1.0000, distance = 2.0000 },
    },

    wardrobes = {
        { coords = vec3(481.4015, 0.0000, 0.0000), radius = 1.0000, distance = 2.0000 },
    },

    cctv = {
    },

    duty = {
        {
            coords = vec4(470.3200, -982.5046, 26.3864, 185.0000),
            radius = 1.2000,
            distance = 2.0000,
            ped = {
                model = 's_m_y_cop_01',
                scenario = 'WORLD_HUMAN_CLIPBOARD',
            },
        },
    },

    armouries = {
        {
            coords = vec4(476.6925, 0.0000, 0.0000, 0.0000),
            ped = {
                model = 's_m_y_cop_01',
                scenario = 'WORLD_HUMAN_GUARD_STAND',
                onCreate = function(ped) end
            },
            items = {
                {name = 'WEAPON_PISTOL', price = 100, category = 'weapons'},
                {name = 'WEAPON_COMBATPISTOL', price = 100, category = 'weapons'},
                {name = 'WEAPON_PUMPSHOTGUN', price = 100, category = 'weapons'},
                {name = 'WEAPON_CARBINERIFLE', price = 1000, category = 'weapons'},
                {name = 'WEAPON_STUNGUN', price = 100, category = 'weapons'},
                {name = 'WEAPON_FLASHLIGHT', price = 0, category = 'weapons'},
                {name = 'WEAPON_NIGHTSTICK', price = 100, category = 'weapons'},
                {name = 'handcuffs', price = 100, category = 'misc'},
                {name = 'bodycam', price = 100, category = 'misc'},
                {name = 'radio', price = 50, category = 'misc'},
            }
        },
    },

    extras = {
    },

    garages = {
        ['garage_1'] = {
            label = 'Police Garage',
            blip = {
                enabled = true,
                coords  = vector3(445.2965, 0.0000, 0.0000),
                sprite  = 357,
                color   = 3,
                scale   = 0.75,
                label   = 'Police Garage',
            },
            ped = {
                model    = 's_m_y_cop_01',
                coords   = vec4(448.7747, 0.0000, 0.0000, 0.0000),
                anim     = { dict = 'amb@world_human_cop_idles@male@idle_b', clip = 'idle_e' },
                onCreate = function(ped) end,
            },
            allowedJobs = {
                ['police'] = 0,
                ['sheriff'] = 0,
            },
            spawnPoints = {
                vector4(462.8831, 0.0000, 0.0000, 0.0000),
                vector4(466.1604, 0.0000, 0.0000, 0.0000),
                vector4(0.0000, 0.0000, 0.0000, 0.0000),
            },
            vehicles = {
                ['police'] = {
                    [0] = { ['polbuffalo4'] = 'Police Buffalo 4' },
                },
            },
        },
    },

    laboratories = {
    },

    vehicleShops = {
    },

    mugshots = {
    },

    bodycams = {
    },
}
