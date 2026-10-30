-- Speed, rpm, gear / altitude, fuel, seatbelt (with crash ejection) and the driver key hints.

local MPH, KMH, KNOTS, FEET = 2.236936, 3.6, 1.943844, 3.28084
local AIR_CLASSES = { [15] = true, [16] = true }
local BICYCLE_CLASS, BOAT_CLASS, TRAIN_CLASS = 13, 14, 21
local getFuel

local electric = {}
for _, model in ipairs(Config.Vehicle.electric) do electric[joaat(model)] = true end

-- 'air' (helicopters / planes), 'boat', 'bicycle', 'train', 'electric' or 'car'; decides the gauge style.
local function gaugeMode(veh)
    local class = GetVehicleClass(veh)
    if AIR_CLASSES[class] then return 'air' end
    if class == BOAT_CLASS then return 'boat' end
    if class == BICYCLE_CLASS then return 'bicycle' end
    if class == TRAIN_CLASS then return 'train' end
    if electric[GetEntityModel(veh)] then return 'electric' end
    return 'car'
end

local function showHints()
    local cfg = Config.Vehicle.hints
    Hud.setHints(cfg.items, cfg.duration)
end

local function hideHints()
    Hud.setHints(nil)
end

local function resolveFuel()
    local choice = Config.Vehicle.fuel
    if choice == 'auto' then
        choice = 'native'
        for _, res in ipairs({ 'ox_fuel', 'LegacyFuel', 'cdn-fuel', 'ps-fuel', 'lj-fuel' }) do
            if GetResourceState(res) == 'started' then
                choice = res
                break
            end
        end
    end
    Bridge.debug('fuel source', choice)

    if choice == 'ox_fuel' then
        return function(veh) return Entity(veh).state.fuel or GetVehicleFuelLevel(veh) end
    elseif choice ~= 'native' then
        return function(veh) return exports[choice]:GetFuel(veh) end
    end
    -- Native fuel level is measured against the handling tank volume (usually 65L).
    return function(veh)
        local tank = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume')
        local level = GetVehicleFuelLevel(veh)
        return tank > 0 and level / tank * 100 or level
    end
end

local function gearLabel(veh)
    if GetEntitySpeedVector(veh, true).y < -0.5 then return 'R' end
    local gear = GetVehicleCurrentGear(veh)
    if gear <= 0 then return 'N' end
    return tostring(gear)
end

local function canBelt(veh)
    return not Config.Vehicle.noBeltClasses[GetVehicleClass(veh)]
end

local function setBelt(state)
    if Hud.belted == state then return end
    Hud.belted = state
    LocalPlayer.state:set('seatbelt', state, false)
    TriggerEvent('my-hud:client:seatbelt', state)
end

local function toggleBelt()
    local veh = Hud.vehicle
    if veh == 0 or not canBelt(veh) or IsPauseMenuActive() then return end
    setBelt(not Hud.belted)
    if Hud.settings.beltPlugSound then
        PlaySoundFrontend(-1, Hud.belted and 'NAV_UP_DOWN' or 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end

RegisterCommand(Config.Vehicle.seatbeltCommand, toggleBelt, false)
RegisterKeyMapping(Config.Vehicle.seatbeltCommand, 'Toggle seatbelt', 'keyboard', Config.Vehicle.seatbeltKey)

-- Speed unit per vehicle class (Settings > Cars & Bikes / Bicycles / Boats / Air / Trains).
local UNIT_FACTOR = { mph = MPH, kmh = KMH, knots = KNOTS }
local UNIT_LABEL = { mph = 'MPH', kmh = 'KMH', knots = 'KNOTS' }
local function unitFor(mode)
    local s = Hud.settings
    if mode == 'bicycle' then return s.bikeUnit end
    if mode == 'boat' then return s.boatUnit end
    if mode == 'air' then return s.airUnit end
    if mode == 'train' then return s.trainUnit end
    return s.speedUnit
end

-- Speed limit of the street the vehicle is on, in the player's unit (0 = no sign).
local limitStreet, limitValue = nil, 0
local function speedLimit(veh, unit)
    local cfg = Config.SpeedLimits
    if not cfg or not cfg.enabled then return 0 end
    local c = GetEntityCoords(veh)
    local street = GetStreetNameAtCoord(c.x, c.y, c.z)
    if street ~= limitStreet then
        limitStreet = street
        limitValue = cfg.streets[GetStreetNameFromHashKey(street)] or cfg.default or 0
    end
    if unit == 'kmh' then return Hud.round(limitValue * 1.609344 / 10) * 10 end
    return limitValue
end

local function anyDoorOpen(veh)
    for i = 0, 3 do
        if GetVehicleDoorAngleRatio(veh, i) > 0.1 then return true end
    end
    return false
end

local function eject(ped, veh, velocity)
    local coords = GetOffsetFromEntityInWorldCoords(veh, 0.0, 2.2, 0.8)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    Wait(1)
    SetPedToRagdoll(ped, Config.Vehicle.eject.ragdollMs, Config.Vehicle.eject.ragdollMs, 0, false, false, false)
    SetEntityVelocity(ped, velocity.x, velocity.y, velocity.z)
    setBelt(false)
end

CreateThread(function()
    getFuel = resolveFuel()
    local lastSpeed, lastVelocity = 0.0, vector3(0, 0, 0)
    local ejectCfg = Config.Vehicle.eject
    local mode = 'car'

    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh ~= 0 then
            if veh ~= Hud.vehicle then
                mode = gaugeMode(veh)
                if GetPedInVehicleSeat(veh, -1) == ped then showHints() else hideHints() end
            end
            Hud.vehicle = veh
            Hud.inVehicle = true

            local speed = GetEntitySpeed(veh)
            local mph = speed * MPH
            Hud.speedMph = mph
            local beltable = canBelt(veh)

            if ejectCfg.enabled and beltable and not Hud.belted
                and lastSpeed >= ejectCfg.minSpeed and lastSpeed - mph >= ejectCfg.minDelta
                and HasEntityCollidedWithAnything(veh) then
                eject(ped, veh, lastVelocity)
            end
            lastSpeed, lastVelocity = mph, GetEntityVelocity(veh)

            Hud.muteBell = mode == 'bicycle' and not Hud.settings.bellSounds
            if Hud.visible and Hud.settings.showVehicle then
                local unit = unitFor(mode)
                local air = mode == 'air'
                local indicators = GetVehicleIndicatorLights(veh)
                local ok, fuel = pcall(getFuel, veh)
                local _, lightsOn, highBeams = GetVehicleLightsState(veh)
                local meters = Hud.settings.distanceUnit == 'meters'
                local altitude, alt, climb = '', 0, 0
                if air then
                    local height = math.max(0, GetEntityHeightAboveGround(veh))
                    alt = Hud.round(meters and height or height * FEET)
                    altitude = ('%d %s'):format(alt, meters and 'm' or 'ft')
                    -- vertical speed per minute
                    climb = Hud.round(GetEntityVelocity(veh).z * 60 * (meters and 1 or FEET))
                end
                local tilted = air or mode == 'boat'
                Hud.push('vehicle', {
                    show = true,
                    mode = mode,
                    speed = Hud.round(speed * (UNIT_FACTOR[unit] or MPH)),
                    unit = UNIT_LABEL[unit] or 'MPH',
                    altitude = altitude,
                    alt = alt,
                    altUnit = meters and 'm' or 'ft',
                    climb = climb,
                    heading = tilted and Hud.round((360.0 - GetEntityHeading(veh)) % 360.0) or 0,
                    pitch = tilted and Hud.round(GetEntityPitch(veh)) or 0,
                    roll = air and Hud.round(GetEntityRoll(veh)) or 0,
                    limit = (mode == 'car' or mode == 'electric') and speedLimit(veh, unit) or 0,
                    cruise = Hud.cruise == veh,
                    braking = mode == 'train' and IsControlPressed(0, 72) or false,
                    doorsOpen = mode == 'train' and anyDoorOpen(veh) or false,
                    -- rounded to the gauge's 30 segments so idle jitter does not spam the NUI
                    rpm = Hud.round(GetVehicleCurrentRpm(veh) * 30) * 100 // 30,
                    gear = gearLabel(veh),
                    fuel = Hud.round(Hud.clamp(ok and tonumber(fuel) or 0, 0, 100)),
                    -- engine health is -4000..1000; below 0 the engine is smoking / on fire
                    engine = Hud.round(Hud.clamp(GetVehicleEngineHealth(veh) / 10, 0, 100)),
                    indLeft = indicators & 1 ~= 0,
                    indRight = indicators & 2 ~= 0,
                    belt = beltable and Hud.belted or false,
                    beltable = beltable,
                    moving = mph > Config.Vehicle.blinkSpeed,
                    lights = lightsOn == 1 or highBeams == 1,
                    locked = GetVehicleDoorLockStatus(veh) >= 2,
                })
            else
                Hud.push('vehicle', { show = false })
            end
            Wait(Hud.tick('vehicle'))
        else
            if Hud.inVehicle then
                Hud.inVehicle, Hud.vehicle, Hud.speedMph = false, 0, 0
                Hud.muteBell = false
                lastSpeed = 0.0
                setBelt(false)
                hideHints()
                Hud.push('vehicle', { show = false })
            end
            Wait(500)
        end
    end
end)

exports('IsSeatbeltOn', function() return Hud.belted end)
exports('SetSeatbelt', function(state) setBelt(state == true) end)
