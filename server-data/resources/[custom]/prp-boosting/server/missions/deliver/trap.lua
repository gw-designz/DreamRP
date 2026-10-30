local MissionConfig = {
    metadata = {
        label = "Park the vehicle and wait for target",
        startable = false,
        autoStart = true
    },
    scenarios = {
        {
            peds = {
                vec4(701.4, 617.9, 128.1, 77.7),
                vec4(703.1, 617.2, 128.1, 77.2),
            },
            vehCoords = vector4(681.5, 606.3, 128.3, 340.8),
            driveToCoords = vector4(695.6, 622.2, 128.3, 314.2)
        },
    },
    shootoutChance = {
        ["F"] = 0,
        ["E"] = 2,
        ["D"] = 3,
        ["C"] = 5,
        ["B"] = 10,
        ["A"] = 25,
        ["S"] = 35,
    }
}

local DropOffMission = {}
DropOffMission.__index = DropOffMission
DropOffMission = setmetatable(DropOffMission, Mission)

function DropOffMission:OnStart(stateId, contract, groupId)
    local locations = {}
    local stealLocations = MissionConfig.scenarios
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
    self.locationCoords = stealLocations[location].vehCoords
    stealLocations[location].taken = self.taskId
    self.scenarioVehicles = {}
    self.scenarioPeds = {}
    self.isShootout = math.random(1, 100) <= MissionConfig.shootoutChance[contract.vehicleClass]
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", "Trap Location", self.locationCoords.xyz, 500, 3, true)
    self:SendEventToMembers("prp-boosting:setPreviewVehicle", self.locationCoords)
    local src = bridge.fw.getSrcFromIdentifier(stateId)
    local smsLocation = lib.callback.await("prp-boosting:getStreetName", src, self.locationCoords.xyz)
    if smsLocation then
        self:SendSMSMessage(("They want this vehicle delivered at %s. Park it, walk away, don’t look back. Watch out, they might have set a trap for you..."):format(smsLocation.main), nil, "BoostWorks")
    else
        self:SendSMSMessage("They want this vehicle delivered. Park it, walk away, don’t look back. Watch out, they might have set a trap for you...", nil, "BoostWorks")
    end
end

function DropOffMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        local stealLocations = MissionConfig.scenarios
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
        if not self.scenarioSpawned and dist < 5 and GetEntitySpeed(veh) < 2 and not DoesEntityExist(GetPedInVehicleSeat(veh, -1)) then
            self.scenarioSpawned = true
            local scenario = MissionConfig.scenarios[self.location]
            for k, v in pairs(scenario.cars or {}) do
                self.scenarioVehicles[k] = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), v.coords, v.model)
                TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(self.scenarioVehicles[k]), NetworkGetNetworkIdFromEntity(self.scenarioVehicles[k]))
                SetVehicleDoorsLocked(self.scenarioVehicles[k], 2)
                Entity(self.scenarioVehicles[k]).state.Locked = true
                Entity(self.scenarioVehicles[k]).state.DisableLockpick = true
            end
            self:SendEventToMembers("prp-boosting:setPreviewVehicle")
            self:NpcCheck(scenario.peds, true, false, true)
            Citizen.Wait(300)
            local seatId = -1
            if self.npcNetIds then
                for k, v in pairs(self.npcNetIds) do
                    local ent = NetworkGetEntityFromNetworkId(v)
                    if DoesEntityExist(ent) and GetEntityType(ent) == 1 then
                        if seatId == -1 then
                            self.driverPed = ent
                        end
                        TriggerClientEvent("prp-boosting:pedEnterVehicle", NetworkGetEntityOwner(ent), v, NetworkGetNetworkIdFromEntity(contract.vehEntity), seatId)
                        seatId = seatId+1
                    end
                end
            end
            while GetPedInVehicleSeat(veh, -1) ~= self.driverPed do
                Citizen.Wait(0)
            end
            local success = lib.callback.await("prp-boosting:triggerTrap", NetworkGetEntityOwner(veh), NetworkGetNetworkIdFromEntity(veh), NetworkGetNetworkIdFromEntity(self.driverPed), MissionConfig.scenarios[self.location].driveToCoords)
            if success then
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
    RegisteredMissions["deliver_trap"] = DropOffMission
end)