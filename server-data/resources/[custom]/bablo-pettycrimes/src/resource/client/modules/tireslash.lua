if not Config.Modules.TIRE_SLASH then return end

local state = { busy = false }

local WHEEL_BONES = {
    { bone = "wheel_lf",  index = 0 },
    { bone = "wheel_rf",  index = 1 },
    { bone = "wheel_lm1", index = 2 },
    { bone = "wheel_rm1", index = 3 },
    { bone = "wheel_lr",  index = 4 },
    { bone = "wheel_rr",  index = 5 },
}

local function getNearestWheelIndex(vehicle)
    local pedCoords = GetEntityCoords(cache.ped)
    local nearestIndex = nil
    local shortestDist = 999.0

    for _, wheel in ipairs(WHEEL_BONES) do
        local boneIdx = GetEntityBoneIndexByName(vehicle, wheel.bone)
        if boneIdx ~= -1 then
            local bonePos = GetWorldPositionOfEntityBone(vehicle, boneIdx)
            local dist = #(pedCoords - bonePos)
            if dist < shortestDist then
                shortestDist = dist
                nearestIndex = wheel.index
            end
        end
    end

    return nearestIndex
end

local function hasAllowedWeapon()
    local allowedWeapons = Config.TireSlash.AllowedWeapons
    if not allowedWeapons then return false end

    local currentWeapon = GetSelectedPedWeapon(cache.ped)
    for _, weaponName in ipairs(allowedWeapons) do
        if currentWeapon == GetHashKey(weaponName) then return true end
    end
    return false
end

local function isVehicleClassAllowed(vehicle)
    local blacklist = Config.TireSlash.BlacklistedVehicleClasses
    if not blacklist then return true end

    local vehClass = GetVehicleClass(vehicle)
    for _, blockedClass in ipairs(blacklist) do
        if vehClass == blockedClass then return false end
    end
    return true
end

local function getVehicleTireSlashCount(vehicle)
    return Entity(vehicle).state.tireSlashCount or 0
end

local function setVehicleTireSlashCount(vehicle, count)
    Entity(vehicle).state:set("tireSlashCount", count, true)
end

local function isTireAlreadySlashed(vehicle, tireIndex)
    return Entity(vehicle).state["tireSlashed_" .. tireIndex] == true
end

local function markTireSlashed(vehicle, tireIndex)
    Entity(vehicle).state:set("tireSlashed_" .. tireIndex, true, true)
    setVehicleTireSlashCount(vehicle, getVehicleTireSlashCount(vehicle) + 1)
end

local function maybeSendDispatch()
    local roll = math.random(1, 100)
    if roll > Config.TireSlash.AlertChance then return end

    Dispatch:Send(BuildDispatchData({
        message = Translate("TIRE_SLASH_DISPATCH"),
        coords  = GetEntityCoords(cache.ped),
        jobs    = { "police", "lspd", "bcso" },
        blip    = {
            sprite = 326,
            color  = 1,
            scale  = 0.8,
            text   = Translate("TIRE_SLASH_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.TireSlash.Dispatch))
end

local function notifyDriver(vehicle, tireIndex)
    local driver = GetPedInVehicleSeat(vehicle, -1)
    if not driver or driver == 0 then return end
    if not IsEntityAPed(driver) then return end

    local serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(driver))
    if serverId and serverId > 0 then
        TriggerServerEvent(eventName .. "server:tireSlashSync", serverId, tireIndex)
    end
end

local function performTireSlash(vehicle)
    if state.busy then return end

    if not Framework:canDoAction("TIRE_SLASH") then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if not hasAllowedWeapon() then
        Framework:Notify(Translate("TIRE_SLASH_NO_WEAPON"))
        return
    end

    if not isVehicleClassAllowed(vehicle) then
        Framework:Notify(Translate("TIRE_SLASH_CANT_SLASH"))
        return
    end

    if Main:getPoliceCount() < Config.TireSlash.PoliceRequired then
        Framework:Notify(Translate("NOT_ENOUGH_POLICE"))
        return
    end

    local tireIndex = getNearestWheelIndex(vehicle)
    if tireIndex == nil then
        Framework:Notify(Translate("TIRE_SLASH_CANT_SLASH"))
        return
    end

    if IsVehicleTyreBurst(vehicle, tireIndex, false) or isTireAlreadySlashed(vehicle, tireIndex) then
        Framework:Notify(Translate("TIRE_SLASH_ALREADY_FLAT"))
        return
    end

    local maxTires = Config.TireSlash.MaxTiresPerVehicle or 4
    if getVehicleTireSlashCount(vehicle) >= maxTires then
        Framework:Notify(Translate("TIRE_SLASH_MAX_REACHED"))
        return
    end

    state.busy = true

    TaskTurnPedToFaceEntity(cache.ped, vehicle, 500)
    Wait(500)

    local animDict = "melee@knife@streamed_core_fps"
    local animClip = "ground_attack_on_spot"
    Main:loadanimDict(animDict)

    local animDuration = GetAnimDuration(animDict, animClip)
    local halfDurationMs = math.floor((animDuration / 2) * 1000)

    TaskPlayAnim(cache.ped, animDict, animClip, 8.0, -8.0, -1, 15, 1.0, false, false, false)
    Wait(halfDurationMs)

    SetVehicleTyreBurst(vehicle, tireIndex, false, 1000.0)
    markTireSlashed(vehicle, tireIndex)
    notifyDriver(vehicle, tireIndex)

    local slashCount = getVehicleTireSlashCount(vehicle)
    local alertThreshold = Config.TireSlash.AlertOnSlash or 2
    if slashCount >= alertThreshold then
        maybeSendDispatch()
    end

    TriggerServerEvent(eventName .. "server:tireSlashDone")

    Wait(halfDurationMs)
    ClearPedTasks(cache.ped)
    RemoveAnimDict(animDict)

    state.busy = false
end

local function canInteractWithVehicle(vehicle)
    if state.busy then return false end
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    if IsPedInAnyVehicle(cache.ped, false) then return false end
    if not hasAllowedWeapon() then return false end
    if not isVehicleClassAllowed(vehicle) then return false end

    local maxTires = Config.TireSlash.MaxTiresPerVehicle or 4
    if getVehicleTireSlashCount(vehicle) >= maxTires then return false end

    return true
end

Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(5000)

    if not Target or not Target.addGlobalVehicle then
        Trace("TireSlash: Target:addGlobalVehicle not available")
        return
    end

    Target:addGlobalVehicle({
        label       = Translate("TIRE_SLASH_LABEL"),
        icon        = "fas fa-cut",
        distance    = 1.5,
        action      = performTireSlash,
        canInteract = canInteractWithVehicle,
    })

    Trace("TireSlash: Global vehicle target registered")
end)

RegisterNetEvent(eventName .. "client:tireSlashSync")
AddEventHandler(eventName .. "client:tireSlashSync", function(tireIndex)
    Framework:Notify(Translate("TIRE_SLASH_VICTIM_ALERT"))

    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle and vehicle ~= 0 then
        SetVehicleTyreBurst(vehicle, tireIndex, false, 1000.0)
    end
end)
