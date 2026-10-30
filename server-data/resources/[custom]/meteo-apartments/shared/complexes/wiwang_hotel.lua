-- WiWang Hotel Apartment Complex

return {
    label = 'WiWang Hotel', -- https://forum.cfx.re/t/mlo-wiwang-hotel-380-rooms/5364084
    coords = vec3(-824.7368, -702.1234, 28.0600),
    startingRoom = 101,
    totalRooms = 380,
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
        coords = vec4(-823.4498, -702.0884, 28.0600, 16.0116),
        model = 's_m_y_valet_01',
        scenario = 'WORLD_HUMAN_CLIPBOARD'
    },

    garage = {
        id = 'wiwang_hotel',
        vehicleClass = nil,
        spawnPoint = vec4(-835.1924, -681.6054, 27.2835, 359.3614),
        ped = {
            coords = vec4(-840.9529, -681.0942, 27.2882, 186.9983),
            model = 's_m_y_valet_01',
            scenario = 'WORLD_HUMAN_CLIPBOARD'
        },
        parkZone = {
            coords = vec3(-842.2386, -687.8847, 27.3151),
            radius = 3.0
        }
    },

    elevator = { -- got from https://github.com/uFLOKY/wiwang_hotel/blob/main/map_wiwang_hotel/elevators.lua
        { coords = vec4(-819.82, -699.8, 28.07, 90.216), label = 'Lobby' },
        { coords = vec4(-824.11, -717.47, 41.57, 223.66), label = 'Floor 1' },
        { coords = vec4(-824.11, -717.47, 45.36, 221.24), label = 'Floor 2' },
        { coords = vec4(-824.1, -717.47, 49.16, 221.29), label = 'Floor 3' },
        { coords = vec4(-824.09, -717.47, 52.96, 221.34), label = 'Floor 4' },
        { coords = vec4(-824.08, -717.47, 56.76, 221.75), label = 'Floor 5' },
        { coords = vec4(-824.07, -717.48, 60.56, 220.95), label = 'Floor 6' },
        { coords = vec4(-824.06, -717.48, 64.36, 221.71), label = 'Floor 7' },
        { coords = vec4(-824.06, -717.48, 68.16, 221.38), label = 'Floor 8' },
        { coords = vec4(-824.32, -717.23, 71.97, 223.36), label = 'Floor 9' },
        { coords = vec4(-824.27, -717.32, 75.77, 221.08), label = 'Floor 10' },
        { coords = vec4(-824.2, -717.39, 79.57, 220.42), label = 'Floor 11' },
        { coords = vec4(-824.12, -717.46, 83.37, 223.31), label = 'Floor 12' },
        { coords = vec4(-824.05, -717.53, 87.17, 219.96), label = 'Floor 13' },
        { coords = vec4(-824.05, -717.54, 90.96, 219.93), label = 'Floor 14' },
        { coords = vec4(-824.04, -717.54, 94.76, 220.04), label = 'Floor 15' },
        { coords = vec4(-823.97, -717.61, 98.57, 219.73), label = 'Floor 16' },
        { coords = vec4(-823.96, -717.62, 102.36, 219.9), label = 'Floor 17' },
        { coords = vec4(-823.95, -717.62, 106.16, 220.07), label = 'Floor 18' },
        { coords = vec4(-823.88, -717.69, 109.97, 219.83), label = 'Floor 19' },
        { coords = vec4(-823.81, -717.77, 113.77, 218.5), label = 'Floor 20' },
    },

    rooms = {
        -- This will generate automatically when you create room using /aptdev
            [101] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.590, -730.455, 40.570),
                vec3(-826.594, -724.738, 40.620),
                vec3(-821.171, -724.763, 40.570),
                vec3(-821.171, -730.456, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.22
            },
            door = {
                coords = vec3(-825.866, -724.611, 41.675),
                model = -138454175,
                heading = 359,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.162, -725.600, 40.570, 179.50)
        },
            [102] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.185, -730.458, 40.570),
                vec3(-826.788, -730.440, 40.570),
                vec3(-826.766, -724.740, 40.574),
                vec3(-832.216, -724.757, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.27
            },
            door = {
                coords = vec3(-831.466, -724.611, 41.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.759, -725.499, 40.570, 179.19)
        },
            [103] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.764, -730.449, 40.570),
                vec3(-832.379, -730.451, 40.637),
                vec3(-832.437, -724.738, 40.643),
                vec3(-837.779, -724.738, 40.576)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-837.066, -724.611, 41.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.287, -725.473, 40.570, 182.47)
        },
            [104] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.301, -730.451, 40.631),
                vec3(-838.047, -730.463, 40.570),
                vec3(-838.054, -724.738, 40.664),
                vec3(-843.411, -724.765, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-842.666, -724.611, 41.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.932, -725.375, 40.570, 178.53)
        },
            [105] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-838.115, -715.558, 40.570),
                vec3(-843.433, -715.559, 40.645),
                vec3(-843.446, -721.271, 40.621),
                vec3(-838.091, -721.259, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-838.820, -721.390, 41.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.578, -720.358, 40.570, 359.13)
        },
            [106] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.525, -715.510, 40.570),
                vec3(-837.838, -715.548, 40.570),
                vec3(-837.901, -721.239, 40.570),
                vec3(-832.507, -721.212, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-833.220, -721.390, 41.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-833.918, -720.773, 40.570, 1.24)
        },
            [107] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.938, -715.559, 40.643),
                vec3(-832.229, -715.559, 40.676),
                vec3(-832.288, -721.223, 40.570),
                vec3(-826.912, -721.271, 40.604)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-827.620, -721.390, 41.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.370, -720.753, 40.570, 2.49)
        },
            [108] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.878, -704.285, 40.570),
                vec3(-825.856, -709.689, 40.586),
                vec3(-820.105, -709.647, 40.640),
                vec3(-820.125, -704.226, 40.578)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-819.983, -704.989, 41.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.613, -705.738, 40.570, 90.58)
        },
            [109] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -698.692, 40.692),
                vec3(-825.805, -704.014, 40.570),
                vec3(-820.105, -704.059, 40.620),
                vec3(-820.116, -698.626, 40.618)
            },
                minZ = 40.57,
                maxZ = 43.32
            },
            door = {
                coords = vec3(-819.983, -699.389, 41.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.740, -700.030, 40.570, 87.10)
        },
            [110] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -693.124, 40.670),
                vec3(-825.817, -698.358, 40.654),
                vec3(-820.130, -698.490, 40.606),
                vec3(-820.217, -693.026, 40.592)
            },
                minZ = 40.59,
                maxZ = 43.24
            },
            door = {
                coords = vec3(-819.983, -693.789, 41.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.999, -694.517, 40.570, 89.30)
        },
            [111] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -687.514, 40.643),
                vec3(-825.808, -692.748, 40.570),
                vec3(-820.197, -692.846, 40.570),
                vec3(-820.105, -687.437, 40.598)
            },
                minZ = 40.57,
                maxZ = 43.27
            },
            door = {
                coords = vec3(-819.983, -688.189, 41.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.827, -688.919, 40.570, 89.88)
        },
            [112] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.847, -681.899, 40.570),
                vec3(-825.817, -687.279, 40.648),
                vec3(-820.126, -687.290, 40.579),
                vec3(-820.105, -681.878, 40.608)
            },
                minZ = 40.57,
                maxZ = 43.22
            },
            door = {
                coords = vec3(-819.983, -682.589, 41.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.929, -683.279, 40.570, 90.91)
        },
            [113] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.770, -687.206, 40.570),
                vec3(-810.792, -681.961, 40.570),
                vec3(-816.392, -681.923, 40.570),
                vec3(-816.399, -687.235, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.52
            },
            door = {
                coords = vec3(-816.610, -686.526, 41.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.973, -685.824, 40.570, 266.35)
        },
            [114] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -692.843, 40.645),
                vec3(-810.761, -687.426, 40.593),
                vec3(-816.483, -687.464, 40.570),
                vec3(-816.454, -692.889, 40.608)
            },
                minZ = 40.57,
                maxZ = 43.32
            },
            door = {
                coords = vec3(-816.610, -692.126, 41.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.976, -691.503, 40.570, 269.63)
        },
            [115] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -698.408, 40.625),
                vec3(-810.709, -693.130, 40.570),
                vec3(-816.387, -693.045, 40.570),
                vec3(-816.438, -698.467, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.27
            },
            door = {
                coords = vec3(-816.610, -697.726, 41.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.407, -696.982, 40.570, 269.47)
        },
            [116] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.710, -704.002, 40.570),
                vec3(-810.771, -698.729, 40.653),
                vec3(-816.464, -698.700, 40.570),
                vec3(-816.484, -704.066, 40.584)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-816.610, -703.326, 41.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.712, -702.670, 40.570, 271.32)
        },
            [117] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -709.584, 40.633),
                vec3(-810.820, -704.289, 40.570),
                vec3(-816.484, -704.228, 40.572),
                vec3(-816.470, -709.648, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.37
            },
            door = {
                coords = vec3(-816.610, -708.926, 41.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-816.048, -708.230, 40.570, 269.78)
        },
            [118] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -715.212, 40.679),
                vec3(-810.771, -709.927, 40.646),
                vec3(-816.461, -709.846, 40.570),
                vec3(-816.472, -715.250, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-816.610, -714.526, 41.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.737, -713.817, 40.570, 268.61)
        },
            [119] = {
            floor = 1,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.741, -720.814, 40.570),
                vec3(-810.749, -715.425, 40.589),
                vec3(-816.451, -715.490, 40.570),
                vec3(-816.420, -720.813, 40.570)
            },
                minZ = 40.57,
                maxZ = 43.57
            },
            door = {
                coords = vec3(-816.570, -720.126, 41.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.882, -719.399, 40.570, 268.87)
        },
            [201] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.553, -730.453, 44.370),
                vec3(-821.366, -730.412, 44.370),
                vec3(-821.173, -724.781, 44.370),
                vec3(-826.575, -724.818, 44.370)
            },
                minZ = 44.37,
                maxZ = 46.97
            },
            door = {
                coords = vec3(-825.866, -724.611, 45.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.128, -725.831, 44.370, 184.37)
        },
            [202] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.150, -730.488, 44.370),
                vec3(-826.833, -730.462, 44.370),
                vec3(-826.825, -724.782, 44.370),
                vec3(-832.163, -724.783, 44.370)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-831.466, -724.611, 45.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.834, -725.272, 44.370, 177.83)
        },
            [203] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.723, -730.451, 44.458),
                vec3(-832.484, -730.451, 44.434),
                vec3(-832.503, -724.802, 44.370),
                vec3(-837.822, -724.738, 44.373)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-837.066, -724.611, 45.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.351, -725.762, 44.370, 179.65)
        },
            [204] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.332, -730.451, 44.437),
                vec3(-838.125, -730.439, 44.370),
                vec3(-838.085, -724.837, 44.370),
                vec3(-843.398, -724.738, 44.384)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-842.666, -724.611, 45.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.971, -725.533, 44.370, 179.61)
        },
            [205] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-838.169, -715.553, 44.370),
                vec3(-838.095, -721.271, 44.426),
                vec3(-843.383, -721.154, 44.370),
                vec3(-843.520, -715.577, 44.424)
            },
                minZ = 44.37,
                maxZ = 47.02
            },
            door = {
                coords = vec3(-838.820, -721.390, 45.475),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.593, -720.082, 44.370, 0.32)
        },
            [206] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.559, -715.559, 44.410),
                vec3(-837.825, -715.545, 44.370),
                vec3(-837.826, -721.229, 44.370),
                vec3(-832.542, -721.217, 44.370)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-833.220, -721.390, 45.475),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-833.895, -720.487, 44.370, 358.37)
        },
            [207] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.895, -715.559, 44.370),
                vec3(-832.254, -715.591, 44.370),
                vec3(-832.241, -721.216, 44.370),
                vec3(-826.865, -721.271, 44.420)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-827.620, -721.390, 45.475),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.207, -720.688, 44.370, 359.05)
        },
            [208] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.875, -704.323, 44.370),
                vec3(-825.784, -709.601, 44.370),
                vec3(-820.105, -709.615, 44.400),
                vec3(-820.132, -704.293, 44.370)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-819.983, -704.989, 45.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.748, -705.750, 44.370, 87.93)
        },
            [209] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.874, -704.027, 44.370),
                vec3(-825.817, -698.754, 44.485),
                vec3(-820.105, -698.632, 44.382),
                vec3(-820.131, -704.039, 44.370)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-819.983, -699.389, 45.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.809, -700.107, 44.370, 84.98)
        },
            [210] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.797, -693.067, 44.370),
                vec3(-825.815, -698.490, 44.395),
                vec3(-820.128, -698.396, 44.370),
                vec3(-820.105, -693.036, 44.456)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-819.983, -693.789, 45.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.834, -694.548, 44.370, 89.88)
        },
            [211] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.865, -687.513, 44.370),
                vec3(-825.817, -692.722, 44.456),
                vec3(-820.105, -692.846, 44.374),
                vec3(-820.105, -687.470, 44.370)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-819.983, -688.189, 45.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.838, -688.935, 44.370, 90.00)
        },
            [212] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -681.868, 44.428),
                vec3(-825.840, -687.259, 44.370),
                vec3(-820.194, -687.167, 44.370),
                vec3(-820.208, -681.826, 44.436)
            },
                minZ = 44.37,
                maxZ = 47.12
            },
            door = {
                coords = vec3(-819.983, -682.589, 45.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.091, -683.333, 44.370, 87.60)
        },
            [213] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.742, -687.210, 44.370),
                vec3(-810.719, -681.895, 44.370),
                vec3(-816.462, -681.887, 44.370),
                vec3(-816.484, -687.214, 44.433)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-816.610, -686.526, 45.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.816, -685.865, 44.370, 269.37)
        },
            [214] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.736, -692.811, 44.370),
                vec3(-810.758, -687.477, 44.370),
                vec3(-816.426, -687.426, 44.371),
                vec3(-816.484, -692.802, 44.442)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-816.610, -692.126, 45.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.757, -691.387, 44.370, 274.49)
        },
            [215] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.720, -698.429, 44.370),
                vec3(-810.771, -693.121, 44.425),
                vec3(-816.471, -693.099, 44.370),
                vec3(-816.471, -698.490, 44.374)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-816.610, -697.726, 45.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.658, -697.076, 44.370, 269.15)
        },
            [216] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -703.988, 44.448),
                vec3(-810.749, -698.649, 44.370),
                vec3(-816.484, -698.653, 44.383),
                vec3(-816.484, -703.980, 44.438)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-816.610, -703.326, 45.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.777, -702.635, 44.370, 273.16)
        },
            [217] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -709.576, 44.439),
                vec3(-810.771, -704.367, 44.437),
                vec3(-816.439, -704.316, 44.370),
                vec3(-816.484, -709.592, 44.428)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-816.610, -708.926, 45.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.823, -708.157, 44.370, 270.80)
        },
            [218] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.697, -715.221, 44.370),
                vec3(-810.698, -709.857, 44.370),
                vec3(-816.484, -709.876, 44.417),
                vec3(-816.465, -715.289, 44.381)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-816.610, -714.526, 45.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.605, -713.860, 44.370, 269.22)
        },
            [219] = {
            floor = 2,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.778, -720.813, 44.370),
                vec3(-810.804, -715.515, 44.370),
                vec3(-816.461, -715.480, 44.370),
                vec3(-816.455, -720.888, 44.420)
            },
                minZ = 44.37,
                maxZ = 47.37
            },
            door = {
                coords = vec3(-816.570, -720.126, 45.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.756, -719.441, 44.370, 272.20)
        },
            [301] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.528, -730.418, 48.170),
                vec3(-821.228, -730.451, 48.224),
                vec3(-821.189, -724.738, 48.196),
                vec3(-826.545, -724.738, 48.180)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-825.866, -724.611, 49.275),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-824.996, -725.499, 48.170, 180.58)
        },
            [302] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.120, -730.401, 48.170),
                vec3(-826.766, -730.390, 48.208),
                vec3(-826.862, -724.853, 48.170),
                vec3(-832.229, -724.748, 48.243)
            },
                minZ = 48.17,
                maxZ = 50.82
            },
            door = {
                coords = vec3(-831.466, -724.611, 49.275),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.641, -725.712, 48.170, 181.93)
        },
            [303] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.758, -730.467, 48.170),
                vec3(-832.377, -730.497, 48.170),
                vec3(-832.400, -724.780, 48.170),
                vec3(-837.801, -724.738, 48.181)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-837.066, -724.611, 49.275),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.357, -725.321, 48.170, 177.13)
        },
            [304] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.354, -730.502, 48.170),
                vec3(-837.978, -730.448, 48.170),
                vec3(-837.996, -724.738, 48.205),
                vec3(-843.417, -724.738, 48.285)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-842.666, -724.611, 49.275),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.843, -725.578, 48.170, 183.59)
        },
            [305] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.499, -715.554, 48.170),
                vec3(-838.144, -715.537, 48.170),
                vec3(-838.080, -721.271, 48.227),
                vec3(-843.520, -721.222, 48.194)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-838.820, -721.390, 49.275),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.631, -720.607, 48.170, 359.95)
        },
            [306] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.527, -715.534, 48.170),
                vec3(-837.819, -715.553, 48.170),
                vec3(-837.920, -721.267, 48.196),
                vec3(-832.460, -721.271, 48.187)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-833.220, -721.390, 49.275),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-833.859, -720.653, 48.170, 0.11)
        },
            [307] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.919, -715.530, 48.170),
                vec3(-832.273, -715.529, 48.170),
                vec3(-832.320, -721.216, 48.206),
                vec3(-826.905, -721.259, 48.170)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-827.620, -721.390, 49.275),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.363, -720.140, 48.170, 8.01)
        },
            [308] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.865, -704.299, 48.170),
                vec3(-825.862, -709.682, 48.170),
                vec3(-820.115, -709.651, 48.170),
                vec3(-820.116, -704.253, 48.170)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-819.983, -704.989, 49.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.276, -705.849, 48.170, 93.46)
        },
            [309] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -698.679, 48.241),
                vec3(-825.884, -704.041, 48.170),
                vec3(-820.184, -704.064, 48.170),
                vec3(-820.106, -698.659, 48.170)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-819.983, -699.389, 49.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.785, -700.111, 48.170, 90.88)
        },
            [310] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.854, -693.117, 48.170),
                vec3(-825.796, -698.438, 48.170),
                vec3(-820.173, -698.490, 48.198),
                vec3(-820.105, -693.070, 48.273)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-819.983, -693.789, 49.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.911, -694.523, 48.170, 91.65)
        },
            [311] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.835, -687.513, 48.170),
                vec3(-825.805, -692.814, 48.170),
                vec3(-820.181, -692.889, 48.189),
                vec3(-820.105, -687.488, 48.177)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-819.983, -688.189, 49.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.096, -688.961, 48.170, 92.06)
        },
            [312] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.812, -681.895, 48.170),
                vec3(-825.805, -687.223, 48.170),
                vec3(-820.184, -687.234, 48.170),
                vec3(-820.105, -681.828, 48.225)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-819.983, -682.589, 49.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.920, -683.310, 48.170, 89.27)
        },
            [313] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.731, -687.223, 48.170),
                vec3(-810.791, -681.890, 48.170),
                vec3(-816.484, -681.844, 48.199),
                vec3(-816.484, -687.243, 48.214)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-816.610, -686.526, 49.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.512, -685.808, 48.170, 269.74)
        },
            [314] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.736, -692.852, 48.170),
                vec3(-810.803, -687.509, 48.170),
                vec3(-816.410, -687.511, 48.170),
                vec3(-816.484, -692.845, 48.171)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-816.610, -692.126, 49.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.630, -691.439, 48.170, 270.39)
        },
            [315] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.733, -698.390, 48.170),
                vec3(-810.789, -693.129, 48.170),
                vec3(-816.484, -693.045, 48.213),
                vec3(-816.484, -698.431, 48.262)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-816.610, -697.726, 49.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.629, -697.038, 48.170, 269.92)
        },
            [316] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.725, -703.999, 48.170),
                vec3(-810.771, -698.703, 48.226),
                vec3(-816.417, -698.679, 48.170),
                vec3(-816.458, -704.054, 48.170)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-816.610, -703.326, 49.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.628, -702.548, 48.170, 275.55)
        },
            [317] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.728, -709.617, 48.170),
                vec3(-810.740, -704.247, 48.170),
                vec3(-816.418, -704.277, 48.170),
                vec3(-816.484, -709.669, 48.214)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-816.610, -708.926, 49.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.595, -708.096, 48.170, 272.11)
        },
            [318] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.774, -715.217, 48.170),
                vec3(-810.802, -709.851, 48.170),
                vec3(-816.449, -709.863, 48.170),
                vec3(-816.484, -715.233, 48.256)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-816.610, -714.526, 49.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.628, -713.856, 48.170, 271.33)
        },
            [319] = {
            floor = 3,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.737, -720.839, 48.170),
                vec3(-810.748, -715.440, 48.170),
                vec3(-816.484, -715.466, 48.207),
                vec3(-816.484, -720.839, 48.229)
            },
                minZ = 48.17,
                maxZ = 51.17
            },
            door = {
                coords = vec3(-816.570, -720.126, 49.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.811, -719.421, 48.170, 271.41)
        },
            [401] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.534, -730.451, 52.011),
                vec3(-821.236, -730.455, 51.970),
                vec3(-821.183, -724.776, 51.970),
                vec3(-826.567, -724.753, 51.970)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-825.866, -724.611, 53.075),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.201, -725.447, 51.970, 181.38)
        },
            [402] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.155, -730.497, 51.970),
                vec3(-826.801, -730.461, 51.970),
                vec3(-826.766, -724.766, 52.035),
                vec3(-832.191, -724.738, 51.974)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-831.466, -724.611, 53.075),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.799, -725.618, 51.970, 182.52)
        },
            [403] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.763, -730.492, 51.970),
                vec3(-832.512, -730.451, 52.066),
                vec3(-832.394, -724.744, 51.970),
                vec3(-837.770, -724.763, 51.970)
            },
                minZ = 51.97,
                maxZ = 54.72
            },
            door = {
                coords = vec3(-837.066, -724.611, 53.075),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.346, -725.415, 51.970, 184.22)
        },
            [404] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.352, -730.499, 51.970),
                vec3(-837.994, -730.486, 51.970),
                vec3(-838.005, -724.792, 51.970),
                vec3(-843.399, -724.738, 52.020)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-842.666, -724.611, 53.075),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.901, -725.706, 51.970, 182.36)
        },
            [405] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-838.095, -715.495, 51.970),
                vec3(-843.520, -715.532, 51.974),
                vec3(-843.520, -721.232, 52.009),
                vec3(-838.057, -721.258, 51.999)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-838.820, -721.390, 53.075),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.602, -720.708, 51.970, 359.17)
        },
            [406] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.560, -715.526, 51.970),
                vec3(-837.824, -715.559, 52.010),
                vec3(-837.829, -721.192, 51.970),
                vec3(-832.469, -721.208, 51.970)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-833.220, -721.390, 53.075),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-833.760, -720.581, 51.970, 356.61)
        },
            [407] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.922, -715.522, 51.970),
                vec3(-832.206, -715.575, 51.970),
                vec3(-832.280, -721.271, 51.986),
                vec3(-826.906, -721.271, 51.990)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-827.620, -721.390, 53.075),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.292, -720.551, 51.970, 4.85)
        },
            [408] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.833, -704.282, 51.970),
                vec3(-825.820, -709.592, 51.970),
                vec3(-820.105, -709.670, 52.049),
                vec3(-820.105, -704.290, 52.045)
            },
                minZ = 51.97,
                maxZ = 54.67
            },
            door = {
                coords = vec3(-819.983, -704.989, 53.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.929, -705.700, 51.970, 91.64)
        },
            [409] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.860, -698.687, 51.970),
                vec3(-825.817, -703.935, 52.080),
                vec3(-820.105, -703.980, 52.007),
                vec3(-820.105, -698.704, 52.036)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-819.983, -699.389, 53.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.959, -700.075, 51.970, 94.75)
        },
            [410] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -693.132, 52.052),
                vec3(-825.778, -698.399, 51.970),
                vec3(-820.122, -698.490, 52.004),
                vec3(-820.105, -693.071, 52.004)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-819.983, -693.789, 53.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.667, -694.538, 51.970, 94.35)
        },
            [411] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -687.497, 51.970),
                vec3(-825.817, -692.829, 52.036),
                vec3(-820.170, -692.889, 51.980),
                vec3(-820.105, -687.433, 51.982)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-819.983, -688.189, 53.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.956, -688.877, 51.970, 92.98)
        },
            [412] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.834, -681.911, 51.970),
                vec3(-825.845, -687.285, 51.970),
                vec3(-820.105, -687.226, 52.004),
                vec3(-820.105, -681.845, 52.020)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-819.983, -682.589, 53.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.913, -683.293, 51.970, 90.57)
        },
            [413] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.766, -687.249, 51.970),
                vec3(-810.832, -681.934, 51.970),
                vec3(-816.484, -681.893, 52.077),
                vec3(-816.464, -687.211, 51.970)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-816.610, -686.526, 53.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.699, -685.763, 51.970, 274.28)
        },
            [414] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.783, -692.832, 51.970),
                vec3(-810.795, -687.432, 51.970),
                vec3(-816.433, -687.486, 51.970),
                vec3(-816.484, -692.810, 52.037)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-816.610, -692.126, 53.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.752, -691.354, 51.970, 266.38)
        },
            [415] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.708, -698.419, 51.970),
                vec3(-810.777, -693.081, 51.970),
                vec3(-816.398, -693.026, 52.038),
                vec3(-816.484, -698.470, 52.097)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-816.610, -697.726, 53.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.545, -697.100, 51.970, 267.88)
        },
            [416] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -703.996, 52.041),
                vec3(-810.753, -698.655, 51.970),
                vec3(-816.458, -698.710, 51.970),
                vec3(-816.484, -704.033, 52.058)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-816.610, -703.326, 53.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.579, -702.710, 51.970, 267.91)
        },
            [417] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.743, -709.623, 51.970),
                vec3(-810.765, -704.287, 51.970),
                vec3(-816.480, -704.226, 51.999),
                vec3(-816.484, -709.643, 52.012)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-816.610, -708.926, 53.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.481, -708.175, 51.970, 272.17)
        },
            [418] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -715.242, 51.970),
                vec3(-810.771, -709.910, 52.039),
                vec3(-816.484, -709.867, 51.971),
                vec3(-816.484, -715.248, 52.013)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-816.610, -714.526, 53.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.736, -713.905, 51.970, 269.42)
        },
            [419] = {
            floor = 4,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.744, -720.810, 51.970),
                vec3(-810.753, -715.459, 51.970),
                vec3(-816.484, -715.474, 51.974),
                vec3(-816.484, -720.830, 52.001)
            },
                minZ = 51.97,
                maxZ = 54.97
            },
            door = {
                coords = vec3(-816.570, -720.126, 53.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.617, -719.485, 51.970, 270.16)
        },
            [501] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.546, -730.484, 55.770),
                vec3(-821.292, -730.468, 55.770),
                vec3(-821.219, -724.770, 55.770),
                vec3(-826.581, -724.738, 55.775)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-825.866, -724.611, 56.875),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.206, -725.447, 55.770, 182.53)
        },
            [502] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.138, -730.454, 55.770),
                vec3(-826.850, -730.451, 55.867),
                vec3(-826.839, -724.770, 55.770),
                vec3(-832.164, -724.738, 55.848)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-831.466, -724.611, 56.875),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.811, -725.443, 55.770, 179.35)
        },
            [503] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.721, -730.492, 55.770),
                vec3(-832.565, -730.451, 55.870),
                vec3(-832.366, -724.805, 55.816),
                vec3(-837.761, -724.738, 55.801)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-837.066, -724.611, 56.875),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.365, -725.724, 55.770, 185.57)
        },
            [504] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.323, -730.451, 55.817),
                vec3(-838.016, -730.484, 55.770),
                vec3(-837.965, -724.814, 55.819),
                vec3(-843.378, -724.738, 55.863)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-842.666, -724.611, 56.875),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.908, -725.831, 55.770, 183.71)
        },
            [505] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-838.127, -715.547, 55.770),
                vec3(-843.401, -715.559, 55.815),
                vec3(-843.495, -721.271, 55.806),
                vec3(-838.057, -721.238, 55.867)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-838.820, -721.390, 56.875),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.456, -720.533, 55.770, 359.72)
        },
            [506] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.485, -715.487, 55.770),
                vec3(-837.839, -715.559, 55.817),
                vec3(-837.892, -721.265, 55.770),
                vec3(-832.539, -721.271, 55.848)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-833.220, -721.390, 56.875),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-833.936, -720.219, 55.770, 4.56)
        },
            [507] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.942, -715.559, 55.831),
                vec3(-832.114, -715.559, 55.862),
                vec3(-832.290, -721.271, 55.834),
                vec3(-826.937, -721.271, 55.849)
            },
                minZ = 55.83,
                maxZ = 58.83
            },
            door = {
                coords = vec3(-827.620, -721.390, 56.875),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.300, -720.464, 55.770, 4.95)
        },
            [508] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -704.381, 55.855),
                vec3(-825.817, -709.608, 55.845),
                vec3(-820.105, -709.633, 55.807),
                vec3(-820.105, -704.298, 55.848)
            },
                minZ = 55.81,
                maxZ = 58.81
            },
            door = {
                coords = vec3(-819.983, -704.989, 56.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.203, -705.645, 55.770, 94.63)
        },
            [509] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -698.722, 55.852),
                vec3(-825.817, -703.958, 55.872),
                vec3(-820.105, -704.044, 55.948),
                vec3(-820.105, -698.634, 55.891)
            },
                minZ = 55.85,
                maxZ = 58.85
            },
            door = {
                coords = vec3(-819.983, -699.389, 56.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.896, -700.200, 55.770, 91.58)
        },
            [510] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -693.100, 55.843),
                vec3(-825.861, -698.484, 55.770),
                vec3(-820.105, -698.458, 55.810),
                vec3(-820.105, -693.069, 55.927)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-819.983, -693.789, 56.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.835, -694.501, 55.770, 91.61)
        },
            [511] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -687.466, 55.866),
                vec3(-825.860, -692.882, 55.770),
                vec3(-820.121, -692.878, 55.770),
                vec3(-820.105, -687.435, 55.790)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-819.983, -688.189, 56.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.273, -688.914, 55.770, 92.51)
        },
            [512] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.872, -681.843, 55.770),
                vec3(-825.817, -687.161, 55.900),
                vec3(-820.118, -687.290, 55.865),
                vec3(-820.105, -681.851, 55.946)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-819.983, -682.589, 56.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.834, -683.401, 55.770, 93.41)
        },
            [513] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.730, -687.214, 55.770),
                vec3(-810.771, -681.962, 55.916),
                vec3(-816.448, -681.874, 55.770),
                vec3(-816.484, -687.276, 55.826)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-816.610, -686.526, 56.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.611, -685.738, 55.770, 271.64)
        },
            [514] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.741, -692.822, 55.770),
                vec3(-810.740, -687.504, 55.770),
                vec3(-816.435, -687.426, 55.823),
                vec3(-816.484, -692.838, 55.850)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-816.610, -692.126, 56.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.640, -691.460, 55.770, 272.71)
        },
            [515] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.740, -698.378, 55.770),
                vec3(-810.704, -693.071, 55.770),
                vec3(-816.484, -693.056, 55.842),
                vec3(-816.484, -698.417, 55.836)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-816.610, -697.726, 56.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.724, -697.094, 55.770, 272.25)
        },
            [516] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.793, -703.965, 55.770),
                vec3(-810.771, -698.744, 55.912),
                vec3(-816.448, -698.626, 55.855),
                vec3(-816.484, -704.056, 55.818)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-816.610, -703.326, 56.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.696, -702.551, 55.770, 269.82)
        },
            [517] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.719, -709.586, 55.770),
                vec3(-810.697, -704.332, 55.770),
                vec3(-816.451, -704.226, 55.815),
                vec3(-816.484, -709.660, 55.819)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-816.610, -708.926, 56.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.754, -708.306, 55.770, 269.31)
        },
            [518] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -715.238, 55.909),
                vec3(-810.771, -709.968, 55.852),
                vec3(-816.462, -709.826, 55.873),
                vec3(-816.484, -715.263, 55.897)
            },
                minZ = 55.85,
                maxZ = 58.85
            },
            door = {
                coords = vec3(-816.610, -714.526, 56.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.776, -713.904, 55.770, 268.29)
        },
            [519] = {
            floor = 5,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.723, -720.863, 55.770),
                vec3(-810.806, -715.632, 55.770),
                vec3(-816.484, -715.440, 55.901),
                vec3(-816.455, -720.888, 55.865)
            },
                minZ = 55.77,
                maxZ = 58.77
            },
            door = {
                coords = vec3(-816.570, -720.126, 56.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.596, -719.511, 55.770, 269.73)
        },
            [601] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.535, -730.486, 59.570),
                vec3(-821.283, -730.465, 59.570),
                vec3(-821.166, -724.741, 59.629),
                vec3(-826.630, -724.771, 59.603)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-825.866, -724.611, 60.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.201, -725.610, 59.570, 180.65)
        },
            [602] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.126, -730.451, 59.650),
                vec3(-826.966, -730.451, 59.713),
                vec3(-826.782, -724.738, 59.611),
                vec3(-832.194, -724.738, 59.620)
            },
                minZ = 59.61,
                maxZ = 62.61
            },
            door = {
                coords = vec3(-831.466, -724.611, 60.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.769, -725.708, 59.570, 180.64)
        },
            [603] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.742, -730.508, 59.570),
                vec3(-832.472, -730.451, 59.712),
                vec3(-832.366, -724.761, 59.591),
                vec3(-837.788, -724.738, 59.628)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-837.066, -724.611, 60.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.375, -725.382, 59.570, 186.29)
        },
            [604] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.359, -730.489, 59.570),
                vec3(-837.991, -730.486, 59.570),
                vec3(-838.030, -724.800, 59.570),
                vec3(-843.429, -724.743, 59.646)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-842.666, -724.611, 60.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-842.055, -725.484, 59.570, 180.04)
        },
            [605] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-838.120, -715.552, 59.570),
                vec3(-843.393, -715.594, 59.570),
                vec3(-843.520, -721.227, 59.600),
                vec3(-838.122, -721.271, 59.632)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-838.820, -721.390, 60.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.683, -720.453, 59.570, 3.73)
        },
            [606] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.552, -715.559, 59.671),
                vec3(-837.827, -715.559, 59.570),
                vec3(-837.920, -721.236, 59.570),
                vec3(-832.528, -721.271, 59.667)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-833.220, -721.390, 60.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-834.040, -720.259, 59.570, 2.49)
        },
            [607] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.911, -715.485, 59.570),
                vec3(-832.305, -715.522, 59.570),
                vec3(-832.320, -721.230, 59.629),
                vec3(-826.888, -721.271, 59.597)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-827.620, -721.390, 60.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.293, -720.546, 59.570, 6.90)
        },
            [608] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.790, -704.324, 59.570),
                vec3(-825.834, -709.656, 59.570),
                vec3(-820.120, -709.673, 59.570),
                vec3(-820.105, -704.235, 59.673)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-819.983, -704.989, 60.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.700, -705.685, 59.570, 90.62)
        },
            [609] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -698.714, 59.667),
                vec3(-825.817, -703.987, 59.644),
                vec3(-820.105, -704.025, 59.700),
                vec3(-820.105, -698.633, 59.677)
            },
                minZ = 59.64,
                maxZ = 62.64
            },
            door = {
                coords = vec3(-819.983, -699.389, 60.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.608, -700.096, 59.570, 90.25)
        },
            [610] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.822, -693.120, 59.570),
                vec3(-825.850, -698.372, 59.570),
                vec3(-820.126, -698.485, 59.570),
                vec3(-820.105, -693.098, 59.613)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-819.983, -693.789, 60.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.840, -694.504, 59.570, 93.37)
        },
            [611] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.855, -687.477, 59.570),
                vec3(-825.817, -692.804, 59.635),
                vec3(-820.128, -692.889, 59.579),
                vec3(-820.105, -687.456, 59.623)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-819.983, -688.189, 60.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.891, -688.960, 59.570, 91.60)
        },
            [612] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.835, -681.884, 59.570),
                vec3(-825.817, -687.121, 59.692),
                vec3(-820.105, -687.239, 59.577),
                vec3(-820.105, -681.904, 59.641)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-819.983, -682.589, 60.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.735, -683.300, 59.570, 90.69)
        },
            [613] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.755, -687.227, 59.570),
                vec3(-810.761, -681.826, 59.584),
                vec3(-816.438, -681.826, 59.580),
                vec3(-816.484, -687.271, 59.712)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-816.610, -686.526, 60.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.813, -685.813, 59.570, 269.05)
        },
            [614] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.731, -692.842, 59.570),
                vec3(-810.730, -687.426, 59.590),
                vec3(-816.484, -687.441, 59.648),
                vec3(-816.484, -692.855, 59.584)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-816.610, -692.126, 60.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.975, -691.478, 59.570, 270.10)
        },
            [615] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.731, -698.465, 59.570),
                vec3(-810.771, -693.097, 59.640),
                vec3(-816.427, -693.026, 59.605),
                vec3(-816.436, -698.432, 59.570)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-816.610, -697.726, 60.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.587, -696.990, 59.570, 270.19)
        },
            [616] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.749, -704.049, 59.570),
                vec3(-810.792, -698.659, 59.570),
                vec3(-816.369, -698.740, 59.570),
                vec3(-816.484, -704.018, 59.594)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-816.610, -703.326, 60.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.594, -702.484, 59.570, 275.00)
        },
            [617] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -709.588, 59.640),
                vec3(-810.728, -704.226, 59.573),
                vec3(-816.471, -704.246, 59.570),
                vec3(-816.441, -709.689, 59.614)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-816.610, -708.926, 60.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.815, -708.146, 59.570, 272.03)
        },
            [618] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.821, -715.182, 59.570),
                vec3(-810.791, -709.912, 59.570),
                vec3(-816.417, -709.851, 59.570),
                vec3(-816.484, -715.226, 59.581)
            },
                minZ = 59.57,
                maxZ = 62.57
            },
            door = {
                coords = vec3(-816.610, -714.526, 60.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.814, -713.883, 59.570, 271.58)
        },
            [619] = {
            floor = 6,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -720.832, 59.664),
                vec3(-810.771, -715.486, 59.678),
                vec3(-816.484, -715.447, 59.666),
                vec3(-816.484, -720.863, 59.592)
            },
                minZ = 59.59,
                maxZ = 62.59
            },
            door = {
                coords = vec3(-816.570, -720.126, 60.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-816.008, -719.390, 59.570, 275.18)
        },
            [701] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.530, -730.404, 63.370),
                vec3(-821.325, -730.451, 63.418),
                vec3(-821.211, -724.789, 63.370),
                vec3(-826.630, -724.742, 63.389)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-825.866, -724.611, 64.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.128, -725.425, 63.370, 182.18)
        },
            [702] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.165, -730.451, 63.442),
                vec3(-826.937, -730.451, 63.538),
                vec3(-826.766, -724.823, 63.398),
                vec3(-832.216, -724.738, 63.447)
            },
                minZ = 63.40,
                maxZ = 66.40
            },
            door = {
                coords = vec3(-831.466, -724.611, 64.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.821, -725.610, 63.370, 180.12)
        },
            [703] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.726, -730.451, 63.428),
                vec3(-832.500, -730.451, 63.489),
                vec3(-832.366, -724.747, 63.407),
                vec3(-837.813, -724.738, 63.561)
            },
                minZ = 63.41,
                maxZ = 66.41
            },
            door = {
                coords = vec3(-837.066, -724.611, 64.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.305, -725.412, 63.370, 184.71)
        },
            [704] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.295, -730.451, 63.425),
                vec3(-837.999, -730.451, 63.448),
                vec3(-837.982, -724.813, 63.370),
                vec3(-843.423, -724.738, 63.488)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-842.666, -724.611, 64.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-842.049, -725.544, 63.370, 179.14)
        },
            [705] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.397, -715.518, 63.370),
                vec3(-838.135, -715.559, 63.474),
                vec3(-838.100, -721.221, 63.370),
                vec3(-843.474, -721.271, 63.466)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-838.820, -721.390, 64.475),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.566, -720.265, 63.370, 4.63)
        },
            [706] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.542, -715.526, 63.370),
                vec3(-837.804, -715.559, 63.430),
                vec3(-837.843, -721.271, 63.488),
                vec3(-832.456, -721.262, 63.394)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-833.220, -721.390, 64.475),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-833.875, -720.411, 63.370, 358.93)
        },
            [707] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.925, -715.500, 63.370),
                vec3(-832.230, -715.559, 63.489),
                vec3(-832.320, -721.235, 63.392),
                vec3(-826.857, -721.256, 63.445)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-827.620, -721.390, 64.475),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.446, -720.313, 63.370, 4.82)
        },
            [708] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -704.324, 63.477),
                vec3(-825.817, -709.627, 63.421),
                vec3(-820.105, -709.680, 63.426),
                vec3(-820.112, -704.226, 63.441)
            },
                minZ = 63.42,
                maxZ = 66.42
            },
            door = {
                coords = vec3(-819.983, -704.989, 64.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.997, -705.701, 63.370, 89.64)
        },
            [709] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.872, -698.692, 63.370),
                vec3(-825.817, -703.961, 63.463),
                vec3(-820.175, -704.089, 63.404),
                vec3(-820.105, -698.664, 63.486)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-819.983, -699.389, 64.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.851, -700.253, 63.370, 99.27)
        },
            [710] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.877, -693.120, 63.370),
                vec3(-825.813, -698.381, 63.370),
                vec3(-820.105, -698.460, 63.443),
                vec3(-820.105, -693.036, 63.478)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-819.983, -693.789, 64.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.026, -694.602, 63.370, 95.87)
        },
            [711] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.848, -687.489, 63.370),
                vec3(-825.817, -692.751, 63.438),
                vec3(-820.144, -692.889, 63.370),
                vec3(-820.138, -687.487, 63.370)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-819.983, -688.189, 64.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.212, -688.840, 63.370, 90.31)
        },
            [712] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.852, -681.867, 63.370),
                vec3(-825.889, -687.190, 63.370),
                vec3(-820.137, -687.290, 63.498),
                vec3(-820.105, -681.898, 63.456)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-819.983, -682.589, 64.475),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.056, -683.339, 63.370, 100.72)
        },
            [713] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -681.925, 63.415),
                vec3(-810.728, -687.214, 63.370),
                vec3(-816.470, -687.290, 63.397),
                vec3(-816.484, -681.861, 63.393)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-816.610, -686.526, 64.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.733, -685.808, 63.370, 271.62)
        },
            [714] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.740, -692.837, 63.370),
                vec3(-810.734, -687.512, 63.370),
                vec3(-816.484, -687.531, 63.451),
                vec3(-816.484, -692.887, 63.446)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-816.610, -692.126, 64.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.872, -691.468, 63.370, 270.55)
        },
            [715] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.690, -698.416, 63.370),
                vec3(-810.771, -693.094, 63.443),
                vec3(-816.484, -693.045, 63.472),
                vec3(-816.484, -698.477, 63.446)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-816.610, -697.726, 64.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.765, -696.970, 63.370, 272.37)
        },
            [716] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -704.005, 63.430),
                vec3(-810.771, -698.734, 63.443),
                vec3(-816.484, -698.647, 63.403),
                vec3(-816.459, -704.026, 63.370)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-816.610, -703.326, 64.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.500, -702.554, 63.370, 273.64)
        },
            [717] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.749, -709.635, 63.370),
                vec3(-810.771, -704.363, 63.423),
                vec3(-816.461, -704.226, 63.402),
                vec3(-816.482, -709.689, 63.431)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-816.610, -708.926, 64.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.513, -708.128, 63.370, 277.64)
        },
            [718] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.780, -715.240, 63.370),
                vec3(-810.786, -709.929, 63.370),
                vec3(-816.484, -709.873, 63.460),
                vec3(-816.484, -715.228, 63.491)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-816.610, -714.526, 64.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.697, -713.770, 63.370, 275.94)
        },
            [719] = {
            floor = 7,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.738, -720.801, 63.370),
                vec3(-810.769, -715.508, 63.370),
                vec3(-816.462, -715.436, 63.370),
                vec3(-816.484, -720.830, 63.416)
            },
                minZ = 63.37,
                maxZ = 66.37
            },
            door = {
                coords = vec3(-816.570, -720.126, 64.475),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.360, -719.461, 63.370, 267.19)
        },
            [801] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.544, -730.451, 67.238),
                vec3(-821.312, -730.451, 67.234),
                vec3(-821.230, -724.792, 67.170),
                vec3(-826.630, -724.757, 67.256)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-825.866, -724.611, 68.275),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.134, -725.610, 67.170, 187.38)
        },
            [802] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.177, -730.439, 67.170),
                vec3(-826.788, -730.455, 67.170),
                vec3(-826.772, -724.762, 67.170),
                vec3(-832.189, -724.738, 67.191)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-831.466, -724.611, 68.275),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.676, -725.958, 67.170, 184.32)
        },
            [803] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.769, -730.472, 67.170),
                vec3(-832.448, -730.451, 67.217),
                vec3(-832.377, -724.738, 67.175),
                vec3(-837.808, -724.738, 67.170)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-837.066, -724.611, 68.275),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.373, -725.743, 67.170, 184.27)
        },
            [804] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.346, -730.470, 67.170),
                vec3(-838.110, -730.443, 67.170),
                vec3(-837.972, -724.738, 67.175),
                vec3(-843.374, -724.759, 67.170)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-842.666, -724.611, 68.275),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.934, -725.694, 67.170, 178.70)
        },
            [805] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-838.111, -715.585, 67.170),
                vec3(-843.409, -715.580, 67.170),
                vec3(-843.490, -721.214, 67.170),
                vec3(-838.057, -721.235, 67.185)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-838.820, -721.390, 68.275),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.617, -720.590, 67.170, 8.40)
        },
            [806] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.511, -715.512, 67.170),
                vec3(-837.812, -715.559, 67.222),
                vec3(-837.820, -721.271, 67.234),
                vec3(-832.510, -721.268, 67.170)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-833.220, -721.390, 68.275),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-833.975, -720.440, 67.170, 7.27)
        },
            [807] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.951, -715.546, 67.170),
                vec3(-832.290, -715.556, 67.170),
                vec3(-832.320, -721.263, 67.204),
                vec3(-826.893, -721.271, 67.198)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-827.620, -721.390, 68.275),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.341, -720.397, 67.170, 358.18)
        },
            [808] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.836, -704.280, 67.170),
                vec3(-825.773, -709.689, 67.186),
                vec3(-820.105, -709.636, 67.256),
                vec3(-820.105, -704.266, 67.201)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-819.983, -704.989, 68.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.030, -705.692, 67.170, 89.35)
        },
            [809] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.836, -698.695, 67.170),
                vec3(-825.824, -704.089, 67.192),
                vec3(-820.142, -704.089, 67.195),
                vec3(-820.105, -698.664, 67.203)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-819.983, -699.389, 68.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.916, -700.152, 67.170, 91.06)
        },
            [810] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.830, -693.065, 67.170),
                vec3(-825.852, -698.398, 67.170),
                vec3(-820.111, -698.490, 67.187),
                vec3(-820.105, -693.044, 67.285)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-819.983, -693.789, 68.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.868, -694.495, 67.170, 91.33)
        },
            [811] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.805, -687.501, 67.170),
                vec3(-825.792, -692.738, 67.170),
                vec3(-820.151, -692.889, 67.223),
                vec3(-820.105, -687.474, 67.256)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-819.983, -688.189, 68.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.200, -688.975, 67.170, 95.52)
        },
            [812] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.838, -681.894, 67.170),
                vec3(-825.833, -687.198, 67.170),
                vec3(-820.107, -687.286, 67.170),
                vec3(-820.150, -681.826, 67.228)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-819.983, -682.589, 68.275),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.827, -683.322, 67.170, 97.72)
        },
            [813] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.732, -687.239, 67.170),
                vec3(-810.727, -681.827, 67.170),
                vec3(-816.484, -681.856, 67.184),
                vec3(-816.484, -687.255, 67.186)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-816.610, -686.526, 68.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.751, -685.777, 67.170, 272.71)
        },
            [814] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -692.819, 67.251),
                vec3(-810.771, -687.543, 67.250),
                vec3(-816.479, -687.426, 67.209),
                vec3(-816.484, -692.851, 67.233)
            },
                minZ = 67.21,
                maxZ = 70.21
            },
            door = {
                coords = vec3(-816.610, -692.126, 68.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.500, -691.346, 67.170, 275.41)
        },
            [815] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.742, -698.388, 67.170),
                vec3(-810.771, -693.170, 67.254),
                vec3(-816.484, -693.095, 67.188),
                vec3(-816.484, -698.479, 67.257)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-816.610, -697.726, 68.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.581, -696.989, 67.170, 267.95)
        },
            [816] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.742, -704.089, 67.173),
                vec3(-810.767, -698.628, 67.170),
                vec3(-816.484, -698.642, 67.230),
                vec3(-816.484, -704.073, 67.219)
            },
                minZ = 67.17,
                maxZ = 70.27
            },
            door = {
                coords = vec3(-816.610, -703.326, 68.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.812, -702.672, 67.170, 273.80)
        },
            [817] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.746, -709.678, 67.170),
                vec3(-810.771, -704.335, 67.235),
                vec3(-816.414, -704.226, 67.230),
                vec3(-816.470, -709.689, 67.278)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-816.610, -708.926, 68.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.581, -708.229, 67.170, 274.87)
        },
            [818] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.778, -715.229, 67.170),
                vec3(-810.771, -709.949, 67.231),
                vec3(-816.484, -709.914, 67.256),
                vec3(-816.484, -715.282, 67.309)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-816.610, -714.526, 68.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.931, -713.771, 67.170, 272.95)
        },
            [819] = {
            floor = 8,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.794, -720.845, 67.170),
                vec3(-810.771, -715.515, 67.248),
                vec3(-816.480, -715.425, 67.267),
                vec3(-816.484, -720.876, 67.232)
            },
                minZ = 67.17,
                maxZ = 70.17
            },
            door = {
                coords = vec3(-816.570, -720.126, 68.275),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.928, -719.442, 67.170, 278.47)
        },
            [901] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.515, -730.451, 71.018),
                vec3(-821.283, -730.451, 71.039),
                vec3(-821.166, -724.747, 71.002),
                vec3(-826.547, -724.749, 70.970)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-825.866, -724.611, 72.075),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.155, -725.455, 70.970, 186.49)
        },
            [902] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.168, -730.451, 71.018),
                vec3(-826.822, -730.457, 70.970),
                vec3(-826.766, -724.798, 71.014),
                vec3(-832.203, -724.740, 70.970)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-831.466, -724.611, 72.075),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.738, -725.570, 70.970, 189.87)
        },
            [903] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.759, -730.492, 70.970),
                vec3(-832.385, -730.457, 70.970),
                vec3(-832.366, -724.758, 71.028),
                vec3(-837.787, -724.738, 71.158)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-837.066, -724.611, 72.075),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.298, -725.509, 70.970, 179.41)
        },
            [904] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.370, -730.451, 71.031),
                vec3(-837.992, -730.479, 70.970),
                vec3(-837.987, -724.738, 70.999),
                vec3(-843.393, -724.738, 71.111)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-842.666, -724.611, 72.075),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.957, -725.532, 70.970, 184.36)
        },
            [905] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.517, -715.567, 70.970),
                vec3(-838.188, -715.559, 71.077),
                vec3(-838.057, -721.223, 71.067),
                vec3(-843.457, -721.271, 71.047)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-838.820, -721.390, 72.075),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.509, -720.573, 70.970, 358.10)
        },
            [906] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.474, -715.534, 70.970),
                vec3(-837.901, -715.559, 71.010),
                vec3(-837.920, -721.267, 71.107),
                vec3(-832.481, -721.271, 71.074)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-833.220, -721.390, 72.075),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-833.954, -720.636, 70.970, 2.83)
        },
            [907] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.951, -715.559, 71.043),
                vec3(-832.281, -715.518, 70.970),
                vec3(-832.275, -721.271, 71.032),
                vec3(-826.877, -721.271, 71.081)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-827.620, -721.390, 72.075),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.291, -720.266, 70.970, 358.35)
        },
            [908] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.852, -704.285, 70.970),
                vec3(-825.821, -709.618, 70.970),
                vec3(-820.138, -709.689, 70.984),
                vec3(-820.105, -704.232, 71.068)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-819.983, -704.989, 72.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.873, -705.743, 70.970, 93.13)
        },
            [909] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.829, -698.713, 70.970),
                vec3(-825.817, -703.947, 71.024),
                vec3(-820.105, -704.052, 70.981),
                vec3(-820.105, -698.675, 71.064)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-819.983, -699.389, 72.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.829, -700.155, 70.970, 95.60)
        },
            [910] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.830, -693.132, 70.970),
                vec3(-825.783, -698.350, 70.970),
                vec3(-820.105, -698.454, 70.974),
                vec3(-820.139, -693.026, 71.108)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-819.983, -693.789, 72.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.896, -694.528, 70.970, 94.53)
        },
            [911] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.800, -687.487, 70.970),
                vec3(-825.782, -692.889, 71.070),
                vec3(-820.105, -692.852, 70.982),
                vec3(-820.105, -687.491, 71.025)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-819.983, -688.189, 72.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-821.102, -688.933, 70.970, 93.05)
        },
            [912] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -681.936, 71.027),
                vec3(-825.817, -687.208, 71.050),
                vec3(-820.105, -687.245, 71.073),
                vec3(-820.105, -681.840, 71.171)
            },
                minZ = 71.03,
                maxZ = 74.03
            },
            door = {
                coords = vec3(-819.983, -682.589, 72.075),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.890, -683.338, 70.970, 90.83)
        },
            [913] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.812, -687.228, 70.970),
                vec3(-810.762, -681.834, 70.970),
                vec3(-816.454, -681.826, 71.015),
                vec3(-816.484, -687.219, 71.118)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-816.610, -686.526, 72.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.767, -685.842, 70.970, 269.09)
        },
            [914] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.791, -692.818, 70.970),
                vec3(-810.771, -687.518, 71.035),
                vec3(-816.484, -687.440, 71.075),
                vec3(-816.484, -692.879, 71.113)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-816.610, -692.126, 72.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.927, -691.407, 70.970, 270.98)
        },
            [915] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.778, -698.411, 70.970),
                vec3(-810.771, -693.176, 71.068),
                vec3(-816.444, -693.067, 70.970),
                vec3(-816.484, -698.475, 71.021)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-816.610, -697.726, 72.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.591, -696.962, 70.970, 273.67)
        },
            [916] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.783, -704.014, 70.970),
                vec3(-810.771, -698.820, 71.056),
                vec3(-816.484, -698.685, 71.044),
                vec3(-816.484, -703.984, 71.108)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-816.610, -703.326, 72.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.606, -702.611, 70.970, 274.54)
        },
            [917] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -709.654, 71.030),
                vec3(-810.771, -704.336, 71.055),
                vec3(-816.446, -704.226, 71.017),
                vec3(-816.484, -709.640, 71.084)
            },
                minZ = 71.02,
                maxZ = 74.02
            },
            door = {
                coords = vec3(-816.610, -708.926, 72.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.839, -708.100, 70.970, 272.44)
        },
            [918] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.849, -715.199, 70.970),
                vec3(-810.760, -709.919, 70.970),
                vec3(-816.484, -709.826, 71.077),
                vec3(-816.484, -715.269, 71.106)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-816.610, -714.526, 72.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.763, -713.785, 70.970, 275.75)
        },
            [919] = {
            floor = 9,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -720.819, 71.033),
                vec3(-810.768, -715.425, 70.972),
                vec3(-816.484, -715.471, 70.987),
                vec3(-816.484, -720.874, 71.074)
            },
                minZ = 70.97,
                maxZ = 73.97
            },
            door = {
                coords = vec3(-816.570, -720.126, 72.075),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.756, -719.412, 70.970, 273.80)
        },
            [1001] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.599, -730.435, 74.770),
                vec3(-821.166, -730.450, 74.783),
                vec3(-821.166, -724.761, 74.874),
                vec3(-826.566, -724.738, 74.911)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-825.866, -724.611, 75.875),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.168, -725.354, 74.770, 178.80)
        },
            [1002] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.153, -730.444, 74.770),
                vec3(-826.796, -730.451, 74.860),
                vec3(-826.835, -724.738, 74.899),
                vec3(-832.170, -724.738, 74.913)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-831.466, -724.611, 75.875),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.682, -725.405, 74.770, 182.71)
        },
            [1003] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.760, -730.498, 74.770),
                vec3(-832.462, -730.451, 74.846),
                vec3(-832.424, -724.738, 74.863),
                vec3(-837.829, -724.761, 74.873)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-837.066, -724.611, 75.875),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.420, -725.459, 74.770, 185.77)
        },
            [1004] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.389, -730.494, 74.770),
                vec3(-838.010, -730.451, 74.845),
                vec3(-838.018, -724.738, 74.770),
                vec3(-843.386, -724.738, 74.886)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-842.666, -724.611, 75.875),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.962, -725.291, 74.770, 190.01)
        },
            [1005] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-838.084, -715.563, 74.770),
                vec3(-843.387, -715.559, 74.827),
                vec3(-843.518, -721.271, 74.780),
                vec3(-838.071, -721.271, 74.831)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-838.820, -721.390, 75.875),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.536, -720.207, 74.770, 2.88)
        },
            [1006] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.535, -715.559, 74.813),
                vec3(-837.911, -715.507, 74.770),
                vec3(-837.884, -721.234, 74.770),
                vec3(-832.456, -721.266, 74.839)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-833.220, -721.390, 75.875),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-834.002, -720.634, 74.770, 1.82)
        },
            [1007] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.863, -715.535, 74.770),
                vec3(-832.226, -715.559, 74.894),
                vec3(-832.306, -721.271, 74.775),
                vec3(-826.857, -721.268, 74.891)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-827.620, -721.390, 75.875),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.373, -720.695, 74.770, 4.79)
        },
            [1008] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.791, -704.292, 74.770),
                vec3(-825.833, -709.689, 74.775),
                vec3(-820.105, -709.593, 74.935),
                vec3(-820.105, -704.242, 74.970)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-819.983, -704.989, 75.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.840, -705.774, 74.770, 95.42)
        },
            [1009] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.862, -698.665, 74.770),
                vec3(-825.817, -703.955, 74.898),
                vec3(-820.105, -704.059, 74.820),
                vec3(-820.105, -698.639, 74.893)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-819.983, -699.389, 75.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.854, -700.129, 74.770, 99.28)
        },
            [1010] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -693.141, 74.827),
                vec3(-825.817, -698.354, 74.862),
                vec3(-820.105, -698.461, 74.843),
                vec3(-820.105, -693.087, 74.873)
            },
                minZ = 74.83,
                maxZ = 77.83
            },
            door = {
                coords = vec3(-819.983, -693.789, 75.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.698, -694.587, 74.770, 92.47)
        },
            [1011] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -687.504, 74.844),
                vec3(-825.817, -692.885, 74.846),
                vec3(-820.105, -692.847, 74.770),
                vec3(-820.105, -687.482, 74.923)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-819.983, -688.189, 75.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.841, -688.853, 74.770, 83.33)
        },
            [1012] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.863, -681.869, 74.770),
                vec3(-825.817, -687.264, 74.823),
                vec3(-820.109, -687.290, 74.813),
                vec3(-820.113, -681.826, 74.826)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-819.983, -682.589, 75.875),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.974, -683.316, 74.770, 91.44)
        },
            [1013] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.738, -687.250, 74.770),
                vec3(-810.771, -681.910, 74.857),
                vec3(-816.484, -681.877, 74.883),
                vec3(-816.484, -687.231, 74.880)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-816.610, -686.526, 75.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.509, -685.701, 74.770, 272.54)
        },
            [1014] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.747, -692.804, 74.770),
                vec3(-810.755, -687.492, 74.770),
                vec3(-816.454, -687.426, 74.833),
                vec3(-816.484, -692.872, 74.961)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-816.610, -692.126, 75.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.528, -691.305, 74.770, 277.21)
        },
            [1015] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.797, -698.446, 74.770),
                vec3(-810.759, -693.101, 74.770),
                vec3(-816.474, -693.026, 74.922),
                vec3(-816.484, -698.484, 74.993)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-816.610, -697.726, 75.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.611, -696.997, 74.770, 273.50)
        },
            [1016] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.736, -704.089, 74.772),
                vec3(-810.791, -698.626, 74.884),
                vec3(-816.484, -698.666, 74.914),
                vec3(-816.484, -704.073, 75.012)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-816.610, -703.326, 75.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.476, -702.503, 74.770, 277.16)
        },
            [1017] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.795, -709.624, 74.770),
                vec3(-810.704, -704.263, 74.770),
                vec3(-816.484, -704.276, 74.885),
                vec3(-816.484, -709.658, 75.031)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-816.610, -708.926, 75.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.756, -708.204, 74.770, 270.77)
        },
            [1018] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.735, -715.212, 74.770),
                vec3(-810.777, -709.940, 74.770),
                vec3(-816.481, -709.826, 74.857),
                vec3(-816.484, -715.251, 74.860)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-816.610, -714.526, 75.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.670, -713.866, 74.770, 273.63)
        },
            [1019] = {
            floor = 10,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.769, -720.808, 74.770),
                vec3(-810.771, -715.428, 74.822),
                vec3(-816.484, -715.433, 74.834),
                vec3(-816.484, -720.844, 74.888)
            },
                minZ = 74.77,
                maxZ = 77.77
            },
            door = {
                coords = vec3(-816.570, -720.126, 75.875),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.763, -719.220, 74.770, 282.41)
        },
            [1101] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.555, -730.464, 78.570),
                vec3(-821.201, -730.477, 78.570),
                vec3(-821.166, -724.770, 78.635),
                vec3(-826.602, -724.738, 78.662)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-825.866, -724.611, 79.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.105, -725.553, 78.570, 186.10)
        },
            [1102] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.207, -730.504, 78.570),
                vec3(-826.855, -730.451, 78.614),
                vec3(-826.795, -724.738, 78.644),
                vec3(-832.191, -724.738, 78.606)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-831.466, -724.611, 79.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.777, -725.434, 78.570, 183.14)
        },
            [1103] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-837.771, -730.451, 78.620),
                vec3(-832.460, -730.451, 78.663),
                vec3(-832.428, -724.738, 78.591),
                vec3(-837.776, -724.738, 78.640)
            },
                minZ = 78.59,
                maxZ = 81.59
            },
            door = {
                coords = vec3(-837.066, -724.611, 79.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-836.336, -725.533, 78.570, 184.24)
        },
            [1104] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-843.389, -730.484, 78.570),
                vec3(-837.993, -730.451, 78.619),
                vec3(-838.026, -724.744, 78.570),
                vec3(-843.396, -724.738, 78.725)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-842.666, -724.611, 79.675),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-841.899, -725.595, 78.570, 184.90)
        },
            [1105] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-838.072, -715.633, 78.570),
                vec3(-843.463, -715.572, 78.570),
                vec3(-843.492, -721.271, 78.573),
                vec3(-838.128, -721.271, 78.695)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-838.820, -721.390, 79.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-839.677, -720.581, 78.570, 13.24)
        },
            [1106] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.529, -715.559, 78.634),
                vec3(-837.833, -715.559, 78.648),
                vec3(-837.894, -721.267, 78.570),
                vec3(-832.514, -721.271, 78.598)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-833.220, -721.390, 79.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-834.074, -720.725, 78.570, 1.07)
        },
            [1107] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.974, -715.562, 78.570),
                vec3(-832.306, -715.553, 78.570),
                vec3(-832.225, -721.271, 78.677),
                vec3(-826.920, -721.271, 78.671)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-827.620, -721.390, 79.675),
                model = -138454175,
                heading = 180,
                securityLevel = 1
            },
            spawnPoint = vec4(-828.436, -720.339, 78.570, 7.25)
        },
            [1108] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.868, -704.297, 78.570),
                vec3(-825.817, -709.559, 78.646),
                vec3(-820.105, -709.601, 78.626),
                vec3(-820.105, -704.266, 78.718)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-819.983, -704.989, 79.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.888, -705.800, 78.570, 91.44)
        },
            [1109] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -698.714, 78.640),
                vec3(-825.756, -703.985, 78.570),
                vec3(-820.128, -704.089, 78.612),
                vec3(-820.105, -698.657, 78.730)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-819.983, -699.389, 79.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.871, -700.235, 78.570, 99.89)
        },
            [1110] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.841, -693.089, 78.570),
                vec3(-825.817, -698.326, 78.709),
                vec3(-820.112, -698.490, 78.594),
                vec3(-820.105, -693.066, 78.621)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-819.983, -693.789, 79.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.856, -694.474, 78.570, 91.84)
        },
            [1111] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.860, -687.490, 78.570),
                vec3(-825.861, -692.869, 78.570),
                vec3(-820.105, -692.817, 78.578),
                vec3(-820.174, -687.426, 78.622)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-819.983, -688.189, 79.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.976, -689.106, 78.570, 97.65)
        },
            [1112] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-825.817, -681.855, 78.644),
                vec3(-825.796, -687.285, 78.570),
                vec3(-820.108, -687.244, 78.570),
                vec3(-820.105, -681.862, 78.628)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-819.983, -682.589, 79.675),
                model = -138454175,
                heading = 270,
                securityLevel = 1
            },
            spawnPoint = vec4(-820.864, -683.341, 78.570, 93.49)
        },
            [1113] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.742, -687.233, 78.570),
                vec3(-810.711, -681.849, 78.570),
                vec3(-816.430, -681.826, 78.680),
                vec3(-816.482, -687.290, 78.766)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-816.610, -686.526, 79.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.758, -685.683, 78.570, 277.20)
        },
            [1114] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.752, -692.823, 78.570),
                vec3(-810.748, -687.426, 78.594),
                vec3(-816.439, -687.426, 78.680),
                vec3(-816.484, -692.886, 78.753)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-816.610, -692.126, 79.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.637, -691.431, 78.570, 269.94)
        },
            [1115] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.715, -698.442, 78.570),
                vec3(-810.771, -693.144, 78.638),
                vec3(-816.484, -693.051, 78.673),
                vec3(-816.484, -698.450, 78.766)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-816.610, -697.726, 79.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.766, -696.904, 78.570, 280.13)
        },
            [1116] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.691, -704.051, 78.570),
                vec3(-810.771, -698.764, 78.671),
                vec3(-816.467, -698.626, 78.676),
                vec3(-816.450, -704.089, 78.749)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-816.610, -703.326, 79.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.771, -702.502, 78.570, 276.24)
        },
            [1117] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -709.646, 78.638),
                vec3(-810.767, -704.328, 78.570),
                vec3(-816.484, -704.248, 78.607),
                vec3(-816.484, -709.631, 78.719)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-816.610, -708.926, 79.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.625, -708.167, 78.570, 275.31)
        },
            [1118] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -715.234, 78.676),
                vec3(-810.715, -709.826, 78.576),
                vec3(-816.484, -709.833, 78.650),
                vec3(-816.484, -715.227, 78.774)
            },
                minZ = 78.58,
                maxZ = 81.58
            },
            door = {
                coords = vec3(-816.610, -714.526, 79.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.654, -713.731, 78.570, 274.51)
        },
            [1119] = {
            floor = 11,
            zone = {
                type = 'poly',
                points = {
                vec3(-810.771, -720.859, 78.687),
                vec3(-810.792, -715.485, 78.570),
                vec3(-816.462, -715.425, 78.675),
                vec3(-816.480, -720.888, 78.764)
            },
                minZ = 78.57,
                maxZ = 81.57
            },
            door = {
                coords = vec3(-816.570, -720.126, 79.675),
                model = -138454175,
                heading = 90,
                securityLevel = 1
            },
            spawnPoint = vec4(-815.592, -719.264, 78.570, 271.18)
        },
            [1201] = {
            floor = 12,
            zone = {
                type = 'poly',
                points = {
                vec3(-826.588, -730.442, 82.370),
                vec3(-821.166, -730.448, 82.421),
                vec3(-821.272, -724.738, 82.437),
                vec3(-826.630, -724.841, 82.455)
            },
                minZ = 82.37,
                maxZ = 85.37
            },
            door = {
                coords = vec3(-825.866, -724.611, 83.475),
                model = -138454175,
                heading = 0,
                securityLevel = 1
            },
            spawnPoint = vec4(-825.187, -725.226, 82.370, 176.71)
        },
            [1202] = {
            floor = 12,
            zone = {
                type = 'poly',
                points = {
                vec3(-832.165, -730.421, 82.370),
                vec3(-826.812, -730.485, 82.370),
                vec3(-826.766, -724.765, 82.445),
                vec3(-832.215, -724.748, 82.370)
            },
                minZ = 82.37,
                maxZ = 85.37
            },
            door = {
                coords = vec3(-831.466, -724.611, 83.475),
                model = -138454175,
                heading = 360,
                securityLevel = 1
            },
            spawnPoint = vec4(-830.836, -725.111, 82.370, 175.21)
        },
    }
}