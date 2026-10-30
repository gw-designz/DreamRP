local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    truckLocations = {
        {
            coords = vec4(-466.9,-1673.7,19.5,161.3),
            locationLabel = "La Puerta"
        },
        {
            coords = vec4(-1161.0, -1992.8, 13.1, 314.8),
            locationLabel = "Los Santos International Airport"
        },
        {
            coords = vec4(1264.9, -2563.4, 42.8, 290.8),
            locationLabel = "El Burro Heights"
        },
        {
            coords = vec4(-161.0, 6267.6, 31.5, 45.5),
            locationLabel = "Paleto Bay"
        },
    },
    stealLocations = {
        {
            coords = vec4(122.6, -129.9, 53.5, 68.0),
            locationLabel = "Southern Vinewood"
        }
    },
    metadata = {
        label = locale("TOW_TRUCK_MISSION_LABEL"),
        startable = true,
        isCheckpoint = true,
    },
    prerequisites = {
        {
            label = locale("Lockpick"),
            type = "ITEM",
            value = "lockpick",
        },
    },
    useSharedLocations = "normal"
}

local StealMission = {}
StealMission.__index = StealMission
StealMission = setmetatable(StealMission, Mission)

function StealMission:OnStart(stateId, contract, groupId)
    local truckLocations = MissionConfig.truckLocations
    local freeTruckLocations = {}
    for k, v in pairs(truckLocations) do
        if not takenLocations[k] then
            table.insert(freeTruckLocations, k)
        end
    end
    if #freeTruckLocations == 0 then
        return self:Cancel()
    end
    local truckLocation = freeTruckLocations[math.random(1, #freeTruckLocations)]
    takenLocations[truckLocation] = true

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
    self.radius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    self.center = self.locationCoords.xyz + (unitVector * math.sqrt(math.random()) * self.radius)

    self.truckLocation = truckLocation
    self.truckCoords = truckLocations[truckLocation].coords
    self.truckRadius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    self.truckCenter = self.truckCoords.xyz
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", locale("TOW_TRUCK_LOCATION"), self.truckCenter.xyz, self.truckRadius, 225, 3)
    local locationLabel = truckLocations[truckLocation].locationLabel
    self:SendSMSMessage(locale("TOW_TRUCK_MISSION_START_TEXT", locationLabel), nil, "BoostWorks")
end

function StealMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        stealLocations[self.location].taken = nil
    end
    if self.truckLocation then
        takenLocations[self.truckLocation] = nil
    end
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if not LoadedBoostingContracts[self.contractId].vehEntity and tickId % 5 == 0 and self.stolenTowTruck and self.locationCoords and self:IsAnyMemberCloseToCoords(vector3(self.locationCoords.x, self.locationCoords.y, self.locationCoords.z), 250.0) then
        self:SpawnContractVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords)
        local vehEntity = LoadedBoostingContracts[self.contractId].vehEntity
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
        SetVehicleDoorsLocked(vehEntity, 2)
        Entity(vehEntity).state.Locked = true
        Entity(vehEntity).state.DisableLockpick = true
        self:SendEventToMembers("prp-boosting:towTruckWaitingThread", self.taskId, NetworkGetNetworkIdFromEntity(vehEntity))
    end

    if not self.towTruck and tickId % 5 == 0 and self.truckCoords and self:IsAnyMemberCloseToCoords(vector3(self.truckCoords.x, self.truckCoords.y, self.truckCoords.z), 250.0) then
        self.towTruck = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.truckCoords, `towtruck`, 60)
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(self.towTruck), NetworkGetNetworkIdFromEntity(self.towTruck))
        SetVehicleDoorsLocked(self.towTruck, 2)
        Entity(self.towTruck).state.Locked = true
    end

    if self.towTruck and not self.stolenTowTruck and GetIsVehicleEngineRunning(self.towTruck) then
        self.stolenTowTruck = true
        self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", locale("SEARCH_AREA"), self.center.xyz, self.radius, 225, 3)
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        local locationLabel = stealLocations[self.location].locationLabel
        self:SendSMSMessage(locale("TOW_TRUCK_MISSION_TICK_TEXT", locationLabel), nil, "BoostWorks")
    end
end

function StealMission:GetMetadata()
    return MissionConfig.metadata
end

function StealMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

RegisterNetEvent("prp-boosting:towTruckAttached", function(missionId)
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId then
        mission:AddProgress(1)
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["steal_towtruck"] = StealMission
end)