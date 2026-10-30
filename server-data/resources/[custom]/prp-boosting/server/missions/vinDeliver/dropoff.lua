local MissionConfig = {
    metadata = {
        label = locale("DROP_OFF_MISSION_LABEL"),
        startable = false,
        autoStart = true
    },
    dropOffLocations = {
        {
            coords = vec4(-1155.5, -2005.5, 12.8, 130.6),
            laptopCoords = vec4(-1156.3, -1999.7, 13.2, 44.9),
        },
    },
    scratchingTime = 1 * 60
}

local DropOffMission = {}
DropOffMission.__index = DropOffMission
DropOffMission = setmetatable(DropOffMission, Mission)

function DropOffMission:OnStart(stateId, contract, groupId)
    self.locationId = math.random(1, #MissionConfig.dropOffLocations)
    self.locationCoords = MissionConfig.dropOffLocations[self.locationId].coords
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", locale("DROP_OFF_LOCATION"), self.locationCoords.xyz, 351, 3, true)
    self.laptopObj = self:CreateLocalObject(`xm_prop_x17_laptop_lester_01`, MissionConfig.dropOffLocations[self.locationId].laptopCoords, true, false)
    self:AddLocalObjectTarget(self.laptopObj, "vin_scratch_laptop", {
        label = "Scratch the VIN",
        icon = "fas fa-box-open",
        event = "prp-boosting:vinScratch",
    })
end

function DropOffMission:OnDestroy(stateId, contract, groupId)

end

function DropOffMission:OnTick(stateId, contract, groupId, tickId)
    if self.waitTimer and os.time() - self.waitTimer > MissionConfig.scratchingTime then
        self:SendSMSMessage("The VIN has been scratched. Vehicle is yours now...", nil, "BoostWorks")
        --exports["prp-veh"]:OwnedAdd({ Type = 0, Id = contract.ownerStateId}, joaat(contract.vehicleModel), contract.vehicleModel, 0, function() end, self.vehProperties, nil, nil, nil, true)
        local src = bridge.fw.getSrcFromIdentifier(stateId)
        bridge.fw.addOwnedVehicle(src, contract.vehicleModel)
        self:AddProgress(1)
    end
end

function DropOffMission:GetMetadata()
    return MissionConfig.metadata
end

function DropOffMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

RegisterNetEvent("prp-boosting:vinScratch", function(missionId, objectId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = Missions[missionId]
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId then
        if mission.waitTimer then return end
        local veh = LoadedBoostingContracts[mission.contractId].vehEntity
        if #(GetEntityCoords(veh) - mission.locationCoords.xyz) > 15 then return end
        mission.waitTimer = os.time()
        mission.vehProperties = lib.callback.await("prp-boosting:getVehicleProperties", NetworkGetEntityOwner(veh), NetworkGetNetworkIdFromEntity(veh))
        mission:RemoveLocalObjectTarget(mission.laptopObj, "vin_scratch_laptop")
        mission:SendEventToMembers("prp-boosting:clearBlips")
        bridge.fw.notify(source, "success", locale("WAIT_FOR_VIN_SCRATCH"))
        Citizen.Wait(5000)
        LoadedBoostingContracts[mission.contractId]:RemoveKeys(veh)
        DeleteEntity(veh)
        LoadedBoostingContracts[mission.contractId].vehEntity = nil
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["vinDeliver_dropoff"] = DropOffMission
end)