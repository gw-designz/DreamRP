local MissionConfig = {
    metadata = {
        label = locale("DESTROY_VEHICLE_MISSION_LABEL"),
        startable = false,
        autoStart = true
    },
}

local DropOffMission = {}
DropOffMission.__index = DropOffMission
DropOffMission = setmetatable(DropOffMission, Mission)

function DropOffMission:OnStart(stateId, contract, groupId)
    if contract.vehicleClass == "D" or contract.vehicleClass == "C" then
        self:SendSMSMessage(locale("DESTROY_VEHICLE_START_TEXT_CD_CLASS"), nil, "BoostWorks")
        return
    end
    self:SendSMSMessage(locale("DESTROY_VEHICLE_START_TEXT"), nil, "BoostWorks")
end

function DropOffMission:OnDestroy(stateId, contract, groupId)
    
end

function DropOffMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
    if tickId % 10 == 0 then
        if GetVehicleEngineHealth(veh) <= 0.0 or (NetworkGetEntityOwner(veh) ~= 0 and lib.callback.await("prp-boosting:isVehicleTotaled", NetworkGetEntityOwner(veh), NetworkGetNetworkIdFromEntity(veh))) then
            Citizen.SetTimeout(15*1000, function()
                if DoesEntityExist(veh) then
                    LoadedBoostingContracts[self.contractId]:RemoveKeys(veh)
                    DeleteEntity(veh)
                end
            end)
            self:AddProgress(1)
            return
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
    RegisteredMissions["deliver_destroy"] = DropOffMission
end)