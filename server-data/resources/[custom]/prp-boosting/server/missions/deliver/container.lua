local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    containerModels = {
        `prp_prop_tr_container_01a`,
    },
    stealLocations = {
        vec4(129.8,-119.8,53.8,258.6),
    },
    metadata = {
        label = locale("CONTAINER_MISSION_LABEL"),
        startable = false,
        autoStart = true
    },
    collisionOffset = {
        [`prp_prop_tr_container_01a`] = vector3(0.000488, -1.813827, 1.394014)
    },
    requiredItem = "diving_angle_grinder",
    removeItem = true,
    useSharedLocations = "container",
}

local DropOffMission = {}
DropOffMission.__index = DropOffMission
DropOffMission = setmetatable(DropOffMission, Mission)

function DropOffMission:OnStart(stateId, contract, groupId)
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
    self.model = MissionConfig.containerModels[math.random(1, #MissionConfig.containerModels)]
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", locale("DROP_OFF_LOCATION"), self.locationCoords.xyz, 500, 3, true)
    self.vehicleCoords = stealLocations[self.location].vehicle
    self:SendEventToMembers("prp-boosting:setPreviewVehicle", self.vehicleCoords)
    self.container = self:CreateLocalObject(self.model, self.locationCoords, true, true)
    self:SetLocalObjectAnim(self.container, {
        dict = "anim@scripted@player@mission@tunf_train_ig1_container_p1@male@",
        name = "action_container",
        stayInAnim = true
    })

    self:SendSMSMessage(locale("CONTAINER_START_TEXT"), nil, "BoostWorks")
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
        local dist = #(vehCoords.xy - self.vehicleCoords.xy)
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
    RegisteredMissions["deliver_container"] = DropOffMission
end)