if not Config.Modules.PARKING_METER_ROBBERY then
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

function ParkingMeterEditor_GetCooldowns()
    local now = os.time()
    local result = {}
    for key, expiry in pairs(cooldowns) do
        if expiry == -1 or expiry > now then
            result[#result + 1] = {
                key      = key,
                expiresAt = expiry,
                remaining = expiry == -1 and -1 or (expiry - now),
            }
        end
    end
    return result
end

function ParkingMeterEditor_ClearCooldown(key)
    cooldowns[key] = nil
end

function ParkingMeterEditor_ClearAll()
    cooldowns = {}
end

-- ─── Events ───────────────────────────────────────────────────────────────────

-- Mark a parking meter broken and optionally break the player's lockpick item.
RegisterNetEvent(eventName .. "server:setBrokenParkingMeter")
AddEventHandler(eventName .. "server:setBrokenParkingMeter", function(args)
    local playerId = source
    local player = Framework.fetchPlayer(Framework, playerId)
    if not player then return end

    local expiry = os.time() + Config.ParkingMeters.Cooldown
    cooldowns[args.coordKey] = expiry

    Trace(
        "Parking meter broken at coordKey: " .. args.coordKey ..
        " until: " .. expiry ..
        " current time: " .. os.time()
    )

    -- Optionally break the lockpick item
    if not Config.ParkingMeters.Item.Require then return end
    if not args.itemData then return end

    -- ⚠️ Original assigns args.itemData to a bare global `itemData` (no `local`).
    --    This looks like a bug — the value is immediately used and never read elsewhere.
    --    Treating it as a local here.
    local heldItem = args.itemData

    if math.random(1, 100) <= Config.ParkingMeters.Item.BreakChance then
        local removed = Inventory.removePlayerItem(Inventory, playerId, heldItem, 1)
        if not removed then
            Trace("Failed to remove item")
            return
        end
        Framework.Notify(Framework, playerId, Translate("LOCKPICK_BROKE"))
    end
end)

-- ─── Callbacks ────────────────────────────────────────────────────────────────

-- Check whether a meter is on cooldown and whether the player has a lockpick.
RegisterServerCallback({
    eventName = eventName .. "server:isParkingMeterBroken",
    eventCallback = function(playerId, coordKey)
        local player = Framework.fetchPlayer(Framework, playerId)
        local requiredItemNames = Config.ParkingMeters.Item.Names

        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        local storedExpiry = cooldowns[coordKey]
        local isAvailable = storedExpiry == nil

        Trace(
            "Checking parking meter coordKey: " .. coordKey ..
            " stored time: " .. tostring(storedExpiry) ..
            " current time: " .. os.time() ..
            " available: " .. tostring(isAvailable)
        )

        if isAvailable then
            -- Meter is available — check lockpick requirement
            local heldItem = nil

            if Config.ParkingMeters.Item.Require then
                local playerItems = Inventory.getPlayerItemsCount(Inventory, playerId)
                for _, itemName in pairs(requiredItemNames) do
                    if playerItems and playerItems[itemName] and playerItems[itemName] > 0 then
                        heldItem = itemName
                        break
                    end
                end
            else
                heldItem = true
            end

            if not heldItem then
                return { status = true, message = Translate("PARKING_METER_MISSING_LOCKPICK") }
            end

            return { status = false, message = "Not broken", itemData = heldItem }
        else
            -- Meter is on cooldown
            if Config.Debug then
                cooldowns[coordKey] = -1
                Trace("Parking meter is resetted")
            end
            -- ⚠️ Original always prints this Trace even outside debug mode.
            --    Preserved as-is.
            Trace("Parking meter is resetted")
            return { status = true, message = Translate("PARKING_METER_ALREADY_BROKEN") }
        end
    end,
})

-- Give the player their loot reward for successfully robbing a parking meter.
RegisterServerCallback({
    eventName = eventName .. "server:giveParkingMeterLoot",
    eventCallback = function(playerId, args)
        local itemName = args.itemName

        local player = Framework.fetchPlayer(Framework, playerId)
        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        if Main.isJobBlacklisted(Main, playerId, "PARKING_METER_ROBBERY") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        -- Find the matching loot entry
        for _, lootEntry in pairs(Config.ParkingMeters.LootTables) do
            if lootEntry.name == itemName then
                local count = 1
                if lootEntry.count then
                    count = math.random(lootEntry.count[1], lootEntry.count[2])
                end

                if itemName == "money" then
                    Framework.addMoney(Framework, playerId, count)
                    local logEntry = "Money x" .. count
                    sendWebhook(playerId, "PARKING_METER_ROBBERY", logEntry)
                    return { status = true, message = Translate("GIVE_MONEY", { count }) }
                else
                    local given = Inventory.addPlayerItem(Inventory, playerId, itemName, count)
                    local logEntry = itemName .. " x" .. count
                    if not given then
                        return { status = false, message = "ITEM_FAILED_TO_GIVE" }
                    end
                    sendWebhook(playerId, "PARKING_METER_ROBBERY", logEntry)
                    return {
                        status = true,
                        message = Translate("ITEM_FOUND", { count, lootEntry.label or "Item" }),
                    }
                end
            end
        end

        return { status = false, message = "INVALID_LOOT_ITEM" }
    end,
})