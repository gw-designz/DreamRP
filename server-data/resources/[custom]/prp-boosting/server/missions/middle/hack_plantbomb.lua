local MissionConfig = {
    hackTriesCooldown = 60,
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
    metadata = {
        label = "Disable the GPS and plant a bomb",
        autoStart = true,
        genTarget = { 2, 4 },
        isHackMission = true,
    },
    -- All genTargets must be greater than 2
    genTargetClasses = {
        D = { 2, 2 },
        C = { 2, 3 },
        B = { 3, 5 },
        A = { 4, 6 },
        S = { 6, 10 },
        X = { 12, 16 },
    },
    prerequisites = {},
    plantSpots = {
        {
            vehCoords = vec4(1150.2, -775.2, 57.0, 358.0),
            bombCoords = vec4(1154.500000, -780.299988, 57.599998, 272.899994),
            bombModel = `sf_prop_sf_art_ex_pe_01a`,
        },
    },
    plantTime = 10000,
}

local HackMission = {}
HackMission.__index = HackMission
HackMission = setmetatable(HackMission, Mission)

function HackMission:OnStart(stateId, contract, groupId)
    self.addonData.lastTry = nil
    self.addonData.lastPing = 0

    self:SendSMSMessage("You’re in, but so is the GPS. Get the GPS out and I'll send you the place to plant a bomb", nil, "BoostWorks")
    local source = bridge.fw.getSrcFromIdentifier(stateId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    local coords = GetEntityCoords(veh)
    if math.random(1, 100) > MissionConfig.trackerConfig[contract.vehicleClass].dispatchChance then
        return
    end
    local title = contract.vehicleModelLabel .. "(" .. contract.vehicleClass .. ") stolen"
    local description = "A vehicle has been stolen with a GPS tracker"
    if contract.contractType ~= "boosting" then
        description = "A high value vehicle has been stolen with a GPS tracker"
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

function HackMission:OnDestroy(stateId, contract, groupId)
    
end

function HackMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
    local currentTime = os.time()
    if not contract then return end

    local inPlantStep = (self:GetProgress() >= self:GetTarget()-1)
    if inPlantStep then
        -- wait for the player to plant the bomb
        return
    end

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
end

function HackMission:GetMetadata(contract)
    local metadata = lib.table.deepclone(MissionConfig.metadata)
    if contract and contract.vehicleClass then
        metadata.genTarget = MissionConfig.genTargetClasses[contract.vehicleClass] or metadata.genTarget
    end
    return metadata
end

function HackMission:GetPrerequisites(contract)
    local itemName = string.lower(("boosting_hack_%s"):format(contract.vehicleClass))
    local itemLabel = bridge.inv.getItemLabel(itemName)
    return {
        {
            label = itemLabel or "Pendrive",
            type = "ITEM",
            value = itemName,
        },
    }
end

function HackMission:OnProgress(progress)
    if progress == self:GetTarget()-1 then
        self:SendSMSMessage("The GPS is disabled, now you need to plant the bomb.", nil, "BoostWorks")
        local spot = MissionConfig.plantSpots[math.random(1, #MissionConfig.plantSpots)]
        self:SendEventToMembers("prp-boosting:setMissionBlip", "plant_bomb", "Bomb Location", spot.vehCoords.xyz, 486, 3, true)
        self:SendEventToMembers("prp-boosting:setPreviewVehicle", spot.vehCoords)
        self.bombObject = self:CreateLocalObject(spot.bombModel, spot.bombCoords, true, false)
        self:AddLocalObjectTarget(self.bombObject, "take_bomb", {
            label = "Pick up the bomb",
            icon = "fas fa-hands",
            event = "prp-boosting:takeBomb",
        })
    end
end

RegisterNetEvent("prp-boosting:takeBomb", function(missionId, objectId)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.missionName == "middle_hack_plantbomb" and mission.taskId == playerMission.taskId then
        if mission:GetProgress() ~= mission:GetTarget()-1 then
            return
        end
        TriggerClientEvent("prp-boosting:playAnim", source, "anim@scripted@player@freemode@gen_grab@male@", "med_rh", -1, 0)
        Citizen.Wait(1000)
        mission.tookBomb = true
        mission:RemoveLocalObject(mission.bombObject)
        mission.bombObject = nil
        mission:SendNotificationToMembers("success", "Now plant the bomb underneath the vehicle...")
        local veh = LoadedBoostingContracts[mission.contractId].vehEntity
        mission:AddTargetOnVehicle(NetworkGetNetworkIdFromEntity(veh), "plant_bomb", {
            label = "Plant the bomb",
            icon = "fas fa-bomb",
            event = "prp-boosting:plantBomb",
        })
        mission:SendEventToMembers("prp-boosting:setPreviewVehicle")
    end
end)

RegisterNetEvent("prp-boosting:plantBomb", function(missionId, objectId)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.missionName == "middle_hack_plantbomb" and mission.taskId == playerMission.taskId then
        if not mission.tookBomb then
            return
        end
        SetEntityHeading(GetPlayerPed(source), (GetEntityHeading(LoadedBoostingContracts[mission.contractId].vehEntity) + 90.0))
        Citizen.Wait(100)
        local success = lib.callback.await("prp-boosting:progressBar", source, "Planting the bomb", MissionConfig.plantTime, "amb@world_human_vehicle_mechanic@male@base", "base", true, nil)
        if not success then
            bridge.fw.notify(source, "error", "You failed to plant the bomb")
            return
        end
        mission:RemoveTargetOnVehicle(NetworkGetNetworkIdFromEntity(LoadedBoostingContracts[mission.contractId].vehEntity), "plant_bomb")
        mission.tookBomb = nil
        mission:AddProgress(1)
    end
end)

function HackMission:GetTarget(actuatorType)
    local target = LoadedBoostingContracts[self.contractId].missions[self.taskContractId].target
    if actuatorType == "hack" then
        return target-1
    end
    return target
end

Citizen.CreateThread(function()
    RegisteredMissions["middle_hack_plantbomb"] = HackMission
end)
