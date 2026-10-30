local MissionConfig = {
    chopShops = {
        {
            coords = vector3(894.673, 3606.675, 32.921),
            giveItemCoords = vector3(895.719, 3612.968, 32.824),
            dist = 10.0,
            label = locale("CHOP_SHOP_LABEL", "Sandy"),
        },
        {
            coords = vector3(105.591, 3698.472, 39.704),
            giveItemCoords = vector3(112.784, 3698.716, 39.439),
            dist = 10.0,
            label = locale("CHOP_SHOP_LABEL", "Stab City"),
        },
        {
            coords = vector3(1539.970, 6336.335, 24.075),
            giveItemCoords = vector3(1537.509, 6340.786, 24.115),
            dist = 10.0,
            label = locale("CHOP_SHOP_LABEL", "Chop Shop"),
        }
    },
    itemsToAward = { -- AMOUNT PER BODY PART
        default = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {1, 2},
            }
        },
        ['D'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {5, 10},
            }
        },
        ['C'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {8, 10},
            }
        },
        ['B'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {10, 15},
            }
        },
        ['A'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {10, 15},
            }
        },
        ['S'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {10, 15},
            }
        },
        
    },
    bonesToCheck = {
        'bonnet',
        'boot',
        'door_dside_f',
        'door_dside_r',
        'door_pside_f',
        'door_pside_r',
        'wheel_lf',
        'wheel_lr',
        'wheel_rf',
        'wheel_rr',
    },
    boneItems = {
        bonnet = {
            itemId = 'boosting_scrap_bonnet',
            itemLabel = locale('Bonnet'),
            hash = `imp_prop_impexp_bonnet_03a`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.02500000037252, 0.22499999403953, 0.14499999582767),
            rotation = vector3(-23, -1, 174.5),
        },
        boot = {
            itemId = 'boosting_scrap_boot',
            itemLabel = locale('Boot'),
            hash = `imp_prop_impexp_trunk_02a`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.05999999865889, 0.15500000119209, 0.07000000029802),
            rotation = vector3(35.5, -1, -2.5),
        },
        door_dside_f = {
            itemId = 'boosting_scrap_door_dside_f',
            itemLabel = locale("Door"),
            hash = `imp_prop_impexp_car_door_04a`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.34000000357627, -0.05999999865889, 0.23000000417232),
            rotation = vector3(-31, 49.5, 89.5),
        },
        door_dside_r = {
            itemId = 'boosting_scrap_door_dside_r',
            itemLabel = locale("Door"),
            hash = `imp_prop_impexp_car_door_04a`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.34000000357627, -0.05999999865889, 0.23000000417232),
            rotation = vector3(-31, 49.5, 89.5),
        },
        door_pside_f = {
            itemId = 'boosting_scrap_door_pside_f',
            itemLabel = locale("Door"),
            hash = `imp_prop_impexp_car_door_04a`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.34000000357627, -0.05999999865889, 0.23000000417232),
            rotation = vector3(-31, 49.5, 89.5),
        },
        door_pside_r = {
            itemId = 'boosting_scrap_door_pside_r',
            itemLabel = locale("Door"),
            hash = `imp_prop_impexp_car_door_04a`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.34000000357627, -0.05999999865889, 0.23000000417232),
            rotation = vector3(-31, 49.5, 89.5),
        },
        wheel_lf = {
            itemId = 'boosting_scrap_wheel_lf',
            itemLabel = locale("Wheel"),
            hash = `prop_wheel_03`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.02500000037252, -0.10000000149011, 0.01499999966472),
            rotation = vector3(-22.5, -62, 46),
        },
        wheel_lr = {
            itemId = 'boosting_scrap_wheel_lr',
            itemLabel = locale("Wheel"),
            hash = `prop_wheel_03`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.02500000037252, -0.10000000149011, 0.01499999966472),
            rotation = vector3(-22.5, -62, 46),
        },
        wheel_rf = {
            itemId = 'boosting_scrap_wheel_rf',
            itemLabel = locale("Wheel"),
            hash = `prop_wheel_03`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.02500000037252, -0.10000000149011, 0.01499999966472),
            rotation = vector3(-22.5, -62, 46),
        },
        wheel_rr = {
            itemId = 'boosting_scrap_wheel_rr',
            itemLabel = locale("Wheel"),
            hash = `prop_wheel_03`,
            animDict = 'anim@heists@box_carry@',
            animClip = 'idle',
            bone = 28422,
            position = vector3(-0.02500000037252, -0.10000000149011, 0.01499999966472),
            rotation = vector3(-22.5, -62, 46),
        },
    }, 
    metadata = {
        label = locale("CHOP_MISSION_LABEL"),
        startable = false,
        autoStart = true
    },
    prerequisites = {

    }
}

Citizen.CreateThread(function()
    for boneName, v in pairs(MissionConfig.boneItems) do
        local animationData = {
            priority = 1,
            dictionary = v.animDict,
            animation = v.animClip,
            prop = {
                hash = v.hash,
                bone = v.bone or 28422,
                position = v.position or vector3(0.0, 0.0, 0.0),
                rotation = v.rotation or vector3(0.0, 0.0, 0.0),
            },
        }
    end
end)

local ChopMission = {}
ChopMission.__index = ChopMission
ChopMission = setmetatable(ChopMission, Mission)

function ChopMission:OnStart(stateId, contract, groupId)
    self.shopIndex = math.random(1, #MissionConfig.chopShops)
    self.chopShop = MissionConfig.chopShops[self.shopIndex]
    
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    self.netId = netId
    local owner = NetworkGetEntityOwner(veh)
    if owner == 0 then
        self:Fail()
        return
    end

    Entity(veh).state.cutBones = {}
    self.bonesToRemove = {}
    self.itemsToTake = {}
    self.filteredBones = lib.callback.await("prp-boosting:filterVehicleBones", owner, netId, MissionConfig.bonesToCheck)
    for _, boneName in ipairs(self.filteredBones) do
        self.bonesToRemove[boneName] = true;
        self.itemsToTake[MissionConfig.boneItems[boneName].itemId] = (self.itemsToTake[MissionConfig.boneItems[boneName].itemId] or 0) + 1;
    end
    
    self:SendEventToMembers("prp-boosting:createChopShopInteractions", netId, self.shopIndex, self.chopShop.coords, self.chopShop.dist, self.bonesToRemove, self.chopShop.giveItemCoords)
    self:SendEventToMembers("prp-boosting:setMissionBlip", "chop_shop", self.chopShop.label, self.chopShop.coords, 779, 3, true)
    self:SendEventToMembers("prp-boosting:setPreviewVehicle", vector4(self.chopShop.coords.x, self.chopShop.coords.y, self.chopShop.coords.z, 0.0))
    self:SendSMSMessage(locale("CHOP_START_TEXT"), nil, "BoostWorks")
end

function ChopMission:OnDestroy(stateId, contract, groupId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    self:SendEventToMembers("prp-boosting:removeChopShopInteractions", self.shopIndex, self.netId, self.filteredBones)

    Citizen.SetTimeout(15000, function()
        if DoesEntityExist(veh) then
            LoadedBoostingContracts[self.contractId]:RemoveKeys(veh)
            DeleteEntity(veh);
        end
    end)
end

function ChopMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        self:Fail()
        return
    end
end

function ChopMission:GetMetadata()
    return MissionConfig.metadata
end

function ChopMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

local wheelMap = {
    wheel_lf = 0,
    wheel_rf = 1,
    wheel_lr = 2,
    wheel_rr = 3,
}

local doorMap = {
    door_dside_f = 0,
    door_pside_f = 1,
    door_dside_r = 2,
    door_pside_r = 3,
    bonnet = 4,
    boot = 5,
}

RegisterNetEvent("prp-boosting:removeVehicleBone", function(missionId, boneName)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.missionName == "deliver_chop" and mission.taskId == playerMission.taskId then
        local veh = LoadedBoostingContracts[mission.contractId].vehEntity
        local cutBones = Entity(veh).state.cutBones

        if not mission.bonesToRemove[boneName] then
            return
        end

        if cutBones and cutBones[boneName] then
            return
        end

        cutBones[boneName] = true
        Entity(veh).state.cutBones = cutBones;
        
        mission.bonesToRemove[boneName] = nil

        local vehicleNetId = NetworkGetNetworkIdFromEntity(veh)
        if wheelMap[boneName] then
            local entityOwnerId = NetworkGetEntityOwner(veh)
            TriggerClientEvent('prp-crime:client:scrapBreakOffVehicleWheel', entityOwnerId, vehicleNetId, wheelMap[boneName])
        end

        if doorMap[boneName] then
            SetVehicleDoorBroken(veh, doorMap[boneName], true)
        end

        bridge.inv.giveItem(source, MissionConfig.boneItems[boneName].itemId, 1, {
            missionId = missionId,
        })
    end
end)

local itemNames = {}
local itemNamesKV = {}
for boneName, v in pairs(MissionConfig.boneItems) do
    itemNames[#itemNames + 1] = v.itemId
    itemNamesKV[v.itemId] = true
end

RegisterNetEvent("prp-boosting:placeChoppedPart", function(missionId)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.missionName == "deliver_chop" and mission.taskId == playerMission.taskId then
        local search = {}
        local pInv = bridge.inv.getInventoryItems(source)
        for slot, item in pairs(pInv) do
            if itemNamesKV[item.name] and item.metadata?.missionId == missionId then
                if not search[item.name] then
                    search[item.name] = {}
                end
                search[item.name][slot] = item
            end
        end

        if not mission.removedPreview then
            mission.removedPreview = true
            mission:SendEventToMembers("prp-boosting:setPreviewVehicle")
        end
        if not next(search) then
            bridge.fw.notify(source, "error", locale("NO_CHOPPED_PARTS"));
            return
        end

        local awardCount = 0;
        for _, items in pairs(search) do
            for _, item in pairs(items) do
                if mission.itemsToTake[item.name] and mission.itemsToTake[item.name] > 0 then
                    bridge.inv.removeItem(source, item.name, 1, item.metadata, item.slot)
                    mission.itemsToTake[item.name] -= 1
                    if mission.itemsToTake[item.name] == 0 then
                        mission.itemsToTake[item.name] = nil
                    end
                    awardCount = awardCount + 1
                end
            end
        end

        local contract = LoadedBoostingContracts[mission.contractId]
        local class = contract.vehicleClass
        local awardableItems = lib.table.deepclone(MissionConfig.itemsToAward.default);

        if MissionConfig.itemsToAward[class] then
            for _, item in pairs(MissionConfig.itemsToAward[class]) do
                table.insert(awardableItems, item)
            end
        end

        local awardCounts = {};
        for i = 1, awardCount do
            local item = WeightedRandom(awardableItems)
            local amount = type(item.amount) == "table" and math.random(item.amount[1], item.amount[2]) or item.amount
            awardCounts[item.itemId] = (awardCounts[item.itemId] or 0) + amount
        end

        for itemId, amount in pairs(awardCounts) do
            bridge.inv.giveItem(source, itemId, amount)
        end

        if next(mission.itemsToTake) == nil then
            mission:AddProgress(1)
        end
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["deliver_chop"] = ChopMission
end)