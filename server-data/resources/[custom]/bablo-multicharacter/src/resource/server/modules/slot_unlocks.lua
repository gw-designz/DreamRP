local TABLE_NAME = "bablo_multicharacter_unlockedslots"

local MIGRATION_SQL = [[
CREATE TABLE IF NOT EXISTS `bablo_multicharacter_unlockedslots` (
    `identifier`  VARCHAR(64) NOT NULL,
    `slot_id`     INT         NOT NULL,
    `unlocked_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `unlocked_by` VARCHAR(64) DEFAULT NULL,
    PRIMARY KEY (`identifier`, `slot_id`),
    KEY `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

-- ─── Migration ───────────────────────────────────────────────────────────────

-- Wait up to 15 s for oxmysql to become available, then run the migration.
CreateThread(function()
    local deadline = GetGameTimer() + 15000
    while not (MySQL and MySQL.query and MySQL.query.await) do
        if GetGameTimer() >= deadline then break end
        Wait(50)
    end
    Wait(0)

    local ok, err = pcall(function() MySQL.query.await(MIGRATION_SQL) end)
    if ok then
        print(("^2[bablo-multicharacter] migration ok — `%s` ensured^7"):format(TABLE_NAME))
    else
        print(("^1[bablo-multicharacter] migration FAILED — %s^7"):format(tostring(err)))
    end
end)

-- ─── Identifier helpers ───────────────────────────────────────────────────────

-- Return the license identifier for a server source, or nil.
local function getLicenseForSource(src)
    return GetPlayerIdentifierByType(src, "license") or nil
end

-- Resolve a raw target string (server ID or "license:..." / "steam:..." etc.)
-- to a license identifier string. Returns identifier, or nil + error message.
local function resolveIdentifier(raw)
    if not raw or raw == "" then
        return nil, "missing target"
    end

    local serverId = tonumber(raw)
    if serverId and serverId > 0 and serverId < 100000 then
        local license = getLicenseForSource(serverId)
        if not license then
            return nil, ("no license for server id %d (player offline?)"):format(serverId)
        end
        return license
    end

    -- Accept any identifier that already contains a colon (license:..., steam:..., etc.).
    if raw:find(":", 1, true) then
        return raw
    end

    return nil, "expected server id or identifier (license:..., steam:...)"
end

-- ─── Slot queries ─────────────────────────────────────────────────────────────

-- Return a sorted list of slot indices that are marked locked on any scene in Config.Locations.
local function getPremiumSlotIndices()
    local seen = {}
    for _, location in ipairs(Config.Locations or {}) do
        if location and type(location.scenes) == "table" then
            for slotIndex, scene in ipairs(location.scenes) do
                if scene and scene.locked then
                    seen[slotIndex] = true
                end
            end
        end
    end

    local list = {}
    for slotIndex in pairs(seen) do
        list[#list + 1] = slotIndex
    end
    table.sort(list)
    return list
end

-- Return true if slotIndex is marked as locked on at least one scene in Config.Locations.
local function isSlotPremium(slotIndex)
    for _, location in ipairs(Config.Locations or {}) do
        if location and type(location.scenes) == "table" then
            local scene = location.scenes[slotIndex]
            if scene and scene.locked then return true end
        end
    end
    return false
end

-- Return the array of unlocked slot_ids for the given license identifier.
local function getUnlockedSlotsForIdentifier(identifier)
    if not identifier then return {} end

    local rows = MySQL.query.await(
        ("SELECT `slot_id` FROM `%s` WHERE `identifier` = ?"):format(TABLE_NAME),
        { identifier }
    ) or {}

    local slots = {}
    for _, row in ipairs(rows) do
        slots[#slots + 1] = tonumber(row.slot_id)
    end
    return slots
end

-- ─── Callback ─────────────────────────────────────────────────────────────────

-- resolveSlotAccess: called by the client during Init to determine which premium
-- slots the player has unlocked and which slots are premium in the current config.
lib.callback.register("bablo-multicharacter:server:resolveSlotAccess", function(src)
    local identifier = getLicenseForSource(src)
    return {
        unlockedSlots = getUnlockedSlotsForIdentifier(identifier),
        premium       = getPremiumSlotIndices(),
    }
end)

-- ─── Admin command helpers ────────────────────────────────────────────────────

-- Send a coloured chat message to src, or print to console if src <= 0.
local function notify(src, message)
    if src > 0 then
        TriggerClientEvent("chat:addMessage", src, {
            color = { 255, 200, 80 },
            args  = { "[multicharacter]", message },
        })
    else
        print(("[bablo-multicharacter] %s"):format(message))
    end
end

-- Guard: return false and notify if src is not an admin (or is console).
local function requireAdmin(src)
    if src > 0 then
        if not Framework.IsAdmin or not Framework:IsAdmin(src) then
            notify(src, "You do not have permission to use this command.")
            return false
        end
    end
    return true
end

-- Parse and validate the two arguments common to both slot commands.
-- Returns identifier, slotIndex on success, or calls notify + returns nil on failure.
local function parseSlotArgs(src, args, commandName)
    local identifier, err = resolveIdentifier(args[1])
    if not identifier then
        notify(src, ("Usage: /%s <serverId|license:...> <slotIndex> — %s"):format(
            commandName, err or ""))
        return nil
    end

    local slotIndex = tonumber(args[2])
    if not slotIndex or slotIndex < 1 then
        notify(src, ("Usage: /%s <serverId|license:...> <slotIndex>"):format(commandName))
        return nil
    end

    return identifier, slotIndex
end

-- ─── Slot commands ────────────────────────────────────────────────────────────

CreateThread(function()
    Wait(0)

    local cfg         = Config.SlotCommands or {}
    local openCmd     = cfg.open  or "openslot"
    local closeCmd    = cfg.close or "closeslot"

    -- /openslot <target> <slotIndex>  — grant a premium slot to a player.
    RegisterCommand(openCmd, function(src, args)
        if not requireAdmin(src) then return end

        local identifier, slotIndex = parseSlotArgs(src, args, openCmd)
        if not identifier then return end

        if not isSlotPremium(slotIndex) then
            notify(src, ("Slot %d is not marked as premium on any scene in Config.Locations — nothing to unlock."):format(slotIndex))
            return
        end

        -- Determine who is performing the unlock for auditing.
        local unlockedBy
        if src > 0 then
            unlockedBy = getLicenseForSource(src) or ("source:" .. src)
        else
            unlockedBy = "console"
        end

        MySQL.query.await(
            ("INSERT INTO `%s` (`identifier`, `slot_id`, `unlocked_by`) VALUES (?, ?, ?) " ..
             "ON DUPLICATE KEY UPDATE `unlocked_at` = CURRENT_TIMESTAMP, `unlocked_by` = VALUES(`unlocked_by`)"):format(TABLE_NAME),
            { identifier, slotIndex, unlockedBy }
        )
        notify(src, ("Slot %d unlocked for %s."):format(slotIndex, identifier))
    end, false)

    -- /closeslot <target> <slotIndex>  — revoke a premium slot from a player.
    RegisterCommand(closeCmd, function(src, args)
        if not requireAdmin(src) then return end

        local identifier, slotIndex = parseSlotArgs(src, args, closeCmd)
        if not identifier then return end

        MySQL.query.await(
            ("DELETE FROM `%s` WHERE `identifier` = ? AND `slot_id` = ?"):format(TABLE_NAME),
            { identifier, slotIndex }
        )
        notify(src, ("Slot %d revoked for %s."):format(slotIndex, identifier))
    end, false)
end)

-- ─── Export ───────────────────────────────────────────────────────────────────

exports("GetUnlockedSlotsForSource", function(src)
    local identifier = getLicenseForSource(src)
    return getUnlockedSlotsForIdentifier(identifier)
end)
