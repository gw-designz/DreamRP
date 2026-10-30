Main = { vehicles = {} }

local CrimeModuleKey = {
    MUGGING             = "Mugging",
    MAILBOX_ROBBERY     = "Mailboxes",
    PARKING_METER_ROBBERY = "ParkingMeters",
    PARCEL_THEFT        = "Parcels",
    PICKPOCKETING       = "PickPocketing",
    SMASH_N_GRAB        = "SmashnGrab",
    VENDING_MACHINE     = "VendingMachines",
    ATM_ROBBERY         = "AtmRobbery",
    TIRE_SLASH          = "TireSlash",
    PEDAL_BRICK         = "PedalBrick",
    CASH_REGISTER_ROBBERY = "CashRegisters",
    STORE_SHELVES       = "StoreShelves",
}

local function normalizeString(value)
    if type(value) ~= "string" then return nil end
    local trimmed = value:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return nil end
    return trimmed:lower()
end

function Main:isJobBlacklisted(crimeKey)
    local moduleName = CrimeModuleKey[crimeKey]
    if not moduleName then return false end

    local moduleConfig = Config[moduleName]
    if not moduleConfig then return false end

    local blacklist = moduleConfig.BlacklistedJobs
    if not blacklist or #blacklist == 0 then return false end

    if not Framework or type(Framework.getPlayerJob) ~= "function" then
        return false
    end

    local ok, jobResult = pcall(function()
        return Framework:getPlayerJob()
    end)
    if not ok then return false end

    local playerJob = normalizeString(jobResult)
    if not playerJob then return false end

    for _, entry in ipairs(blacklist) do
        if normalizeString(entry) == playerJob then
            return true
        end
    end

    return false
end

function Main:spawnLocalObject(modelName, coords, heading)
    local obj = CreateObject(GetHashKey(modelName), coords.x, coords.y, coords.z, false, true, false)
    if heading then
        SetEntityHeading(obj, heading)
    end
    return obj
end

function Main:hint(message)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function Main:selectRandomItem(itemTable)
    local totalWeight = 0
    for _, item in pairs(itemTable) do
        totalWeight = totalWeight + item.chance
    end

    local roll = math.random(1, totalWeight)
    local cumulative = 0
    for _, item in pairs(itemTable) do
        cumulative = cumulative + item.chance
        if roll <= cumulative then
            return item
        end
    end
end

function Main:gotoPlace(ped, coords, speed, timeout, slideSpeed, blendDuration)
    TaskGoStraightToCoord(ped, coords.x, coords.y, coords.z, speed, timeout, slideSpeed, blendDuration)

    local cancelKeys = { 32, 33, 34, 35 }

    while true do
        local status = GetScriptTaskStatus(ped, 2106541073)
        if status == 7 then break end

        if ped == PlayerPedId() then
            for _, key in ipairs(cancelKeys) do
                if IsControlJustPressed(0, key) then
                    ClearPedTasks(ped)
                    return false
                end
            end
        end

        Citizen.Wait(0)
    end

    return true
end

function Main:getPoliceCount()
    local result = TriggerServerCallback({
        eventName = eventName .. "server:getEmployeesCount",
        args = { "police" }
    })
    if result and result.status then
        return result.count
    end
    return 0
end

function Main:setEntityStateBag(entity, stateData)
    if not entity or not DoesEntityExist(entity) then return end

    local entityState = Entity(entity).state
    for key, value in pairs(stateData) do
        entityState:set(key, value, true)
    end

    TriggerServerEvent(
        eventName .. "server:setEntityStateBag",
        VehToNet(entity),
        stateData
    )
end

function Main:loadParticle(assetName)
    RequestNamedPtfxAsset(assetName)
    while not HasNamedPtfxAssetLoaded(assetName) do
        Citizen.Wait(150)
    end
    UseParticleFxAsset(assetName)
end

function Main:loadanimDict(dict)
    if not DoesAnimDictExist(dict) then
        Trace("message from bablo-pettycrimes " .. dict .. " is not a valid animation dict!")
        return
    end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

function Main:playAnimation(animData)
    local isPlaying = IsEntityPlayingAnim(animData.ped, animData.dict, animData.lib, 3)
    if isPlaying then return end

    if not animData.flag then animData.flag = 49 end
    if not animData.time then animData.time = -1 end

    self:loadanimDict(animData.dict)

    TaskPlayAnim(
        animData.ped, animData.dict, animData.lib,
        2.0, -1.0, animData.time, animData.flag,
        0, 0, 0, 0
    )
end

function Main:playAdvancedAnimation(ped, dict, anim, options)
    if dict then
        Citizen.CreateThread(function()
            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do
                Citizen.Wait(100)
            end

            if options == nil then
                TaskPlayAnim(ped, dict, anim, 1.0, -1.0, 1.0, 0, 0, 0, 0, 0)
            else
                local speed          = options.speed          ~= nil and options.speed          or 1.0
                local speedMult      = options.speedMultiplier ~= nil and options.speedMultiplier or -1.0
                local duration       = options.duration        ~= nil and options.duration        or 1.0
                local flag           = options.flag            ~= nil and options.flag            or 0
                local playbackRate   = options.playbackRate    ~= nil and options.playbackRate    or 0

                TaskPlayAnim(ped, dict, anim, speed, speedMult, duration, flag, playbackRate, 0, 0, 0)
            end

            RemoveAnimDict(dict)
        end)
    else
        TaskStartScenarioInPlace(ped, anim, 0, true)
    end
end

function Main:isVehicleEmpty(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then return end

    local seatCount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2

    for seat = -1, seatCount do
        if DoesEntityExist(GetPedInVehicleSeat(vehicle, seat)) then
            return false
        end
    end

    return true
end

function Main:getVehicleSpawnName(vehicle)
    if DoesEntityExist(vehicle) then
        return GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    end
    return nil
end
