--[[
    fs-garages / integrations/custom.lua

    Your own key, parking or fuel script, plugged into the garages.

    1. In config/integrations.lua, set the line to 'custom', for example
          keys = 'custom',
    2. Below, find the block of the same name. Delete the comment line just
       above it (the one starting with --[[ and the block's name) and the
       comment line just under it (the closing brackets), then fill in the
       functions with your script's own exports or events.

    A mistake inside one of these functions is written to the server or
    game console with the block's name; the garage keeps working.
]]

Custom = {}

--[[ ── Keys: giving the driver the keys of a car taken out ───────────────

    Fill in ONE of the two, whichever your key script expects.

Custom.keys = {
    --- On the server. `src` is the player, `vehicle` the car, `plate` its plate.
    server = function(src, vehicle, plate)
        exports['my-keys']:GiveKeys(src, plate)
    end,

    --- Or in the driver's own game.
    client = function(vehicle, plate)
        exports['my-keys']:GiveKeys(plate)
    end,

    --- Taking the keys back when the car is parked (both may be left out).
    --- On the server, just before the car is put away:
    serverRemove = function(src, vehicle, plate)
        exports['my-keys']:RemoveKeys(src, plate)
    end,

    --- Or in the driver's own game, just after. `name` is the model's name
    --- as the game shows it (e.g. 'SULTAN'): the car itself is gone by then.
    clientRemove = function(vehicle, plate, name)
        exports['my-keys']:RemoveKeys(plate)
    end,
}
]]

--[[ ── Parking: a script that keeps cars standing in the city ───────────

    Used by the server only.

Custom.parking = {
    --- Remove this car from the city and from your script, so it is not
    --- brought back. Return true when it was removed.
    delete = function(vehicle)
        return exports['my-parking']:DeleteVehicle(vehicle)
    end,

    --- Forget a car your script keeps but has not put in the world right
    --- now (nobody is near it), by its plate.
    deletePlate = function(plate)
        return exports['my-parking']:DeleteVehicleByPlate(plate)
    end,

    --- Does your script still keep this car somewhere in the city?
    knows = function(plate)
        return exports['my-parking']:IsVehicleSaved(plate)
    end,
}
]]

--[[ ── Fuel: reading and setting a car's fuel (in the driver's own game) ──

Custom.fuel = {
    --- How much fuel the car has, 0 to 100.
    get = function(vehicle)
        return exports['my-fuel']:GetFuel(vehicle)
    end,

    --- Set the car's fuel, 0 to 100.
    set = function(vehicle, level)
        exports['my-fuel']:SetFuel(vehicle, level)
    end,
}
]]
