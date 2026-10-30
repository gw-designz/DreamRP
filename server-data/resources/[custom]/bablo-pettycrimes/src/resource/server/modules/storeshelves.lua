if not Config.Modules.STORE_SHELVES then
    return
end

while not eventName do
    Wait(0)
end

-- Cooldown table: shelfKey -> expiry timestamp
local shelfCooldowns = {}

-- Purge expired entries every minute
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for key, expiry in pairs(shelfCooldowns) do
            if expiry <= now then
                shelfCooldowns[key] = nil
            end
        end
    end
end)

-- ─── Editor API ───────────────────────────────────────────────────────────────

function StoreShelvesEditor_GetCooldowns()
    local now = os.time()
    local result = {}
    for key, expiry in pairs(shelfCooldowns) do
        if expiry > now then
            result[#result + 1] = { key = key, label = key, remaining = expiry - now }
        end
    end
    return result
end

function StoreShelvesEditor_ClearCooldown(key)
    shelfCooldowns[key] = nil
end

function StoreShelvesEditor_ClearAll()
    shelfCooldowns = {}
end

-- ─── Events ───────────────────────────────────────────────────────────────────

-- Mark a shelf as broken (on cooldown) after a successful robbery.
RegisterNetEvent(eventName .. "server:setShelfBroken")
AddEventHandler(eventName .. "server:setShelfBroken", function(shelfKey)
    shelfCooldowns[shelfKey] = os.time() + Config.StoreShelves.Cooldown
end)

-- ─── Callbacks ────────────────────────────────────────────────────────────────

-- Return true if the shelf is currently on cooldown.
RegisterServerCallback({
    eventName = eventName .. "server:isShelfBroken",
    eventCallback = function(playerId, shelfKey)
        local expiry = shelfCooldowns[shelfKey]
        if expiry and os.time() < expiry then
            return true
        end
        return false
    end,
})

-- Give loot from every loot table entry that passes its chance roll.
RegisterNetEvent(eventName .. "server:giveShelfLoot")
AddEventHandler(eventName .. "server:giveShelfLoot", function()
    local playerId = source

    if Main.isJobBlacklisted(Main, playerId, "STORE_SHELVES") then return end

    local lootTables = Config.StoreShelves.LootTables
    if not lootTables or #lootTables == 0 then return end

    local anyGiven = false

    for _, lootEntry in ipairs(lootTables) do
        local chance = lootEntry.chance or 100
        if math.random(1, 100) <= chance then
            -- Determine count
            local count = 1
            if lootEntry.count then
                if type(lootEntry.count) == "table" then
                    count = math.random(lootEntry.count[1], lootEntry.count[2])
                elseif type(lootEntry.count) == "number" then
                    count = lootEntry.count
                end
            end

            if lootEntry.name == "money" then
                Inventory.addPlayerMoney(Inventory, playerId, "cash", count)
            else
                Inventory.addPlayerItem(Inventory, playerId, lootEntry.name, count)
            end
            anyGiven = true
        end
    end

    if anyGiven then
        sendWebhook(playerId, "STORE_SHELVES", "Successfully searched store shelves and received loot.")
    end
end)
