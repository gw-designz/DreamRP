while not Config do Citizen.Wait(1) end

-- Shop locations are defined in maps/departments/*.lua under `vehicleShops`.
Config.VehicleShop = {
    ---@field Enabled: boolean [master toggle for the police vehicle shop feature]
    Enabled = true,

    ---@field Vehicles: table [purchasable vehicles grouped by category - each entry is a list of vehicle definitions]
    ---@field Vehicles.entry: table [{ id: string, name: string, model: string, price: number, armor?: number, description?: string, rank?: string, allowedJobs: string[], allowedGrades: { jobName = minGrade } }]
    Vehicles = {
        ['patrol'] = {
            {
                id = 'police',
                name = 'Police Cruiser',
                model = 'police',
                price = 1000,
                armor = 0,
                description = 'Standard patrol vehicle for daily operations.',
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 0, ['sheriff'] = 0 },
            },
            {
                id = 'police2',
                name = 'Police Cruiser 2',
                model = 'police2',
                price = 0,
                armor = 1,
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 0, ['sheriff'] = 0 },
            },
            {
                id = 'police3',
                name = 'Police Cruiser 3',
                model = 'police3',
                price = 5000,
                armor = 1,
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 1, ['sheriff'] = 1 },
            },
        },

        ['unmarked'] = {
            {
                id = 'police4',
                name = 'Unmarked Cruiser',
                model = 'police4',
                price = 15000,
                armor = 0,
                description = 'Unmarked vehicle for undercover operations.',
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 2, ['sheriff'] = 2 },
            },
            {
                id = 'fbi',
                name = 'Buffalo STX',
                model = 'fbi',
                price = 25000,
                armor = 1,
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 2, ['sheriff'] = 2 },
            },
            {
                id = 'fbi2',
                name = 'FIB SUV',
                model = 'fbi2',
                price = 30000,
                armor = 1,
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 3, ['sheriff'] = 3 },
            },
        },

        ['interceptor'] = {
            {
                id = 'policet',
                name = 'Police Interceptor',
                model = 'police3',
                price = 45000,
                description = 'High-speed pursuit vehicle.',
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 3, ['sheriff'] = 3 },
            },
            {
                id = 'dominator',
                name = 'Vapid Dominator',
                model = 'dominator',
                price = 65000,
                rank = 'Sergeant',
                allowedJobs = { 'police' },
                allowedGrades = { ['police'] = 4 },
            },
        },

        ['swat'] = {
            {
                id = 'policet2',
                name = 'Police Transporter',
                model = 'policet',
                price = 35000,
                armor = 2,
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 3, ['sheriff'] = 3 },
            },
            {
                id = 'riot',
                name = 'Police Riot',
                model = 'riot',
                price = 80000,
                armor = 4,
                description = 'Armored transport for tactical operations.',
                rank = 'Sergeant',
                allowedJobs = { 'police' },
                allowedGrades = { ['police'] = 4 },
            },
        },

        ['motorcycle'] = {
            {
                id = 'policeb',
                name = 'Police Bike',
                model = 'policeb',
                price = 12000,
                description = 'Fast response motorcycle unit.',
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 1, ['sheriff'] = 1 },
            },
        },

        ['helicopter'] = {
            {
                id = 'polmav',
                name = 'Police Maverick',
                model = 'polmav',
                price = 500000,
                armor = 1,
                description = 'Air support helicopter.',
                rank = 'Lieutenant',
                allowedJobs = { 'police' },
                allowedGrades = { ['police'] = 5 },
            },
        },

        ['boat'] = {
            {
                id = 'predator',
                name = 'Police Predator',
                model = 'predator',
                price = 150000,
                armor = 0,
                description = 'Marine patrol boat.',
                allowedJobs = { 'police', 'sheriff' },
                allowedGrades = { ['police'] = 3, ['sheriff'] = 3 },
            },
        },
    },

    ---@field TestDrive: table [test drive settings - { enabled: boolean, duration: number(seconds), spawnOffset: vector3, returnMessage: string }]
    TestDrive = {
        enabled = true,
        duration = 60,
        spawnOffset = vector3(0, 5, 0),
        returnMessage = 'Your test drive has ended. The vehicle has been returned.',
    },
}
