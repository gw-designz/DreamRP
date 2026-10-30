if not Config.Modules.ATM_ROBBERY then
    return
end

while not eventName do
    Wait(0)
end

-- Cooldown table: coordKey -> expiry timestamp
local atmCooldowns = {}

-- Per-player money pool accumulated while drilling: playerId -> amount
local playerPool = {}

-- ─── Cooldown helpers ─────────────────────────────────────────────────────────

local function coordsToKey(coords)
    return string.format("%.0f:%.0f:%.0f", coords.x, coords.y, coords.z)
end

local function isAtmOnCooldown(coords)
    local key = coordsToKey(coords)
    local expiry = atmCooldowns[key]
    if expiry and os.time() < expiry then
        return true
    end
    return false
end

local function setAtmCooldown(coords)
    local key = coordsToKey(coords)
    local duration = Config.AtmRobbery.GlobalCooldown or 300
    atmCooldowns[key] = os.time() + duration
end

-- ─── Editor API ───────────────────────────────────────────────────────────────

function AtmRobberyEditor_GetCooldowns()
    local now = os.time()
    local result = {}
    for key, expiry in pairs(atmCooldowns) do
        local remaining = expiry - now
        if remaining > 0 then
            result[#result + 1] = { key = key, remaining = remaining }
        end
    end
    return result
end

function AtmRobberyEditor_ClearCooldown(key)
    atmCooldowns[key] = nil
end

function AtmRobberyEditor_ClearAll()
    atmCooldowns = {}
end

-- ─── Callbacks ────────────────────────────────────────────────────────────────

-- Validate conditions before attaching the drill, then consume the required item.
RegisterServerCallback({
    eventName = eventName .. "server:atmRobberyAttach",
    eventCallback = function(playerId, args)
        local player = Framework.fetchPlayer(Framework, playerId)
        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        -- Police count check
        local employees = Framework.getEmployees(Framework, "police")
        local policeCount = (employees and #employees) or 0
        if policeCount < Config.AtmRobbery.PoliceRequired then
            return { status = false, message = "NOT_ENOUGH_POLICE" }
        end

        -- Required item check
        local requiredItem = Config.AtmRobbery.RequiredItem
        local playerItems = Inventory.getPlayerItemsCount(Inventory, playerId)
        local itemCount = playerItems[requiredItem]
        -- ⚠️ Original: `L7_2 = L7_2 > 0 or L7_2` — this means if count is nil/0
        --    the expression falls back to the raw value (falsy). Effectively: has item?
        local hasItem = itemCount and itemCount > 0
        if not hasItem then
            return { status = false, message = "NO_ITEM" }
        end

        -- Cooldown check
        if args.atmCoords and isAtmOnCooldown(args.atmCoords) then
            return { status = false, message = "COOLDOWN" }
        end

        Inventory.removePlayerItem(Inventory, playerId, requiredItem, 1)
        playerPool[playerId] = 0

        return { status = true }
    end,
})

-- Player cancelled the attach: refund the drill item.
RegisterServerCallback({
    eventName = eventName .. "server:atmRobberyAttachCancel",
    eventCallback = function(playerId)
        Inventory.addPlayerItem(Inventory, playerId, Config.AtmRobbery.RequiredItem, 1)
        return { status = true }
    end,
})

-- Each drilling tick adds a random amount to the player's money pool.
RegisterServerCallback({
    eventName = eventName .. "server:atmRobberyPoolAdd",
    eventCallback = function(playerId)
        local player = Framework.fetchPlayer(Framework, playerId)
        if not player then
            return { status = false }
        end

        local minAdd = Config.AtmRobbery.PoolPerPedMin or 200
        local maxAdd = Config.AtmRobbery.PoolPerPedMax or 600
        local added = math.random(minAdd, maxAdd)

        playerPool[playerId] = (playerPool[playerId] or 0) + added

        return { status = true, added = added, total = playerPool[playerId] }
    end,
})

-- Return the player's current accumulated pool without modifying it.
RegisterServerCallback({
    eventName = eventName .. "server:atmRobberyPoolCheck",
    eventCallback = function(playerId)
        return { status = true, pool = playerPool[playerId] or 0 }
    end,
})

-- Drain the pool: give money to player, set ATM cooldown, send webhook.
RegisterServerCallback({
    eventName = eventName .. "server:atmRobberyDrain",
    eventCallback = function(playerId, args)
        local player = Framework.fetchPlayer(Framework, playerId)
        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        if Main.isJobBlacklisted(Main, playerId, "ATM_ROBBERY") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        local pool = playerPool[playerId] or 0
        if pool <= 0 then
            return { status = false, message = "EMPTY" }
        end

        Framework.addMoney(Framework, playerId, pool)

        if args.atmCoords then
            setAtmCooldown(args.atmCoords)
        end

        sendWebhook(playerId, "ATM_ROBBERY_DRAIN", "Money x" .. pool)
        playerPool[playerId] = 0

        return {
            status = true,
            reward = pool,
            message = Translate("GIVE_MONEY", { pool }),
        }
    end,
})

-- Detach drill: chance to break the item, then clear player pool entry.
RegisterServerCallback({
    eventName = eventName .. "server:atmRobberyDetach",
    eventCallback = function(playerId)
        local player = Framework.fetchPlayer(Framework, playerId)
        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        local requiredItem = Config.AtmRobbery.RequiredItem
        local breakChance = Config.AtmRobbery.ItemBreakChanceOnRemove or 20
        local broke = breakChance >= math.random(1, 100)

        if not broke then
            Inventory.addPlayerItem(Inventory, playerId, requiredItem, 1)
        end

        playerPool[playerId] = nil

        return { status = true, broke = broke }
    end,
})

-- Clean up pool entry when a player disconnects.
AddEventHandler("playerDropped", function()
    playerPool[source] = nil
end)
