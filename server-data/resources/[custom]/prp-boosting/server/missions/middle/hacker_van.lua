local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    metadata = {
        label = locale("MIDDLE_MISSION_HACKER_VAN_LABEL"),
        autoStart = true,
        genTarget = { 2, 3 },
        isHackMission = true,
    },
    prerequisites = {
        {
            label = locale("Lockpick"),
            type = "ITEM",
            value = "lockpick",
        },
        {
            label = locale("Pendrive"),
            type = "ITEM",
            value = "boosting_hack_",
            addClassItem = true
        },
    },
    trackerConfig = {
        D = {
            pingInterval = 10,
            blipColor = 26,
            dispatchChance = 0,
        },
        C = {
            pingInterval = 8,
            blipColor = 24,
            dispatchChance = 25,
        },
        B = {
            pingInterval = 6,
            blipColor = 46,
            dispatchChance = 50,
        },
        A = {
            pingInterval = 4,
            blipColor = 61,
            dispatchChance = 100,
        },
        S = {
            pingInterval = 2,
            blipColor = 5,
            dispatchChance = 100,
        },
        X = {
            pingInterval = 1,
            blipColor = 59,
            dispatchChance = 100,
        }
    },
    genTargetClasses = {
        D = { 4, 5 },
        C = { 6, 8 },
        B = { 2, 4 },
        A = { 4, 8 },
        S = { 6, 10 },
        X = { 12, 16 },
    },
    useSharedLocations = "normal",
    hackerVanRadius = 300.0,
}

local VanMission = {}
VanMission.__index = VanMission
VanMission = setmetatable(VanMission, Mission)

function VanMission:OnStart(stateId, contract, groupId)
    self.addonData.lastTry = nil
    self.addonData.lastPing = 0
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
    self.radius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    self.center = self.locationCoords.xyz + (unitVector * math.sqrt(math.random()) * self.radius)

    self.truckCoords = stealLocations[location].coords
    self.truckRadius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    self.truckCenter = self.truckCoords.xyz
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", locale("HACKER_VAN_LOCATION"), self.truckCenter.xyz, self.truckRadius, 225, 3)
    local locationLabel = stealLocations[location].locationLabel
    self:SendSMSMessage(locale("HACKER_VAN_TEXT_LOCATION", locationLabel), nil, "BoostWorks")
    local source = bridge.fw.getSrcFromIdentifier(stateId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    local coords = GetEntityCoords(veh)
    if math.random(1, 100) > MissionConfig.trackerConfig[contract.vehicleClass].dispatchChance then
        return
    end
    local title = contract.vehicleModelLabel .. "(" .. contract.vehicleClass .. ") stolen"
    local description = locale("MIDDLE_MISSION_HACK_BOMB_PD_ALERT")
    if contract.contractType ~= "boosting" then
        description = locale("MIDDLE_MISSION_HACK_BOMB_PD_ALERT")
    end
    local blip = {
        sprite = 326,
        scale = 1.2,
        colour = 1,
        length = 2,
        flash = false,
        text = title,
    }
    bridge.dispatch.sendAlert(source, exports["prp-bridge"]:GetPoliceJobs(), coords, {
        title = title,
        description = description,
        code = "10-31A",
    }, blip, false)
end

function VanMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        stealLocations[self.location].taken = nil
    end
end

function VanMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
    local currentTime = os.time()
    if not contract then return end
    local pingInterval = MissionConfig.trackerConfig[contract.vehicleClass].pingInterval or 1
    local blipColor = MissionConfig.trackerConfig[contract.vehicleClass].blipColor or 1
    if currentTime - self.addonData.lastPing < pingInterval then
        return
    end

    self.addonData.lastPing = currentTime
    local vehicle = contract.vehEntity
    if not DoesEntityExist(vehicle) then return end

    local sendTable = {
        self.taskId,
        NetworkGetNetworkIdFromEntity(vehicle),
        GetEntityCoords(vehicle),
        contract.vehicleModelLabel,
        pingInterval,
        blipColor
    }

    local policePlayers = exports["prp-bridge"]:GetPoliceOnDuty(true)
    local msg = msgpack.pack_args(sendTable)
    local msgLen = msg:len()
    for src, _ in pairs(policePlayers) do
        TriggerClientEventInternal("prp-boosting:hack:trackerUpdate", tostring(src), msg, msgLen)
    end

    if not self.hackerVan and tickId % 5 == 0 and self.truckCoords and self:IsAnyMemberCloseToCoords(vector3(self.truckCoords.x, self.truckCoords.y, self.truckCoords.z), 250.0) then
        self.hackerVan = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.truckCoords, `burrito4`)
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(self.hackerVan), NetworkGetNetworkIdFromEntity(self.hackerVan))
        SetVehicleDoorsLocked(self.hackerVan, 2)
        self.vanRadius = MissionConfig.hackerVanRadius
        Entity(self.hackerVan).state.Locked = true
    end

    if self.hackerVan and not self.stolenHackerVan and GetIsVehicleEngineRunning(self.hackerVan) then
        self.stolenHackerVan = true
        self:SendEventToMembers("prp-boosting:clearBlips")
    end
    if self.stolenHackerVan and DoesEntityExist(self.hackerVan) then
        self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "van", locale("HACKER_VAN"), GetEntityCoords(self.hackerVan), self.vanRadius, 67, 2)
    end
end

function VanMission:GetMetadata(contract)
    local metadata = lib.table.deepclone(MissionConfig.metadata)
    if contract and contract.vehicleClass then
        metadata.genTarget = MissionConfig.genTargetClasses[contract.vehicleClass] or metadata.genTarget
    end
    return metadata
end

function VanMission:GetPrerequisites()
    return MissionConfig.prerequisites
end


Citizen.CreateThread(function()
    RegisteredMissions["middle_hacker_van"] = VanMission
end)