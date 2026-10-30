local cooldowns = {}

-- ────────────────────────────────────────────────────────────
-- Guard: module must be enabled in Config
-- ────────────────────────────────────────────────────────────
if not Config.Modules.PARCEL_THEFT then
    return
end

-- ────────────────────────────────────────────────────────────
-- Helper: build a fresh cooldown entry with the configured TTL
-- ────────────────────────────────────────────────────────────
function BuildCooldownEntry()
    return {
        cooldown  = true,
        timestamp = os.time() + Config.Parcels.Cooldown,
    }
end

-- ────────────────────────────────────────────────────────────
-- Editor utilities (exposed globally for the in-game editor)
-- ────────────────────────────────────────────────────────────

function ParcelsEditor_GetCooldowns()
    local now    = os.time()
    local result = {}

    for key, entry in pairs(cooldowns) do
        if entry and entry.cooldown then
            local ts = entry.timestamp
            -- -1 means permanent / never-expiring cooldown
            if ts == -1 or now < ts then
                local remaining = (ts == -1) and -1 or (ts - now)
                result[#result + 1] = {
                    key       = tostring(key),
                    expiresAt = ts,
                    remaining = remaining,
                }
            end
        end
    end

    return result
end

function ParcelsEditor_ClearCooldown(key)
    local numericKey = tonumber(key)
    cooldowns[numericKey or key] = nil
end

function ParcelsEditor_ClearAll()
    for key in pairs(cooldowns) do
        cooldowns[key] = nil
    end
end

-- ────────────────────────────────────────────────────────────
-- Shared parcel builders (used by callbacks)
-- ────────────────────────────────────────────────────────────

function getParcels()
    local result = {}

    for id, data in pairs(Config.Parcels.Houses) do
        result[id] = {
            id       = id,
            coords   = data.coords,
            heading  = data.heading,
            prop     = data.prop      or "hei_prop_heist_box",
            distance = data.distance  or 25.0,
            cooldown = cooldowns[id] ~= nil,
        }
    end

    return result
end

function getParcel(id)
    local data = Config.Parcels.Houses[id]
    if not data then return nil end

    return {
        id       = id,
        coords   = data.coords,
        heading  = data.heading,
        prop     = data.prop     or "hei_prop_heist_box",
        distance = data.distance or 25.0,
        cooldown = cooldowns[id] ~= nil,
    }
end

-- ────────────────────────────────────────────────────────────
-- Startup: wait for eventName to be ready, then run the loop
-- ────────────────────────────────────────────────────────────

while not eventName do
    Wait(0)
end

Citizen.CreateThread(function()
    local houses = Config.Parcels.Houses
    if not houses or #houses < 1 then
        Trace("No locations found")
        return
    end

    local spawnChance = Config.Parcels.Chance

    -- Initial pass: randomly put some locations on cooldown so not every
    -- spot has a parcel waiting the moment the script starts.
    for id in pairs(houses) do
        if math.random(1, 100) > spawnChance then
            cooldowns[id] = BuildCooldownEntry()
        end
    end

    Citizen.Wait(2000)

    -- Main tick: every 5 s, check expired cooldowns and decide whether
    -- to spawn a new parcel or extend the cooldown.
    while true do
        local updatedIds   = {}
        local updateCount  = 0
        local now          = os.time()

        for id, entry in pairs(cooldowns) do
            if entry and entry.timestamp and entry.timestamp < now then
                updateCount = updateCount + 1
                updatedIds[updateCount] = id

                if math.random(1, 100) <= spawnChance then
                    -- Parcel becomes available again
                    cooldowns[id] = nil
                else
                    -- Keep on cooldown for another cycle
                    cooldowns[id] = BuildCooldownEntry()
                end
            end
        end

        if updateCount > 0 then
            Trace("Updated " .. updateCount .. " parcels")

            -- Collect the updated parcel data and push to all clients
            local changedParcels = {}
            local allParcels     = getParcels()
            for _, id in pairs(updatedIds) do
                changedParcels[id] = allParcels[id]
            end

            TriggerClientEvent(eventName .. "client:updateParcels", -1, changedParcels)
        end

        Citizen.Wait(5000)
    end
end)

-- ────────────────────────────────────────────────────────────
-- Server callback: fetch all available parcels for a client
-- ────────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName = eventName .. "server:getParcels",
    eventCallback = function(source, data)
        local houses = Config.Parcels.Houses
        if not houses or #houses < 1 then
            return { status = false, message = "NO_LOCATIONS" }
        end

        local available = {}
        for id, houseData in pairs(houses) do
            if not cooldowns[id] and houseData.coords then
                available[id] = {
                    id       = id,
                    coords   = houseData.coords,
                    heading  = houseData.heading,
                    prop     = houseData.prop     or "hei_prop_heist_box",
                    distance = houseData.distance or 25.0,
                    cooldown = false,
                }
            end
        end

        return { status = true, parcels = available }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Server callback: player steals a parcel
-- ────────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName = eventName .. "server:stealParcel",
    eventCallback = function(source, parcelId)
        if not Framework:fetchPlayer(source) then
            return { status = false, message = "NO_CHARACTER" }
        end

        if not parcelId then
            return { status = false, message = "NO_PARCEL_ID" }
        end

        if not Config.Parcels.Houses[parcelId] then
            return { status = false, message = "NO_PARCEL" }
        end

        if cooldowns[parcelId] then
            return { status = false, message = "ALREADY_TAKEN" }
        end

        -- Mark the parcel as taken
        cooldowns[parcelId] = BuildCooldownEntry()

        -- Notify all clients of the change
        TriggerClientEvent(eventName .. "client:updateParcels", -1, { [parcelId] = getParcel(parcelId) })

        -- Give the item to the player
        if not Inventory:addPlayerItem(source, "bpackage", 1) then
            return { status = false, message = "FAILED_TO_GIVE_ITEM" }
        end

        return { status = true, message = "PARCEL_TAKEN" }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Server callback: open a parcel and distribute loot
-- ────────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName = eventName .. "server:giveParcelLoot",
    eventCallback = function(source, payload)
        -- payload = { itemName, itemData, giveLoot }
        if not Framework:fetchPlayer(source) then
            return { status = false, message = "NO_CHARACTER" }
        end

        if Main:isJobBlacklisted(source, "PARCEL_THEFT") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        local itemName = payload.itemName
        local itemData = payload.itemData
        local giveLoot = payload.giveLoot

        -- Remove the parcel package from the player's inventory
        if not Inventory:removePlayerItem(source, itemData, 1) then
            Trace("Failed to remove item")
            return { status = false, message = "FAILED_TO_REMOVE_ITEM" }
        end

        -- If the parcel yields no loot (e.g. empty package), just succeed
        if not giveLoot then
            return { status = true, success = true }
        end

        -- Find the matching loot table entry
        for _, lootEntry in pairs(Config.Parcels.LootTables) do
            if lootEntry.name == itemName then
                local count = 1
                if lootEntry.count then
                    count = math.random(lootEntry.count[1], lootEntry.count[2])
                end

                if itemName == "money" then
                    Framework:addMoney(source, count)
                    sendWebhook(source, "OPENED_PARCEL", "Money x" .. count)
                    return {
                        status  = true,
                        success = true,
                        message = Translate("GIVE_MONEY", { count }),
                    }
                else
                    local added = Inventory:addPlayerItem(source, itemName, count)
                    sendWebhook(source, "OPENED_PARCEL", itemName .. " x" .. count)

                    if not added then
                        return { status = false, message = "ITEM_FAILED_TO_GIVE" }
                    end

                    return {
                        status  = true,
                        success = true,
                        message = Translate("ITEM_FOUND", { count, lootEntry.label or "Item" }),
                    }
                end
            end
        end

        -- No matching loot table entry found
        return { status = false, message = "INVALID_LOOT_ITEM" }
    end,
})