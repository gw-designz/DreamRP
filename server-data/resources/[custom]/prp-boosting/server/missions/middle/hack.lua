local MissionConfig = {
    hackTriesCooldown = 60,
    minigameConfig = {
        global = {
            -- ["snake"] = {
            --     requiredLength =  10,
            --     x =  20,
            --     y =  20,
            --     speed =  10,
            -- },
        },
        D = {
            ["noHesi"] = {
                time =  30000,
                speed =  0.35,
                laneCount =  5,
                waveCount =  10,
            },
            ["gtHero"] = {
                dotCount =  12,
                speed =  0.0030,
            },
            ["spaceInvaders"] = {
                enemyCount =  45,
                enemyInterval =  700,
                enemySpeed =  0.25,
                enemyManoeuvre =  true,
            },
            ["circleColors"] = {
                attackCount =  12,
                speed =  0.2,
            }
        },
        C = {
            ["gtHero"] = {
                dotCount = 24,
                speed = 0.0045,
            },
            ["circleRun"] = {
                time =  20000,
                circleSpeed =  2*math.pi / 5000,
                minDist =  math.pi / 8,
            },
            ["spaceInvaders"] = {
                enemyCount =  45,
                enemyInterval =  500,
                enemySpeed =  0.35,
                enemyManoeuvre =  true,
            },
            ["circleColors"] = {
                attackCount = 24,
                speed = 0.35,
            }
        },
        B = {
            ["buttonClicker"] = {
                time = 3500,
                clickTime = 9500,
            },
            ["jumper"] = {
                cameraSpeed = 0.1,
                platformCount = 10,
                hardMode = false,
            },
            ["superCircle"] = {
                time = 20000,
                globalRotSpeed = 2*math.pi/10000,
                rotSpeed = 2*math.pi/6000,
                speed = 0.5/1750,
                targetDist = 0.2,
            },
            ["blockman"] = {
                time =  30000,
                blockCount =  70,
            },
        },
        A = {
            ["keyBuilder"] = {
                blockSize = 0.2,
                blockCount = 15,
                speed = 0.5,
                speedup = 0.025,
            },
            ["spikeAvoider"] = {
                time =  45000,
                speed =  0.4,
                laneCount =  4,             
            },
            ["roadCrossing"] = {
                time =  300000,
                speed =  0.2,
                laneCount =  4,
            },
            ["noHesi"] = {
                time = 30000,
                speed = 0.55,
                laneCount = 5,
                waveCount = 10,
                isOncoming = false,
                hasBlockades = false,
            },
            ["bubbles"] = {
                time =  45000,
                speed =  math.pi/16,
                layerCount =  4,
            }
        },
        S = {
            ["keyBuilder"] = {
                blockSize = 0.2,
                blockCount = 15,
                speed = 0.5,
                speedup = 0.025,
            },
            ["spikeAvoider"] = {
                time =  45000,
                speed =  0.5,
                laneCount =  4,             
            },
            ["roadCrossing"] = {
                time =  300000,
                speed =  0.3,
                laneCount =  4,
            },
            ["noHesi"] = {
                time = 30000,
                speed = 0.6,
                laneCount = 5,
                waveCount = 12,
                isOncoming = false,
                hasBlockades = false,
            },
            ["bubbles"] = {
                time =  45000,
                speed =  math.pi/16,
                layerCount =  5,
            }
        },
        X = {

        }

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
        D = { 1, 1 },
        C = { 1, 2 },
        B = { 3, 5 },
        A = { 4, 6 },
        S = { 6, 10 },
        X = { 12, 16 },
    },
    metadata = {
        label = locale("MIDDLE_MISSION_HACK_BOMB_LABEL"),
        autoStart = true,
        genTarget = { 2, 3 },
        isHackMission = true,
    },
    prerequisites = {},
    minimalSpeed = 15, -- mph
}

local HackMission = {}
HackMission.__index = HackMission
HackMission = setmetatable(HackMission, Mission)

function HackMission:OnStart(stateId, contract, groupId)
    self.addonData.lastTry = nil
    self.addonData.lastPing = 0

    self:SendSMSMessage(locale("MIDDLE_MISSION_HACK_START_TEXT"), nil, "BoostWorks")
    local source = bridge.fw.getSrcFromIdentifier(stateId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    local coords = GetEntityCoords(veh)
    if math.random(1, 100) > MissionConfig.trackerConfig[contract.vehicleClass].dispatchChance then
        return
    end
    local title = contract.vehicleModelLabel .. "(" .. contract.vehicleClass .. ") stolen"
    local description = locale("MIDDLE_MISSION_HACK_BOMB_PD_ALERT")
    if contract.contractType ~= "boosting" then
        description = locale("MISSION_MISSION_H_VAL_VEH_ALERT")
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
            label = itemLabel or locale("Pendrive"),
            type = "ITEM",
            value = itemName,
        },
    }
end

Citizen.CreateThread(function()
    for k,v in pairs(Config.UnlockDrops) do
        local itemName = string.format("boosting_hack_%s", k:lower())
        bridge.fw.registerItemUse(itemName, function(src, item)
            PerformVehicleGPSHack(src, k)
        end)
    end
end)

function PerformVehicleGPSHack(src, class)
    local stateId = bridge.fw.getIdentifier(src)
    local mission = GetActiveMissionByStateId(stateId)

    if not mission then
        bridge.fw.notify(src, 'error', locale("NO_GPS_MODULE"))
        return { status = false, message = locale("NO_GPS_MODULE")}
    end

    if not mission:GetMetadata(LoadedBoostingContracts[mission.contractId])?.isHackMission then
        bridge.fw.notify(src, 'error', locale("NO_GPS_MODULE"))
        return
    end
    
    local ped = GetPlayerPed(src)
    if not DoesEntityExist(ped) then
        bridge.fw.notify(src, 'error', locale("UNHANDLED_EXCEPTION"))
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not DoesEntityExist(vehicle) then
        bridge.fw.notify(src, 'error', locale("NO_VEHICLE_FOUND"))
        return
    end

    if GetEntitySpeed(vehicle) < (MissionConfig.minimalSpeed * 0.44704) then -- Convert mph to m/s
        bridge.fw.notify(src, 'error', locale("VEHICLE_HACK_TOO_SLOW", MissionConfig.minimalSpeed))
        return
    end
    
    local contract = LoadedBoostingContracts[mission.contractId]
    local isLastMissionTowTruck = LoadedBoostingContracts[mission.contractId].missions[mission.taskContractId-1]?.name == "steal_towtruck"
    local isLastMissionCargobob = LoadedBoostingContracts[mission.contractId].missions[mission.taskContractId-1]?.name == "steal_cargobob"
    if vehicle ~= contract.vehEntity
    and (mission.missionName ~= "middle_hacker_van" or mission.hackerVan ~= vehicle)
    and (
        not isLastMissionTowTruck or (isLastMissionTowTruck and (GetEntityModel(vehicle) ~= `towtruck`)
        or not lib.callback.await("prp-boosting:isVehicleAttachedToTowTruck", src, NetworkGetNetworkIdFromEntity(contract.vehEntity))
        ))
    and (
        not isLastMissionCargobob and (isLastMissionCargobob and (GetEntityModel(vehicle) ~= `cargobob`))
        or not lib.callback.await("prp-boosting:isVehicleAttachedToCargobob", src, NetworkGetNetworkIdFromEntity(contract.vehEntity))
    ) then
        bridge.fw.notify(src, 'error', locale("NO_GPS_MODULE"))
        return
    end

    if mission.missionName == "middle_hacker_van" and (not mission.hackerVan or (#(GetEntityCoords(mission.hackerVan) - GetEntityCoords(contract.vehEntity)) > mission.vanRadius)) then
        bridge.fw.notify(src, 'error', locale("NEED_TO_BE_CLOSE_TO_TARGET"))
        return
    end

    local contractClass = contract.vehicleClass

    if class ~= contractClass then
        bridge.fw.notify(src, 'error', locale("DEVICE_INCOMPATIBLE_2"))
        return
    end

    if mission.addonData.lastTry and os.time() - mission.addonData.lastTry < MissionConfig.hackTriesCooldown then
        bridge.fw.notify(src, 'error', locale("VEHICLE_HACK_YOU_MUST_WAIT", math.max(0, (MissionConfig.hackTriesCooldown - (os.time() - mission.addonData.lastTry)))))
        return
    end

    local targetHacks = mission:GetTarget("hack")
    if mission:GetProgress() >= targetHacks then
        bridge.fw.notify(src, 'success', locale("GPS_BREACH_SUCESSFULL"))
        return
    end

    local minigames = {}
    for k, v in pairs(MissionConfig.minigameConfig) do
        if k == "global" or k == class:upper() then
            for minigame, options in pairs(v) do
                minigames[#minigames + 1] = { minigame, options }
            end
        end
    end

    local minigame = minigames[math.random(1, #minigames)]
    local minigameName = minigame[1]
    local minigameOptions = MissionConfig.minigameConfig[class:upper()][minigameName] or minigame[2]

    mission.addonData.lastTry = os.time()
    local minigameStatus = lib.callback.await("prp-boosting:playMinigame", src, minigameName, minigameOptions)
    if Config.Debug then
        minigameStatus = true
    end
    if not minigameStatus or (minigameStatus ~= true) then
        bridge.fw.notify(src, 'error', locale("GPS_BREACH_FAILED"))
        return
    end

    if mission.missionName == "middle_hacker_van" and (not mission.hackerVan or (#(GetEntityCoords(mission.hackerVan) - GetEntityCoords(contract.vehEntity)) > mission.vanRadius)) then
        bridge.fw.notify(src, 'error', locale("NEED_TO_BE_CLOSE_TO_TARGET"))
        return
    end

    mission:AddProgress(1)
    if mission:GetProgress() >= targetHacks then
        bridge.fw.notify(src, 'success', locale("GPS_BREACH_SUCESSFULL"))
        return
    end

    bridge.fw.notify(src, 'inform', locale("GPS_BREACH_SHOW_PROGRESS", mission:GetProgress(), mission:GetTarget()))
end

Citizen.CreateThread(function()
    RegisteredMissions["middle_hack"] = HackMission
end)