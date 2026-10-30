local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    metadata = {
        label = locale("STEAL_MISSION_LABEL"),
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
    self:SendSMSMessage(locale("STEAL_MISSION_START_TEXT", locationLabel), nil, "BoostWorks")
    self.enableTick = true
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
        self:NpcCheck(self.npcLocations)
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


Citizen.CreateThread(function()
    RegisteredMissions["steal_normal"] = StealMission
end)

