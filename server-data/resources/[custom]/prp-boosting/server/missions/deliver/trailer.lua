local MissionConfig = {
    metadata = {
        label = locale("TRAILER_DROP_OFF_MISSION_LABEL"),
        startable = false,
        autoStart = true
    },
    trailerModel = `trailers3`,
    useSharedLocations = "trailer",
}

local DropOffMission = {}
DropOffMission.__index = DropOffMission
DropOffMission = setmetatable(DropOffMission, Mission)

function DropOffMission:OnStart(stateId, contract, groupId)
    local locations = {}
    local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.trailerLocations
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
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", locale("DROP_OFF_LOCATION"), self.locationCoords.xyz, 479, 3, true)

    local src = bridge.fw.getSrcFromIdentifier(stateId)
    local smsLocation = lib.callback.await("prp-boosting:getStreetName", src, self.locationCoords.xyz)
    if smsLocation then
        self:SendSMSMessage(locale("TRAILER_DROP_OFF_START_TEXT_LOCATION", smsLocation.main), nil, "BoostWorks")
    else
        self:SendSMSMessage(locale("TRAILER_DROP_OFF_START_TEXT"), nil, "BoostWorks")
    end
end

function DropOffMission:OnDestroy(stateId, contract, groupId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if veh and DoesEntityExist(veh) then
        LoadedBoostingContracts[self.contractId]:RemoveKeys(veh)
        DeleteEntity(veh)
    end
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.trailerLocations
        stealLocations[self.location].taken = nil
    end
end

function DropOffMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
    if not self.trailerVehicle and self.locationCoords and self:IsAnyMemberCloseToCoords(self.locationCoords.xyz, 250.0) then
        self.trailerVehicle = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords, MissionConfig.trailerModel)
        while not DoesEntityExist(self.trailerVehicle) do
            Citizen.Wait(0)
        end
        Citizen.Wait(500)
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(self.trailerVehicle), NetworkGetNetworkIdFromEntity(self.trailerVehicle))
        TriggerClientEvent("prp-boosting:setVehicleDoor", NetworkGetEntityOwner(self.trailerVehicle),  NetworkGetNetworkIdFromEntity(self.trailerVehicle), 5, true)
    end
    if self.trailerVehicle then
        local vehCoords = GetEntityCoords(veh)
        local dist = #(vehCoords.xy - self.locationCoords.xy)
        if dist < 5 and GetEntitySpeed(veh) < 1 and tickId % 10 == 0 then
            local isCarInTrailer = lib.callback.await("prp-boosting:isCarInTrailer", NetworkGetEntityOwner(veh), NetworkGetNetworkIdFromEntity(self.trailerVehicle), NetworkGetNetworkIdFromEntity(veh))
            if isCarInTrailer then
                FreezeEntityPosition(veh, true)
                Citizen.Wait(15000)
                LoadedBoostingContracts[self.contractId]:RemoveKeys(veh)
                DeleteEntity(veh)
                self:AddProgress(1)
            end
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
    RegisteredMissions["deliver_trailer"] = DropOffMission
end)