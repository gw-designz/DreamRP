local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    bobLocations = {
        {
            coords = vec4(2140.5, 4818.7, 41.7, 115.9),
            locationLabel = "Grapeseed",
            npcLocations = {
                vec4(2142.1, 4815.9, 40.2, 200.0),
                vec4(2144.9, 4817.2, 40.3, 235.0),
                vec4(2130.6, 4814.1, 40.2, 112.8),
            }
        },
        {
            coords = vec4(1644.6, 3281.0, 43.7, 104.8),
            locationLabel = "Sandy Shores",
            npcLocations = {
                vec4(1644.9, 3286.4, 42.3, 15.4),
                vec4(1638.7, 3284.6, 42.3, 13.0),
                vec4(1642.1, 3274.4, 42.3, 199.3),
                vec4(1646.8, 3276.1, 42.3, 206.1),
            }
        },
    },
    stealLocations = {
        {
            coords = vec4(-1532.9538574219, -432.56701660156, 34.789794921875, 48.188972473145),
            locationLabel = "Boulevard Del Perro",
            npcLocations = {
                vec3(-1533.922729, -434.316681, 34.789795),
                vec3(-1531.984985, -430.817352, 34.789795)
            }
        },
        {
            coords = vec4(-1509.5736083984, -435.13845825195, 34.806640625, 263.6220703125),
            locationLabel = "Boulevard Del Perro",
            npcLocations = {
                vec3(-1507.646973, -435.675232, 34.806641),
                vec3(-1511.500244, -434.601685, 34.806641)
            }
        },
        {
            coords = vec4(-1374.4615478516, -447.65274047852, 33.829345703125, 34.015747070312),
            locationLabel = "South Rockford Dr",
            npcLocations = {
                vec3(-1376.175171, -446.621429, 33.829346),
                vec3(-1372.747925, -448.684052, 33.829346)
            }
        },
        {
            coords = vec4(-1349.841796875, -458.74285888672, 33.1552734375, 218.2677154541),
            locationLabel = "North Rockford Dr",
            npcLocations = {
                vec3(-1349.987671, -460.737549, 33.155273),
                vec3(-1349.695923, -456.748169, 33.155273)
            }
        },
        {
            coords = vec4(-1332.4088134766, -483.44177246094, 32.7509765625, 218.2677154541),
            locationLabel = "North Rockford Dr",
            npcLocations = {
                vec3(-1332.554688, -485.436462, 32.750977),
                vec3(-1332.262939, -481.447083, 32.750977)
            }
        },
        {
            coords = vec4(-1178.0834960938, -423.90328979492, 33.896728515625, 226.77166748047),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-1176.407227, -422.812286, 33.896729),
                vec3(-1179.759766, -424.994293, 33.896729)
            }
        },
        {
            coords = vec4(-1142.3077392578, -418.78680419922, 35.430053710938, 218.2677154541),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-1142.453613, -420.781494, 35.430054),
                vec3(-1142.161865, -416.792114, 35.430054)
            }
        },
        {
            coords = vec4(-1039.4241943359, -388.11428833008, 37.1318359375, 308.97637939453),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-1038.517578, -386.331604, 37.131836),
                vec3(-1040.330811, -389.896973, 37.131836)
            }
        },
        {
            coords = vec4(-974.61096191406, -341.22198486328, 36.9970703125, 348.6614074707),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-976.607910, -341.111298, 36.997070),
                vec3(-972.614014, -341.332672, 36.997070)
            }
        },
        {
            coords = vec4(-929.16925048828, -317.05053710938, 38.564086914062, 249.44882202148),
            locationLabel = "Marathon Ave",
            npcLocations = {
                vec3(-929.775146, -318.956543, 38.564087),
                vec3(-928.563354, -315.144531, 38.564087)
            }
        },
        {
            coords = vec4(-896.69012451172, -63.956039428711, 37.485717773438, 17.007873535156),
            locationLabel = "Mad Wayne Thunder Dr",
            npcLocations = {
                vec3(-897.225281, -65.883110, 37.485718),
                vec3(-896.154968, -62.028973, 37.485718)
            }
        },
        {
            coords = vec4(-696.27691650391, 42.118682861328, 42.557495117188, 116.22047424316),
            locationLabel = "Strangeways Dr",
            npcLocations = {
                vec3(-698.276550, 42.155590, 42.557495),
                vec3(-694.277283, 42.081776, 42.557495)
            }
        },
        {
            coords = vec4(-601.79339599609, 137.43296813965, 59.120849609375, 25.511812210083),
            locationLabel = "Spanish Ave",
            npcLocations = {
                vec3(-599.935364, 138.173080, 59.120850),
                vec3(-603.651428, 136.692856, 59.120850)
            }
        },
        {
            coords = vec4(-329.1428527832, 277.68792724609, 85.676147460938, 99.212593078613),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-328.643341, 275.751312, 85.676147),
                vec3(-329.642365, 279.624542, 85.676147)
            }
        },
        {
            coords = vec4(-208.64175415039, 281.32748413086, 91.7421875, 161.57479858398),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-209.072784, 279.374481, 91.742188),
                vec3(-208.210724, 283.280487, 91.742188)
            }
        },
        {
            coords = vec4(-145.4373626709, 242.22857666016, 94.10107421875, 263.6220703125),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-143.510742, 241.691818, 94.101074),
                vec3(-147.363983, 242.765335, 94.101074)
            }
        },
        {
            coords = vec4(-59.05054473877, 218.09671020508, 105.91284179688, 161.57479858398),
            locationLabel = "Eclipse Blvd",
            npcLocations = {
                vec3(-59.481583, 216.143707, 105.912842),
                vec3(-58.619507, 220.049713, 105.912842)
            }
        },
        {
            coords = vec4(-29.854942321777, 209.39340209961, 105.91284179688, 167.24407958984),
            locationLabel = "Las Lagunas Blvd",
            npcLocations = {
                vec3(-31.332325, 208.045319, 105.912842),
                vec3(-28.377560, 210.741486, 105.912842)
            }
        },
        {
            coords = vec4(222.73846435547, 173.57801818848, 104.59851074219, 249.44882202148),
            locationLabel = "Vinewood Blvd",
            npcLocations = {
                vec3(222.132553, 171.672012, 104.598511),
                vec3(223.344376, 175.484024, 104.598511)
            }
        },
        {
            coords = vec4(311.01098632812, 54.092308044434, 99.257202148438, 161.57479858398),
            locationLabel = "Power St",
            npcLocations = {
                vec3(310.579956, 52.139309, 99.257202),
                vec3(311.442017, 56.045307, 99.257202)
            }
        },
        {
            coords = vec4(272.8747253418, 67.31867980957, 99.257202148438, 155.90550231934),
            locationLabel = "Alta St",
            npcLocations = {
                vec3(273.647430, 65.473969, 99.257202),
                vec3(272.102020, 69.163391, 99.257202)
            }
        },
        {
            coords = vec4(285.62637329102, 8.7824182510376, 78.700317382812, 161.57479858398),
            locationLabel = "Power St",
            npcLocations = {
                vec3(285.195343, 6.829419, 78.700317),
                vec3(286.057404, 10.735417, 78.700317)
            }
        },
        {
            coords = vec4(914.74285888672, -144.72528076172, 75.296752929688, 235.27558898926),
            locationLabel = "Mirror Park Blvd",
            npcLocations = {
                vec3(912.859924, -144.051041, 75.296753),
                vec3(916.625793, -145.399521, 75.296753)
            }
        },
        {
            coords = vec4(1047.4681396484, -487.17361450195, 63.282836914062, 82.204727172852),
            locationLabel = "Bridge St",
            npcLocations = {
                vec3(1049.200439, -486.174103, 63.282837),
                vec3(1045.735840, -488.173126, 63.282837)
            }
        },
    },
    metadata = {
        label = "Capture the vehicle using Cargobob",
        startable = true,
        isCheckpoint = true,
    },
    prerequisites = {
        {
            label = "Lockpick",
            type = "ITEM",
            value = "lockpick",
        },
    },
}

local StealMission = {}
StealMission.__index = StealMission
StealMission = setmetatable(StealMission, Mission)

function StealMission:OnStart(stateId, contract, groupId)
    local bobLocations = MissionConfig.bobLocations
    local freeBobLocations = {}
    for k, v in pairs(bobLocations) do
        if not takenLocations[k] then
            table.insert(freeBobLocations, k)
        end
    end
    if #freeBobLocations == 0 then
        return self:Cancel()
    end
    local bobLocation = freeBobLocations[math.random(1, #freeBobLocations)]
    takenLocations[bobLocation] = true

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

    self.bobLocation = bobLocation
    self.bobCoords = bobLocations[bobLocation].coords
    self.bobRadius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    self.bobCenter = self.bobCoords.xyz
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", "Cargobob Location", self.bobCenter.xyz, self.bobRadius, 225, 3)
    local locationLabel = bobLocations[bobLocation].locationLabel
    self:SendSMSMessage(("Got a interesting job for you. Cargobob at %s — steal it and I'll provide more details."):format(locationLabel), nil, "BoostWorks")
end

function StealMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        stealLocations[self.location].taken = nil
    end
    if self.bobLocation then
        takenLocations[self.bobLocation] = nil
    end
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if not LoadedBoostingContracts[self.contractId].vehEntity and tickId % 5 == 0 and self.stolenBob and self.locationCoords and self:IsAnyMemberCloseToCoords(vector3(self.locationCoords.x, self.locationCoords.y, self.locationCoords.z), 250.0) then
        self:SpawnContractVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords)
        local vehEntity = LoadedBoostingContracts[self.contractId].vehEntity
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
        SetVehicleDoorsLocked(vehEntity, 2)
        Entity(vehEntity).state.Locked = true
        Entity(vehEntity).state.DisableLockpick = true
        self:SendEventToMembers("prp-boosting:cargobobWaitingThread", self.taskId, NetworkGetNetworkIdFromEntity(vehEntity))
    end

    if not self.cargobob and tickId % 5 == 0 and self.bobCoords and self:IsAnyMemberCloseToCoords(vector3(self.bobCoords.x, self.bobCoords.y, self.bobCoords.z), 250.0) then
        self:NpcCheck(MissionConfig.bobLocations[self.bobLocation].npcLocations)
        self.cargobob = self:SpawnVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.bobCoords, `cargobob`, 60)
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(self.cargobob), NetworkGetNetworkIdFromEntity(self.cargobob))
        SetVehicleDoorsLocked(self.cargobob, 2)
        Entity(self.cargobob).state.Locked = true
    end

    if self.cargobob and not self.stolenBob and GetIsVehicleEngineRunning(self.cargobob) then
        self.stolenBob = true
        self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", "Search Area", self.center.xyz, self.radius, 225, 3)
        local stealLocations = MissionConfig.useSharedLocations and Config.SharedLocations[MissionConfig.useSharedLocations] or MissionConfig.stealLocations
        local locationLabel = stealLocations[self.location].locationLabel
        self:SendSMSMessage(("Vehicle at %s — pick it up and fly away."):format(locationLabel), nil, "BoostWorks")
    end
end

function StealMission:GetMetadata()
    return MissionConfig.metadata
end

function StealMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

RegisterNetEvent("prp-boosting:cargobobAttached", function(missionId)
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId then
        mission:AddProgress(1)
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["steal_cargobob"] = StealMission
end)