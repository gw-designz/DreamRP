if not Config.Modules.VENDING_MACHINE then
    return
end

while not eventName do
    Wait(0)
end

-- Cooldown table: coordKey -> expiry timestamp (or -1 for permanent in debug)
local cooldowns = {}

-- Purge expired entries every minute
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        local now = os.time()
        for key, expiry in pairs(cooldowns) do
            if expiry and expiry < now then
                cooldowns[key] = nil
            end
        end
    end
end)

-- ─── Editor API ───────────────────────────────────────────────────────────────

function VendingEditor_GetCooldowns()
    local now = os.time()
    local result = {}
    for key, expiry in pairs(cooldowns) do
        if expiry == -1 or expiry > now then
            result[#result + 1] = {
                key = key,
                expiresAt = expiry,
                remaining = expiry == -1 and -1 or (expiry - now),
            }
        end
    end
    return result
end

function VendingEditor_ClearCooldown(key)
    cooldowns[key] = nil
end

function VendingEditor_ClearAll()
    cooldowns = {}
end

-- ─── Callbacks ────────────────────────────────────────────────────────────────

-- Check whether a vending machine is on cooldown and whether the player has a
-- required lockpick item (if Item.Require is enabled).
RegisterServerCallback({
    eventName = eventName .. "server:isVendingBroken",
    eventCallback = function(playerId, coordKey)
        local player = Framework.fetchPlayer(Framework, playerId)
        local requiredItemNames = Config.VendingMachines.Item.Names

        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        local now = os.time()
        local isBroken = cooldowns[coordKey] ~= nil

        if not isBroken then
            -- Machine is available — check if player has a required item
            local heldItem = nil

            if Config.VendingMachines.Item.Require then
                local playerItems = Inventory.getPlayerItemsCount(Inventory, playerId)
                for _, itemName in pairs(requiredItemNames) do
                    if playerItems[itemName] and playerItems[itemName] > 0 then
                        heldItem = itemName
                        break
                    end
                end
            else
                heldItem = true
            end

            if not heldItem then
                return { status = true, message = Translate("VENDING_MISSING_ITEM") }
            end

            return { status = false, message = "Not broken", itemData = heldItem }
        else
            -- Machine is on cooldown; in debug mode keep it permanent
            if Config.Debug then
                cooldowns[coordKey] = -1
            end
            return { status = true, message = Translate("VENDING_ALREADY_BROKEN") }
        end
    end,
})

-- Process the vending machine robbery: set cooldown, optionally break the item,
-- then give a random loot reward.
RegisterServerCallback({
    eventName = eventName .. "server:vendingRobbed",
    eventCallback = function(playerId, args)
        local player = Framework.fetchPlayer(Framework, playerId)
        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        if Main.isJobBlacklisted(Main, playerId, "VENDING_MACHINE") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        local coordKey = args.coordKey
        local heldItem = args.itemData

        -- Set cooldown
        cooldowns[coordKey] = os.time() + Config.VendingMachines.Cooldown

        -- Chance to break the lockpick item
        if Config.VendingMachines.Item.Require and heldItem and type(heldItem) == "string" then
            if math.random(1, 100) <= Config.VendingMachines.Item.BreakChance then
                local removed = Inventory.removePlayerItem(Inventory, playerId, heldItem, 1)
                if removed then
                    Framework.Notify(Framework, playerId, Translate("LOCKPICK_BROKE"))
                end
            end
        end

        -- Select loot
        local lootItem = SelectRandomItem(Config.VendingMachines.LootTables)
        if not lootItem then
            return { status = true, message = Translate("NOTHING_FOUND") }
        end

        local itemName = lootItem.name
        local count = 1
        if lootItem.count then
            count = math.random(lootItem.count[1], lootItem.count[2])
        end

        if itemName == "money" then
            Framework.addMoney(Framework, playerId, count)
            local logEntry = "Money x" .. count
            sendWebhook(playerId, "VENDING_MACHINE_ROBBERY", logEntry)
            Framework.Notify(Framework, playerId, Translate("GIVE_MONEY", { count }))
            return { status = true }
        else
            local given = Inventory.addPlayerItem(Inventory, playerId, itemName, count)
            if not given then
                return { status = false, message = "ITEM_FAILED_TO_GIVE" }
            end
            local label = lootItem.label or itemName
            local logEntry = itemName .. " x" .. count
            sendWebhook(playerId, "VENDING_MACHINE_ROBBERY", logEntry)
            Framework.Notify(Framework, playerId, Translate("ITEM_FOUND", { count, label }))
            return { status = true }
        end
    end,
})
