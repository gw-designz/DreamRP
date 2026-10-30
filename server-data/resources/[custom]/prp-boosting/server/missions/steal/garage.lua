local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    garages = {
        {
            model = `prop_gar_door_01`,
            coords = vec3(-1067.0, -1665.6, 5.0),
            vehCoords = vec4(-1064.1, -1663.4, 3.2, 125.8),
            locationLabel = "the Vespucci Beach",
        },
        {
            model = `prop_com_gar_door_01`,
            coords = vec3(254.7,2596.3,45.6),
            vehCoords = vector4(258.603, 2589.199, 44.328, 10.515),
            locationLabel = "the Sandy Repair Garage",
        },
        {
            model = `prop_gar_door_04`,
            coords = vec3(777.0,-1867.4,33.0),
            vehCoords = vector4(772.053, -1866.794, 28.756, 266.569),
            locationLabel = "Popular Street",
        },
        {
            model = `prop_gar_door_04`,
            coords = vec3(130.4,-1054.0,28.2),
            vehCoords = vector4(135.143, -1051.058, 28.531, 0.0),
            locationLabel = "Elgin Avenue"
        },
        {
            model = `prop_gar_door_04`,
            coords = vec3(949.4,-1698.1,33.8),
            vehCoords = vector4(946.526, -1698.161, 29.447, 263.607), 
            locationLabel = "La Mesa",
        }
    },
    metadata = {
        label = locale("STEAL_GARAGE_MISSION_LABEL"),
        startable = true,
        isCheckpoint = true,
    },
    requiredItem = "pdm_blowtorch",
    removeItem = true,
    cuttingTime = 10000,
    prerequisites = {
        {
            label = locale("Lockpick"),
            type = "ITEM",
            value = "lockpick",
        },
        {
            label = locale("Blowtorch"),
            type = "ITEM",
            value = "pdm_blowtorch",
        },
    },
}

local StealMission = {}
StealMission.__index = StealMission
StealMission = setmetatable(StealMission, Mission)

function StealMission:OnStart(stateId, contract, groupId)
    local locations = {}
    for k, v in pairs(MissionConfig.garages) do
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
    self.garage = MissionConfig.garages[location]
    self.radius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    self.center = self.garage.coords.xyz + (unitVector * math.sqrt(math.random()) * self.radius)
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", locale("SEARCH_AREA"), self.center.xyz, self.radius, 225, 3)
    self:SendEventToMembers("prp-boosting:createGarageInteraction", self.location, self.garage.coords.xyz, self.garage.model)
    TriggerClientEvent("prp-boosting:setGarageClosed", -1, location, self.garage)

    local locationLabel = MissionConfig.garages[location].locationLabel
    self:SendSMSMessage(locale("STEAL_GARAGE_START_TEXT", locationLabel), nil, "BoostWorks")
end

function StealMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        TriggerClientEvent("prp-boosting:removeGarage", -1, self.location)
        takenLocations[self.location] = nil
    end
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if not LoadedBoostingContracts[self.contractId].vehEntity and tickId % 5 == 0 and self.garage?.coords and self:IsAnyMemberCloseToCoords(vector3(self.garage.coords.x, self.garage.coords.y, self.garage.coords.z), 250.0) then
        self:SpawnContractVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.garage.vehCoords)
        local vehEntity = LoadedBoostingContracts[self.contractId].vehEntity
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
        SetVehicleDoorsLocked(vehEntity, 2)
        Entity(vehEntity).state.Locked = true
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

RegisterNetEvent("prp-boosting:openGarage", function(missionId, locationId)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.missionName == "steal_garage" and mission.taskId == playerMission.taskId and mission.location == locationId then
        if MissionConfig.requiredItem then
            local hasItem = bridge.inv.hasItem(source, MissionConfig.requiredItem, 1)
            if not hasItem then
                bridge.fw.notify(source, "error", locale("DONT_HAVE_ITEM", locale("Blowtorch")))
                return
            end
            if MissionConfig.removeItem then
                local success = bridge.inv.removeItem(source, MissionConfig.requiredItem, 1)
                if not success then
                    bridge.fw.notify(source, "error", locale("FAILED_TO_REMOVE", locale("Blowtorch")))
                    return
                end
            end
        end
        local success = lib.callback.await("prp-boosting:progressBar", source, locale("CUTTING_LOCK"), MissionConfig.cuttingTime, nil, nil, true, "WORLD_HUMAN_WELDING")
        if not success then
            bridge.fw.notify(source, "error", locale("FAILED_TO_CUT_LOCK"))
            return
        end
        TriggerClientEvent("prp-boosting:removeGarage", -1, mission.location)
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["steal_garage"] = StealMission
end)

RegisterNetEvent("prp-characters:server:characterSelected", function(source, stateId)
    Citizen.Wait(300)
    local garageStates = {}
    for k, v in pairs(Missions) do
        if (v.missionName == "steal_garage" or v.missionName == "steal_villa") and v.garage then
            garageStates[v.location] = v.garage
        end
    end
    TriggerClientEvent("prp-boosting:setGarageStates", source, garageStates)
end)