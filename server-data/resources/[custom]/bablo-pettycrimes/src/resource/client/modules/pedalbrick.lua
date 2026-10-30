if not Config.Modules.PEDAL_BRICK then return end

local state = {
    busy       = false,
    brickReady = false,
    brickProp  = nil,
}

-- Incremented each time a brick item is used; used to detect expiry of a specific use
local brickUseGeneration = 0

local function isVehicleClassAllowed(vehicle)
    local blacklist = Config.PedalBrick.BlacklistedVehicleClasses
    if not blacklist then return true end

    local vehClass = GetVehicleClass(vehicle)
    for _, blocked in ipairs(blacklist) do
        if vehClass == blocked then return false end
    end
    return true
end

local function isVehicleLocked(vehicle)
    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    return lockStatus == 2 or lockStatus == 3 or lockStatus == 7 or lockStatus == 8
end

local function spawnBrickProp()
    if state.brickProp and DoesEntityExist(state.brickProp) then return end

    local hash = GetHashKey("ng_proc_brick_01a")
    RequestModel(hash)
    local elapsed = 0
    while not HasModelLoaded(hash) and elapsed < 5000 do
        Wait(50)
        elapsed = elapsed + 50
    end

    if not HasModelLoaded(hash) then return end

    local prop = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    local boneIdx = GetPedBoneIndex(cache.ped, 57005)

    AttachEntityToEntity(
        prop, cache.ped, boneIdx,
        0.1, 0.1, 0.0, 30.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(hash)
    state.brickProp = prop
end

local function destroyBrickProp()
    if state.brickProp and DoesEntityExist(state.brickProp) then
        DeleteEntity(state.brickProp)
    end
    state.brickProp = nil
end

local function maybeSendDispatch()
    local roll = math.random(1, 100)
    if roll > Config.PedalBrick.AlertChance then return end

    Dispatch:Send(BuildDispatchData({
        message = Translate("PEDAL_BRICK_DISPATCH"),
        coords  = GetEntityCoords(cache.ped),
        jobs    = { "police", "lspd", "bcso" },
        blip    = {
            sprite = 326,
            color  = 1,
            scale  = 0.8,
            text   = Translate("PEDAL_BRICK_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.PedalBrick.Dispatch))
end

local function watchForCollisionFire(vehicle)
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 8000 do
            if not DoesEntityExist(vehicle) then return end
            if IsEntityOnFire(vehicle) then
                Dispatch:Send(BuildDispatchData({
                    message = Translate("PEDAL_BRICK_FIRE_DISPATCH"),
                    coords  = GetEntityCoords(vehicle),
                    jobs    = { "police", "lspd", "bcso" },
                    blip    = {
                        sprite = 436,
                        color  = 1,
                        scale  = 1.0,
                        text   = Translate("PEDAL_BRICK_FIRE_DISPATCH_BLIP"),
                        flash  = true,
                    },
                }, Config.PedalBrick.FireDispatch))
                return
            end
            Wait(500)
        end
    end)
end

local function runAccelerationLoop(vehicle, durationMs, maxSpeed, accelRate, breakOnCollision)
    local startTime = GetGameTimer()
    local hasMovedFast = false
    local collisionGraceMs = 1500

    while GetGameTimer() - startTime < durationMs do
        if not DoesEntityExist(vehicle) then return end

        local speed = GetEntitySpeed(vehicle)
        local elapsed = GetGameTimer() - startTime

        if speed > 5.0 then hasMovedFast = true end

        if speed < maxSpeed then
            SetVehicleForwardSpeed(vehicle, speed + accelRate)
        end

        if breakOnCollision and hasMovedFast and elapsed > collisionGraceMs then
            if HasEntityCollidedWithAnything(vehicle) then
                SetVehicleEngineOn(vehicle, false, false, false)
                SetVehicleEngineHealth(vehicle, 0.0)
                SetVehicleUndriveable(vehicle, true)
                Entity(vehicle).state:set("pedalBricked", false, true)
                watchForCollisionFire(vehicle)
                return
            end
        end

        Wait(50)
    end

    if DoesEntityExist(vehicle) then
        Entity(vehicle).state:set("pedalBricked", false, true)
    end
end

local function performPedalBrick(vehicle)
    if state.busy then return end

    if not Framework:canDoAction("PEDAL_BRICK") then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if Main:getPoliceCount() < Config.PedalBrick.PoliceRequired then
        Framework:Notify(Translate("NOT_ENOUGH_POLICE"))
        return
    end

    if not isVehicleClassAllowed(vehicle) then
        Framework:Notify(Translate("PEDAL_BRICK_CANT_USE"))
        return
    end

    if isVehicleLocked(vehicle) then
        Framework:Notify(Translate("PEDAL_BRICK_LOCKED"))
        return
    end

    if Entity(vehicle).state.pedalBricked then
        Framework:Notify(Translate("PEDAL_BRICK_ALREADY"))
        return
    end

    local driver = GetPedInVehicleSeat(vehicle, -1)
    if driver and driver ~= 0 and DoesEntityExist(driver) then
        Framework:Notify(Translate("PEDAL_BRICK_OCCUPIED"))
        return
    end

    state.busy = true

    local serverResult = TriggerServerCallback({
        eventName = eventName .. "server:pedalBrickUse",
        args      = {},
    })

    if not serverResult or not serverResult.status then
        state.busy = false
        if serverResult and serverResult.message then
            Framework:Notify(Translate(serverResult.message))
        end
        return
    end

    TaskTurnPedToFaceEntity(cache.ped, vehicle, 500)
    Wait(500)

    SetVehicleDoorOpen(vehicle, 0, false, true)
    Wait(400)

    -- Schedule brick prop cleanup after placement starts
    Citizen.CreateThread(function()
        Wait(2000)
        destroyBrickProp()
    end)

    local placed = lib.progressBar({
        duration     = 4000,
        label        = Translate("PEDAL_BRICK_PLACING"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
        anim         = { dict = "mp_car_bomb", clip = "car_bomb_mechanic", flag = 1 },
    })

    ClearPedTasks(cache.ped)
    destroyBrickProp()

    if not placed then
        SetVehicleDoorShut(vehicle, 0, false)
        TriggerServerEvent(eventName .. "server:pedalBrickRefund")
        state.busy = false
        return
    end

    SetVehicleDoorShut(vehicle, 0, false)
    state.brickReady = false

    Entity(vehicle).state:set("pedalBricked", true, true)

    maybeSendDispatch()

    Framework:Notify(Translate("PEDAL_BRICK_PLACED"))

    local durationMs    = (Config.PedalBrick.AccelDuration or 15) * 1000
    local breakOnCollision = Config.PedalBrick.BreakOnCollision ~= false
    local maxSpeed      = Config.PedalBrick.MaxSpeed  or 25.0
    local accelRate     = Config.PedalBrick.AccelRate or 0.5

    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleHandbrake(vehicle, false)
    SetVehicleBrakeLights(vehicle, false)

    Citizen.CreateThread(function()
        runAccelerationLoop(vehicle, durationMs, maxSpeed, accelRate, breakOnCollision)
    end)

    TriggerServerEvent(eventName .. "server:pedalBrickDone")
    state.busy = false
end

RegisterNetEvent(eventName .. "client:useBrickItem")
AddEventHandler(eventName .. "client:useBrickItem", function()
    brickUseGeneration = brickUseGeneration + 1
    local thisGeneration = brickUseGeneration

    state.brickReady = true
    spawnBrickProp()
    Framework:Notify(Translate("PEDAL_BRICK_READY"))

    Citizen.SetTimeout(30000, function()
        if state.brickReady and brickUseGeneration == thisGeneration then
            state.brickReady = false
            destroyBrickProp()
            Framework:Notify(Translate("PEDAL_BRICK_EXPIRED"))
        end
    end)
end)

Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(5000)

    if not Target or not Target.addGlobalVehicle then
        Trace("PedalBrick: Target:addGlobalVehicle not available")
        return
    end

    Target:addGlobalVehicle({
        label    = Translate("PEDAL_BRICK_LABEL"),
        icon     = "fas fa-cube",
        distance = 2.5,
        action   = performPedalBrick,
        canInteract = function(vehicle)
            if state.busy or not state.brickReady then return false end
            if not vehicle or not DoesEntityExist(vehicle) then return false end
            if IsPedInAnyVehicle(cache.ped, false) then return false end
            if not isVehicleClassAllowed(vehicle) then return false end
            if isVehicleLocked(vehicle) then return false end
            if Entity(vehicle).state.pedalBricked then return false end

            local driver = GetPedInVehicleSeat(vehicle, -1)
            if driver and driver ~= 0 and DoesEntityExist(driver) then return false end

            return true
        end,
    })

    Trace("PedalBrick: Global vehicle target registered")
end)
