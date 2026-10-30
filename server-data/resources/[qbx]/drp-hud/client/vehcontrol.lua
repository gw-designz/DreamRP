-- Vehicle control panel (bottom center): engine, lock, indicators, doors, windows, seats,
-- hood, trunk, lights, cruise and neon. Opens with Config.VehicleControls.command / key
-- while in a vehicle; the NUI takes the mouse until it is closed again.

local cfg = Config.VehicleControls
if not cfg or not cfg.enabled then return end

local open = false
local windowsDown = {}  -- [veh] = { [index] = true }, the game cannot tell a rolled down window

local function hasCommand(name)
    for _, c in ipairs(GetRegisteredCommands()) do
        if c.name == name then return true end
    end
    return false
end

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    Hud.send('vcontrols', { open = false })
end

local function state(veh)
    local ped = PlayerPedId()
    local doors, hasDoor, seats, windows = {}, {}, {}, {}
    for i = 0, 5 do
        local exists = GetIsDoorValid(veh, i)
        hasDoor[tostring(i)] = exists
        doors[tostring(i)] = exists and GetVehicleDoorAngleRatio(veh, i) > 0.1
    end
    local down = windowsDown[veh] or {}
    for i = 0, 3 do windows[tostring(i)] = down[i] == true end
    local seatCount = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    for i = -1, seatCount - 2 do
        seats[tostring(i + 1)] = GetPedInVehicleSeat(veh, i) == ped
    end
    local neon = false
    for i = 0, 3 do neon = neon or IsVehicleNeonLightEnabled(veh, i) end
    local indicators = GetVehicleIndicatorLights(veh)
    local _, lightsOn, highBeams = GetVehicleLightsState(veh)
    return {
        engine = GetIsVehicleEngineRunning(veh),
        locked = GetVehicleDoorLockStatus(veh) >= 2,
        indLeft = indicators & 1 ~= 0,
        indRight = indicators & 2 ~= 0,
        lights = lightsOn == 1 or highBeams == 1,
        cruise = Hud.cruise == veh,
        neon = neon,
        doors = doors,
        hasDoor = hasDoor,
        windows = windows,
        seats = seats,
        seatCount = seatCount,
    }
end

local function setCruise(veh, on)
    if on then
        Hud.cruise = veh
        SetVehicleMaxSpeed(veh, math.max(GetEntitySpeed(veh), 2.0))
    else
        if Hud.cruise and DoesEntityExist(Hud.cruise) then SetVehicleMaxSpeed(Hud.cruise, 0.0) end
        Hud.cruise = nil
    end
end

local actions = {}

function actions.engine(veh)
    SetVehicleEngineOn(veh, not GetIsVehicleEngineRunning(veh), false, true)
end

function actions.lock(veh)
    if cfg.lockCommand and hasCommand(cfg.lockCommand) then
        ExecuteCommand(cfg.lockCommand)
    else
        SetVehicleDoorsLocked(veh, GetVehicleDoorLockStatus(veh) >= 2 and 1 or 2)
    end
end

-- SetVehicleIndicatorLights: 0 is the right signal, 1 the left.
local function setIndicators(veh, left, right)
    SetVehicleIndicatorLights(veh, 1, left)
    SetVehicleIndicatorLights(veh, 0, right)
end

function actions.left(veh)
    local mask = GetVehicleIndicatorLights(veh)
    setIndicators(veh, mask ~= 1, false)
end

function actions.right(veh)
    local mask = GetVehicleIndicatorLights(veh)
    setIndicators(veh, false, mask ~= 2)
end

function actions.hazard(veh)
    local on = GetVehicleIndicatorLights(veh) ~= 3
    setIndicators(veh, on, on)
end

function actions.door(veh, index)
    if not GetIsDoorValid(veh, index) then return end
    if GetVehicleDoorAngleRatio(veh, index) > 0.1 then
        SetVehicleDoorShut(veh, index, false)
    else
        SetVehicleDoorOpen(veh, index, false, false)
    end
end

function actions.window(veh, index)
    windowsDown[veh] = windowsDown[veh] or {}
    local down = not windowsDown[veh][index]
    windowsDown[veh][index] = down
    if down then RollDownWindow(veh, index) else RollUpWindow(veh, index) end
end

function actions.seat(veh, index)
    if IsVehicleSeatFree(veh, index) then SetPedIntoVehicle(PlayerPedId(), veh, index) end
end

function actions.lights(veh)
    local _, lightsOn, highBeams = GetVehicleLightsState(veh)
    SetVehicleLights(veh, (lightsOn == 1 or highBeams == 1) and 1 or 2)
end

function actions.cruise(veh)
    setCruise(veh, Hud.cruise ~= veh)
end

function actions.neon(veh)
    local on = false
    for i = 0, 3 do on = on or IsVehicleNeonLightEnabled(veh, i) end
    for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, not on) end
end

RegisterNUICallback('vcAction', function(data, cb)
    cb(1)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    local action = data and actions[data.action]
    if veh == 0 or not action then return end
    -- everything but switching seats needs the driver
    if data.action ~= 'seat' and GetPedInVehicleSeat(veh, -1) ~= PlayerPedId() then return end
    action(veh, tonumber(data.index))
    Hud.push('vc', state(veh))
end)

RegisterNUICallback('vcClose', function(_, cb)
    close()
    cb(1)
end)

local function toggle()
    if open then return close() end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 or IsPauseMenuActive() or Hud.settings.hidden.vcontrols then return end
    open = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    Hud.push('vc', state(veh))
    Hud.send('vcontrols', { open = true })
    CreateThread(function()
        while open do
            local current = GetVehiclePedIsIn(PlayerPedId(), false)
            if current == 0 then break end
            -- keep driving with the panel up, but not looking around with the mouse
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then break end
            Wait(0)
        end
        SetNuiFocusKeepInput(false)
        close()
    end)
    CreateThread(function()
        while open do
            local veh2 = GetVehiclePedIsIn(PlayerPedId(), false)
            if veh2 ~= 0 then Hud.push('vc', state(veh2)) end
            Wait(250)
        end
    end)
end

RegisterCommand(cfg.command, toggle, false)
RegisterKeyMapping(cfg.command, 'Vehicle control panel', 'keyboard', cfg.key)

-- Cruise ends when leaving the vehicle.
CreateThread(function()
    while true do
        if Hud.cruise and GetVehiclePedIsIn(PlayerPedId(), false) ~= Hud.cruise then setCruise(nil, false) end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if open then SetNuiFocus(false, false) end
    if Hud.cruise then setCruise(nil, false) end
end)
