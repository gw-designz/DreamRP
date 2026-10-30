Config = Config or {}

--[[
╔════════════════════════════════════════════════════════════════════════════════════╗
║                             GARAGES CONFIGURATION                                  ║
╠════════════════════════════════════════════════════════════════════════════════════╣
║            For detailed documentation and setup instructions, visit:               ║
║         https://docs.teamsgg.dev/paid-scripts/phone/configure/valet-system         ║
╚════════════════════════════════════════════════════════════════════════════════════╝
--]]


Config.Garages = "auto"
--[[
    The garages script you use.
    If yours is not supported you can follow these steps to integrate it.
    1. Rename the `your_garage.lua` file in both `(client/server)\apps\framework\garage` with the name of your garage script. ex: qb-garages.lua.
    2. Check `client\apps\framework\garage\garage.lua` what is the expected garage object. (array of vehicles)
    3. Implement the functions according to your garage. You can use the `qb-garages.lua` as an example.
    4. Change `Config.Garages` to the name of your garage script.
    5. If you want open a ticket and contribute the integration so other people can use it as well.
    Supported:
        * qb-garages - https://github.com/qbcore-framework/qb-houses
        * qbx_garages - https://github.com/Qbox-project/qbx_garages
        * esx_garage - https://github.com/esx-framework/esx_garage
        * jg-advancedgarages
        * vms_garagesv2
        * cd_garage
    ]]

Config.Valet = {}
Config.Valet.Enabled = true        -- Allow players to get their vehicles from the phone
Config.Valet.Price = 100           -- Price to get your vehicle
Config.Valet.DriveToPlayer = false -- If true, the valet will drive to the player's location to deliver the vehicle
--[[
    The vehicle keys system you use.
    Supported:
        * qb-vehiclekeys
        * MrNewbVehicleKeys
        * jaksam-vehicles-keys
        * qs-vehiclekeys
        * mk_vehiclekeys
        * wasabi_carlock
        * cd_garage
        * okokGarage
    -- ! Your system is missing? Head over to `client\apps\framework\garage\garage.lua` and add it.
 ]]
Config.Valet.VehicleKeys = "none"

Config.Garage = Config.Garage or {}
--- Custom Garage app thumbnails: `{ model = spawnName, cover = url }`. Match is case-insensitive; numeric `model` (hash) matches `joaat(spawnName)`. Existing `cover` on a vehicle is kept.
Config.Garage.CustomVehicles = {
    {
        model = 'bati',
        cover = 'https://i.imgur.com/0JZ6X3S.png',
    },
}
