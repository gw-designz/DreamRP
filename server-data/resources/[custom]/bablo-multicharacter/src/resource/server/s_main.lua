-- ─── Stub event handlers ─────────────────────────────────────────────────────
-- These are intentional no-ops in the original: hooks are registered so that
-- other resources / the framework can detect the event exists, but no server-side
-- logic is needed here (the real work happens in playtime.lua and slot_unlocks.lua).

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
end)

AddEventHandler("playerDropped", function(reason)
end)

-- ─── Server name callback ─────────────────────────────────────────────────────

-- Returns sv_projectName if set, falling back to sv_hostname.
-- Used by the client to produce a per-server KVP storage key for settings.
lib.callback.register("bablo-multicharacter:server:getServerName", function()
    local name = GetConvar("sv_projectName", "")
    if name == "" then
        name = GetConvar("sv_hostname", "")
    end
    return name
end)

-- ─── Routing bucket helpers ───────────────────────────────────────────────────

-- Track which players have been placed into the multichar bucket so we can
-- restore them when they select a character.
local playersInBucket = {}

-- Resolve the bucket ID to put a player into, based on Config.RoutingBucket:
--   false / nil  → no bucket (returns nil, caller skips SetPlayerRoutingBucket)
--   true         → use the player's own source ID as the bucket
--   number       → use that fixed bucket ID (floored)
local function resolveBucketId(src)
    local cfg = Config.RoutingBucket
    if cfg == nil or cfg == false then return nil end
    if cfg == true then return src end
    if type(cfg) == "number" then return math.floor(cfg) end
    return nil
end

-- Move a player back to bucket 0 (the default world) and clear the tracking entry.
local function leaveBucket(src)
    if playersInBucket[src] then
        SetPlayerRoutingBucket(src, 0)
        playersInBucket[src] = nil
    end
end

-- ─── Bucket callbacks ─────────────────────────────────────────────────────────

lib.callback.register("bablo-multicharacter:server:enterBucket", function(src)
    local bucketId = resolveBucketId(src)
    if bucketId ~= nil then
        SetPlayerRoutingBucket(src, bucketId)
        playersInBucket[src] = true
    end
    return true
end)

lib.callback.register("bablo-multicharacter:server:leaveBucket", function(src)
    leaveBucket(src)
    return true
end)

-- ─── Framework hooks: leave bucket on character load ─────────────────────────
-- Both QBCore and ESX fire their own "player loaded" events after the framework
-- has finished loading the character. We hook both so the player is moved back
-- to the main world regardless of which framework is running.

AddEventHandler("QBCore:Server:OnPlayerLoaded", function()
    if source and source > 0 then
        leaveBucket(source)
    end
end)

AddEventHandler("esx:playerLoaded", function(playerId)
    local src = tonumber(playerId)
    if src and src > 0 then
        leaveBucket(src)
    end
end)

-- Clean up tracking state when a player disconnects.
AddEventHandler("playerDropped", function()
    if source then
        playersInBucket[source] = nil
    end
end)
