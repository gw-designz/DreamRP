--[[
    fs-garages / server/vehicles.lua

    Parking, and taking a car out again. Everything here is decided by the
    server: a player's game only asks.

    A car is parked from the driver's seat inside one of a garage's spaces;
    its look (paint, parts, damage, fuel) is kept with it. It is taken out
    at that garage's kiosk and put in a free space of that garage. A car
    parked somewhere else can be brought over for Config.Parking.transferFee.
    A car with no garage written down, or one whose garage is not among
    these (kept by the garage script used before, or in a garage an admin
    has since deleted), can be taken out at any garage.

    Before a car is made in the city it is taken off the garage's list in
    the database, so two people at two kiosks cannot both get it.

    A car left out in the city that is no longer there is "lost", and is got
    back at an impound for Config.Impound.fee. A parking script that keeps
    cars in the city through restarts (config/integrations.lua) is asked
    first: a car it still keeps is not lost, and when the garages remove a
    car they do it through that script, so it does not come back as a copy.
]]

local util = Garage.util

local KIOSK_REACH = 4.0

--- Which of the game's vehicle types each garage type keeps.
local TYPES = {
    car = { automobile = true, bike = true, quadbike = true, trailer = true, amphibious_automobile = true, amphibious_quadbike = true },
    boat = { boat = true, submarine = true, amphibious_automobile = true, amphibious_quadbike = true },
    air = { heli = true, plane = true, blimp = true },
}

-- ── helpers ────────────────────────────────────────────────────────────

local locks = {}

--- One thing at a time per car: a second press while the first is still
--- going is turned away instead of doubling up.
local function withLock(key, fn)
    if locks[key] then return false, 'err_busy' end
    locks[key] = true
    local ok, a, b = pcall(fn)
    locks[key] = nil
    if not ok then
        util.error(('%s failed: %s'):format(key, tostring(a)))
        return false, 'err_unknown'
    end
    return a, b
end

local function where(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped), ped
end

local function nearKiosk(src, garage)
    local at = where(src)
    local k = garage and garage.kiosk
    return at and k and #(at - vec3(k.x, k.y, k.z)) <= KIOSK_REACH
end

--- May this player use this garage at all? A job garage is for its jobs.
local function mayUse(src, garage)
    if garage.kind ~= 'job' then return true end
    local job = Bridge.getJob(src)
    return job ~= nil and util.contains(garage.jobs, job.name)
end

local function hashOf(model)
    if type(model) == 'string' then return GetHashKey(model) end
    return tonumber(model)
end

--- The same model whether it is written as a name or as either form of
--- its hash.
local function sameModel(a, b)
    local ha, hb = hashOf(a), hashOf(b)
    if not ha or not hb then return true end
    return ha % 4294967296 == hb % 4294967296
end

--- A space of the garage with no vehicle in it.
local function freeSpot(garage)
    local vehicles = GetAllVehicles()
    for _, spot in ipairs(garage.spots or {}) do
        local taken = false
        for _, vehicle in ipairs(vehicles) do
            local c = GetEntityCoords(vehicle)
            if math.abs(c.z - spot.z) < 3.0 and util.flat(c, spot) < 2.6 then
                taken = true
                break
            end
        end
        if not taken then return spot end
    end
end

--- The space of the garage a car stands in, if any.
local function spotOf(garage, coords)
    for _, spot in ipairs(garage.spots or {}) do
        if math.abs(coords.z - spot.z) < 3.0 and util.flat(coords, spot) <= (Config.Parking.reach or 2.5) then return spot end
    end
end

--- The car with this plate standing in the city right now, if any.
local function liveVehicle(plate)
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) and util.plate(GetVehicleNumberPlateText(vehicle)) == plate then return vehicle end
    end
end

--- Every plate standing in the city right now, as a set.
local function livePlates()
    local set = {}
    for _, vehicle in ipairs(GetAllVehicles()) do
        if DoesEntityExist(vehicle) then set[util.plate(GetVehicleNumberPlateText(vehicle))] = true end
    end
    return set
end

--- Does the parking script still keep this car somewhere in the city?
local function kept(plate)
    return Garage.Integrations.call('parking', 'knows', plate) == true
end

--- Takes a car out of the city: through the parking script when there is
--- one, so it is not brought back, and the ordinary way after it.
local function removeVehicle(vehicle)
    Garage.Integrations.call('parking', 'delete', vehicle)
    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end
end

local function occupied(vehicle)
    for seat = -1, 6 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped and ped ~= 0 then return true end
    end
    return false
end

local names = nil

--- Model name for a model hash (for the car pictures), made once: every
--- car of the game, then the framework's list on top for add-on cars.
local function modelName(model)
    if type(model) == 'string' then return model:lower() end
    if not names then
        names = {}
        for _, name in ipairs(Garage.Models.names) do util.nameHash(names, name) end
        for hash, name in pairs(Bridge.modelNames() or {}) do names[hash] = tostring(name):lower() end
    end
    return names[tonumber(model) or 0]
end

-- ── the kiosk ──────────────────────────────────────────────────────────

--- The garage a parked car belongs to, or nil when it may come out at any.
local function homeOf(car)
    return car.garage and car.garage ~= '' and util.garage(car.garage) or nil
end

--- Where one of the player's cars is, as the kiosk shows it. `live` is the
--- set of plates standing in the city right now.
local function placeOf(car, garage, live)
    if car.state == 'impounded' then return 'impounded' end
    if car.state == 'out' then
        if live[car.plate] or kept(car.plate) then return 'out' end
        return 'lost'
    end
    local home = homeOf(car)
    if not home or home.id == garage.id then return 'here' end
    return 'elsewhere'
end

--- What getting a car back from the impound costs.
local function impoundFee(car)
    local own = Config.Impound.useImpoundPrice ~= false and tonumber(car.fee) or 0
    if car.state == 'impounded' and own > 0 then return math.floor(own) end
    return math.max(0, math.floor(tonumber(Config.Impound.fee) or 0))
end

--- May this car be got back at an impound, by where it is.
local function recoverable(place)
    return place == 'lost' or place == 'impounded' or (place == 'out' and Config.Impound.takeFromCity ~= false)
end

function Garage.openKiosk(src, data)
    local garage = util.garage(data.garage)
    if not garage then return false, 'err_unknown' end
    if not nearKiosk(src, garage) then return false, 'err_too_far' end
    if not mayUse(src, garage) then return false, 'err_not_your_job' end
    local identifier = Bridge.getIdentifier(src)
    if not identifier then return false, 'err_unknown' end

    local cars, live = {}, livePlates()
    local depot = garage.kind == 'depot'
    for _, car in ipairs(Bridge.vehicles(identifier)) do
        local place = placeOf(car, garage, live)
        local other = place == 'elsewhere' and homeOf(car) or nil
        local props = car.props or {}
        local back = depot and recoverable(place)
        cars[#cars + 1] = {
            plate = car.plate, model = car.model, name = modelName(car.model), kind = car.kind,
            place = place, at = other and other.label or nil, atType = other and other.type or nil,
            fuel = tonumber(props.fuelLevel), engine = tonumber(props.engineHealth), body = tonumber(props.bodyHealth),
            recover = back or nil, recoverFee = back and impoundFee(car) or nil,
        }
    end
    return true, {
        garage = { id = garage.id, label = garage.label, type = garage.type, kind = garage.kind },
        cars = cars, fee = math.max(0, math.floor(tonumber(Config.Parking.transferFee) or 0)),
    }
end

-- ── making the car ─────────────────────────────────────────────────────

--- Makes a car in a space, or nil when the game would not.
local function makeVehicle(model, kind, spot)
    local vehicle = CreateVehicleServerSetter(model, kind, spot.x, spot.y, spot.z + 0.3, spot.w)
    local deadline = GetGameTimer() + 3000
    while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and GetGameTimer() < deadline do Wait(50) end
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    return vehicle
end

--- The plate, the owner's mark and the keys, and what the driver's game needs.
local function handOver(src, vehicle, identifier, plate, car)
    SetVehicleNumberPlateText(vehicle, plate)
    Entity(vehicle).state:set('fsGarage', identifier, true)
    Garage.Integrations.call('keys', 'server', src, vehicle, plate)
    return { net = NetworkGetNetworkIdFromEntity(vehicle), plate = plate, props = car.props or {} }
end

-- ── taking a car out ───────────────────────────────────────────────────

function Garage.retrieve(src, data)
    local garage = util.garage(data.garage)
    if not garage then return false, 'err_unknown' end
    if not nearKiosk(src, garage) then return false, 'err_too_far' end
    if not mayUse(src, garage) then return false, 'err_not_your_job' end
    local plate = util.plate(data.plate)
    local kind = tostring(data.type or '')
    if plate == '' or not (TYPES[garage.type] or {})[kind] then return false, 'err_wrong_type' end
    local identifier = Bridge.getIdentifier(src)
    if not identifier then return false, 'err_unknown' end

    return withLock('car:' .. plate, function()
        local car = Bridge.vehicle(plate)
        if not car or car.owner ~= identifier then return false, 'err_not_yours' end
        if car.state ~= 'garaged' then return false, 'err_not_here' end
        local home = homeOf(car)
        if home and home.id ~= garage.id then return false, 'err_not_here' end
        local spot = freeSpot(garage)
        if not spot then return false, 'err_no_space' end
        local model = hashOf(car.model or (car.props or {}).model)
        if not model then return false, 'err_unknown' end

        -- Taken off the garage's list first: a second kiosk now finds nothing.
        if not Bridge.claim(plate) then return false, 'err_not_here' end

        local vehicle = makeVehicle(model, kind, spot)
        if not vehicle then
            -- Could not be made: back on the list where it was.
            Bridge.park(plate, car.garage, car.props or {})
            return false, 'err_spawn_failed'
        end
        util.debug(('%s took %s out of %s'):format(src, plate, garage.id))
        return true, handOver(src, vehicle, identifier, plate, car)
    end)
end

-- ── getting a car back from the impound ────────────────────────────────

function Garage.recover(src, data)
    local garage = util.garage(data.garage)
    if not garage or garage.kind ~= 'depot' then return false, 'err_unknown' end
    if not nearKiosk(src, garage) then return false, 'err_too_far' end
    local plate = util.plate(data.plate)
    local kind = tostring(data.type or '')
    if plate == '' or not (TYPES[garage.type] or {})[kind] then return false, 'err_wrong_type' end
    local identifier = Bridge.getIdentifier(src)
    if not identifier then return false, 'err_unknown' end

    return withLock('car:' .. plate, function()
        local car = Bridge.vehicle(plate)
        if not car or car.owner ~= identifier then return false, 'err_not_yours' end
        local live = liveVehicle(plate)
        local place = placeOf(car, garage, live and { [plate] = true } or {})
        if not recoverable(place) then return false, place == 'out' and 'err_in_city' or 'err_not_here' end
        if live and occupied(live) then return false, 'err_in_use' end
        local spot = freeSpot(garage)
        if not spot then return false, 'err_no_space' end
        local model = hashOf(car.model or (car.props or {}).model)
        if not model then return false, 'err_unknown' end

        local fee = impoundFee(car)
        local account = Config.Impound.account == 'cash' and 'cash' or 'bank'
        if fee > 0 and not Bridge.removeMoney(src, account, fee) then
            return false, account == 'cash' and 'err_no_cash' or 'err_no_money'
        end

        -- The old one goes first, wherever it is, so there are never two.
        if live then removeVehicle(live) end
        if place == 'out' or place == 'lost' then Garage.Integrations.call('parking', 'deletePlate', plate) end

        local vehicle = makeVehicle(model, kind, spot)
        if not vehicle then
            if fee > 0 then Bridge.addMoney(src, account, fee) end
            return false, 'err_spawn_failed'
        end
        Bridge.release(plate)
        util.debug(('%s got %s back from %s for %s'):format(src, plate, garage.id, fee))
        return true, handOver(src, vehicle, identifier, plate, car)
    end)
end

-- ── bringing a car over from another garage ────────────────────────────

function Garage.transfer(src, data)
    local garage = util.garage(data.garage)
    if not garage then return false, 'err_unknown' end
    if not nearKiosk(src, garage) then return false, 'err_too_far' end
    if not mayUse(src, garage) then return false, 'err_not_your_job' end
    local plate = util.plate(data.plate)
    local identifier = Bridge.getIdentifier(src)
    if plate == '' or not identifier then return false, 'err_unknown' end

    return withLock('car:' .. plate, function()
        local car = Bridge.vehicle(plate)
        if not car or car.owner ~= identifier then return false, 'err_not_yours' end
        local from = car.state == 'garaged' and homeOf(car)
        -- One that may come out anywhere needs no bringing over.
        if not from or from.id == garage.id then return false, 'err_not_here' end
        if from.type ~= garage.type then return false, 'err_wrong_type' end
        local fee = math.max(0, math.floor(tonumber(Config.Parking.transferFee) or 0))
        if fee > 0 and not Bridge.removeMoney(src, 'bank', fee) then return false, 'err_no_money' end
        if not Bridge.move(plate, garage.id) then
            if fee > 0 then Bridge.addMoney(src, 'bank', fee) end
            return false, 'err_not_here'
        end
        return true
    end)
end

-- ── parking ────────────────────────────────────────────────────────────

function Garage.park(src, data)
    local garage = util.garage(data.garage)
    if not garage then return false, 'err_unknown' end
    if not mayUse(src, garage) then return false, 'err_not_your_job' end
    local vehicle = tonumber(data.net) and NetworkGetEntityFromNetworkId(tonumber(data.net)) or 0
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false, 'err_no_vehicle' end
    local _, ped = where(src)
    if not ped or GetPedInVehicleSeat(vehicle, -1) ~= ped then return false, 'err_not_driver' end
    if not spotOf(garage, GetEntityCoords(vehicle)) then return false, 'err_not_in_space' end
    if not (TYPES[garage.type] or {})[GetVehicleType(vehicle)] then return false, 'err_wrong_type' end

    local plate = util.plate(GetVehicleNumberPlateText(vehicle))
    local identifier = Bridge.getIdentifier(src)
    if plate == '' or not identifier then return false, 'err_unknown' end

    return withLock('car:' .. plate, function()
        local car = Bridge.vehicle(plate)
        if not car or car.owner ~= identifier then return false, 'err_not_yours' end
        if not sameModel(car.model or (car.props or {}).model, GetEntityModel(vehicle)) then return false, 'err_not_yours' end
        -- The look comes from the driver's game; the car itself, its plate
        -- and its model are the server's.
        local props = type(data.props) == 'table' and data.props or {}
        props.plate = plate
        props.model = GetEntityModel(vehicle)
        if not Bridge.park(plate, garage.id, props) then return false, 'err_unknown' end
        Garage.Integrations.call('keys', 'serverRemove', src, vehicle, plate)
        removeVehicle(vehicle)
        util.debug(('%s parked %s in %s'):format(src, plate, garage.id))
        return true
    end)
end
