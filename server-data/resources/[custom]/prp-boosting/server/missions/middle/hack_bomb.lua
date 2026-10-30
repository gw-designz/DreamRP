local MissionConfig = {
    hackTriesCooldown = 60,
    trackerConfig = {
        D = {
            pingInterval = 10,
            blipColor = 26,
            dispatchChance = 0,
        },
        C = {
            pingInterval = 8,
            blipColor = 24,
            dispatchChance = 25,
        },
        B = {
            pingInterval = 6,
            blipColor = 46,
            dispatchChance = 50,
        },
        A = {
            pingInterval = 4,
            blipColor = 61,
            dispatchChance = 100,
        },
        S = {
            pingInterval = 2,
            blipColor = 5,
            dispatchChance = 100,
        },
        X = {
            pingInterval = 1,
            blipColor = 59,
            dispatchChance = 100,
        }
    },
    metadata = {
        label = locale("MIDDLE_MISSION_HACK_BOMB_LABEL"),
        autoStart = true,
        genTarget = { 2, 3 },
        isHackMission = true,
    },
    genTargetClasses = {
        D = { 1, 1 },
        C = { 1, 2 },
        B = { 3, 5 },
        A = { 4, 6 },
        S = { 6, 10 },
        X = { 12, 16 },
    },
    prerequisites = {
        --     label = locale("Pendrive"),
        --     type = "ITEM",
        --     value = "boosting_hack_",
        --     addClassItem = true
        -- },
    }
}

local HackMission = {}
HackMission.__index = HackMission
HackMission = setmetatable(HackMission, Mission)

function HackMission:OnStart(stateId, contract, groupId)
    self.addonData.lastTry = nil
    self.addonData.lastPing = 0

    self:SendSMSMessage(locale("MIDDLE_MISSION_HACK_BOMB_START_TEXT"), nil, "BoostWorks")
    local source = bridge.fw.getSrcFromIdentifier(stateId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    local coords = GetEntityCoords(veh)
    if math.random(1, 100) > MissionConfig.trackerConfig[contract.vehicleClass].dispatchChance then
        return
    end
    local title = locale("VEH_STOLEN_TITLE", contract.vehicleModelLabel, contract.vehicleClass)
    local description = locale("MIDDLE_MISSION_HACK_BOMB_PD_ALERT")
    if contract.contractType ~= "boosting" then
        description = locale("MISSION_MISSION_H_VAL_VEH_ALERT")
    end
    local blip = {
        sprite = 326,
        scale = 1.2,
        colour = 1,
        length = 2,
        flash = false,
        text = title
    }
    bridge.dispatch.sendAlert(source, exports["prp-bridge"]:GetPoliceJobs(), coords, {
        title = title,
        description = description,
        code = "10-31A",
    }, blip, false)
end

function HackMission:OnDestroy(stateId, contract, groupId)
    
end

function HackMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
    local currentTime = os.time()
    if not contract then return end
    local pingInterval = MissionConfig.trackerConfig[contract.vehicleClass].pingInterval or 1
    local blipColor = MissionConfig.trackerConfig[contract.vehicleClass].blipColor or 1
    if currentTime - self.addonData.lastPing < pingInterval then
        return
    end

    self.addonData.lastPing = currentTime
    local vehicle = contract.vehEntity
    if not DoesEntityExist(vehicle) then return end

    local sendTable = {
        self.taskId,
        NetworkGetNetworkIdFromEntity(vehicle),
        GetEntityCoords(vehicle),
        contract.vehicleModelLabel,
        pingInterval,
        blipColor
    }

    local policePlayers = exports["prp-bridge"]:GetPoliceOnDuty(true)
    local msg = msgpack.pack_args(sendTable)
    local msgLen = msg:len()
    for src, _ in pairs(policePlayers) do
        TriggerClientEventInternal("prp-boosting:hack:trackerUpdate", tostring(src), msg, msgLen)
    end
    local isLastMissionCargobob = LoadedBoostingContracts[self.contractId].missions[self.taskContractId-1]?.name == "steal_cargobob"
    if not self.bombInitiated and (GetEntitySpeed(vehicle) * 2.2) > 10 and not isLastMissionCargobob then
        self.bombInitiated = true
        self:SendNotificationToMembers("error", locale("MIDDLE_MISSION_HACK_BOMB_WARNING"))
    end
    if self.bombInitiated and (GetEntitySpeed(vehicle) * 2.2) < 10 and not Config.Debug then
        TriggerClientEvent("prp-boosting:explodeVehicle", NetworkGetEntityOwner(vehicle), NetworkGetNetworkIdFromEntity(vehicle))
        self:Fail(true, true)
    end
end

function HackMission:GetMetadata(contract)
    local metadata = lib.table.deepclone(MissionConfig.metadata)
    if contract and contract.vehicleClass then
        metadata.genTarget = MissionConfig.genTargetClasses[contract.vehicleClass] or metadata.genTarget
    end
    return metadata
end

function HackMission:GetPrerequisites(contract)
    local itemName = string.lower(("boosting_hack_%s"):format(contract.vehicleClass))
    local itemLabel = bridge.inv.getItemLabel(itemName)
    return {
        {
            label = itemLabel or locale("Pendrive"),
            type = "ITEM",
            value = itemName,
        },
    }
end


Citizen.CreateThread(function()
    RegisteredMissions["middle_hack_bomb"] = HackMission
end)