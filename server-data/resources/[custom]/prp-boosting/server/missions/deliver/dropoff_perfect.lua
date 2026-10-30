local MissionConfig = {
    metadata = {
        label = "Drop Off the vehicle in perfect condition",
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
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", "Drop Off Location", self.locationCoords.xyz, 500, 3, true)
    self:SendEventToMembers("prp-boosting:setPreviewVehicle", self.locationCoords)
    local src = bridge.fw.getSrcFromIdentifier(stateId)
    local smsLocation = lib.callback.await("prp-boosting:getStreetName", src, self.locationCoords.xyz)
    if smsLocation then
        self:SendSMSMessage(("They want this vehicle delivered at %s. Bring it to them but watch out, they seem shady..."):format(smsLocation.main), nil, "BoostWorks")
    else
        self:SendSMSMessage("They want this vehicle delivered. Bring it to them but watch out, they seem shady...", nil, "BoostWorks")
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
            local engineHealth = GetVehicleEngineHealth(veh)
            local bodyHealth = GetVehicleBodyHealth(veh)
            local totalHealthPercent = ((engineHealth + bodyHealth) / 2) / 1000 * 100
            if totalHealthPercent < 50 then
                self:SendSMSMessage("The vehicle is too damaged to be delivered. What did you do to it?! I wont't pay you for this shit", nil, "BoostWorks")
                self:Fail(true)
                return
            else
                local penalty = math.floor(100 - totalHealthPercent)
                LoadedBoostingContracts[self.contractId].penaltyPercent = penalty
                if penalty > 1 then
                    self:SendSMSMessage(("The vehicle is damaged. I will take %s%% of the contract value for this."):format(penalty), nil, "BoostWorks")
                end
            end
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
    RegisteredMissions["deliver_dropoff_perfect"] = DropOffMission
end)