local MissionConfig = {
    metadata = {
        label = locale("CARGO_PLANE_MISSION_LABEL"),
        startable = false,
        autoStart = true
    },
    planeModel = `titan`,
    dropOffLocations = {
        {
            coords = vec4(1559.7, 3213.1, 41.3, 104.7)
        },
        {
            coords = vec4(1563.7, 3158.7, 41.4, 139.3),
        },
        {
            coords = vec4(2084.8, 4785.3, 42.0, 112.6),
        },
        {
            coords = vec4(-1042.7, -3118.0, 14.8, 60.6),
        },
        {
            coords = vec4(-1373.7, -2275.6, 14.8, 147.3)
        }
    },
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
    stealLocations[location].taken = self.taskId
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", locale("DROP_OFF_LOCATION"), self.locationCoords.xyz, 307, 3, true)

    local src = bridge.fw.getSrcFromIdentifier(stateId)
    local smsLocation = lib.callback.await("prp-boosting:getStreetName", src, self.locationCoords.xyz)
    if smsLocation then
        self:SendSMSMessage(locale("PLANE_TEXT_LOCATION", smsLocation.main), nil, "BoostWorks")
    else
        self:SendSMSMessage(locale("PLANE_TEXT"), nil, "BoostWorks")
    end
end

function DropOffMission:OnDestroy(stateId, contract, groupId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if veh and DoesEntityExist(veh) then
        LoadedBoostingContracts[self.contractId]:RemoveKeys(veh)
        DeleteEntity(veh)
    end
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.dropOffLocations
        stealLocations[self.location].taken = nil
    end
end

function DropOffMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
    if not self.cargoVehicle and self.locationCoords and self:IsAnyMemberCloseToCoords(self.locationCoords.xyz, 250.0) then
        self.cargoVehicle = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords, MissionConfig.planeModel)
        while not DoesEntityExist(self.cargoVehicle) do
            Citizen.Wait(0)
        end
        SetVehicleDoorsLocked(self.cargoVehicle, 2)
        Entity(self.cargoVehicle).state.Locked = true
        Entity(self.cargoVehicle).state.DisableLockpick = true
        Citizen.Wait(500)
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(self.cargoVehicle), NetworkGetNetworkIdFromEntity(self.cargoVehicle))
        TriggerClientEvent("prp-boosting:setVehicleDoor", NetworkGetEntityOwner(self.cargoVehicle),  NetworkGetNetworkIdFromEntity(self.cargoVehicle), 5, true)
    end
    if self.cargoVehicle then
        local vehCoords = GetEntityCoords(veh)
        local dist = #(vehCoords.xy - self.locationCoords.xy)
        if dist < 5 and GetEntitySpeed(veh) < 1 and tickId % 10 == 0 then
            local isCarInTrailer = lib.callback.await("prp-boosting:isCarInTrailer", NetworkGetEntityOwner(veh), NetworkGetNetworkIdFromEntity(self.cargoVehicle), NetworkGetNetworkIdFromEntity(veh))
            if isCarInTrailer then
                self:SendNotificationToMembers("success", locale("PLANE_SUCCESS_NOTIFY"))
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
    RegisteredMissions["deliver_cargoplane"] = DropOffMission
end)