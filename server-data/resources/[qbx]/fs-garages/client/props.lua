--[[
    fs-garages / client/props.lua

    A car's look, read off it when it is parked and put back on it when it
    comes out: paint, parts, wheels, lights, extras and damage.

    Written in the same shape ox_lib, ESX and QBCore use, so cars saved by
    a vehicle shop or another garage script come out exactly as they were,
    and a server can switch to these garages without anybody's car
    changing. Where the three disagree (extras, custom colours) both forms
    are read.
]]

Garage = Garage or {}

local Props = {}
Garage.Props = Props

--- The parts the game numbers, by the names the saved look uses.
local MODS = {
    modSpoilers = 0, modFrontBumper = 1, modRearBumper = 2, modSideSkirt = 3, modExhaust = 4, modFrame = 5,
    modGrille = 6, modHood = 7, modFender = 8, modRightFender = 9, modRoof = 10, modEngine = 11, modBrakes = 12,
    modTransmission = 13, modHorns = 14, modSuspension = 15, modArmor = 16, modNitrous = 17, modSubwoofer = 19,
    modHydraulics = 21, modPlateHolder = 25, modVanityPlate = 26, modTrimA = 27, modOrnaments = 28,
    modDashboard = 29, modDial = 30, modDoorSpeaker = 31, modSeats = 32, modSteeringWheel = 33,
    modShifterLeavers = 34, modAPlate = 35, modSpeakers = 36, modTrunk = 37, modHydrolic = 38, modEngineBlock = 39,
    modAirFilter = 40, modStruts = 41, modArchCover = 42, modAerials = 43, modTrimB = 44, modTank = 45,
    modWindows = 46, modDoorR = 47, modLightbar = 49,
}

--- The parts that are only on or off.
local TOGGLES = { modTurbo = 18, modSmokeEnabled = 20, modXenon = 22 }

--- Model hash -> the extras that model must keep on, made once.
local required = nil

local function requiredOf(model)
    if not required then
        required = {}
        for name, list in pairs(Garage.Models.required) do
            local set = {}
            for _, id in ipairs(list) do set[id] = true end
            required[GetHashKey(name) % 4294967296] = set
        end
    end
    return required[model % 4294967296] or {}
end

--- Is the extra on, as the saved look says it? ox_lib (and these garages)
--- write 0 for on and 1 for off. ESX and QBCore write true for on, and
--- their own garages switch an extra on for any number at all, 1 included;
--- reading their 1 as off took the tail and rotors off helicopters. Which
--- way to read it is told by the rest of the look: only ox_lib keeps broken
--- windows, doors and tyres as plain lists.
local function extraOn(props, value)
    if value == true or value == false then return value end
    local oxLib = props.windows ~= nil or props.doors ~= nil or props.tyres ~= nil
    if oxLib then return tonumber(value) == 0 end
    return value ~= nil
end

local function round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

--- Everything about the car's look, to be kept with it.
function Props.get(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    local color1, color2 = GetVehicleColours(vehicle)
    local pearlescent, wheelColor = GetVehicleExtraColours(vehicle)
    local paintType1 = GetVehicleModColor_1(vehicle)
    local paintType2 = GetVehicleModColor_2(vehicle)
    if GetIsVehiclePrimaryColourCustom(vehicle) then color1 = { GetVehicleCustomPrimaryColour(vehicle) } end
    if GetIsVehicleSecondaryColourCustom(vehicle) then color2 = { GetVehicleCustomSecondaryColour(vehicle) } end

    local extras = {}
    for id = 0, 20 do
        if DoesExtraExist(vehicle, id) then extras[tostring(id)] = IsVehicleExtraTurnedOn(vehicle, id) and 0 or 1 end
    end

    local neon = {}
    for i = 0, 3 do neon[i + 1] = IsVehicleNeonLightEnabled(vehicle, i) end

    local windows, doors, tyres = {}, {}, {}
    for i = 0, 7 do
        if not IsVehicleWindowIntact(vehicle, i) then windows[#windows + 1] = i end
    end
    for i = 0, 5 do
        if IsVehicleDoorDamaged(vehicle, i) then doors[#doors + 1] = i end
    end
    for i = 0, 7 do
        if IsVehicleTyreBurst(vehicle, i, false) then tyres[tostring(i)] = IsVehicleTyreBurst(vehicle, i, true) and 2 or 1 end
    end

    local liveryCount = GetVehicleLiveryCount(vehicle)
    local props = {
        model = GetEntityModel(vehicle),
        plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = round(GetVehicleBodyHealth(vehicle)),
        engineHealth = round(GetVehicleEngineHealth(vehicle)),
        tankHealth = round(GetVehiclePetrolTankHealth(vehicle)),
        dirtLevel = round(GetVehicleDirtLevel(vehicle)),
        paintType1 = paintType1,
        paintType2 = paintType2,
        color1 = color1,
        color2 = color2,
        pearlescentColor = pearlescent,
        wheelColor = wheelColor,
        interiorColor = GetVehicleInteriorColor(vehicle),
        dashboardColor = GetVehicleDashboardColour(vehicle),
        wheels = GetVehicleWheelType(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        neonEnabled = neon,
        neonColor = { GetVehicleNeonLightsColour(vehicle) },
        tyreSmokeColor = { GetVehicleTyreSmokeColor(vehicle) },
        extras = extras,
        modCustomTiresF = GetVehicleModVariation(vehicle, 23),
        modCustomTiresR = GetVehicleModVariation(vehicle, 24),
        modFrontWheels = GetVehicleMod(vehicle, 23),
        modBackWheels = GetVehicleMod(vehicle, 24),
        modLivery = liveryCount == -1 and GetVehicleMod(vehicle, 48) or GetVehicleLivery(vehicle),
        modRoofLivery = GetVehicleRoofLivery(vehicle),
        bulletProofTyres = not GetVehicleTyresCanBurst(vehicle),
        windows = windows,
        doors = doors,
        tyres = tyres,
    }
    for name, index in pairs(MODS) do props[name] = GetVehicleMod(vehicle, index) end
    for name, index in pairs(TOGGLES) do props[name] = IsToggleModOn(vehicle, index) end
    -- Fuel comes from the fuel script the server uses, not the game's own gauge.
    props.fuelLevel = round(Garage.Integrations.call('fuel', 'get', vehicle) or GetVehicleFuelLevel(vehicle))
    return props
end

local function rgb(value)
    if type(value) == 'table' and value[1] then return tonumber(value[1]) or 0, tonumber(value[2]) or 0, tonumber(value[3]) or 0 end
    if type(value) == 'table' and value.r then return tonumber(value.r) or 0, tonumber(value.g) or 0, tonumber(value.b) or 0 end
end

--- Puts a kept look back on the car. Anything the look does not mention
--- is left as the car came.
function Props.set(vehicle, props)
    if type(props) ~= 'table' or not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    SetVehicleModKit(vehicle, 0)
    local color1, color2 = GetVehicleColours(vehicle)
    local pearlescent, wheelColor = GetVehicleExtraColours(vehicle)

    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth + 0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end

    if props.paintType1 then SetVehicleModColor_1(vehicle, props.paintType1, 0, props.pearlescentColor or 0) end
    if props.paintType2 then SetVehicleModColor_2(vehicle, props.paintType2, 0) end
    -- A plain colour is a number; a custom one is three numbers (ox_lib and
    -- QBCore keep it in color1, ESX in customPrimaryColor).
    local n1 = type(props.color1) == 'number' and props.color1 or color1
    local n2 = type(props.color2) == 'number' and props.color2 or color2
    SetVehicleColours(vehicle, n1, n2)
    local r, g, b = rgb(props.color1)
    if not r then r, g, b = rgb(props.customPrimaryColor) end
    if r then SetVehicleCustomPrimaryColour(vehicle, r, g, b) end
    r, g, b = rgb(props.color2)
    if not r then r, g, b = rgb(props.customSecondaryColor) end
    if r then SetVehicleCustomSecondaryColour(vehicle, r, g, b) end
    SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescent, props.wheelColor or wheelColor)
    if props.interiorColor then SetVehicleInteriorColor(vehicle, props.interiorColor) end
    if props.dashboardColor then SetVehicleDashboardColour(vehicle, props.dashboardColor) end

    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end
    if props.xenonColor then SetVehicleXenonLightsColor(vehicle, props.xenonColor) end
    if type(props.neonEnabled) == 'table' then
        for i = 1, 4 do SetVehicleNeonLightEnabled(vehicle, i - 1, props.neonEnabled[i] == true) end
    end
    r, g, b = rgb(props.neonColor)
    if r then SetVehicleNeonLightsColour(vehicle, r, g, b) end
    r, g, b = rgb(props.tyreSmokeColor)
    if r then SetVehicleTyreSmokeColor(vehicle, r, g, b) end

    if type(props.extras) == 'table' then
        local must = requiredOf(GetEntityModel(vehicle))
        for id, value in pairs(props.extras) do
            id = tonumber(id)
            -- An extra the model must have stays on, whatever was saved.
            if id and DoesExtraExist(vehicle, id) then
                SetVehicleExtra(vehicle, id, not (must[id] or extraOn(props, value)))
            end
        end
    end

    for name, index in pairs(MODS) do
        local value = tonumber(props[name])
        if value then SetVehicleMod(vehicle, index, value, false) end
    end
    for name, index in pairs(TOGGLES) do
        if props[name] ~= nil then ToggleVehicleMod(vehicle, index, props[name] == true or props[name] == 1) end
    end
    if tonumber(props.modFrontWheels) then SetVehicleMod(vehicle, 23, props.modFrontWheels, props.modCustomTiresF == true) end
    if tonumber(props.modBackWheels) then SetVehicleMod(vehicle, 24, props.modBackWheels, props.modCustomTiresR == true) end
    if tonumber(props.modLivery) then
        SetVehicleMod(vehicle, 48, props.modLivery, false)
        SetVehicleLivery(vehicle, props.modLivery)
    end
    if tonumber(props.modRoofLivery) then SetVehicleRoofLivery(vehicle, props.modRoofLivery) end
    if props.bulletProofTyres ~= nil then SetVehicleTyresCanBurst(vehicle, not props.bulletProofTyres) end

    if type(props.windows) == 'table' then
        for _, i in pairs(props.windows) do SmashVehicleWindow(vehicle, tonumber(i)) end
    end
    if type(props.doors) == 'table' then
        for _, i in pairs(props.doors) do SetVehicleDoorBroken(vehicle, tonumber(i), true) end
    end
    if type(props.tyres) == 'table' then
        for i, burst in pairs(props.tyres) do
            if burst then SetVehicleTyreBurst(vehicle, tonumber(i), burst == 2, 1000.0) end
        end
    end

    -- Damage as ESX keeps it (window, door or tyre number -> broken) and as
    -- QBCore keeps it (windows by whether they are still whole).
    for i, broken in pairs(type(props.windowsBroken) == 'table' and props.windowsBroken or {}) do
        if broken == true then SmashVehicleWindow(vehicle, tonumber(i)) end
    end
    for i, intact in pairs(type(props.windowStatus) == 'table' and props.windowStatus or {}) do
        if intact == false then SmashVehicleWindow(vehicle, tonumber(i)) end
    end
    for _, list in ipairs({ props.doorsBroken, props.doorStatus }) do
        for i, broken in pairs(type(list) == 'table' and list or {}) do
            if broken == true then SetVehicleDoorBroken(vehicle, tonumber(i), true) end
        end
    end
    for _, list in ipairs({ props.tyreBurst, props.tireBurstState }) do
        for i, burst in pairs(type(list) == 'table' and list or {}) do
            if burst == true then
                local whole = type(props.tireBurstCompletely) == 'table' and props.tireBurstCompletely[i] == true
                SetVehicleTyreBurst(vehicle, tonumber(i), whole, 1000.0)
            end
        end
    end

    if props.fuelLevel then Garage.Integrations.call('fuel', 'set', vehicle, (tonumber(props.fuelLevel) or 100) + 0.0) end
end
