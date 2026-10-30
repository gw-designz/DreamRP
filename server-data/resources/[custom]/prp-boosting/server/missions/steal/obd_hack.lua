
local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    metadata = {
        label = locale("OBD_HACK_MISSION_LABEL"),
        startable = true,
        isCheckpoint = true,
    },
    hackTriesCooldown = 30,
    minigameConfig = {
        global = {
            ["gtHero"] = {
                dotCount =  32,
                speed =  0.0035,
            },
            ["circleRun"] = {
                time =  20000,
                circleSpeed =  2*math.pi / 5000,
                minDist =  math.pi / 8,
            },
            ["spaceInvaders"] = {
                enemyCount =  45,
                enemyInterval =  500,
                enemySpeed =  0.3,
                enemyManoeuvre =  true,
            },
            ["circleColors"] = {
                attackCount =  24,
                speed =  0.3,
            }
        },
        D = {
        },
        C = {
        },
        B = {

        },
        A = {

        },
        S = {

        },
        X = {

        }

    },
    prerequisites = {
        {
            label = locale("Lockpick"),
            type = "ITEM",
            value = "lockpick",
        },
        {
            label = locale("OBD_CONNECTOR"),
            type = "ITEM",
            value = "boosting_obd_",
            addClassItem = true
        },
    },
    useSharedLocations = "normal"
}

local StealMission = {}
StealMission.__index = StealMission
StealMission = setmetatable(StealMission, Mission)

function StealMission:OnStart(stateId, contract, groupId)
    local locations = {}
    local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
    for k, v in pairs(stealLocations) do
        if not v.taken then
            table.insert(locations, k)
        end
    end
    if #locations == 0 then
        return self:Cancel()
    end
    local location = locations[math.random(1, #locations)]
    self.location = location
    self.locationCoords = stealLocations[location].coords
    self.npcLocations = stealLocations[location].npcLocations
    stealLocations[location].taken = self.taskId
    self.radius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    self.center = self.locationCoords.xyz + (unitVector * math.sqrt(math.random()) * self.radius)
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", locale("SEARCH_AREA"), self.center.xyz, self.radius, 225, 3)
    local locationLabel = stealLocations[location].locationLabel
    self:SendSMSMessage(locale("OBD_HACK_MISSION_START_TEXT", locationLabel), nil, "BoostWorks")
    self.enableTick = true

    self.hackProgress = 0
end

function StealMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        stealLocations[self.location].taken = nil
    end
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if not LoadedBoostingContracts[self.contractId].vehEntity and tickId % 5 == 0 and self.locationCoords and self:IsAnyMemberCloseToCoords(vector3(self.locationCoords.x, self.locationCoords.y, self.locationCoords.z), 250.0) then
        self:SpawnContractVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords)
        local vehEntity = LoadedBoostingContracts[self.contractId].vehEntity
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
        SetVehicleDoorsLocked(vehEntity, 2)
        Entity(vehEntity).state.Locked = true
        Entity(vehEntity).state.disableInteriorLockpick = true
        Entity(vehEntity).state.DisableLockpick = true
                TriggerClientEvent("prp-boosting:setUndriveable", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity), true)
        self:NpcCheck(self.npcLocations)
    end
    if LoadedBoostingContracts[self.contractId].vehEntity then
        local veh = LoadedBoostingContracts[self.contractId].vehEntity
        if (self.hackProgress or 0) >= 4 and GetIsVehicleEngineRunning(veh) then
            self:AddProgress(1)
        end
    end
end

function StealMission:GetMetadata()
    return MissionConfig.metadata
end

function StealMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

exports("IsInsideObdVehicle", function(stateId)
    local mission = GetActiveMissionByStateId(stateId)
    local source = bridge.fw.getSrcFromIdentifier(stateId)

    local ped = GetPlayerPed(source)
    if not DoesEntityExist(ped) then
        return { status = false, message = locale("UNHANDLED_EXCEPTION") }
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(vehicle) then
        return { status = false, message = locale("NO_VEHICLE_FOUND") }
    end

    if not mission then 
        return { status = false, message = locale("NO_OBD_MODULE") }
    end

    local contract = LoadedBoostingContracts[mission.contractId]
    if not contract then
        return { status = false, message = locale("NO_OBD_MODULE") }
    end

    if mission.missionName ~= "steal_obd_hack" then
        return { status = false, message = locale("NO_OBD_MODULE") }
    end

    if vehicle ~= contract.vehEntity then 
        return { status = false, message = locale("NO_OBD_MODULE") }
    end

    return { status = true, missionProgress = mission.hackProgress }
end)

local commandForProgress = {
    ecu_flash = 0,
    ecu_immo = 1,
    key_register = 2,
    key_save = 3,
}

local successMessages = {
    ecu_flash = locale("ECU_FLASHED_SUCCESS"),
    ecu_immo = locale("IMMO_PASSED_SUCCESS"),
    key_register = locale("KEY_REGISTERED_SUCCESS"),
    key_save = locale("KEY_SAVED_SUCCESS"),
}

exports("RunOBDCommand", function(stateId, command, classList)
    local mission = GetActiveMissionByStateId(stateId)
    local source = bridge.fw.getSrcFromIdentifier(stateId)

    local ped = GetPlayerPed(source)
    if not DoesEntityExist(ped) then
        return { status = false, message = locale("UNHANDLED_EXCEPTION") }
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(vehicle) then
        return { status = false, message = locale("NO_VEHICLE_FOUND") }
    end

    if not mission then 
        return { status = false, message = locale("NO_OBD_MODULE") }
    end

    local contract = LoadedBoostingContracts[mission.contractId]
    if not contract then
        return { status = false, message = locale("NO_OBD_MODULE") }
    end

    if mission.missionName ~= "steal_obd_hack" then
        return { status = false, message = locale("NO_OBD_MODULE") }
    end

    if vehicle ~= contract.vehEntity then 
        return { status = false, message = locale("NO_OBD_MODULE") }
    end

    local class = contract.vehicleClass
    local found = false
    for i = 1, #classList do
        if class:upper() == classList[i]:upper() then
            found = true
            break
        end
    end

    if not found then
        return { status = false, message = locale("DEVICE_INCOMPATIBLE") }
    end

    local progress = commandForProgress[command]
    if not progress then
        return { status = false, message = locale("INVALID_COMMAND") }
    end
    
    if progress == mission.hackProgress then
        if mission.addonData.lastTry and os.time() - mission.addonData.lastTry < MissionConfig.hackTriesCooldown then
            mission:Fail(true, true)
            Citizen.SetTimeout(15000, function()
                if DoesEntityExist(vehicle) then
                    DeleteEntity(vehicle)
                end
            end)

            return {status = false, message = locale("ECU_BRICKED")}
        end

        local minigames = {}
        for k, v in pairs(MissionConfig.minigameConfig) do
            if k == "global" or k == class:upper() then
                for minigame, options in pairs(v) do
                    minigames[#minigames + 1] = { minigame, options }
                end
            end
        end

        local minigame = minigames[math.random(1, #minigames)]
        local minigameName = minigame[1]
        local minigameOptions = MissionConfig.minigameConfig[class:upper()][minigameName] or minigame[2]

        mission.addonData.lastTry = os.time()
        local minigameStatus = lib.callback.await("prp-boosting:playMinigame", source, minigameName, minigameOptions)
        if minigameStatus == true then
            mission.hackProgress = mission.hackProgress + 1
            mission.addonData.lastTry = nil

            if command == "key_save" then
                Entity(vehicle).state.disableInteriorLockpick = false
                Entity(vehicle).state.DisableLockpick = false
                TriggerClientEvent("prp-boosting:setUndriveable", NetworkGetEntityOwner(vehicle), NetworkGetNetworkIdFromEntity(vehicle), false)
                bridge.vkeys.give(source, vehicle)
            end

            return { status = true, message = successMessages[command] }
        else
            return {status = false, message = locale("OBD_HACK_FAILED", MissionConfig.hackTriesCooldown)};
        end
    elseif progress < mission.hackProgress then
        return { status = false, message = locale("COMMAND_ALREADY_EXECUTED") }
    else
        return { status = false, message = locale("INVALID_COMMAND") }
    end
end)

local function isInsideOBDVehicle(src)
    local stateId = bridge.fw.getIdentifier(src)
    local mission = GetActiveMissionByStateId(stateId)

    local ped = GetPlayerPed(src)
    if not DoesEntityExist(ped) then
        bridge.fw.notify(src, 'error', locale("UNHANDLED_EXCEPTION"))
        return false
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(vehicle) then
        bridge.fw.notify(src, 'error', locale("NO_VEHICLE_FOUND"))
        return false
    end

    if not mission then
        bridge.fw.notify(src, 'error', locale("NO_OBD_MODULE"))
        return false
    end

    local contract = LoadedBoostingContracts[mission.contractId]
    if not contract then
        bridge.fw.notify(src, 'error', locale("NO_OBD_MODULE"))
        return false
    end

    if mission.missionName ~= "steal_obd_hack" then
        bridge.fw.notify(src, 'error', locale("NO_OBD_MODULE"))
        return false
    end

    if vehicle ~= contract.vehEntity then
        bridge.fw.notify(src, 'error', locale("NO_OBD_MODULE"))
        return false
    end

    return true
end

Citizen.CreateThread(function()
    RegisteredMissions["steal_obd_hack"] = StealMission

    for k,v in pairs(Config.UnlockDrops) do
        local itemName = string.format("boosting_obd_%s", k:lower())
        bridge.fw.registerItemUse(itemName, function(src, item)
            if not isInsideOBDVehicle(src) then
                return
            end
            TriggerClientEvent("prp-boosting:useObdModule", src, k)
        end)
    end
end)

RegisterServerEvent("prp-boosting:runOBDCommand", function(class, command)
    if not class or not command then
        return
    end
    local src = source
    local stateId = bridge.fw.getIdentifier(src)
    local mission = GetActiveMissionByStateId(stateId)

    local ped = GetPlayerPed(src)
    if not DoesEntityExist(ped) then
        bridge.fw.notify(src, 'error', locale("UNHANDLED_EXCEPTION"))
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(vehicle) then
        bridge.fw.notify(src, 'error', locale("NO_VEHICLE_FOUND"))
        return
    end

    if not mission then
        bridge.fw.notify(src, 'error', locale("NO_OBD_MODULE"))
        return
    end

    local contract = LoadedBoostingContracts[mission.contractId]
    if not contract then
        bridge.fw.notify(src, 'error', locale("NO_OBD_MODULE"))
        return
    end

    if mission.missionName ~= "steal_obd_hack" then
        bridge.fw.notify(src, 'error', locale("NO_OBD_MODULE"))
        return
    end

    if vehicle ~= contract.vehEntity then 
        bridge.fw.notify(src, 'error', locale("NO_OBD_MODULE"))
        return
    end

    local contractClass = contract.vehicleClass

    if class ~= contractClass then
        bridge.fw.notify(src, 'error', locale("DEVICE_INCOMPATIBLE"))
        return
    end

    local progress = commandForProgress[command]
    if not progress then
        bridge.fw.notify(src, 'error', locale("INVALID_COMMAND"))
        return
    end

    if progress == mission.hackProgress then
        if mission.addonData.lastTry and os.time() - mission.addonData.lastTry < MissionConfig.hackTriesCooldown then
            mission:Fail(true, true)
            Citizen.SetTimeout(15000, function()
                if DoesEntityExist(vehicle) then
                    DeleteEntity(vehicle)
                end
            end)

            bridge.fw.notify(src, 'error', locale("ECU_BRICKED"))
            return
        end

        local minigames = {}
        for k, v in pairs(MissionConfig.minigameConfig) do
            if k == "global" or k == class:upper() then
                for minigame, options in pairs(v) do
                    minigames[#minigames + 1] = { minigame, options }
                end
            end
        end

        local minigame = minigames[math.random(1, #minigames)]
        local minigameName = minigame[1]
        local minigameOptions = MissionConfig.minigameConfig[class:upper()][minigameName] or minigame[2]

        mission.addonData.lastTry = os.time()
        local minigameStatus = lib.callback.await("prp-boosting:playMinigame", src, minigameName, minigameOptions)
        if Config.Debug then
            minigameStatus = true
        end
        if minigameStatus == true then
            mission.hackProgress = mission.hackProgress + 1
            mission.addonData.lastTry = nil

            if command == "key_save" then
                Entity(vehicle).state.disableInteriorLockpick = false
                Entity(vehicle).state.DisableLockpick = false
                TriggerClientEvent("prp-boosting:setUndriveable", NetworkGetEntityOwner(vehicle), NetworkGetNetworkIdFromEntity(vehicle), false)
                bridge.vkeys.give(src, vehicle)
            end
            bridge.fw.notify(src, 'success', successMessages[command])
            return
        else
            bridge.fw.notify(src, 'error', locale("OBD_HACK_FAILED", MissionConfig.hackTriesCooldown))
            return
        end
    elseif progress < mission.hackProgress then
        bridge.fw.notify(src, 'error', locale("COMMAND_ALREADY_EXECUTED"))
        return
    else
        bridge.fw.notify(src, 'error', locale("INVALID_COMMAND"))
        return
    end
end)
