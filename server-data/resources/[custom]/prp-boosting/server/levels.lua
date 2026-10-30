---@type table<integer|string, { xp: integer, level: integer, repLimit: table }>
local playerCache = {}

---Initialize player's cache
---@param stateId integer|string
local function initializePlayerData(stateId)
    local playerData = exports.oxmysql:single_async("SELECT xp, repLimit FROM boosting_users WHERE stateId = ?", { stateId })
    if not playerData then
        return
    end
    local xp = playerData.xp or 0
    playerCache[stateId] = { xp = xp, level = GetBoostingLevelByStateId(stateId, true), repLimit = playerData and json.decode(playerData.repLimit) or {} }
end

---Returns boosting level
---@param src integer
---@return integer
function GetBoostingLevel(src)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return 1 end
    if not playerCache[stateId] then
        initializePlayerData(stateId)
    end
    if playerCache[stateId] and playerCache[stateId].level then
        return playerCache[stateId].level
    end
    local level = GetBoostingLevelByStateId(stateId) or 1
    return level
end

---Returns boosting level by state ID
---@param stateId integer|string|nil
---@param skipCache boolean|nil
---@return integer
function GetBoostingLevelByStateId(stateId, skipCache)
    if not stateId then return 1 end
    if playerCache[stateId] and not skipCache then
        return playerCache[stateId].level
    end
    local currentXp = exports.oxmysql:single_async("SELECT xp FROM boosting_users WHERE stateId = ?", { stateId })
    if not currentXp then return 1 end
    currentXp = currentXp.xp or 0
    for i=#Config.BoostingLevels, 1, -1 do
        if currentXp >= Config.BoostingLevels[i].value then
            return i
        end
    end
    return 1
end

---Get boosting level and XP by state ID
---@param stateId integer|string|nil
---@return integer, integer
function GetBoostingLevelAndXpByStateId(stateId)
    if not stateId then return 1, 0 end
    if not playerCache[stateId] then
        initializePlayerData(stateId)
    end
    if playerCache[stateId] then
        return playerCache[stateId].level, playerCache[stateId].xp
    end
    return 1, 0
end

---Get boosting level and XP
---@param src integer
---@return integer, integer
function GetBoostingLevelAndXp(src)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return 1, 0 end
    return GetBoostingLevelAndXpByStateId(stateId)
end

---Add boosting XP to a player
---@param src integer
---@param amount integer
function AddBoostingXp(src, amount)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return end
    AddBoostingXpByStateId(stateId, amount)
end

-- Get rep limit for a player by state ID
---@param stateId integer|string|nil
---@return table
function GetRepLimitByStateId(stateId)
    if not stateId then return {} end
    if not playerCache[stateId] then
        initializePlayerData(stateId)
    end
    return playerCache[stateId] and playerCache[stateId].repLimit or {}
end

-- Get rep limit for a player
---@param src integer
---@return table
function GetRepLimit(src)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return {} end
    return GetRepLimitByStateId(stateId)
end

---Add boosting XP to a player by state ID
---@param stateId integer|string
---@param amount integer
function AddBoostingXpByStateId(stateId, amount)
    initializePlayerData(stateId)
    local newXp = playerCache[stateId].xp + amount
    exports.oxmysql:update_async("UPDATE boosting_users SET xp = ? WHERE stateId = ?", { newXp, stateId })
    playerCache[stateId].xp = newXp
    local newLevel = GetBoostingLevelByStateId(stateId, true)
    playerCache[stateId].level = newLevel
end

function GetGroupPointsExpForClass(vehicleClass)
    local config = Config.AddGroupPoints[vehicleClass] or Config.AddGroupPoints["default"]
    if not config or not config.exp then return 0 end
    return config.exp
end

function AwardBoostingExperienceByStateId(stateId, experience, eventType, contract)
    if not experience or experience <= 0 then return end
    local memberLevel = GetBoostingLevelByStateId(stateId)
    local lowestLevel, highestModifier = math.huge, 1.0
    for level, modifier in pairs(Config.CatchupRepModifier) do
        if memberLevel < level and level < lowestLevel then
            lowestLevel = level
            highestModifier = modifier
        end
    end
    experience = math.floor(experience * highestModifier)
    experience = CheckXpLimitByStateId(stateId, experience)
    if not experience or experience <= 0 then return end
    AddBoostingXpByStateId(stateId, experience)
    LoggerBySid(stateId, "boosting", ("Player %s got %s experience for boosting"):format(stateId, contract.id), {
        boosting_eventType = eventType,
        boosting_contractId = contract.id,
        boosting_vehicleModel = contract.vehicleModel,
        boosting_vehicleClass = contract.vehicleClass,
        boosting_experience = experience,
        boosting_ownerStateId = contract.ownerStateId,
    })
end

function RemoveBoostingXp(src, amount)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return end
    RemoveBoostingXpByStateId(stateId, amount)
end

function RemoveBoostingXpByStateId(stateId, amount)
    initializePlayerData(stateId)
    local newXp = math.max(0, playerCache[stateId].xp - amount)
    exports.oxmysql:update_async("UPDATE boosting_users SET xp = ? WHERE stateId = ?", { newXp, stateId })
    playerCache[stateId].xp = newXp
    local newLevel = GetBoostingLevelByStateId(stateId, true)
    playerCache[stateId].level = newLevel
end

function GetBoostingXp(src)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return 0 end
    if not playerCache[stateId] then
        initializePlayerData(stateId)
    end
    return playerCache[stateId] and playerCache[stateId].xp or 0
end

function GetBoostingXpByStateId(stateId)
    if not stateId then return 0 end
    if not playerCache[stateId] then
        initializePlayerData(stateId)
    end
    return playerCache[stateId] and playerCache[stateId].xp or 0
end

---Returns XP limit for a player's level
---@param src integer
---@return integer
function GetXpLimit(src)
    local level = GetBoostingLevel(src)
    return Config.BoostingLevels[level] and Config.BoostingLevels[level].repLimit or 9999999
end

---Returns XP limit for a player's level by state ID
---@param stateId integer|string
---@return integer
function GetXpLimitByStateId(stateId)
    local level = GetBoostingLevelByStateId(stateId)
    return Config.BoostingLevels[level] and Config.BoostingLevels[level].repLimit or 9999999
end

---Checks XP limit for a player
---@param src integer
---@param amount integer
function CheckXpLimit(src, amount)
    local stateId = bridge.fw.getIdentifier(src)
    return CheckXpLimitByStateId(stateId, amount)
end

---Checks XP limit for a player by state ID
---@param stateId integer|string|nil
---@param amount integer
---@return integer
function CheckXpLimitByStateId(stateId, amount)
    if not stateId then return 0 end
    initializePlayerData(stateId)
    local xpLimit = GetXpLimitByStateId(stateId)
    local limitData = {
        reputation = xpLimit,
        time = 24 * 60 * 60,
    }
    if not playerCache[stateId].repLimit or not playerCache[stateId].repLimit.time then
        if amount > limitData.reputation then
            amount = limitData.reputation
        end
        playerCache[stateId].repLimit = {
            reputation = amount,
            time = os.time()
        }
    else
        if os.time() - playerCache[stateId].repLimit.time > limitData.time then
            playerCache[stateId].repLimit = {
                reputation = 0,
                time = os.time()
            }
        end
        if playerCache[stateId].repLimit.reputation >= limitData.reputation and os.time() - playerCache[stateId].repLimit.time < limitData.time then
            return 0
        end
        if playerCache[stateId].repLimit.reputation + amount > limitData.reputation then
            amount = limitData.reputation - playerCache[stateId].repLimit.reputation
        end
        playerCache[stateId].repLimit.reputation += amount
    end
    exports.oxmysql:update_async("UPDATE boosting_users SET repLimit = ? WHERE stateId = ?", { json.encode(playerCache[stateId].repLimit), stateId })
    return amount
end