--[[
    fs-garages / integrations/known.lua

    The key and fuel scripts the garages know by themselves. Each one is
    tried in this order when its line in config/integrations.lua is 'auto'.

    Keys are given either by the server (`server(src, vehicle, plate)`) or
    by the driver's own game (`client(vehicle, plate)`), whichever the key
    script expects, and taken back the same way when the car is parked
    (`serverRemove(src, vehicle, plate)` before the car goes,
    `clientRemove(vehicle, plate, name)` after). Fuel is read and set in
    the driver's own game. A parking script is only spoken to by the server.
]]

local Integrations = Garage.Integrations

local function started(name)
    return function() return GetResourceState(name) == 'started' end
end

-- ── keys ───────────────────────────────────────────────────────────────

-- Quasar's keys are given by plate and the model's name as the game shows
-- it, in the driver's own game. The name is read before the car is parked,
-- since the car is gone by the time its keys are taken back.
Integrations.add('keys', 'qs-vehiclekeys', {
    running = started('qs-vehiclekeys'),
    client = function(vehicle, plate)
        exports['qs-vehiclekeys']:GiveKeys(plate, GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)), false)
    end,
    clientRemove = function(_, plate, name)
        exports['qs-vehiclekeys']:RemoveKeys(plate, name)
    end,
})

Integrations.add('keys', 'qbx_vehiclekeys', {
    running = started('qbx_vehiclekeys'),
    server = function(src, vehicle) exports.qbx_vehiclekeys:GiveKeys(src, vehicle) end,
    serverRemove = function(src, vehicle) exports.qbx_vehiclekeys:RemoveKeys(src, vehicle, true) end,
})

Integrations.add('keys', 'qb-vehiclekeys', {
    running = started('qb-vehiclekeys'),
    server = function(src, _, plate) TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate) end,
})

Integrations.add('keys', 'MrNewbVehicleKeys', {
    running = started('MrNewbVehicleKeys'),
    client = function(vehicle) exports.MrNewbVehicleKeys:GiveKeys(vehicle) end,
})

Integrations.add('keys', 'wasabi_carlock', {
    running = started('wasabi_carlock'),
    client = function(_, plate) exports.wasabi_carlock:GiveKey(plate) end,
})

Integrations.add('keys', 'Renewed-Vehiclekeys', {
    running = started('Renewed-Vehiclekeys'),
    client = function(_, plate) exports['Renewed-Vehiclekeys']:addKey(plate) end,
})

Integrations.add('keys', 'vehicles_keys', {
    running = started('vehicles_keys'),
    server = function(src, _, plate) exports.vehicles_keys:giveVehicleKeysToPlayerId(src, plate, 'owner') end,
})

-- ── parking scripts that keep cars in the city ─────────────────────────

--[[
    AdvancedParking (Kiminaze) brings back any car it knows that has gone
    from the world. A car the garages remove the ordinary way comes back as
    a copy, so it is removed through AdvancedParking instead. A car it still
    knows is not lost: it stands somewhere in the city, or will again.
]]
Integrations.add('parking', 'AdvancedParking', {
    running = started('AdvancedParking'),
    delete = function(vehicle) return exports['AdvancedParking']:DeleteVehicle(vehicle, false) end,
    deletePlate = function(plate) return exports['AdvancedParking']:DeleteVehicleUsingData(nil, nil, plate, false) end,
    knows = function(plate) return exports['AdvancedParking']:GetVehiclePosition(plate) ~= nil end,
})

-- ── fuel ───────────────────────────────────────────────────────────────

--- A fuel script whose exports are GetFuel(vehicle) and SetFuel(vehicle, level).
local function exportFuel(name)
    return {
        running = started(name),
        get = function(vehicle) return exports[name]:GetFuel(vehicle) end,
        set = function(vehicle, level) exports[name]:SetFuel(vehicle, level) end,
    }
end

Integrations.add('fuel', 'fs-fuel', exportFuel('fs-fuel'))

Integrations.add('fuel', 'ox_fuel', {
    running = started('ox_fuel'),
    get = function(vehicle) return Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle) end,
    set = function(vehicle, level)
        SetVehicleFuelLevel(vehicle, level + 0.0)
        Entity(vehicle).state:set('fuel', level + 0.0, true)
    end,
})

Integrations.add('fuel', 'LegacyFuel', exportFuel('LegacyFuel'))
Integrations.add('fuel', 'ps-fuel', exportFuel('ps-fuel'))
Integrations.add('fuel', 'cdn-fuel', exportFuel('cdn-fuel'))
Integrations.add('fuel', 'lc_fuel', exportFuel('lc_fuel'))

-- No fuel script at all: the game's own fuel level.
Integrations.add('fuel', 'game', {
    get = function(vehicle) return GetVehicleFuelLevel(vehicle) end,
    set = function(vehicle, level) SetVehicleFuelLevel(vehicle, level + 0.0) end,
})
