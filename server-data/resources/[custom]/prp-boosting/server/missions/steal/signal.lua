local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    metadata = {
        label = locale("SIGNAL_MISSION_LABEL"),
        startable = true,
        isCheckpoint = true,
    },
    carBriefcaseRange = 75.0,
    targetBriefcaseRange = 75.0,
    prerequisites = {
        {
            label = locale("SIGNAL_MISSION_REQUIRED_1"),
            type = "ITEM",
            value = "WEAPON_BRIEFCASE",
        },
        {
            label = locale("SIGNAL_MISSION_REQUIRED_2"),
            type = "PLAYER_COUNT",
            value = 2,
        },
    },
    useSharedLocations = "normal",
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
    self.radius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    self.center = self.locationCoords.xyz + (unitVector * math.sqrt(math.random()) * self.radius)
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", locale("SEARCH_AREA"), self.center.xyz, self.radius, 225, 3)
    local locationLabel = stealLocations[location].locationLabel
    self:SendSMSMessage(locale("SIGNAL_MISSION_START_TEXT", locationLabel), nil, "BoostWorks")
    self:GenerateKeyLocation()
    self.enableTick = true
end

function StealMission:GenerateKeyLocation()
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    local t = math.sqrt(math.random())
    self.keyLocation = self.locationCoords.xyz + unitVector * (MissionConfig.targetBriefcaseRange + t * (MissionConfig.carBriefcaseRange + MissionConfig.targetBriefcaseRange - 10.0))
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
        Citizen.Wait(200)
        local vehEntity = LoadedBoostingContracts[self.contractId].vehEntity
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
        SetVehicleDoorsLocked(vehEntity, 2)
        Entity(vehEntity).state.Locked = true
        Entity(vehEntity).state.DisableLockpick = true
        self:SendEventToMembers("prp-boosting:ensureCaseThread", NetworkGetNetworkIdFromEntity(vehEntity))
        self:NpcCheck(self.npcLocations)
        
    end
    if LoadedBoostingContracts[self.contractId].vehEntity then
        local veh = LoadedBoostingContracts[self.contractId].vehEntity
        if GetVehicleDoorLockStatus(veh) ~= 2 and not self.firstPing then
            SetVehicleDoorsLocked(veh, 2)
            Citizen.Wait(100)
        end
        if GetIsVehicleEngineRunning(veh) then
            self:AddProgress(1)
        end
    end
end

function StealMission:CasePing(source, playerPed)
    local playerCoords = GetEntityCoords(playerPed)
    if not self.firstPing then
        self.firstPing = true
        self:SendEventToMembers("prp-boosting:clearBlips")
    end
    self:SendEventToMembers("prp-boosting:pingCaseBlip", playerCoords, MissionConfig.carBriefcaseRange, 1)
    for stateId, member in pairs(self:GetMembers()) do
        local targetPed = GetPlayerPed(member.src)
        if member.src ~= source and GetSelectedPedWeapon(targetPed) == `WEAPON_BRIEFCASE` then
            local targetCoords = GetEntityCoords(targetPed)
            local dist = #(playerCoords - targetCoords)
            local keyDist = #(targetCoords - self.keyLocation)
            if dist < (MissionConfig.carBriefcaseRange+MissionConfig.targetBriefcaseRange) and keyDist < MissionConfig.targetBriefcaseRange and not self.gotKeys then
                self.gotKeys = true
                Citizen.SetTimeout(500, function()
                    self:SendEventToMembers("prp-boosting:pingCaseBlip", targetCoords, MissionConfig.targetBriefcaseRange, 2)
                    self:SendEventToMembers("prp-boosting:pingCaseBlip", playerCoords, MissionConfig.carBriefcaseRange, 2)
                    bridge.vkeys.give(source, LoadedBoostingContracts[self.contractId].vehEntity)
                    bridge.fw.notify(source, "success", locale("ACQUIRED_KEYS"))
                end)
            else
                Citizen.SetTimeout(1000, function()
                    if keyDist < MissionConfig.targetBriefcaseRange then
                        self:SendEventToMembers("prp-boosting:pingCaseBlip", targetCoords, MissionConfig.targetBriefcaseRange, 46)
                    else
                        self:SendEventToMembers("prp-boosting:pingCaseBlip", targetCoords, MissionConfig.targetBriefcaseRange, 9)
                    end
                end)
            end
        end
    end
end

RegisterNetEvent("prp-boosting:caseVehiclePing", function(missionId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = Missions[missionId]
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId then
        local playerPed = GetPlayerPed(source)
        if GetSelectedPedWeapon(playerPed) ~= `WEAPON_BRIEFCASE` then return end
        mission:CasePing(source, playerPed)
    end
end)

function StealMission:GetMetadata()
    return MissionConfig.metadata
end

function StealMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

Citizen.CreateThread(function()
    RegisteredMissions["steal_signal"] = StealMission
end)

