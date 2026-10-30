local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    containerModels = {
        `prp_prop_tr_container_01a`,
    },
    metadata = {
        label = locale("STEAL_CONTAINER_MISSION_LABEL"),
        startable = true,
        isCheckpoint = true,
    },
    collisionOffset = {
        [`prp_prop_tr_container_01a`] = vector3(0.000488, -1.813827, 1.394014)
    },
    requiredItem = "diving_angle_grinder",
    removeItem = true,
    prerequisites = {
        {
            label = locale("Lockpick"),
            type = "ITEM",
            value = "lockpick",
        },
        {
            label = locale("ANGLE_GRINDER"),
            type = "ITEM",
            value = "diving_angle_grinder",
        },
    },
    useSharedLocations = "container",
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
    self.locationCoords = stealLocations[location].container
    self.npcLocations = stealLocations[location].npcLocations
    stealLocations[location].taken = self.taskId
    self.radius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    self.model = MissionConfig.containerModels[math.random(1, #MissionConfig.containerModels)]
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    self.center = self.locationCoords.xyz + (unitVector * math.sqrt(math.random()) * self.radius)
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "container", locale("SEARCH_AREA"), self.center.xyz, self.radius, 225, 3)
    self:SpawnContainer()

    local locationLabel = stealLocations[location].locationLabel
    self:SendSMSMessage(locale("STEAL_CONTAINER_START_TEXT", locationLabel), nil, "BoostWorks")
end

function StealMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        stealLocations[self.location].taken = nil
    end
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if LoadedBoostingContracts[self.contractId].vehEntity then
        local veh = LoadedBoostingContracts[self.contractId].vehEntity
        if GetIsVehicleEngineRunning(veh) then
            self:AddProgress(1)
        end
    end
end

function StealMission:SpawnContainer()
    self.container = self:CreateLocalObject(self.model, self.locationCoords, true, true)
    local collisionCoords = GetEntityMatrixFromVec(self.locationCoords) * MissionConfig.collisionOffset[self.model] + self.locationCoords.xyz
    self.containerCollision = self:CreateLocalObject(`prp_prop_tr_container_dummy_col`, vector4(collisionCoords.x, collisionCoords.y, collisionCoords.z, self.locationCoords.w), true, true)
    self:AddLocalObjectTarget(self.containerCollision, "container_open", {
        label = locale("OPEN_CONTAINER"),
        icon = "fas fa-box-open",
        event = "prp-boosting:openContainer",
    })
end

function StealMission:SetContainerOpen(isOpen)
    if not self.container then return end
    if isOpen then
        self:SetLocalObjectAnim(self.container, {
            dict = "anim@scripted@player@mission@tunf_train_ig1_container_p1@male@",
            name = "action_container",
            stayInAnim = true
        })
        Citizen.SetTimeout(4000, function()
            self:RemoveLocalObject(self.containerCollision)
        end)
    else
        self:SetLocalObjectAnim(self.container, nil)
        local collisionCoords = GetEntityMatrixFromVec(self.locationCoords) * MissionConfig.collisionOffset[self.model] + self.locationCoords.xyz
        self.containerCollision = self:CreateLocalObject(`prp_prop_tr_container_dummy_col`, vector4(collisionCoords.x, collisionCoords.y, collisionCoords.z, self.locationCoords.w), true, true)
    end
end

RegisterNetEvent("prp-boosting:openContainer", function(missionId, objectId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = Missions[missionId]
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId then
        if MissionConfig.requiredItem then
            local hasItem = bridge.inv.hasItem(source, MissionConfig.requiredItem, 1)
            if not hasItem then
                bridge.fw.notify(source, "error", locale("NO_ANGLE_GRINDER"))
                return
            end
            if MissionConfig.removeItem then
                local success = bridge.inv.removeItem(source, MissionConfig.requiredItem, 1)
                if not success then
                    bridge.fw.notify(source, "error", locale("FAILED_TO_REMOVE", locale("ANGLE_GRINDER")))
                    return
                end
            end
        end
        mission:SetContainerOpen(true)
        TriggerClientEvent("prp-boosting:containerOpen", source, mission.locationCoords)
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        mission:SpawnContractVehicle(source, stealLocations[mission.location].vehicle)
        local vehEntity = LoadedBoostingContracts[mission.contractId].vehEntity
        SetVehicleDoorsLocked(vehEntity, 1)
        Entity(vehEntity).state.Locked = false
    end
end)

function StealMission:GetMetadata()
    return MissionConfig.metadata
end

function StealMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

Citizen.CreateThread(function()
    RegisteredMissions["steal_container"] = StealMission
end)

local glm = require("glm")
function GetEntityMatrixFromVec(coords)
    local heading = coords.w * math.pi/180.0
    local forward = vector3(math.cos(heading), math.sin(heading), 0)
    local right = vector3(-forward.y, forward.x, 0)
    local up = vector3(0, 0, 1)
    return (mat(forward, right, up))
end