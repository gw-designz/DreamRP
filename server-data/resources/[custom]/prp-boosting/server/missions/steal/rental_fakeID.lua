local takenLocations = {}
local MissionConfig = {
    metadata = {
        label = locale("FAKE_ID_MISSION_LABEL"),
        startable = true,
        isCheckpoint = true,
    },
    locations = {
        {
            coords = vector4(-44.426, -1680.356, 29.426, 237.797),
            pedCoords = vector4(-51.841, -1684.283, 28.488, 149.564),
            locationLabel = locale("RENTAL_LABEL", "Mosley"),
        }
    },
    prerequisites = {
        {
            label = locale("FAKE_ID"),
            type = "ITEM",
            value = "fake_id",
        },
    },
}

local StealMission = {}
StealMission.__index = StealMission
StealMission = setmetatable(StealMission, Mission)

function generateName2()
    return Config.Firstnames[math.random(1, #Config.Firstnames)] .. " " .. Config.Lastnames[math.random(1, #Config.Lastnames)]
end

function generateName()
    return generateName2()
end

Citizen.CreateThread(function()
    bridge.fw.registerItemUse("empty_fake_id", function(src, item)
        local stateId = bridge.fw.getIdentifier(src)
        if not stateId then return end
        bridge.inv.removeItem(src, "empty_fake_id", 1)
        local data = lib.callback.await("prp-boosting:getFakeIdData", src)
    
        if not data then
            local success = bridge.inv.giveItem(src, "empty_fake_id", 1)
            return
        end

        if not data.name or string.len(data.name) < 3 then
            local success = bridge.inv.giveItem(src, "empty_fake_id", 1)
            return
        end

        if data.stateId == nil then
            local success = bridge.inv.giveItem(src, "empty_fake_id", 1)
            return
        end
        
        if data.gender == nil then
            local success = bridge.inv.giveItem(src, "empty_fake_id", 1)
            return
        end

        local metadata = {
            name = data.name,
            dob = os.time{ year = math.random(1960, 2004), month = math.random(1, 12), day = math.random(1, 28) },
            stateId = data.stateId,
            gender = data.gender,
        }

        bridge.inv.giveItem(src, "fake_id", 1, metadata)
    end)
end)

function StealMission:OnStart(stateId, contract, groupId)
    local locations = {}
    for k, v in pairs(MissionConfig.locations) do
        if not takenLocations[k] then
            table.insert(locations, k)
        end
    end
    if #locations == 0 then
        return self:Cancel()
    end

    local location = locations[math.random(1, #locations)]
    takenLocations[location] = true
    self.location = location
    self.garage = MissionConfig.locations[location]
    self.targetName = generateName()

    self.pedId = self:CreateLocalPed(`cs_carbuyer`, self.garage.pedCoords, true, true);
    self:AddLocalObjectTarget(self.pedId, "talk_rental", {
        label = locale("TALK_TO_AGENT"),
        icon = "fas fa-person",
        event = "prp-boosting:rental_fakeId:talk",
    })
    self:SendEventToMembers("prp-boosting:setMissionBlip", "rental", locale("VEHICLE_RENTAL"), self.garage.pedCoords.xyz, 500, 3, true)

    local locationLabel = MissionConfig.locations[location].locationLabel
    self:SendSMSMessage(locale("FAKE_ID_MISSION_START_TEXT", locationLabel, self.targetName), nil, "BoostWorks")
end

function StealMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        takenLocations[self.location] = nil
    end
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if not LoadedBoostingContracts[self.contractId].vehEntity and tickId % 5 == 0 and self.garage?.coords and self:IsAnyMemberCloseToCoords(vector3(self.garage.coords.x, self.garage.coords.y, self.garage.coords.z), 250.0) then
        self:SpawnContractVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.garage.coords)
        local vehEntity = LoadedBoostingContracts[self.contractId].vehEntity
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
        SetVehicleDoorsLocked(vehEntity, 2)
        Entity(vehEntity).state.Locked = true
        Entity(vehEntity).state.DisableLockpick = true
    end
    if LoadedBoostingContracts[self.contractId].vehEntity then
        local veh = LoadedBoostingContracts[self.contractId].vehEntity
        if GetIsVehicleEngineRunning(veh) then
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

RegisterNetEvent("prp-boosting:rental_fakeId:talk", function(missionId, objectId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = Missions[missionId]
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId then
        local contract = LoadedBoostingContracts[mission.contractId]
        local options = {};
        local prevModels = {contract.vehicleModel}; 
        for i = 1, 4 do
            local vehData = GetVehicleFromClass(contract.vehicleClass, prevModels)
            if not vehData then break end
            table.insert(prevModels, vehData.modelName)
            table.insert(options, {
                id = i,
                text = vehData.label,
                description = locale("DIALOG_RENT_CAR"),
                vehName = vehData.modelName,
            })
        end

        local correctIndex = math.random(1, #options)
        local correctVehData = Config.Vehicles[contract.vehicleModel]
        options[correctIndex].text = correctVehData.label
        options[correctIndex].vehName = contract.vehicleModel

        local answerIndex = mission:StartLocalPedDialog(source, mission.pedId, locale("RENTAL_AGENT"), locale("RENTAL_PED_DIALOG_TITLE"), locale("RENTAL_PED_DIALOG_DESCRIPTION"), options)
        if answerIndex == nil then return end

        local count = 0
        local invItems = bridge.inv.getInventoryItems(source)
        for k,v in pairs(invItems) do
            if v.name == "fake_id" and v.metadata and v.metadata.name == mission.targetName then
                count = count + v.count
            end
        end
        local hasCorrectFakeId = count > 0;
        if answerIndex ~= correctIndex or not hasCorrectFakeId then
            mission:SendNotificationToMembers("error", locale("FAKE_ID_WRONG_ID"))
            return
        end
        
        local vehEntity = LoadedBoostingContracts[mission.contractId].vehEntity
        mission:SendNotificationToMembers("success", locale("FAKE_ID_RENTAL_SUCCESS"))
        bridge.vkeys.give(source, vehEntity)
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["steal_rental_fakeId"] = StealMission
end)