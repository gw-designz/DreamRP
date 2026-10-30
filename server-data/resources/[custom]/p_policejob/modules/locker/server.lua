-- Wait for Config.Locker to be available
while not (Config and Config.Locker) do Citizen.Wait(500) end

if not Config.Locker.Enabled then return end

-- registeredStashes[stashId] = true — prevents re-registering the same stash
local registeredStashes = {}

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Returns true if the given player's job meets the locker access threshold
local function PlayerHasLockerAccess(playerSource)
    if not Config.Jobs then return true end

    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end

    local threshold = Config.Jobs[job.name]
    if threshold == nil then return false end

    return threshold <= job.grade
end

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Client → server: player opened a locker; register its stash if not already done
RegisterNetEvent("p_policejob/server/locker/open", function(rawLockerId)
    local playerSource = source

    if not rawLockerId or rawLockerId == "" then return end

    if not PlayerHasLockerAccess(playerSource) then
        Bridge.Debug(string.format("[Locker] Player %s denied access to locker %s",
            playerSource, tostring(rawLockerId)))
        return
    end

    local lockerId = tostring(rawLockerId):sub(1, 64)
    local stashId  = Config.Locker.StashPrefix .. "_" .. lockerId

    if registeredStashes[stashId] then return end

    registeredStashes[stashId] = true

    Bridge.Debug(string.format("[Locker] Player %s opened locker %s (stash %s)",
        playerSource, lockerId, stashId))

    if Bridge.Inventory.registerStash then
        Bridge.Inventory.registerStash(stashId, stashId,
            Config.Locker.Slots,
            Config.Locker.MaxWeight)
    end

    if Config.Webhooks and Config.Webhooks.locker and Config.Webhooks.locker ~= "" then
        Bridge.Logs.Send(playerSource, "Locker",
            string.format("Opened locker: %s", lockerId),
            Config.Webhooks.locker)
    end
end)

-- ─── Callbacks ────────────────────────────────────────────────────────────────

lib.callback.register("p_policejob/server/locker/checkAccess", function(playerSource)
    return PlayerHasLockerAccess(playerSource)
end)
