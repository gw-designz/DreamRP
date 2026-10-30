local VehiclesByClass = {}

Citizen.CreateThread(function()
    while not HasVehiclesBeenFetched do
        Citizen.Wait(10)
    end
    for k, v in pairs(Config.Vehicles) do
        if not VehiclesByClass[v.class] then
            VehiclesByClass[v.class] = {}
        end
        v.modelName = k
        table.insert(VehiclesByClass[v.class], v)
    end
end)

function GetVinscratchChanceByLevel(userLevel)
    local chance = 0;
    for k, v in pairs(Config.VinScratchChance) do
        if k <= userLevel and v > chance then
            chance = v
        end
    end

    if(not chance) then return 0 end

    -- We want the chance to be `chance` out of 3 tries so
    return 1 - (1-chance) ^ (1/3)
end

function GetVehicleFromClass(class, skipModels)
    if VehiclesByClass[class] then
        if skipModels then
            local availableModels = {}
            for k, v in pairs(VehiclesByClass[class]) do
                if not skipModels[v.modelName] then
                    table.insert(availableModels, v)
                end
            end

            if #availableModels == 0 then return nil end

            return availableModels[math.random(1, #availableModels)]
        end
        return VehiclesByClass[class][math.random(1, #VehiclesByClass[class])]
    end
end

function WeightedRandom(tbl, key, validateFunc)
    local totalWeight = 0
    local validateCache = {};
    if not tbl then return nil end

    for k, v in pairs(tbl) do
        if validateFunc and not validateFunc(k, v)  then
            validateCache[v] = true
        else
            totalWeight = totalWeight + v.weight;
        end
    end

    local random = math.random() * totalWeight
    for k, v in pairs(tbl) do
        if not validateCache[v] then
            random = random - v.weight
            if random <= 0 then
                return key and v[key] or v, k
            end
        end
    end

    return nil;
end

function CheckDefaultProps(prevKey, prevObj)
    return function(key, value)
        if prevObj.requiredNext and not prevObj.requiredNext[value.name] then
            return false
        end

        if prevObj.blockedNext and prevObj.blockedNext[value.name] then
            return false
        end

        if value.requiredPrevious and not value.requiredPrevious[prevKey] then
            return false
        end

        if value.blockedPrevious and value.blockedPrevious[prevKey] then
            return false
        end

        return true
    end
end

function GenerateContractCard(level, config, iter, overrideClass)
    if not iter then iter = 0 end
    if iter > 20 then return nil end
    local data, class = WeightedRandom(config, nil, function(key, value)
        if Config.LevelForClass[key] ~= nil and level < Config.LevelForClass[key] then
            return false
        end

        return true
    end)

    if overrideClass then
        data = config[overrideClass]
        class = overrideClass
    end

    local weights = data.drops
    local rewards = data.rewards

    local start, startKey = WeightedRandom(weights.start, 'name')
    local middle, middleKey = WeightedRandom(weights.middle, 'name', CheckDefaultProps(start, weights.start[startKey]))
    if not middle then
        print("Failed to generate middle mission for boosting contract - start mission: " .. tostring(start) .. ", class: " .. tostring(class) .. ", level: " .. tostring(level))
        return GenerateContractCard(level, config, iter + 1)
    end
    local deliver, _ = WeightedRandom(weights.deliver, 'name', CheckDefaultProps(middle, weights.middle[middleKey]))
    if not deliver then
        print("Failed to generate deliver mission for boosting contract - middle mission: " .. tostring(middle) .. ", class: " .. tostring(class) .. ", level: " .. tostring(level))
        return GenerateContractCard(level, config, iter + 1)
    end

    local vehData = GetVehicleFromClass(class)
    if not vehData then
        print("Failed to get vehicle data for boosting contract - class: " .. tostring(class) .. ", level: " .. tostring(level))
        return GenerateContractCard(level, config, iter + 1)
    end
    return {
        id = -1,
        fileName = vehData.modelName .. "_UNLOCKABLE",
        contractType = "boosting",
        contractTypeLabel = "Boosting",
        contractFullLabel = "TODO",
        vehicleModel = vehData.modelName,
        vehicleModelLabel = vehData and (vehData?.manufacturer .. " " .. vehData?.label) or locale(locale("Unknown")),
        vehicleClass = vehData?.class,
        rewards = {
            amount = math.floor(math.random(rewards.amount[1], rewards.amount[2])),
            cryptoName = rewards.cryptoName,
            experience = math.random(rewards.experience[1], rewards.experience[2]),
        },
        ownerStateId = -1,
        missions = { start, middle, deliver },
        prerequisites = {},
        deleted = false,
        active = false,
        finished = false,
        price = data.price,
    }
end

function GenerateVinScratchCard(level, config, iter, overrideClass)
    if not iter then iter = 0 end
    if iter > 20 then return nil end
    local data, class = WeightedRandom(config, nil, function(key, value)
        if Config.LevelForVinScratchClass[key] ~= nil and level < Config.LevelForVinScratchClass[key] then
            return false
        end

        return true
    end)

    if overrideClass then
        data = config[overrideClass]
        class = overrideClass
    end

    local weights = data.drops
    local rewards = data.rewards

    local missions = {}

    local prereqCount = math.random(data.prereqCount[1], data.prereqCount[2])
    for i = 1, prereqCount do
        local mission = WeightedRandom(weights.prereqs, 'name')
        if not mission then return GenerateVinScratchCard(level, config, iter + 1) end
        table.insert(missions, mission)
    end

    local start, startKey = WeightedRandom(weights.start, 'name')
    local middle, middleKey = WeightedRandom(weights.middle, 'name', CheckDefaultProps(start, weights.start[startKey]))
    if not middle then return GenerateContractCard(level, config, iter + 1) end
    local deliver, _ = WeightedRandom(weights.vinDeliver, 'name', CheckDefaultProps(middle, weights.middle[middleKey]))
    if not deliver then return GenerateContractCard(level, config, iter + 1) end

    local vehData = GetVehicleFromClass(class) 
    if not vehData then return GenerateContractCard(level, config, iter + 1) end

    table.insert(missions, start)
    table.insert(missions, middle)
    table.insert(missions, deliver)
    return {
        id = -1,
        fileName = vehData.modelName .. "_UNLOCKABLE",
        contractType = "vin_scratch",
        contractTypeLabel = "VIN Scratch",
        contractFullLabel = "TODO",
        vehicleModel = vehData.modelName,
        vehicleModelLabel = vehData and (vehData?.manufacturer .. " " .. vehData?.label) or "Unknown",
        vehicleClass = vehData?.class,
        rewards = {
            amount = math.random(rewards.amount[1], rewards.amount[2]),
            cryptoName = rewards.cryptoName,
            experience = math.random(rewards.experience[1], rewards.experience[2]),
        },
        ownerStateId = -1,
        missions = missions,
        prerequisites = {},
        deleted = false,
        active = false,
        finished = false,
        price = data.price,
    }
end

lib.callback.register("prp-boosting:loadUnlocks", function(source)
    local stateId = bridge.fw.getIdentifier(source)

    local result = MySQL.single.await("SELECT * FROM boosting_unlocks WHERE stateId = ?", { stateId })
    local contracts, unlocked, selectedIndex, createdAt
    local unlockTimer = Config.UnlockTimer
    local unlockTimerModifier = 1.0
    unlockTimer = math.floor(unlockTimer * unlockTimerModifier)
    if not result or os.time() - result.createdAt/1000 > unlockTimer then
        local cons = {}

        local currentLevel = GetBoostingLevelByStateId(stateId)
        for i = 1, 3 do
            local contract;

            local chance = GetVinscratchChanceByLevel(currentLevel)
            if math.random() < chance then
                contract = GenerateVinScratchCard(currentLevel, Config.VinScratchGeneration)
            else
                local unlockDrops = lib.table.deepclone(Config.UnlockDrops)
                local highestLevel, overrides = 0, nil
                for k, v in pairs(Config.UnlockDropsWeightsOverride) do
                    if k <= currentLevel and k > highestLevel then
                        highestLevel = k
                        overrides = v
                    end
                end
                if overrides then
                    for k, v in pairs(overrides) do
                        if unlockDrops[k] then
                            unlockDrops[k].weight = v
                        end
                    end
                end
                contract = GenerateContractCard(currentLevel, unlockDrops)
            end

            if not contract then
                error("!! FAILED TO GENERATE CONTRACT CARD AFTER 20 ITERATIONS !! THIS LIKELY MEANS THERE IS AN ERROR IN THE CONFIG")
                return nil; 
            end
            table.insert(cons, contract)
        end

        MySQL.update.await("INSERT INTO boosting_unlocks (stateId, contracts, unlocked, selectedIndex, createdAt) VALUES (@stateId, @contracts, @unlocked, @selectedIndex, FROM_UNIXTIME(@createdAt)) ON DUPLICATE KEY UPDATE contracts = @contracts, unlocked = @unlocked, selectedIndex = @selectedIndex, createdAt = FROM_UNIXTIME(@createdAt)", {
            ["@stateId"] = stateId,
            ["@contracts"] = json.encode(cons),
            ["@unlocked"] = 0,
            ["@selectedIndex"] = nil,
            ["@createdAt"] = os.time()
        })

        contracts = cons
        unlocked = {false, false, false}
        selectedIndex = nil
        createdAt = os.time() * 1000
    else
        contracts = json.decode(result.contracts)
        unlocked = {}
        for i = 1, 3 do
            unlocked[i] = result.unlocked & (1 << (i-1)) > 0
        end

        selectedIndex = result.selectedIndex
        createdAt = result.createdAt
    end

    return {
        contracts = contracts,
        unlocked = unlocked,
        selectedIndex = selectedIndex,
        nextUnlockTime = createdAt + unlockTimer * 1000
    }
end)

lib.callback.register("prp-boosting:unlockedContracts", function(source, unlocked)
    local stateId = bridge.fw.getIdentifier(source)
    if(type(unlocked) ~= "table") then return { success = false, error = locale("INVALID_DATA") } end

    local internalUnlocked = 0;
    for i = 1, 3 do
        if type(unlocked[i]) ~= "boolean" then return { success = false, error = locale("INVALID_DATA") } end

        if unlocked[i] then
            internalUnlocked = internalUnlocked | (1 << (i-1))
        end
    end
    MySQL.update.await("UPDATE boosting_unlocks SET unlocked = @unlocked WHERE stateId = @stateId", {
        ["@unlocked"] = internalUnlocked,
        ["@stateId"] = stateId
    })
end)


lib.callback.register("prp-boosting:selectContract", function(source, index)
    local stateId = bridge.fw.getIdentifier(source)
    local result = MySQL.single.await("SELECT * FROM boosting_unlocks WHERE stateId = ?", { stateId })

    index = tonumber(index)+1;
    if not result then return { success = false, error = locale("CONTRACT_NOT_FOUND") } end
    local contracts = json.decode(result.contracts)
    if not contracts[index] then return { success = false, error = locale("CONTRACT_NOT_FOUND") } end
    MySQL.update.await("UPDATE boosting_unlocks SET selectedIndex = @index WHERE stateId = @stateId", {
        ["@index"] = index-1,
        ["@stateId"] = stateId
    })

    local contract = contracts[index]

    local id = MySQL.insert.await("INSERT INTO boosting_contracts (contractType, vehicleModel, vehicleClass, reward, experience, owner) VALUES (@contractType, @vehicleModel, @vehicleClass, @reward, @experience, @owner)", {
        ["@contractType"] = contract.contractType,
        ["@vehicleModel"] = contract.vehicleModel,
        ["@vehicleClass"] = contract.vehicleClass,
        ["@reward"] = contract.rewards.amount,
        ["@experience"] = contract.rewards.experience,
        ["@owner"] = stateId
    })

    for k, v in ipairs(contract.missions) do
        if v ~= "__EMPTY__" then
            local missionConfig = RegisteredMissions[v]:GetMetadata(contract)
            local addonData = RegisteredMissions[v].GenerateAddonData and RegisteredMissions[v]:GenerateAddonData(contract) or {}
            MySQL.insert.await("INSERT INTO boosting_contracts_tasks (contractId, name, target, type, vehicleClass, addonData) VALUES (@contractId, @name, @target, 'mission', @vehicleClass, @addonData)", {
                ["@contractId"] = id,
                ["@name"] = v,
                ["@target"] = missionConfig.genTarget and (type(missionConfig.genTarget) == "table" and math.random(missionConfig.genTarget[1], missionConfig.genTarget[2]) or missionConfig.genTarget) or 1,
                ["@vehicleClass"] = contract.vehicleClass,
                ["@addonData"] = json.encode(addonData or {})
            })
        end
    end

    LoadBoostingContract(id)
    return { success = true }
end)

function TryGenerateMarketContract()
    local lastSystemListing = MySQL.single.await("SELECT * FROM boosting_listings WHERE authorStateId = 0 ORDER BY createdAt DESC LIMIT 1");
    if lastSystemListing and os.time() - lastSystemListing.createdAt/1000 < Config.MarketGenerationInterval then return end
    
    local contract = GenerateContractCard(999999, Config.MarketGeneration)
    if not contract then return end
    local id = MySQL.insert.await("INSERT INTO boosting_contracts (contractType, vehicleModel, vehicleClass, reward, experience, owner, cryptoName) VALUES (@contractType, @vehicleModel, @vehicleClass, @reward, @experience, @owner, @cryptoName)", {
        ["@contractType"] = contract.contractType,
        ["@vehicleModel"] = contract.vehicleModel,
        ["@vehicleClass"] = contract.vehicleClass,
        ["@reward"] = contract.rewards.amount,
        ["@cryptoName"] = contract.rewards.cryptoName or "BANK",
        ["@experience"] = contract.rewards.experience,
        ["@owner"] = 0
    });

    for k, v in ipairs(contract.missions) do
        if v ~= "__EMPTY__" then
            local missionConfig = RegisteredMissions[v]:GetMetadata(contract)
            local addonData = RegisteredMissions[v].GenerateAddonData and RegisteredMissions[v]:GenerateAddonData(contract) or {}
            MySQL.insert.await("INSERT INTO boosting_contracts_tasks (contractId, name, target, type, vehicleClass, addonData) VALUES (@contractId, @name, @target, 'mission', @vehicleClass, @addonData)", {
                ["@contractId"] = id,
                ["@name"] = v,
                ["@target"] = missionConfig.genTarget and (type(missionConfig.genTarget) == "table" and math.random(missionConfig.genTarget[1], missionConfig.genTarget[2]) or missionConfig.genTarget) or 1,
                ["@vehicleClass"] = contract.vehicleClass,
                ["@addonData"] = json.encode(addonData or {})
            })
        end
    end

    MySQL.insert.await("INSERT INTO boosting_listings (type, contractId, price, authorStateId, cryptoName) VALUES (@type, @contractId, @price, @authorStateId, @cryptoName)", {
        ["@type"] = "bin",
        ["@contractId"] = id,
        ["@price"] = type(contract.price) == "table" and math.random(contract.price[1], contract.price[2]) or contract.price or 10,
        ["@authorStateId"] = 0,
        ["@cryptoName"] = Config.MarketGeneration[contract.vehicleClass].cryptoName or "BANK"
    })
end

Citizen.CreateThread(function()
    Citizen.Wait(5000)
    while true do
        TryGenerateMarketContract()
        Citizen.Wait(60 * 1000);
    end
end)

function RedeemContract(src, item)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return false end
    local success = bridge.inv.removeItem(src, item.name, 1, nil, item.slot)
    if not success then return false end

    local class = item.name:sub(19):upper()
    if class == "" then return end
    local contract = GenerateContractCard(999999, Config.UnlockDrops, 0, class)
    if not contract then return false end
    local id = MySQL.insert.await("INSERT INTO boosting_contracts (contractType, vehicleModel, vehicleClass, reward, experience, owner, cryptoName) VALUES (@contractType, @vehicleModel, @vehicleClass, @reward, @experience, @owner, @cryptoName)", {
        ["@contractType"] = contract.contractType,
        ["@vehicleModel"] = contract.vehicleModel,
        ["@vehicleClass"] = contract.vehicleClass,
        ["@reward"] = contract.rewards.amount,
        ["@experience"] = contract.rewards.experience,
        ["@owner"] = stateId,
        ["@cryptoName"] = contract.rewards.cryptoName or "BANK"
    });

    for k, v in ipairs(contract.missions) do
        if v ~= "__EMPTY__" then
            local missionConfig = RegisteredMissions[v]:GetMetadata(contract)
            local addonData = RegisteredMissions[v].GenerateAddonData and RegisteredMissions[v]:GenerateAddonData(contract) or {}
            MySQL.insert.await("INSERT INTO boosting_contracts_tasks (contractId, name, target, type, vehicleClass, addonData) VALUES (@contractId, @name, @target, 'mission', @vehicleClass, @addonData)", {
                ["@contractId"] = id,
                ["@name"] = v,
                ["@target"] = missionConfig.genTarget and (type(missionConfig.genTarget) == "table" and math.random(missionConfig.genTarget[1], missionConfig.genTarget[2]) or missionConfig.genTarget) or 1,
                ["@vehicleClass"] = contract.vehicleClass,
                ["@addonData"] = json.encode(addonData or {})
            })
        end
    end
    local contract = LoadBoostingContract(id)
    if not contract then return false end
    bridge.fw.notify(src, "success", locale("CONTRACT_REDEEMED"))
end

function RedeemVinScratch(src, item)
    local stateId = bridge.fw.getIdentifier(src)
    local success = bridge.inv.removeItem(src, item.name, 1, nil, item.slot)
    if not success then return false end
    local class = item.name:sub(21):upper()
    if class == "" then return end
    local contract = GenerateVinScratchCard(999999, Config.VinScratchGeneration, 0, class)
    if not contract then return false end
    local id = MySQL.insert.await("INSERT INTO boosting_contracts (contractType, vehicleModel, vehicleClass, reward, experience, owner, cryptoName) VALUES (@contractType, @vehicleModel, @vehicleClass, @reward, @experience, @owner, @cryptoName)", {
        ["@contractType"] = contract.contractType,
        ["@vehicleModel"] = contract.vehicleModel,
        ["@vehicleClass"] = contract.vehicleClass,
        ["@reward"] = contract.rewards.amount,
        ["@experience"] = contract.rewards.experience,
        ["@owner"] = stateId,
        ["@cryptoName"] = contract.rewards.cryptoName or "BANK"
    });

    for k, v in ipairs(contract.missions) do
        if v ~= "__EMPTY__" then
            local missionConfig = RegisteredMissions[v]:GetMetadata(contract)
            local addonData = RegisteredMissions[v].GenerateAddonData and RegisteredMissions[v]:GenerateAddonData(contract) or {}
            MySQL.insert.await("INSERT INTO boosting_contracts_tasks (contractId, name, target, type, vehicleClass, addonData) VALUES (@contractId, @name, @target, 'mission', @vehicleClass, @addonData)", {
                ["@contractId"] = id,
                ["@name"] = v,
                ["@target"] = missionConfig.genTarget and (type(missionConfig.genTarget) == "table" and math.random(missionConfig.genTarget[1], missionConfig.genTarget[2]) or missionConfig.genTarget) or 1,
                ["@vehicleClass"] = contract.vehicleClass,
                ["@addonData"] = json.encode(addonData or {})
            })
        end
    end

    local contract = LoadBoostingContract(id)
    if not contract then return false end
    bridge.fw.notify(src, "success", locale("CONTRACT_REDEEMED"))
end