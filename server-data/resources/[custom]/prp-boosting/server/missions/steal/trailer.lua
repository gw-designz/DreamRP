local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    trailerLocations = {
        {
            coords = vec4(658.2, -1662.5, 9.8, 177.7),
            locationLabel = "Los Santos Canal",
        },
    },
    metadata = {
        label = locale("TRAILER_MISSION_LABEL"),
        startable = true,
        isCheckpoint = true,
    },
    trailerModel = `tr2`,
    trailerOffsets = {
        { coords = vec3(-0.048028, 4.587867, 1.008078), rot	= vec3(-0.265553, 0.047895, -4.633224) },
        { coords = vec3(0.000372, -0.579920, 1.102111), rot	= vec3(2.815959, -0.039532, -0.905457) },
        { coords = vec3(-0.164773, 4.855928, 3.057808), rot	= vec3(-3.548188, 4.0, -0.175339) },
        { coords = vec3(0.026294, -2.613838, 0.825), rot = vec3(0.0, -4.0, 0.055908), bone = "bonnet" },
        { coords = vec3(-0.016189, -7.515129, 0.825), rot = vec3(0.0, 0.114317, 0.571815), bone = "bonnet" },
    },
    vehModels = {
        [`sultan`] = true,
        [`buffalo2`] = true,
        [`komoda`] = true
    },
    requiredItem = "bolt_cutter",
    removeItem = true,
    minigameConfig = {
        global = {
            ["rythmArrows"] = {
                speed = 100,
                arrowCount = 4,
                time = 4000,
                threshold = 15.0,
            },
        },
        D = {

        },
        C = {

        },
        B = {

        },
        A = {

        },
        S = {

        },
        X = {

        }

    },
    prerequisites = {
        {
            label = locale("BOLT_CUTTER"),
            type = "ITEM",
            value = "bolt_cutter",
        },
        {
            label = locale("Lockpick"),
            type = "ITEM",
            value = "lockpick",
        },
    },
    useSharedLocations = "trailer",
}

local StealMission = {}
StealMission.__index = StealMission
StealMission = setmetatable(StealMission, Mission)

function StealMission:OnStart(stateId, contract, groupId)
    local locations = {}
    local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.trailerLocations
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
    self.radius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    self.center = self.locationCoords.xyz + (unitVector * math.sqrt(math.random()) * self.radius)
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", locale("SEARCH_AREA"), self.center.xyz, self.radius, 225, 3)
    local locationLabel = stealLocations[location].locationLabel or locale("Unknown")
    self:SendSMSMessage(locale("TRAILER_MISSION_START_TEXT", locationLabel), nil, "BoostWorks")
    self.vehicles = {}
    self.enableTick = true
end

function StealMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.trailerLocations
        stealLocations[self.location].taken = nil
    end
    for k, v in pairs(self.vehicles or {}) do
        if not v.dontDelete and DoesEntityExist(k) then
            DeleteEntity(k)
        end
    end
    if self.trailerVehicle then
        DeleteEntity(self.trailerVehicle)
    end
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if not LoadedBoostingContracts[self.contractId].vehEntity and tickId % 5 == 0 and self.locationCoords and self:IsAnyMemberCloseToCoords(vector3(self.locationCoords.x, self.locationCoords.y, self.locationCoords.z), 150.0) then
        local vehPosition = math.random(1, 5)
        self.trailerVehicle = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords, MissionConfig.trailerModel)
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(self.trailerVehicle), NetworkGetNetworkIdFromEntity(self.trailerVehicle))
        Citizen.Wait(200)
        FreezeEntityPosition(self.trailerVehicle, true)
        for i=1, 5 do
            local veh
            if i == vehPosition then
                veh = self:SpawnContractVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords.xyz + vector3(math.random(0.0, 5.0), math.random(0.0, 5.0), 3.0))
            else
                local vehModels = {}
                for k, v in pairs(MissionConfig.vehModels) do
                    if k ~= joaat(LoadedBoostingContracts[self.contractId].vehicleModel) then
                        table.insert(vehModels, k)
                    end
                end
                veh = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords.xyz + vector3(math.random(0.0, 5.0), math.random(0.0, 5.0), 3.0), vehModels[math.random(1, #vehModels)])
            end
            self.vehicles[veh] = { attached = true, dontDelete = i == vehPosition, upper = i > 2 }
            while not DoesEntityExist(veh) do
                Citizen.Wait(0)
            end
            TriggerClientEvent("prp-boosting:attachVehicleOnToTrailer", NetworkGetEntityOwner(self.trailerVehicle), NetworkGetNetworkIdFromEntity(self.trailerVehicle), NetworkGetNetworkIdFromEntity(veh), MissionConfig.trailerOffsets[i])
        end
        self:AddTargetOnVehicle(NetworkGetNetworkIdFromEntity(self.trailerVehicle), "open_back", {
            label = locale("OPEN_BACK"),
            icon = "fas fa-box-open",
            event = "prp-boosting:openTrailerBack",
        })
        exports["prp-bridge"]:CreateVehTempAttachObject(self.trailerVehicle, {
            model = `m23_2_prop_m32_chainlock_01a`,
            bone = "boot",
            offset = vector3(1.1, 0.175, 0.2),
            rotation = vector3(0.0, 0.0, 70.0),
            rotationOrder = 1,
            disableCollistion = { true, true, true, true },
        })
    end
    for k, v in pairs(self.vehicles or {}) do
        if v.attached and DoesEntityExist(k) and GetIsVehicleEngineRunning(k) and (not v.upper or (v.upper and self.trailerDown)) and self.trailerOpen then
            self.vehicles[k].attached = false
            TriggerClientEvent("prp-boosting:detachEntity", NetworkGetEntityOwner(k), NetworkGetNetworkIdFromEntity(k))
        end
    end
    if LoadedBoostingContracts[self.contractId].vehEntity then
        local veh = LoadedBoostingContracts[self.contractId].vehEntity
        if DoesEntityExist(veh) and GetIsVehicleEngineRunning(veh) and #(GetEntityCoords(veh) - self.locationCoords.xyz) > 100.0 then
            self:AddProgress(1)
        end
    end
end

function StealMission:PlayRandomMinigame(source)
    local minigames = {}
    for k, v in pairs(MissionConfig.minigameConfig) do
        if k == "global" or k == LoadedBoostingContracts[self.contractId].vehicleClass:upper() then
            for minigame, options in pairs(v) do
                minigames[#minigames + 1] = { minigame, options }
            end
        end
    end

    local minigame = minigames[math.random(1, #minigames)]
    local minigameName = minigame[1]
    local minigameOptions = minigame[2]

    local minigameStatus = lib.callback.await("prp-boosting:playMinigame", source, minigameName, minigameOptions)
    return minigameStatus == true
end

RegisterNetEvent("prp-boosting:openTrailerBack", function(missionId, taskId, vehNetId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = Missions[missionId]
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId and NetworkGetEntityFromNetworkId(vehNetId) == mission.trailerVehicle then
        if MissionConfig.requiredItem then
            local hasItem = bridge.inv.hasItem(source, MissionConfig.requiredItem, 1)
            if not hasItem then
                bridge.fw.notify(source, "error", locale("DONT_HAVE_ITEM", "cutter"))
                return
            end
        end
        FreezeEntityPosition(mission.trailerVehicle, false)
        local success = lib.callback.await("prp-boosting:boltCutterAnim", source, vehNetId)
        if not success then
            bridge.fw.notify(source, "error", locale("TOO_SOY"))
            return
        end

        if MissionConfig.removeItem then
            local success = bridge.inv.removeItem(source, MissionConfig.requiredItem, 1)
            if not success then
                bridge.fw.notify(source, "error", locale("FAILED_TO_REMOVE", "the cutter"))
                return
            end
        end

        TriggerClientEvent("prp-boosting:setVehicleDoor", NetworkGetEntityOwner(mission.trailerVehicle), vehNetId, 5, true)
        mission:RemoveTargetOnVehicle(vehNetId, "open_back")
        mission:AddTargetOnVehicle(vehNetId, "move_down", {
            label = locale("SET_TRAILER_DOWN"),
            icon = "fas fa-box",
            event = "prp-boosting:setTrailerDown",
        })
        mission.trailerOpen = true
        exports["prp-bridge"]:ClearVehTempAttachObjects(mission.trailerVehicle)
    end
end)

RegisterNetEvent("prp-boosting:setTrailerDown", function(missionId, taskId, vehNetId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = Missions[missionId]
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId and NetworkGetEntityFromNetworkId(vehNetId) == mission.trailerVehicle then
        if not mission:PlayRandomMinigame(source) then return end
        TriggerClientEvent("prp-boosting:setVehicleDoor", NetworkGetEntityOwner(mission.trailerVehicle), vehNetId, 4, true)
        mission:RemoveTargetOnVehicle(vehNetId, "move_down")
        mission:AddTargetOnVehicle(vehNetId, "move_up", {
            label = locale("SET_TRAILER_UP"),
            icon = "fas fa-box",
            event = "prp-boosting:setTrailerUp",
        })
        mission.trailerDown = true
    end
end)

RegisterNetEvent("prp-boosting:setTrailerUp", function(missionId, taskId, vehNetId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = Missions[missionId]
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId and NetworkGetEntityFromNetworkId(vehNetId) == mission.trailerVehicle then
        if not mission:PlayRandomMinigame(source) then return end
        TriggerClientEvent("prp-boosting:setVehicleDoor", NetworkGetEntityOwner(mission.trailerVehicle), vehNetId, 4, false)
        mission:RemoveTargetOnVehicle(vehNetId, "move_up")
        mission:AddTargetOnVehicle(vehNetId, "move_down", {
            label = locale("SET_TRAILER_DOWN"),
            icon = "fas fa-box",
            event = "prp-boosting:setTrailerDown",
        })
        mission.trailerDown = false
    end
end)

function StealMission:GetMetadata()
    return MissionConfig.metadata
end

function StealMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

Citizen.CreateThread(function()
    RegisteredMissions["steal_trailer"] = StealMission
end)

