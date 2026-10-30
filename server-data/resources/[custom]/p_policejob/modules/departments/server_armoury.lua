-- Global Armoury object shared across the resource
Armoury = {}

local ARMOURY_SAVE_FILE = "armoury.json"
local ARMOURY_ITEMS_FILE = "armoury_items.json"

-- itemOverrides[armouryId] = list of item definitions edited in-game (replaces map items)
local itemOverrides = {}

-- stockData[armouryId][itemName] = { stock, limits }
local stockData = {}

-- purchaseCounts[uniqueId][armouryId][itemName] = quantityBoughtThisSession
local purchaseCounts = {}

-- armouryConfigs[armouryId] = armouryDefinition (from map files)
local armouryConfigs = {}

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Returns Config.DepartmentMap as a flat list of map name strings
function GetDepartmentMapList()
    if type(Config.DepartmentMap) == "table" and Config.DepartmentMap then
        return Config.DepartmentMap
    end
    return { Config.DepartmentMap }
end

-- Builds armouryConfigs by reading all department map files
function BuildArmouryConfigs()
    local configs = {}

    for _, mapName in ipairs(GetDepartmentMapList()) do
        local mapData = lib.load(string.format("maps.departments.%s", mapName))

        if type(mapData) == "table" and type(mapData.armouries) == "table" then
            for i, armouryDef in ipairs(mapData.armouries) do
                local armouryId = string.format("%s:%d", mapName, i)
                configs[armouryId] = armouryDef
            end
        end
    end

    return configs
end

-- Persists the current stockData to armoury.json
function SaveArmouryFile()
    SaveResourceFile(
        GetCurrentResourceName(),
        ARMOURY_SAVE_FILE,
        json.encode(stockData, { indent = true }),
        -1
    )
end

-- Persists in-game item list edits to armoury_items.json
function SaveArmouryItemsFile()
    SaveResourceFile(
        GetCurrentResourceName(),
        ARMOURY_ITEMS_FILE,
        json.encode(itemOverrides, { indent = true }),
        -1
    )
end

-- JSON turns grade keys into strings ("0"); convert them back to numbers
function NormaliseLimits(limits)
    local normalised = {}
    if type(limits) ~= "table" then return normalised end

    for gradeKey, limit in pairs(limits) do
        local grade = tonumber(gradeKey)
        local value = tonumber(limit)
        if grade and value then normalised[grade] = math.floor(value) end
    end

    return normalised
end

-- Returns (or initialises) the stock entry for a given armoury/item pair.
-- Merges default limits from the item definition if first-time init.
function GetOrInitStockEntry(armouryId, itemDef)
    if not stockData[armouryId] then
        stockData[armouryId] = {}
    end

    if not stockData[armouryId][itemDef.name] then
        local defaultStock = itemDef.stock or (Config.Armoury and Config.Armoury.DefaultStock)
        local entry = { stock = defaultStock, limits = {} }

        if type(itemDef.limits) == "table" then
            for gradeKey, limit in pairs(itemDef.limits) do
                entry.limits[tonumber(gradeKey) or gradeKey] = limit
            end
        end

        stockData[armouryId][itemDef.name] = entry
    end

    return stockData[armouryId][itemDef.name]
end

-- Finds an item definition in an armoury config by item name
function FindItemInArmoury(armouryDef, itemName)
    if not (armouryDef and type(armouryDef.items) == "table") then return nil end
    for _, item in ipairs(armouryDef.items) do
        if item.name == itemName then return item end
    end
    return nil
end

-- Returns the highest numeric grade key for the given job name, or nil
function GetMaxGradeForJob(jobName)
    local jobs = Bridge.Framework.getJobs and Bridge.Framework.getJobs()
    if not (jobs and jobs[jobName]) then return nil end

    local maxGrade = -1
    for gradeKey in pairs(jobs[jobName]) do
        local g = tonumber(gradeKey)
        if g and g > maxGrade then maxGrade = g end
    end

    return (maxGrade >= 0) and maxGrade or nil
end

-- Returns true if the item name starts with "weapon_"
function IsWeaponItem(itemName)
    return itemName:lower():sub(1, 7) == "weapon_"
end

-- Returns the item's license requirements as a table, or nil if none
function GetItemLicenses(itemDef)
    if type(itemDef.licenses) == "table" then return itemDef.licenses end
    if type(itemDef.license)  == "string" then return { itemDef.license } end
    return nil
end

-- Checks all required licenses against a cache; returns true or false + missing license name
function CheckPlayerLicenses(playerSource, itemDef, licenseCache)
    local required = GetItemLicenses(itemDef)
    if not required then return true end

    for _, licenseName in ipairs(required) do
        if licenseCache[licenseName] == nil then
            local has = Bridge.Framework.checkPlayerLicense(playerSource, licenseName)
            licenseCache[licenseName] = has or false
        end

        if not licenseCache[licenseName] then
            return false, licenseName
        end
    end

    return true
end

-- Generates a serial number in the format: 6digits + 3UpperLetters + 6digits
function GenerateSerialNumber()
    local chars = string.char(
        math.random(65, 90),
        math.random(65, 90),
        math.random(65, 90)
    )
    return string.format("%d%s%d", math.random(100000, 999999), chars, math.random(100000, 999999))
end

-- Returns true if the player's job is in Config.Jobs and meets the ManageGrade threshold
function PlayerCanManageArmoury(playerJob)
    if not (playerJob and Config.Jobs[playerJob.name]) then return false end
    local requiredGrade = (Config.Armoury and Config.Armoury.ManageGrade) or 0
    return playerJob.grade >= requiredGrade
end

-- Returns the remaining purchase allowance for a given player/armoury/item/grade.
-- Returns nil if no limit is set (unlimited). Returns 0 if fully spent.
function GetRemainingLimit(armouryId, itemName, uniqueId, playerGrade)
    local armEntry = stockData[armouryId] and stockData[armouryId][itemName]
    if not (armEntry and armEntry.limits) then return nil end

    local limit = armEntry.limits[playerGrade]
    if limit == nil then return nil end

    local spent = purchaseCounts[uniqueId]
        and purchaseCounts[uniqueId][armouryId]
        and purchaseCounts[uniqueId][armouryId][itemName]
        or 0

    return math.max(0, limit - spent)
end

-- Spawns a thread that attempts to register a weapon's serial with p_mdt
function RegisterWeaponInMDT(ownerId, itemName, serial)
    Citizen.CreateThread(function()
        if not (Config.Armoury and Config.Armoury.RegisterWeaponsInMDT) then return end
        if GetResourceState("p_mdt") ~= "started" then return end

        local itemData = Bridge.Inventory.getItemData(itemName)

        local ok, err = pcall(function()
            exports.p_mdt:RegisterWeapon(nil, {
                ownerId = ownerId,
                serial  = serial,
                model   = (itemData and itemData.label) or itemName,
            })
        end)

        if not ok then
            Bridge.Debug(string.format("[Armoury] MDT weapon registration failed: %s", tostring(err)))
        end
    end)
end

-- ─── Startup ─────────────────────────────────────────────────────────────────

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(100)

    -- Build armoury config map from department files
    armouryConfigs = BuildArmouryConfigs()

    -- Load persisted stock data from file
    local raw = LoadResourceFile(GetCurrentResourceName(), ARMOURY_SAVE_FILE)
    if raw and raw ~= "" then
        local decoded = json.decode(raw)
        if type(decoded) == "table" then
            stockData = decoded
        end
    end

    for _, armouryStock in pairs(stockData) do
        for _, entry in pairs(armouryStock) do
            entry.limits = NormaliseLimits(entry.limits)
        end
    end

    -- Apply in-game item list edits on top of the map definitions
    local rawItems = LoadResourceFile(GetCurrentResourceName(), ARMOURY_ITEMS_FILE)
    if rawItems and rawItems ~= "" then
        local decoded = json.decode(rawItems)
        if type(decoded) == "table" then
            itemOverrides = decoded
        end
    end

    for armouryId, items in pairs(itemOverrides) do
        if armouryConfigs[armouryId] and type(items) == "table" then
            armouryConfigs[armouryId].items = items
        end
    end

    -- Ensure all items have a stock entry; save defaults for any new items
    for armouryId, armouryDef in pairs(armouryConfigs) do
        if type(armouryDef.items) == "table" then
            for _, itemDef in ipairs(armouryDef.items) do
                GetOrInitStockEntry(armouryId, itemDef)
            end
        end
    end

    SaveArmouryFile()
end)

-- ─── Armoury Methods ─────────────────────────────────────────────────────────

-- Processes a purchase request; validates job, licenses, grade, stock, and limits.
-- Deducts money, gives items (with serial numbers for weapons), and updates stock/limits.
function Armoury:purchase(playerSource, payload)
    if not (payload and type(payload) == "table"
        and payload.account and payload.items and payload.armouryId) then
        return false
    end

    local armouryId  = payload.armouryId
    local armouryDef = armouryConfigs[armouryId]
    if not armouryDef then return false end

    local playerJob = Bridge.Framework.getPlayerJob(playerSource)
    if not (playerJob and Config.Jobs[playerJob.name]) then
        Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
        return false
    end

    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return false end

    -- Pre-validate all items and compute total cost
    local totalCost  = 0
    local licenseCache = {}

    for _, cartItem in ipairs(payload.items) do
        local itemDef = FindItemInArmoury(armouryDef, cartItem.id)
        if not itemDef then return false end

        if type(cartItem.quantity) ~= "number" or cartItem.quantity <= 0 then return false end

        local hasLicense, missingLicense = CheckPlayerLicenses(playerSource, itemDef, licenseCache)
        if not hasLicense then
            Bridge.Notify.showNotify(playerSource, locale("armoury_license_required", itemDef.name, missingLicense), "error")
            return false
        end

        if itemDef.minGrade and playerJob.grade < itemDef.minGrade then
            Bridge.Notify.showNotify(playerSource, locale("armoury_grade_required", itemDef.name), "error")
            return false
        end

        local stockEntry = GetOrInitStockEntry(armouryId, itemDef)

        if Config.Armoury and Config.Armoury.UseStock then
            if stockEntry.stock < cartItem.quantity then
                Bridge.Notify.showNotify(playerSource, locale("armoury_out_of_stock", itemDef.name), "error")
                return false
            end
        end

        local remaining = GetRemainingLimit(armouryId, cartItem.id, uniqueId, playerJob.grade)
        if remaining ~= nil and remaining < cartItem.quantity then
            Bridge.Notify.showNotify(playerSource, locale("armoury_limit_reached", itemDef.name), "error")
            return false
        end

        totalCost = totalCost + itemDef.price * cartItem.quantity
    end

    -- Process payment
    local playerMoney = Bridge.Framework.getMoney(playerSource)

    if payload.account == "society" then
        if not (Bridge.Society and Bridge.Society.getMoney and Bridge.Society.removeMoney) then
            Bridge.Notify.showNotify(playerSource, locale("not_enough_money"), "error")
            return false
        end

        local societyFunds = Bridge.Society.getMoney(playerSource, playerJob.name) or 0
        if totalCost > societyFunds then
            Bridge.Notify.showNotify(playerSource, locale("not_enough_money"), "error")
            return false
        end

        local removed = Bridge.Society.removeMoney(playerSource, playerJob.name, totalCost)
        if not removed then
            Bridge.Notify.showNotify(playerSource, locale("not_enough_money"), "error")
            return false
        end
    else
        local accountBalance = playerMoney[payload.account]
        if not accountBalance or totalCost > accountBalance then
            Bridge.Notify.showNotify(playerSource, locale("not_enough_money"), "error")
            return false
        end

        Bridge.Framework.removeMoney(playerSource, payload.account, totalCost)
    end

    -- Give items and update stock/limits
    local purchaseSummary = {}

    for _, cartItem in ipairs(payload.items) do
        local itemDef    = FindItemInArmoury(armouryDef, cartItem.id)
        local stockEntry = GetOrInitStockEntry(armouryId, itemDef)

        if IsWeaponItem(cartItem.id) then
            -- Weapons get individual serials, one at a time
            for _ = 1, cartItem.quantity do
                local serial = GenerateSerialNumber()
                Bridge.Inventory.addItem(playerSource, cartItem.id, 1, { serial = serial })
                RegisterWeaponInMDT(uniqueId, cartItem.id, serial)
            end
        else
            Bridge.Inventory.addItem(playerSource, cartItem.id, cartItem.quantity)
        end

        if Config.Armoury and Config.Armoury.UseStock then
            stockEntry.stock = math.max(0, stockEntry.stock - cartItem.quantity)
        end

        -- Track per-session purchase count for limit enforcement
        if not purchaseCounts[uniqueId] then purchaseCounts[uniqueId] = {} end
        if not purchaseCounts[uniqueId][armouryId] then purchaseCounts[uniqueId][armouryId] = {} end
        purchaseCounts[uniqueId][armouryId][cartItem.id] =
            (purchaseCounts[uniqueId][armouryId][cartItem.id] or 0) + cartItem.quantity

        purchaseSummary[#purchaseSummary + 1] = string.format("%sx %s", cartItem.quantity, cartItem.id)
    end

    SaveArmouryFile()

    -- Webhook log
    if Config.Webhooks and Config.Webhooks.armoury and Config.Webhooks.armoury ~= "" then
        local playerName = Bridge.Framework.getPlayerName and Bridge.Framework.getPlayerName(playerSource)
            or ("ID " .. playerSource)

        Bridge.Logs.Send(
            playerSource,
            "Armoury",
            string.format("%s purchased from %s for $%s (%s) - %s",
                playerName, armouryId, totalCost, payload.account,
                table.concat(purchaseSummary, ", ")),
            Config.Webhooks.armoury
        )
    end

    return true
end

-- Builds the items and categories list visible to a specific player/armoury combination.
-- Respects stock, limits, license checks, and grade requirements.
function BuildArmouryItemList(playerSource, armouryId, playerJob, uniqueId)
    local armouryDef = armouryConfigs[armouryId]
    if not armouryDef then return {}, {} end

    local items      = {}
    local categories = {}
    local seenCategories = {}
    local licenseCache   = {}

    for _, itemDef in ipairs(armouryDef.items) do
        local invItem = Bridge.Inventory.getItemData(itemDef.name)
        if not invItem then goto continue end

        local stockEntry    = GetOrInitStockEntry(armouryId, itemDef)
        local remaining     = GetRemainingLimit(armouryId, itemDef.name, uniqueId, playerJob.grade)
        local useStock      = Config.Armoury and Config.Armoury.UseStock

        -- Effective stock visible to client
        local effectiveStock
        if useStock then
            effectiveStock = stockEntry.stock
        else
            effectiveStock = -1
        end

        if remaining ~= nil then
            if effectiveStock == -1 then
                effectiveStock = remaining
            else
                effectiveStock = math.min(effectiveStock, remaining)
            end
        end

        -- Determine if this item is locked (grade check; license checked live on purchase)
        local locked = false
        if itemDef.minGrade then
            locked = playerJob.grade < itemDef.minGrade
        end

        items[#items + 1] = {
            id          = itemDef.name,
            name        = invItem.label,
            description = invItem.description,
            price       = itemDef.price,
            category    = itemDef.category,
            stock       = effectiveStock,
            locked      = locked,
        }

        if itemDef.category and not seenCategories[itemDef.category] then
            seenCategories[itemDef.category] = true
            categories[#categories + 1] = itemDef.category
        end

        ::continue::
    end

    return items, categories
end

-- ─── Callbacks ───────────────────────────────────────────────────────────────

-- Returns the item/category list for the player's armoury view
lib.callback.register("p_policejob/server/armoury/getItems", function(playerSource, armouryId)
    local playerJob = Bridge.Framework.getPlayerJob(playerSource)
    if not (playerJob and Config.Jobs[playerJob.name]) then return nil end

    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return nil end

    local items, categories = BuildArmouryItemList(playerSource, armouryId, playerJob, uniqueId)

    return {
        items      = items,
        categories = categories,
        canManage  = PlayerCanManageArmoury(playerJob),
        useStock   = Config.Armoury and Config.Armoury.UseStock,
    }
end)

-- Delegates purchase logic to Armoury:purchase
lib.callback.register("p_policejob/server/armoury/purchase", function(playerSource, payload)
    return Armoury:purchase(playerSource, payload)
end)

-- Returns management data (items with stock + limits) for a specific armoury
lib.callback.register("p_policejob/server/armoury/getManageData", function(playerSource, armouryId)
    local playerJob = Bridge.Framework.getPlayerJob(playerSource)
    if not PlayerCanManageArmoury(playerJob) then return nil end

    local armouryDef = armouryConfigs[armouryId]
    if not armouryDef then return nil end

    local items = {}
    for _, itemDef in ipairs(armouryDef.items) do
        local stockEntry = GetOrInitStockEntry(armouryId, itemDef)
        local invItem    = Bridge.Inventory.getItemData(itemDef.name)

        -- Grade keys are sent as strings so the NUI receives an object, not a sparse array
        local limits = {}
        for grade, limit in pairs(stockEntry.limits or {}) do
            limits[tostring(grade)] = limit
        end

        items[#items + 1] = {
            name     = itemDef.name,
            label    = (invItem and invItem.label) or itemDef.name,
            image    = invItem and invItem.image,
            price    = itemDef.price or 0,
            category = itemDef.category or "misc",
            minGrade = itemDef.minGrade,
            licenses = GetItemLicenses(itemDef) or {},
            stock    = stockEntry.stock,
            limits   = limits,
        }
    end

    -- Every registered inventory item, for the item name picker
    local availableItems = {}
    if GetResourceState("ox_inventory") == "started" then
        for name, data in pairs(exports.ox_inventory:Items() or {}) do
            availableItems[#availableItems + 1] = { name = name, label = data.label or name }
        end
        table.sort(availableItems, function(a, b) return a.label < b.label end)
    end

    local maxGrade = GetMaxGradeForJob(playerJob.name) or playerJob.grade

    return {
        armouryId      = armouryId,
        items          = items,
        availableItems = availableItems,
        playerGrade    = playerJob.grade,
        maxGrade       = maxGrade,
        useStock       = Config.Armoury and Config.Armoury.UseStock,
        defaultStock   = (Config.Armoury and Config.Armoury.DefaultStock) or 0,
    }
end)

-- Replaces the whole item list of an armoury (add/remove items, price, category, grade, licenses, stock, limits)
lib.callback.register("p_policejob/server/armoury/saveManage", function(playerSource, armouryId, payloadItems)
    local playerJob = Bridge.Framework.getPlayerJob(playerSource)
    if not PlayerCanManageArmoury(playerJob) then return false, "no_access" end

    local armouryDef = armouryConfigs[armouryId]
    if not armouryDef then return false, "invalid_armoury" end
    if type(payloadItems) ~= "table" then return false, "invalid_payload" end

    local newItems   = {}
    local newEntries = {}
    local seenNames  = {}

    for _, raw in ipairs(payloadItems) do
        local name = type(raw.name) == "string" and raw.name:gsub("^%s+", ""):gsub("%s+$", "") or ""
        if name == "" then return false, "empty_name" end
        if seenNames[name] then return false, ("duplicate:%s"):format(name) end
        if not Bridge.Inventory.getItemData(name) then return false, ("unknown_item:%s"):format(name) end
        seenNames[name] = true

        local price = tonumber(raw.price)
        if not price or price < 0 then return false, ("invalid_price:%s"):format(name) end

        local itemDef = {
            name     = name,
            price    = math.floor(price),
            category = (type(raw.category) == "string" and raw.category ~= "") and raw.category:lower() or "misc",
        }

        local minGrade = tonumber(raw.minGrade)
        if minGrade and minGrade > 0 then itemDef.minGrade = math.floor(minGrade) end

        if type(raw.licenses) == "table" then
            local licenses = {}
            for _, license in ipairs(raw.licenses) do
                if type(license) == "string" and license ~= "" then licenses[#licenses + 1] = license end
            end
            if #licenses > 0 then itemDef.licenses = licenses end
        end

        local stock = tonumber(raw.stock)
        newEntries[name] = {
            stock  = math.max(0, math.floor(stock or (Config.Armoury and Config.Armoury.DefaultStock) or 0)),
            limits = NormaliseLimits(raw.limits),
        }

        newItems[#newItems + 1] = itemDef
    end

    armouryDef.items         = newItems
    itemOverrides[armouryId] = newItems
    stockData[armouryId]     = newEntries

    SaveArmouryItemsFile()
    SaveArmouryFile()

    if Config.Webhooks and Config.Webhooks.armoury and Config.Webhooks.armoury ~= "" then
        local names = {}
        for _, itemDef in ipairs(newItems) do
            names[#names + 1] = ("%s ($%s)"):format(itemDef.name, itemDef.price)
        end

        Bridge.Logs.Send(playerSource, "Armoury",
            string.format("Updated armoury %s items: %s", armouryId, table.concat(names, ", ")),
            Config.Webhooks.armoury)
    end

    return true
end)

-- Sets the stock level for a specific item; requires manage access
lib.callback.register("p_policejob/server/armoury/setStock", function(playerSource, armouryId, itemName, newStock)
    local playerJob = Bridge.Framework.getPlayerJob(playerSource)
    if not PlayerCanManageArmoury(playerJob) then return false end

    local armouryDef = armouryConfigs[armouryId]
    if not armouryDef then return false end

    local itemDef = FindItemInArmoury(armouryDef, itemName)
    if not itemDef then return false end

    local amount = tonumber(newStock)
    if not amount or amount < 0 then return false end

    local entry = GetOrInitStockEntry(armouryId, itemDef)
    entry.stock = math.floor(amount)

    SaveArmouryFile()

    if Config.Webhooks and Config.Webhooks.armoury and Config.Webhooks.armoury ~= "" then
        Bridge.Logs.Send(playerSource, "Armoury",
            string.format("Set stock of %s @ %s to %s", itemName, armouryId, entry.stock),
            Config.Webhooks.armoury)
    end

    return true
end)

-- Sets the per-grade purchase limit for a specific item; requires manage access
lib.callback.register("p_policejob/server/armoury/setLimit", function(playerSource, armouryId, itemName, grade, limitValue)
    local playerJob = Bridge.Framework.getPlayerJob(playerSource)
    if not PlayerCanManageArmoury(playerJob) then return false end

    local armouryDef = armouryConfigs[armouryId]
    if not armouryDef then return false end

    local itemDef = FindItemInArmoury(armouryDef, itemName)
    if not itemDef then return false end

    local gradeNum = tonumber(grade)
    if not gradeNum then return false end

    local entry = GetOrInitStockEntry(armouryId, itemDef)
    if not entry.limits then entry.limits = {} end

    if limitValue == nil or limitValue == "" then
        -- Clear the limit (unlimited for this grade)
        entry.limits[gradeNum] = nil
    else
        local amount = tonumber(limitValue)
        if not amount or amount < 0 then return false end
        entry.limits[gradeNum] = math.floor(amount)
    end

    SaveArmouryFile()

    if Config.Webhooks and Config.Webhooks.armoury and Config.Webhooks.armoury ~= "" then
        Bridge.Logs.Send(playerSource, "Armoury",
            string.format("Set grade %s limit of %s @ %s to %s",
                gradeNum, itemName, armouryId, tostring(entry.limits[gradeNum])),
            Config.Webhooks.armoury)
    end

    return true
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

-- Remove the disconnected player's purchase count data
AddEventHandler("playerDropped", function()
    local droppedSource = source
    local uniqueId      = Bridge.Framework.getUniqueId and Bridge.Framework.getUniqueId(droppedSource)
    if uniqueId then
        purchaseCounts[uniqueId] = nil
    end
end)
