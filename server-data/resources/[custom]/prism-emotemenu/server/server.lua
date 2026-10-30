-- ============================================================
-- prism-emotemenu | server.lua
-- ============================================================

-- Pending shared emote requests: { [targetPlayerId] = { requester, emoteName, timestamp } }
local pendingRequests = {}


-- Validates that both server IDs belong to real connected players with existing peds
local function ValidateBothPlayers(playerIdA, playerIdB)
    if not GetPlayerName(playerIdA) or not GetPlayerName(playerIdB) then return false end

    local pedA = GetPlayerPed(playerIdA)
    local pedB = GetPlayerPed(playerIdB)
    if not DoesEntityExist(pedA) or not DoesEntityExist(pedB) then return false end

    return pedA, pedB
end

-- Returns true if the two peds are within 3 metres of each other
local function ArePlayersNearby(pedA, pedB)
    return #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= 3.0
end


-- ============================================================
-- requestSharedEmote  (requester → target)
-- ============================================================

RegisterNetEvent("prism-emotemenu:requestSharedEmote")
AddEventHandler("prism-emotemenu:requestSharedEmote", function(targetServerId, emoteName)
    local requesterServerId = source

    local pedRequester, pedTarget = ValidateBothPlayers(requesterServerId, targetServerId)
    if not pedRequester then return end
    if not ArePlayersNearby(pedRequester, pedTarget) then return end

    -- Store pending request so we can validate the accept/decline
    pendingRequests[targetServerId] = {
        requester  = requesterServerId,
        emoteName  = emoteName,
        timestamp  = os.time(),
    }

    TriggerClientEvent("prism-emotemenu:receiveSharedEmoteRequest", targetServerId, requesterServerId, emoteName)

    -- Auto-expire the request after 10 seconds if never responded to
    SetTimeout(10000, function()
        local pending = pendingRequests[targetServerId]
        if pending and pending.timestamp == pendingRequests[targetServerId].timestamp then
            pendingRequests[targetServerId] = nil
        end
    end)
end)


-- ============================================================
-- acceptSharedEmote  (target → requester)
-- ============================================================

RegisterNetEvent("prism-emotemenu:acceptSharedEmote")
AddEventHandler("prism-emotemenu:acceptSharedEmote", function(requesterServerId, emoteName)
    local accepterServerId = source

    -- Verify the pending request matches
    local pending = pendingRequests[accepterServerId]
    if not pending or pending.requester ~= requesterServerId then return end

    local pedAccepter, pedRequester = ValidateBothPlayers(accepterServerId, requesterServerId)
    if not pedAccepter then return end
    if not ArePlayersNearby(pedAccepter, pedRequester) then return end

    pendingRequests[accepterServerId] = nil

    -- Sync animation to both sides
    TriggerClientEvent("prism-emotemenu:syncEmote",       accepterServerId,  emoteName, requesterServerId)
    TriggerClientEvent("prism-emotemenu:syncEmoteSource", requesterServerId, emoteName, accepterServerId)
end)


-- ============================================================
-- declineSharedEmote  (target → requester)
-- ============================================================

RegisterNetEvent("prism-emotemenu:declineSharedEmote")
AddEventHandler("prism-emotemenu:declineSharedEmote", function(requesterServerId)
    local declinerServerId = source

    local pending = pendingRequests[declinerServerId]
    if not pending or pending.requester ~= requesterServerId then return end

    pendingRequests[declinerServerId] = nil

    TriggerClientEvent("prism-emotemenu:sharedEmoteDeclined", requesterServerId)
end)


-- ============================================================
-- cancelEmote  (one partner cancelled — relay to the other)
-- ============================================================

RegisterNetEvent("prism-emotemenu:cancelEmote")
AddEventHandler("prism-emotemenu:cancelEmote", function(partnerServerId)
    local callerServerId = source
    TriggerClientEvent("prism-emotemenu:cancelEmote", partnerServerId, callerServerId)
end)


-- ============================================================
-- playerDropped — clean up any pending requests involving them
-- ============================================================

AddEventHandler("playerDropped", function()
    local droppedServerId = source

    -- Remove any request they were the target of
    pendingRequests[droppedServerId] = nil

    -- Remove any requests they were the requester of, and notify the targets
    for targetId, pending in pairs(pendingRequests) do
        if pending.requester == droppedServerId then
            pendingRequests[targetId] = nil
            TriggerClientEvent("prism-emotemenu:sharedEmoteDeclined", targetId)
        end
    end
end)