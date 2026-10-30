if not (Config and Config.K9 and Config.K9.enabled) then return end

-- Global K9 object shared across the resource
K9 = {}

-- activeK9s[playerSource] = { breed = string }
local activeK9s = {}

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Returns true if the given player's job grade meets the K9 access threshold
local function PlayerHasK9Access(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end

    local threshold = Config.Jobs[job.name]
    if not threshold then return false end

    return threshold <= tonumber(job.grade)
end

-- ─── Callbacks ───────────────────────────────────────────────────────────────

-- Validates access and registers a K9 deployment for the requesting player
lib.callback.register("p_policejob/k9/spawn", function(playerSource, requestedBreed)
    if not PlayerHasK9Access(playerSource) then
        return false, locale("no_access")
    end

    if activeK9s[playerSource] then
        return false, "K9 already deployed"
    end

    -- Find the matching breed config (default to first)
    local breedToUse = Config.K9.models[1].breed
    for _, entry in ipairs(Config.K9.models) do
        if entry.breed == requestedBreed then
            breedToUse = requestedBreed
            break
        end
    end

    activeK9s[playerSource] = { breed = breedToUse }

    Bridge.Debug(string.format("[K9] %s deployed K9: %s", playerSource, breedToUse))

    return true
end)

-- Removes a player's K9 registration
lib.callback.register("p_policejob/k9/dismiss", function(playerSource)
    activeK9s[playerSource] = nil
    return true
end)

-- Returns the network id of a target player's ped for the K9 to follow
lib.callback.register("p_policejob/k9/getTargetNetId", function(playerSource, targetServerId)
    if not activeK9s[playerSource] then
        return false, "No K9 deployed"
    end

    if playerSource == targetServerId then
        return false, "Cannot target yourself"
    end

    local targetPed = GetPlayerPed(targetServerId)
    if not (targetPed and targetPed ~= 0) then
        return false, "Player not found"
    end

    return true, NetworkGetNetworkIdFromEntity(targetPed)
end)

-- Performs a K9 drug search on the target player's inventory
-- Returns: success (bool), hasIllegal (bool), illegalItems (table)
lib.callback.register("p_policejob/k9/searchPlayer", function(playerSource, targetServerId)
    if not PlayerHasK9Access(playerSource) then return false end
    if not activeK9s[playerSource] then return false end
    if not targetServerId or playerSource == targetServerId then return false end

    local officerPed = GetPlayerPed(playerSource)
    local targetPed  = GetPlayerPed(targetServerId)
    if not (targetPed and targetPed ~= 0) then return false end

    -- Distance check
    local maxDist = Config.K9.searchDistance or 5.0
    local dist    = #(GetEntityCoords(officerPed) - GetEntityCoords(targetPed))
    if dist > maxDist then
        return false, "too_far"
    end

    -- Check target's inventory for configured illegal items
    local illegalItems = {}
    for _, itemName in ipairs(Config.K9.searchItems or {}) do
        local count = Bridge.Inventory.getItemCount(targetServerId, itemName)
        if count and count > 0 then
            illegalItems[#illegalItems + 1] = itemName
        end
    end

    local illegalStr = (#illegalItems > 0) and table.concat(illegalItems, ", ") or "none"
    Bridge.Debug(string.format("[K9] %s searched %s - illegal items found: %s",
        playerSource, targetServerId, illegalStr))

    return true, (#illegalItems > 0), illegalItems
end)

-- ─── Event Handlers ──────────────────────────────────────────────────────────

AddEventHandler("playerDropped", function()
    activeK9s[source] = nil
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("GetActiveK9", function(playerSource)
    return activeK9s[playerSource]
end)

exports("IsK9Active", function(playerSource)
    return activeK9s[playerSource] ~= nil
end)
