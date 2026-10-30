local createHook
IsRevertMode = false

local function registerInventoryHooks()
    for k, v in pairs(Config.Items) do
        if string.starts(k, "boosting_contract_") then
            bridge.fw.registerItemUse(k, function(src, item)
                RedeemContract(src, item)
            end)
        end
        if string.starts(k, "boosting_vinscratch_") then
            bridge.fw.registerItemUse(k, function(src, item)
                RedeemVinScratch(src, item)
            end)
        end
    end
    bridge.fw.registerItemUse("boosting_tablet", function(src, item)
        local playerData, stateId = GetPlayerData(src)
        local activeContract, players = GetActiveContract(src)
        TriggerClientEvent("prp-boosting:openTablet", src, playerData, stateId, activeContract, players)
    end)
end

---@param src number
exports("OpenTablet", function(src)
    local playerData, stateId = GetPlayerData(src)
    local activeContract, players = GetActiveContract(src)
    TriggerClientEvent("prp-boosting:openTablet", src, playerData, stateId, activeContract, players)
end)

Citizen.CreateThread(function()
    registerInventoryHooks()
end)

RegisterCommand("boosting_setrevert", function(source, args, rawCommand)
    if source == 0 then
        IsRevertMode = tonumber(args[1]) == 1
        print("Revert mode set to: " .. tostring(IsRevertMode))
    end
end, false)

RegisterCommand("boosting_regeneratetargets", function(source, args, rawCommand)
    if source == 0 then
        local contracts = MySQL.query.await("SELECT * FROM boosting_contracts WHERE DELETED = 0 AND FINISHED = 0")
        local count = 0
        local updateCount = 0
        local totalCount = 0
        local contractTasks = {}
        print("Loading all boosting contracts tasks")
        for _, res in ipairs(contracts) do
            local tasks = MySQL.query.await("SELECT * FROM boosting_contracts_tasks WHERE contractId = ? AND active = 0", { res.id })
            contractTasks[res.id] = { tasks = tasks, contract = res }
            totalCount += #tasks
        end
        print("Loaded all boosting contracts tasks, total: " .. totalCount)
        for resId, res in pairs(contractTasks) do
            for k, v in ipairs(res.tasks) do
                if v.name ~= "__EMPTY__" then
                    if not v.name or not RegisteredMissions[v.name] then
                        print("Mission not found: " .. tostring(v.name or "none"))
                        goto continue
                    end
                    local missionConfig = RegisteredMissions[v.name]:GetMetadata(res.contract)
                    updateCount += MySQL.update.await("UPDATE boosting_contracts_tasks SET target = @target WHERE id = @missionId AND active = 0", {
                        ["@missionId"] = v.id,
                        ["@target"] = missionConfig.genTarget and (type(missionConfig.genTarget) == "table" and math.random(missionConfig.genTarget[1], missionConfig.genTarget[2]) or missionConfig.genTarget) or 1,
                    })
                end
                count = count + 1
                if count % 5000 == 0 then
                    print("Progress update " .. count .. "/" .. totalCount)
                    Citizen.Wait(0)
                end
                ::continue::
            end
        end
        print("Updated " .. updateCount .. " missions targets.")
    end
end, false)

function RemovePlayerCurrency(stateId, currency, amount, title, description, moneySource)
    local isCrypto = Config.AllowedCrypto[currency]
    if not isCrypto and currency ~= "BANK" then return false end
    if amount < 0 then return end
    if currency == "BANK" then
        amount = math.floor(amount)
        local src = bridge.fw.getSrcFromIdentifier(stateId)
        if not src then
            return false
        end
        local charged = bridge.fw.removeMoney(src, "bank", amount, title)
        if not charged then
            return false
        end
        return true
    end
    if isCrypto then
        -- return exports["crypto-resource"]:RemoveCrypto(stateId, currency, amount)
    end
    return false
end

function AddPlayerCurrency(stateId, currency, amount, title, description, moneySource)
    local isCrypto = Config.AllowedCrypto[currency]
    if not isCrypto and currency ~= "BANK" then return false end
    if amount < 0 then return end
    if currency == "BANK" then
        amount = math.floor(amount)
        local src = bridge.fw.getSrcFromIdentifier(stateId)
        if not src then
            return false
        end
        local success = bridge.fw.addMoney(src, "bank", amount, title)
        return success
    end
    if isCrypto then
        -- return exports["crypto-resource"]:AddCrypto(stateId, currency, amount)
    end
    return false
end

function Round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

function isAdmin(playerId)
    return bridge.fw.isAdmin(playerId)
end

PlayerUsernames = {}

function GetPlayerData(src)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return end
    if not PlayerUsernames[stateId] then
        return nil, stateId
    end
    local level, xp = GetBoostingLevelAndXpByStateId(stateId)
    local repLimit = GetRepLimitByStateId(stateId)
    return {
        stateId = stateId,
        nickname = PlayerUsernames[stateId],
        level = level,
        xp = xp,
        repLimit = repLimit
    }, stateId
end

lib.callback.register("prp-boosting:getPlayerData", function(src)
    local playerData, stateId = GetPlayerData(src)
    return playerData, stateId
end)

lib.callback.register("prp-boosting:createAccount", function(source, nickname)
    local stateId = bridge.fw.getIdentifier(source)
    if nickname:match("%W") then
        return { success = false, error = locale("INVALID_CHARACTERS_IN_NAME") }
    end
    if string.len(nickname) < 3 or string.len(nickname) > 32 then
        return { success = false, error = locale("USERNAME_LENGTH_WARNING") }
    end
    local id = nil

    pcall(function()
        id = MySQL.insert.await("INSERT INTO boosting_users (stateId, username) VALUES (@stateId, @username)", {
            ["@stateId"] = stateId,
            ["@username"] = nickname
        })
    end)

    if id then
        PlayerUsernames[stateId] = nickname
        local level, xp = GetBoostingLevelAndXpByStateId(stateId)
        local repLimit = GetRepLimitByStateId(stateId)
        TriggerClientEvent("prp-kct:boosting:setUsername", source, {
            stateId = stateId,
            nickname = nickname,
            level = level,
            xp = xp,
            repLimit = repLimit
        })
    end
    return { success = id and true or false, error = id and nil or locale("SOMEONE_HAS_THIS_USERNAME") }
end)

lib.callback.register("prp-boosting:saveSettings", function(source, nickname)
    local stateId = bridge.fw.getIdentifier(source)
    if nickname:match("%W") then
        return { success = false, error = locale("INVALID_CHARACTERS_IN_NAME") }
    end
    if string.len(nickname) < 3 or string.len(nickname) > 32 then
        return { success = false, error = locale("USERNAME_LENGTH_WARNING") }
    end
    local exists = MySQL.scalar.await("SELECT COUNT(*) FROM boosting_users WHERE username = ? AND stateId != ?", { nickname, stateId }) > 0
    if exists then
        return { success = false, error = locale("SOMEONE_HAS_THIS_USERNAME") }
    end
    local result = MySQL.update.await("UPDATE boosting_users SET username = ? WHERE stateId = ?", { nickname, stateId })
    if result > 0 then
        PlayerUsernames[stateId] = nickname
    end
    return { success = result > 0, error = result == 0 and locale("SOMEONE_HAS_THIS_USERNAME") }
end)

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    local result = MySQL.query.await("SELECT * FROM boosting_users")
    for k, v in pairs(result) do
        PlayerUsernames[v.stateId] = v.username
    end
end)

local function appendToFile(_filename, data)
    local resourceName = GetCurrentResourceName()
    local content = LoadResourceFile(resourceName, "//server//" .. _filename) or ""

    content = content .. data

    SaveResourceFile(resourceName, "//server//" .. _filename, content, -1)
end

if false then
    RegisterCommand("boostingCoords", function(source)
        local coords = GetEntityCoords(GetPlayerPed(source))
        local heading = GetEntityHeading(GetPlayerPed(source))

        appendToFile("coords.txt", ("vec4(%s, %s, %s, %s),\n"):format(coords.x, coords.y, coords.z, heading))
    end, false)

    RegisterCommand("generateConfig", function(source)
        local source = source
        local resourceName = GetCurrentResourceName()
        local content = LoadResourceFile(resourceName, "//server//coords.txt") or ""

        local lines = {}
        for line in content:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end

        local output = ""
        local data = {}
        for k, v in pairs(lines) do
            local x, y, z, h = v:match("vec4%((-?[%d%.]+), (-?[%d%.]+), (-?[%d%.]+), (-?[%d%.]+)%)")

            x = tonumber(x)
            y = tonumber(y)
            z = tonumber(z)
            h = tonumber(h)

            local locationData = lib.callback.await("prp-boosting:getStreetName", source, vector3(x, y, z))
            local locationName = locationData.main

            local unitVector = vector3(math.cos(h), math.sin(h), 0)
            local npcLoc1 = vector3(x, y, z) + (unitVector * 2)
            local npcLoc2 = vector3(x, y, z) + (unitVector * -2)
            output = output..([[
        {
            coords = %s
            locationLabel = "%s",
            npcLocations = {
                %s,
                %s
            }
        },
    ]]):format(v, locationName, npcLoc1, npcLoc2)
            Citizen.Wait(1)
        end

        appendToFile("config.txt", output)
    end, false)
end

exports("GetUserNickname", function(stateId)
    return PlayerUsernames[stateId]
end)

exports("GetUserRepLimits", function(stateId)
    local repLimit = MySQL.scalar.await("SELECT repLimit FROM boosting_users WHERE stateId = ?", { stateId }) or "{}"
    repLimit = json.decode(repLimit)
    local level = GetBoostingLevelByStateId(stateId)
    local reputation = Config.BoostingLevels[level] and Config.BoostingLevels[level].repLimit or 9999999
    repLimit.maxReputation = reputation
    return repLimit
end)

lib.callback.register("prp-boosting:getPrestigeData", function(source)
    local stateId = bridge.fw.getIdentifier(source)
    local level = GetBoostingLevelByStateId(stateId)
    local user = MySQL.single.await("SELECT * FROM boosting_users WHERE stateId = ?", { stateId })
    local result = {}
    local prestigeData = json.decode(user.prestigeData or "{}")
    if level >= Config.PrestigeLevel then
        result.canUnlockPrestige = true
        result.prestiges = prestigeData.availableUnlocks or GeneratePrestigeUnlocksForPlayer(stateId, prestigeData)
    end
    return result, level
end)

function GeneratePrestigeUnlocksForPlayer(stateId, prestigeData)
    local unlocks = {}
    prestigeData = prestigeData or {}
    local prestigeLevel = prestigeData.level or 1
    for i=1, 3 do
        unlocks[#unlocks+1] = WeightedRandom(Config.PrestigeUnlocks[prestigeLevel])
    end
    prestigeData.availableUnlocks = unlocks
    MySQL.update.await("UPDATE boosting_users SET prestigeData = ? WHERE stateId = ?", { json.encode(prestigeData), stateId })
    return unlocks
end

lib.callback.register("prp-boosting:unlockPrestige", function(source, unlockName)
    local stateId = bridge.fw.getIdentifier(source)
    if not stateId then
        return { success = false, error = locale("PLAYER_NOT_FOUND") }
     end
    local user = MySQL.single.await("SELECT * FROM boosting_users WHERE stateId = ?", { stateId })
    local prestigeData = json.decode(user.prestigeData or "{}")
    local prestigeLevel = prestigeData.level or 1
    local unlocks = prestigeData.availableUnlocks
    if not unlocks then
        return { success = false, error = locale("NO_UNLOCKS_AVAILABLE") }
    end
    local unlock = nil
    for k, v in ipairs(unlocks) do
        if v.name == unlockName then
            unlock = v
            break
        end
    end
    if not unlock then
        return { success = false, error = locale("NO_UNLOCKS_AVAILABLE") }
    end
    local level = GetBoostingLevelByStateId(stateId)
    if level < Config.PrestigeLevel then
        return { success = false, error = locale("BELOW_REQUIRED_PRESTIGE_LEVEL", Config.PrestigeLevel) }
    end
    local currentXp = GetBoostingXpByStateId(stateId)
    RemoveBoostingXpByStateId(stateId, currentXp)
    prestigeData.availableUnlocks = nil
    prestigeData.level = prestigeLevel + 1
    prestigeData.unlocks = prestigeData.unlocks or {}
    prestigeData.unlocks[unlock.name] = true
    MySQL.update.await("UPDATE boosting_users SET prestigeData = ? WHERE stateId = ?", { json.encode(prestigeData), stateId })
    return { success = true, unlock = unlock }
end)

Citizen.CreateThread(function()

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boosting_users` (
            `stateId` varchar(255) NOT NULL,
            `username` varchar(50) NOT NULL DEFAULT '',
            `repLimit` longtext DEFAULT '{}',
            `prestigeData` longtext DEFAULT '{}',
            `xp` int(11) DEFAULT 0,
            PRIMARY KEY (`stateId`),
            UNIQUE KEY `username` (`username`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boosting_contracts` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `contractType` varchar(50) DEFAULT 'boosting',
            `vehicleModel` varchar(50) DEFAULT 'boosting',
            `vehicleClass` varchar(50) DEFAULT 'boosting',
            `reward` int(10) unsigned DEFAULT NULL,
            `cryptoName` varchar(50) DEFAULT 'BANK',
            `experience` int(11) DEFAULT NULL,
            `owner` varchar(255) DEFAULT NULL,
            `active` tinyint(4) NOT NULL DEFAULT 0,
            `deleted` tinyint(4) NOT NULL DEFAULT 0,
            `finished` tinyint(4) DEFAULT 0,
            `isAdmin` tinyint(4) DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `FK_boosting_contracts_characters` (`owner`),
            KEY `vehicleModel` (`vehicleModel`),
            KEY `vehicleClass` (`vehicleClass`),
            KEY `active` (`active`),
            KEY `deleted` (`deleted`),
            KEY `finished` (`finished`)
        ) ENGINE=InnoDB AUTO_INCREMENT=44 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boosting_contracts_tasks` (
            `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
            `contractId` int(11) NOT NULL,
            `name` varchar(50) DEFAULT NULL,
            `type` varchar(50) DEFAULT NULL,
            `progress` int(11) DEFAULT 0,
            `target` int(11) DEFAULT 10,
            `finished` tinyint(4) DEFAULT 0,
            `vehicleClass` varchar(50) DEFAULT NULL,
            `addonData` longtext DEFAULT '{}',
            `active` tinyint(4) NOT NULL DEFAULT 0,
            `availableTimestamp` datetime DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `FK__boosting_contracts` (`contractId`),
            KEY `vehicleClass` (`vehicleClass`),
            KEY `active` (`active`),
            CONSTRAINT `FK__boosting_contracts` FOREIGN KEY (`contractId`) REFERENCES `boosting_contracts` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        ) ENGINE=InnoDB AUTO_INCREMENT=105 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boosting_listings` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `type` varchar(50) NOT NULL DEFAULT 'bin',
            `contractId` int(11) NOT NULL DEFAULT 0,
            `price` int(11) NOT NULL DEFAULT 0,
            `cryptoName` varchar(50) NOT NULL DEFAULT 'BANK',
            `authorStateId` varchar(255) NOT NULL DEFAULT '',
            `active` tinyint(4) NOT NULL DEFAULT 1,
            `endTimestamp` datetime DEFAULT NULL,
            `winnerStateId` varchar(255) DEFAULT NULL,
            `createdAt`     datetime    default current_timestamp() null,
            PRIMARY KEY (`id`),
            KEY `type` (`type`),
            KEY `contractId` (`contractId`),
            KEY `authorStateId` (`authorStateId`),
            KEY `active` (`active`),
            KEY `endTimestamp` (`endTimestamp`),
            KEY `winnerStateId` (`winnerStateId`),
            CONSTRAINT `FK__boosting_contracts_listings` FOREIGN KEY (`contractId`) REFERENCES `boosting_contracts` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        ) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boosting_listings_bids` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `listingId` int(11) NOT NULL DEFAULT 0,
            `price` int(11) NOT NULL DEFAULT 0,
            `authorStateId` varchar(255) NOT NULL DEFAULT '',
            `timestamp` datetime NOT NULL DEFAULT current_timestamp(),
            `returned` tinyint(4) DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `listingId` (`listingId`),
            KEY `authorStateId` (`authorStateId`),
            KEY `timestamp` (`timestamp`),
            KEY `returned` (`returned`),
            CONSTRAINT `FK__boosting_listings_bid` FOREIGN KEY (`listingId`) REFERENCES `boosting_listings` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        ) ENGINE=InnoDB AUTO_INCREMENT=24 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boosting_unlocks` (
            `stateId` varchar(255) NOT NULL,
            `contracts` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
            `unlocked` int(11) DEFAULT NULL,
            `selectedIndex` int(11) DEFAULT NULL,
            `createdAt` datetime DEFAULT current_timestamp(),
            UNIQUE KEY `boosting_unlocks_stateId_uindex` (`stateId`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci;
    ]])


    MySQL.query.await("ALTER TABLE `boosting_contracts` ADD INDEX IF NOT EXISTS `vehicleModel` (`vehicleModel`), ADD INDEX IF NOT EXISTS `vehicleClass` (`vehicleClass`)")
    MySQL.insert.await("INSERT IGNORE INTO `boosting_users` (stateId, username) VALUES (0, 'System')")

    MySQL.query.await([[
        ALTER TABLE `boosting_contracts` ADD COLUMN IF NOT EXISTS `startTimestamp` datetime DEFAULT NULL AFTER `isAdmin`;
    ]])

    MySQL.query.await([[
        ALTER TABLE `boosting_contracts` ADD COLUMN IF NOT EXISTS `addonData` longtext DEFAULT '{}' AFTER `startTimestamp`;
    ]])
end)

function Logger(src, category, text, data)
    
end

function LoggerBySid(stateId, category, text, data)
    if Config.Webhook == "" then return end
    bridge.log.send(Config.Webhook, category, text, data)
end

RegisterNetEvent("prp-boosting:containerOpening", function(netId1, netId2)
    local entity1 = NetworkGetEntityFromNetworkId(netId1)
    local entity2 = NetworkGetEntityFromNetworkId(netId2)
    if not DoesEntityExist(entity1) or not DoesEntityExist(entity2) then return end
    SetEntityRemoteSyncedScenesAllowed(entity1, true)
    SetEntityRemoteSyncedScenesAllowed(entity2, true)
end)

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end