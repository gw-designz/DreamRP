while not Config do Citizen.Wait(1) end

-- Garage locations are defined in maps/departments/*.lua under `garages`.
Config.Garage = {
    ---@field Enabled: boolean [master toggle for the police garage feature]
    Enabled = true,

    ---@field maxDistance: number [max distance (metres) to interact with the garage ped/point]
    maxDistance = 10.0,

    ---@field CustomImages: table [optional per-model preview images, keyed by vehicle model = image URL]
    CustomImages = {
        -- ['police'] = 'https://example.com/police.jpg',
    },
}
