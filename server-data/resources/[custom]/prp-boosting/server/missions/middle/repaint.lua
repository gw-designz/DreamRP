local MissionConfig = {
    availableColors = {
        "pink",
    },
    repaintSpots = {
        {
            coords = vector3(1977.350, 5170.622, 47.639),
            dist = 5.0
        },
        {
            coords = vector3(3334.336, 5161.455, 18.302),
            dist = 5.0
        },
        {
            coords = vector3(-482.212, 6260.588, 13.018),
            dist = 5.0
        },
        {
            coords = vector3(2734.315, 4289.412, 48.421),
            dist = 8.0
        },
        {
            coords = vector3(-269.143, 2193.517, 129.790),
            dist = 5.0
        }
    },
    colorLabels = {
        pink = "Pink"
    },
    colorIndexes = {
        pink = {
            ["135"] = true,
            ["136"] = true,
            ["136"] = true
        }
    },
    metadata = {
        label = locale("MIDDLE_MISSION_REPAINT_LABEL"),
        autoStart = true,
    }
}

local RepaintMission = {}
RepaintMission.__index = RepaintMission
RepaintMission = setmetatable(RepaintMission, Mission)

function RepaintMission:OnStart(stateId, contract, groupId)
    self.spotIndex = math.random(1, #MissionConfig.repaintSpots);
    self.repaintSpot = MissionConfig.repaintSpots[self.spotIndex]
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    local netId = NetworkGetNetworkIdFromEntity(veh)
    self:SendEventToMembers("prp-boosting:createRepaintInteraction", self.spotIndex, self.repaintSpot.coords, self.repaintSpot.dist)
    self:SendEventToMembers("prp-boosting:setMissionBlip", "repaint_spot", locale("REPAINT_LOCATION"), self.repaintSpot.coords, 72, 3, true)
    self:SendSMSMessage(locale("REPAINT_MISSION_START_TEXT", MissionConfig.colorLabels[self.addonData.color]), nil, "BoostWorks")
end

function RepaintMission:OnDestroy(stateId, contract, groupId)
    self:SendEventToMembers("prp-boosting:removeRepaintInteraction", self.spotIndex)
end

function RepaintMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end

    if not self.addonData.color or not MissionConfig.colorIndexes[self.addonData.color] then
        self:Fail()
        return
    end

    if IsEntityPositionFrozen(veh) then -- check if it's getting edited
        return
    end

    local colorPrimary, colorSecondary = GetVehicleColours(veh)
    if MissionConfig.colorIndexes[self.addonData.color][tostring(colorPrimary)] and MissionConfig.colorIndexes[self.addonData.color][tostring(colorSecondary)] then
        self:AddProgress(1)
    end
end

function RepaintMission:GetMetadata()
    return MissionConfig.metadata
end

function RepaintMission:GetPrerequisites()
    return MissionConfig.prerequisites
end


function RepaintMission:GenerateAddonData()
    return {
        color = MissionConfig.availableColors[math.random(1, #MissionConfig.availableColors)]
    }
end

RegisterNetEvent("prp-boosting:repaintVehicle", function(missionId)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.missionName == "middle_repaint" and mission.taskId == playerMission.taskId and mission.location == locationId then
        local colorIndexes = {}

        for k, v in pairs(MissionConfig.colorIndexes[mission.addonData.color]) do
            table.insert(colorIndexes, tonumber(k))
        end

        local primary = colorIndexes[math.random(1, #colorIndexes)]
        local secondary = colorIndexes[math.random(1, #colorIndexes)]

        SetVehicleColours(LoadedBoostingContracts[mission.contractId].vehEntity, primary, secondary)
        mission:AddProgress(1)
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["middle_repaint"] = RepaintMission
end)