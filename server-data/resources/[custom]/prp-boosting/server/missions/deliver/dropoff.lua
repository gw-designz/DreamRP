local MissionConfig = {
    metadata = {
        label = locale("DROP_OFF_MISSION_LABEL"),
        startable = false,
        autoStart = true
    },
    dropOffLocations = {
        vec4(44.4, -104.3, 55.7, 339.9)
    },
    useSharedLocations = "normal"
}

local DropOffMission = {}
DropOffMission.__index = DropOffMission
DropOffMission = setmetatable(DropOffMission, Mission)

function DropOffMission:OnStart(stateId, contract, groupId)
    local locations = {}
    local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.dropOffLocations
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
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", locale("DROP_OFF_LOCATION"), self.locationCoords.xyz, 500, 3, true)
    self:SendEventToMembers("prp-boosting:setPreviewVehicle", self.locationCoords)
    local src = bridge.fw.getSrcFromIdentifier(stateId)
    local smsLocation = lib.callback.await("prp-boosting:getStreetName", src, self.locationCoords.xyz)
    if smsLocation then
        self:SendSMSMessage(locale("DROP_OFF_START_TEXT_LOCATION", smsLocation.main), nil, "BoostWorks")
    else
        self:SendSMSMessage(locale("DROP_OFF_START_TEXT"), nil, "BoostWorks")
    end
end

function DropOffMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        stealLocations[self.location].taken = nil
    end
end

function DropOffMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
    if self.locationCoords then
        local vehCoords = GetEntityCoords(veh)
        local dist = #(vehCoords.xy - self.locationCoords.xy)
        if dist < 5 and GetEntitySpeed(veh) < 1 and GetPedInVehicleSeat(veh, -1) == 0 then
            Citizen.Wait(2000)
            LoadedBoostingContracts[self.contractId]:RemoveKeys(veh)
            DeleteEntity(veh)
            self:AddProgress(1)
        end
    end
end

function DropOffMission:GetMetadata()
    return MissionConfig.metadata
end

function DropOffMission:GetPrerequisites()
    return MissionConfig.prerequisites
end


Citizen.CreateThread(function()
    RegisteredMissions["deliver_dropoff"] = DropOffMission
end)