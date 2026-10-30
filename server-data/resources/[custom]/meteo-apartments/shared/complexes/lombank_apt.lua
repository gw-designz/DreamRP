
return {
    label = 'Lombank Apartments', -- https://forum.cfx.re/t/mlo-wiwang-hotel-380-rooms/5364084
    coords = vec3(-597.93, 42.12, 43.61),
    startingRoom = 101,
    totalRooms = 70,
    roomType = 'classic',
    startingEnabled = true,  -- Available for spawn selectors

    blip = {
        enabled = true,
        sprite = 475,
        color = 2,
        ownedColor = 10,  -- Green (when player owns 1+ rooms)
        scale = 0.7
    },

    npc = {
        enabled = true,
        coords = vec4(-597.11, 48.48, 43.61, 179.36),
        model = 'a_f_y_business_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD'
    },

    garage = {
        id = 'lombank_garage',
        vehicleClass = nil,
        spawnPoint = vec4(0.0, 0.0, 0.0, 0.0),
        ped = {
            coords = vec4(0.0, 0.0, 0.0, 0.0),
            model = 's_m_y_valet_01',
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        parkZone = { coords = vec3(0.0, 0.0, 0.0), radius = 5.0 }
    },

    elevator = { -- You must add elevator locations here
        { coords = vec4(0.0, 0.0, 0.0, 0.0), label = 'Lobby' },
        { coords = vec4(0.0, 0.0, 0.0, 0.0), label = 'Floor 1' },
        { coords = vec4(0.0, 0.0, 0.0, 0.0), label = 'Floor 2' },
    },

    rooms = {
        -- This will generate automatically when you create room using /aptdev
            [1] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-584.575, 36.839, 85.829),
                vec3(-589.201, 36.862, 85.829),
                vec3(-589.272, 46.961, 85.829),
                vec3(-584.544, 46.942, 85.829)
            },
                minZ = 85.83,
                maxZ = 89.83
            },
            door = {
                coords = vec3(-584.917, 47.050, 86.977),
                model = -1052464162,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-585.687, 45.792, 85.829, 163.77)
        },
    }
}