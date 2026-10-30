local takenLocations = {}
local MissionConfig = {
    radius = { 100.0, 150.0 },
    villas = {
        {
            coords = vec3(26.3,541.9,176.7),
            garagePanel = {
                coords = vec4(26.3,541.9,176.2,62.1),
                model = `m23_1_prop_m31_controlpanel_02a`,
            },
            vehCoords = vector4(22.3, 544.4, 175.4, 60.7),
            garage = {
                model = `prop_ch_025c_g_door_01`,
                coords = vec3(18.6,546.4,176.5), 
            },
            locationLabel = "3671 Whispymound Drive",
            npcLocations = {
                vec4(9.2, 535.4, 175.0, 23.0),
                vec4(-4.0, 527.5, 174.0, 164.8),
                vec4(-6.5, 516.4, 173.6, 333.7),
                vec4(4.0, 534.9, 169.6, 281.3),
                vec4(2.5, 526.1, 169.6, 155.1),
                vec4(19.2, 525.9, 169.2, 2.2),
            },
            carKeys = {
                model = `sf_prop_sf_car_keys_01a`,
                coords = {
                    vec4(1.4, 527.9, 170.5, 32.8),
                    vec4(-0.6,535.4,174.8,303.1),
                    vec4(-8.1,530.8,174.9,40.9),
                    vec4(-8.6,517.9,174.6,244.5),
                }
            }
        }
    },
    metadata = {
        label = "Steal the keys and the vehicle from the Villa",
        startable = true,
        isCheckpoint = true,
    },
    minigameConfig = {
        global = {
            ["snake"] = {
                requiredLength =  10,
                x =  20,
                y =  20,
                speed =  10,
            },
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
                dotCount =  32,
                speed =  0.0035,
            },
            ["circleRun"] = {
                time =  20000,
                circleSpeed =  2*math.pi / 5000,
                minDist =  math.pi / 8,
            },
            ["spaceInvaders"] = {
                enemyCount =  45,
                enemyInterval =  500,
                enemySpeed =  0.3,
                enemyManoeuvre =  true,
            },
            ["circleColors"] = {
                attackCount =  24,
                speed =  0.3,
            }
        },
        B = {
            ["buttonClicker"] = {
                time = 3500,
                clickTime = 9500,
            },
            ["jumper"] = {
                cameraSpeed =  0.1,
                platformCount =  10,
                hardMode =  false,
            },
            ["superCircle"] = {
                time =  20000,
                globalRotSpeed =  2*math.pi/10000,
                rotSpeed =  2*math.pi/6000,
                speed =  0.5/1750,
                targetDist =  0.2,
            },
            ["blockman"] = {
                time =  30000,
                blockCount =  60,
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
                speed = 0.5,
                laneCount = 5,
                waveCount = 10,
                isOncoming = true,
                hasBlockades = true,
            },
            ["bubbles"] = {
                time =  45000,
                speed =  math.pi/16,
                layerCount =  4,
            }
        },
        S = {
            ["gtHero"] = {
                dotCount =  12,
                speed =  0.0030,
            },
            ["buttonClicker"] = {
                time = 3500,
                clickTime = 9500,
            },
            ["jumper"] = {
                cameraSpeed =  0.1,
                platformCount =  10,
                hardMode =  false,
            },
            ["superCircle"] = {
                time =  20000,
                globalRotSpeed =  2*math.pi/10000,
                rotSpeed =  2*math.pi/6000,
                speed =  0.5/1750,
                targetDist =  0.2,
            },
            ["spaceInvaders"] = {
                enemyCount =  45,
                enemyInterval =  500,
                enemySpeed =  0.3,
                enemyManoeuvre =  true,
            },
            ["circleColors"] = {
                attackCount =  24,
                speed =  0.3,
            }
        },
        X = {

        }

    },
    minigameCount = {
        D = { 1, 2 },
        C = { 2, 3 },
        B = { 3, 4 },
        A = { 4, 5 },
        S = { 5, 6 },
        X = { 6, 7 },
    },
    requiredItem = "pdm_blowtorch",
    removeItem = true,
    cuttingTime = 10000,
    prerequisites = {
        {
            label = "Lockpick",
            type = "ITEM",
            value = "lockpick",
        },
        {
            label = "Blowtorch",
            type = "ITEM",
            value = "pdm_blowtorch",
        },
    },
}

local StealMission = {}
StealMission.__index = StealMission
StealMission = setmetatable(StealMission, Mission)

function StealMission:OnStart(stateId, contract, groupId)
    local locations = {}
    for k, v in pairs(MissionConfig.villas) do
        if not takenLocations[k] then
            table.insert(locations, k)
        end
    end
    if #locations == 0 then
        self:SendNotificationToMembers("error", "No spots available, try again later")
        return self:Cancel()
    end
    local location = locations[math.random(1, #locations)]
    takenLocations[location] = true
    self.location = location
    self.villa = MissionConfig.villas[location]
    self.radius = math.random(MissionConfig.radius[1], MissionConfig.radius[2])
    local randomAngle = math.random() * (2 * math.pi)
    local unitVector = vector3(math.cos(randomAngle), math.sin(randomAngle), 0)
    self.center = self.villa.coords.xyz + (unitVector * math.sqrt(math.random()) * self.radius)
    self:SendEventToMembers("prp-boosting:setMissionRadiusBlip", "veh", "Search Area", self.center.xyz, self.radius, 225, 3)
    TriggerClientEvent("prp-boosting:setGarageClosed", -1, "villa_"..location, self.villa.garage)
    self:SpawnGaragePanel()
    self:SpawnKeys()
    local locationLabel = MissionConfig.villas[location].locationLabel
    self:SendSMSMessage(("There's a beauty locked away in a Villa at %s. Sneak in there get the keys and drive it off. You may have some resistance on site."):format(locationLabel), nil, "BoostWorks")
end

function StealMission:SpawnGaragePanel()
    local garagePanel = self.villa.garagePanel
    self.garagePanel = self:CreateLocalObject(garagePanel.model, garagePanel.coords, true, true)
    self:AddLocalObjectTarget(self.garagePanel, "villa_garage_panel", {
        name = "villa_garage_panel",
        label = "Tamper with the Garage Panel",
        icon = "fas fa-wrench",
        event = "prp-boosting:tamperGaragePanel",
    })
end

function StealMission:SpawnKeys()
    local keys = self.villa.carKeys
    self.keyCoords = keys.coords[math.random(1, #keys.coords)]
    self.key = self:CreateLocalObject(keys.model, self.keyCoords, true, true)
    self:AddLocalObjectTarget(self.key, "villa_keys", {
        name = "villa_keys",
        label = "Pick up the keys",
        icon = "fas fa-key",
        event = "prp-boosting:pickUpKeys",
    })
end

function StealMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        TriggerClientEvent("prp-boosting:removeGarage", -1, "villa_"..self.location)
        takenLocations[self.location] = nil
    end
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if not LoadedBoostingContracts[self.contractId].vehEntity and tickId % 5 == 0 and self.villa?.coords and self:IsAnyMemberCloseToCoords(vector3(self.villa.coords.x, self.villa.coords.y, self.villa.coords.z), 250.0) then
        self:SpawnContractVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.villa.vehCoords)
        self:NpcCheck(self.villa.npcLocations, true, 7.5)
        local vehEntity = LoadedBoostingContracts[self.contractId].vehEntity
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
        SetVehicleDoorsLocked(vehEntity, 2)
        Entity(vehEntity).state.Locked = true
        Entity(vehEntity).state.DisableLockpick = true
    end
    if LoadedBoostingContracts[self.contractId].vehEntity then
        local veh = LoadedBoostingContracts[self.contractId].vehEntity
        if GetIsVehicleEngineRunning(veh) then
            self:AddProgress(1)
        end
    end
end

function StealMission:GetMetadata()
    return MissionConfig.metadata
end

function StealMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

RegisterNetEvent("prp-boosting:tamperGaragePanel", function(missionId, locationId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = GetActiveMissionByStateId(stateId)
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if mission and mission.missionName == "steal_villa" and #(playerCoords - mission.villa.garagePanel.coords.xyz) < 10.0 and not mission.addonData.garageOpen then
        TriggerClientEvent("prp-boosting:playAnim", source, "anim@scripted@charlie_missions@mission_5@ig1_avi_hacking@", "hack", -1, 1)
        local class = LoadedBoostingContracts[mission.contractId].vehicleClass
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
    
        local minigameStatus = true
        for i=1, math.random(MissionConfig.minigameCount[class:upper()][1], MissionConfig.minigameCount[class:upper()][2]) do
            local status = lib.callback.await("prp-boosting:playMinigame", source, minigameName, minigameOptions)
            if status ~= true and not Config.Debug then
                minigameStatus = false
                break
            end
        end
        TriggerClientEvent("prp-boosting:stopAnim", source, "anim@scripted@charlie_missions@mission_5@ig1_avi_hacking@", "hack")
        if minigameStatus then
            mission.addonData.garageOpen = true
            mission:SendSMSMessage("You have successfully tampered with the garage panel. The garage is now unlocked. ".. (mission.addonData.gotKey and "You have the key already, drive off!" or "Now go and find a key somewhere in the house"), nil, "BoostWorks")
            TriggerClientEvent("prp-boosting:removeGarage", -1, "villa_"..mission.location)
            mission:RemoveLocalObjectTarget(mission.garagePanel, "villa_garage_panel")
        end
    end
end)

RegisterNetEvent("prp-boosting:pickUpKeys", function()
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = GetActiveMissionByStateId(stateId)
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    if mission and mission.missionName == "steal_villa" and #(playerCoords - mission.keyCoords.xyz) < 10.0 and not mission.addonData.gotKey then
        mission.addonData.gotKey = true
        TriggerClientEvent("prp-boosting:playAnim", source, "anim@scripted@player@freemode@gen_grab@male@", "med_rh", -1, 0)
        Citizen.Wait(1000)
        mission:RemoveLocalObject(mission.key)
        mission.key = nil
        mission:SendSMSMessage("You have successfully picked up the keys. ".. (mission.addonData.garageOpen and "Now go and drive off with the car." or "Tamper with the garage panel to open it and drive off."), nil, "BoostWorks")
        bridge.vkeys.give(source, LoadedBoostingContracts[mission.contractId].vehEntity)
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["steal_villa"] = StealMission
end)