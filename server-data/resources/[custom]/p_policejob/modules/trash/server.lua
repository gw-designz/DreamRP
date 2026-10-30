while true do
    if Config and Config.Trash then break end
    Citizen.Wait(500)
end

if not Config.Trash.Enabled then return end

-- Track registered stash IDs to avoid double-registration
local registeredStashes = {}

-- ============================================================
--  Access check
-- ============================================================

local function hasJobAccess(playerSource)
    if not Config.Jobs then return true end
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end
    local minGrade = Config.Jobs[job.name]
    if minGrade == nil then return false end
    return minGrade <= (job.grade or 0)
end

-- ============================================================
--  Resolve or register a stash for the given trash ID
--  Returns the full stash identifier string
-- ============================================================

local function getOrCreateStash(rawId)
    local stashId = Config.Trash.StashPrefix .. "_" .. rawId

    if not registeredStashes[stashId] then
        registeredStashes[stashId] = true
        Bridge.Inventory.registerStash(
            stashId,
            locale("trash"),
            Config.Trash.Slots,
            Config.Trash.MaxWeight)
    end

    return stashId
end

-- ============================================================
--  Open event — validates access, registers stash
-- ============================================================

RegisterNetEvent("p_policejob/server/trash/open", function(rawId)
    local playerSource = source
    if not rawId or rawId == "" then return end

    if not hasJobAccess(playerSource) then
        Bridge.Debug(("[Trash] Player %s denied access to trash %s"):format(
            playerSource, tostring(rawId)))
        return
    end

    local safeId  = tostring(rawId):sub(1, 64)
    local stashId = getOrCreateStash(safeId)

    Bridge.Debug(("[Trash] Player %s opened trash %s (stash %s)"):format(
        playerSource, safeId, stashId))
end)

-- ============================================================
--  Clear event — validates access, clears stash inventory
-- ============================================================

RegisterNetEvent("p_policejob/server/trash/clear", function(rawId)
    local playerSource = source
    if not rawId or rawId == "" then return end

    if not hasJobAccess(playerSource) then
        Bridge.Debug(("[Trash] Player %s denied clearing trash %s"):format(
            playerSource, tostring(rawId)))
        return
    end

    local safeId  = tostring(rawId):sub(1, 64)
    local stashId = getOrCreateStash(safeId)

    if Bridge.Inventory.clearInventory then
        Bridge.Inventory.clearInventory(stashId)
    end

    Bridge.Debug(("[Trash] Player %s cleared trash %s (stash %s)"):format(
        playerSource, safeId, stashId))

    -- Webhook log (only if webhook configured and non-empty)
    local webhook = Config.Webhooks and Config.Webhooks.trash
    if webhook and webhook ~= "" then
        Bridge.Logs.Send(playerSource, "Trash",
            ("Cleared trash: %s"):format(safeId),
            webhook)
    end
end)
