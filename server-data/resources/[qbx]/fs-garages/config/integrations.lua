--[[
    fs-garages / config/integrations.lua

    The other scripts the garages work with, all in one place.

    For each line below you can write:

      'auto'     the garages find one of the scripts they know by themselves
                 (the first one listed that is running on your server)
      a name     use exactly that script, e.g. 'qb-vehiclekeys'
      'custom'   use your own script: write a few lines for it in
                 integrations/custom.lua (that file shows you how)
      'none'     switch it off

    If a script you named is not running, the console says so when it is
    first needed.
]]

Config.Integrations = {
    --- Giving the driver the keys of a car taken out of a garage, and
    --- taking them back when it is parked.
    --- Known: 'qs-vehiclekeys', 'qbx_vehiclekeys', 'qb-vehiclekeys',
    --- 'MrNewbVehicleKeys', 'wasabi_carlock', 'Renewed-Vehiclekeys',
    --- 'vehicles_keys'.
    --- With none of them (plain ESX), nothing is needed: 'none'.
    keys = 'auto',

    --- A script that keeps cars standing in the city through restarts.
    --- The garages tell it when they put a car away or take a lost one to
    --- the impound, so it does not bring the car back as a copy.
    --- Known: 'AdvancedParking'. Without one, 'none'.
    parking = 'auto',

    --- Reading and setting a car's fuel. Known: 'fs-fuel', 'ox_fuel',
    --- 'LegacyFuel', 'ps-fuel', 'cdn-fuel', 'lc_fuel', and 'game' (the
    --- game's own fuel, when there is no fuel script).
    fuel = 'auto',
}
