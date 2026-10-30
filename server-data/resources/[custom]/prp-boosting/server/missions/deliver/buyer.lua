local MissionConfig = {
    metadata = {
        label = "Deliver the vehicle to the buyer",
        startable = false,
        autoStart = true
    },
    scenarios = {
        {
            cars = {
                {
                    model = `baller3`,
                    coords = vec4(-1437.9, -671.0, 26.6, 85.6),
                },
                {
                    model = `baller3`,
                    coords = vec4(-1434.7, -679.1, 26.4, 139.0),
                },
                {
                    model = `flatbed`,
                    coords = vec4(-1429.0, -673.6, 26.8, 281.7),
                }
            },
            peds = {
                vec4(-1435.2, -677.1, 25.5, 35.3),
                vec4(-1436.4, -678.9, 25.4, 26.3),
                vec4(-1438.8, -672.4, 25.6, 190.1),
                vec4(-1437.0, -672.5, 25.7, 164.2),
                vec4(-1434.0, -672.5, 25.8, 102.5),
                vec4(-1433.0, -676.3, 25.6, 93.3),
            },
            vehCoords = vector4(-1437.4, -675.2, 25.9, 280.1),
        },
        {
            cars = {
                {
                    model = `baller3`,
                    coords = vec4(-444.2, -448.4, 31.9, 287.8),
                },
                {
                    model = `baller3`,
                    coords = vec4(-447.0, -457.4, 31.8, 223.6),
                },
                {
                    model = `flatbed`,
                    coords = vec4(-451.1, -451.6, 32.1, 81.2),
                }
            },
            peds = {
                vec4(-446.7, -450.2, 32.0, 262.7),
                vec4(-444.7, -450.2, 31.9, 191.6),
                vec4(-442.6, -449.3, 31.9, 208.4),
                vec4(-445.4, -457.0, 31.9, 318.4),
                vec4(-446.5, -455.9, 31.9, 300.5),
                vec4(-447.9, -454.5, 32.0, 256.4),
            },
            vehCoords = vector4(-442.7, -452.9, 31.2, 81.5),
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
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", "Buyer Location", self.locationCoords.xyz, 500, 3, true)
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
        if not self.scenarioSpawned and dist < 150.0 then
            self.scenarioSpawned = true
            local scenario = MissionConfig.scenarios[self.location]
            for k, v in pairs(scenario.cars) do
                self.scenarioVehicles[k] = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), v.coords, v.model)
                TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(self.scenarioVehicles[k]), NetworkGetNetworkIdFromEntity(self.scenarioVehicles[k]))
                SetVehicleDoorsLocked(self.scenarioVehicles[k], 2)
                Entity(self.scenarioVehicles[k]).state.Locked = true
                Entity(self.scenarioVehicles[k]).state.DisableLockpick = true
            end
            self:NpcCheck(scenario.peds, true, false, true)
        end
        if dist < 5 and GetEntitySpeed(veh) < 1 and GetPedInVehicleSeat(veh, -1) == 0 and not self.shootoutActive then
            Citizen.Wait(2000)
            self:SendNotificationToMembers("info", "Wait for them to examine the vehicle")
            Citizen.Wait(5000)
            if self.isShootout then
                self:SetNpcsAggresive()
                self:SendNotificationToMembers("error", "This is a setup, kill them to get the reward!")
                self.shootoutActive = true
            else
                self:SendNotificationToMembers("success", "They are happy with the vehicle, you can leave now")
                self:AddProgress(1)
            end
        end
        if self.shootoutActive then
            local group = self:GetMissionGroup()
            self.playersAlive = 0
            local members = group.getMembers()
            for k, v in pairs(members) do
                local ped = GetPlayerPed(v.playerId)
                if ped and ped ~= 0 and GetEntityHealth(ped) > 0 then
                    self.playersAlive = self.playersAlive + 1
                end
            end
            self.pedsAlive = 0
            for k, v in pairs(self.npcNetIds) do
                local ped = NetworkGetEntityFromNetworkId(v)
                if ped and ped ~= 0 and GetEntityHealth(ped) > 0 then
                    self.pedsAlive = self.pedsAlive + 1
                end
            end
            if self.playersAlive == 0 then
                self:SendNotificationToMembers("error", "You have been killed, mission failed")
                self:Fail(true)
            end
            if self.pedsAlive == 0 then
                self:SendNotificationToMembers("success", "You killed all the enemies, you can leave now")
                self:AddProgress(1)
                self.shootoutActive = false
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
    RegisteredMissions["deliver_buyer"] = DropOffMission
end)