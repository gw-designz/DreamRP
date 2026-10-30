--[[
    shared/doorgroups.lua

    Shared, framework-agnostic helpers used by BOTH client and server:
      - Door group membership helpers (group_id linking, §5)
      - Dependency graph evaluation (trigger objects, §5)
      - A couple of small pure-Lua utility functions

    Nothing in this file talks to the DB, natives, or NUI — it only
    operates on plain Lua tables so the exact same logic can run on
    both sides without duplication/drift.

    ── Access rule shape (stored as JSON in doorlocks.access) ──
    {
        mode = 'any' | 'all',       -- OR vs AND across the *categories* below
        jobs        = { { job = 'police', grade = 0 }, ... },
        gangs       = { { gang = 'ballas', grade = 0 }, ... },
        identifiers = { 'ABC123...', 'license:xxxx', ... },
        items       = { { item = 'lockpick', remove = false }, ... },
        password    = { enabled = false, hash = nil, algo = 'sha256' },
        permission  = 'admin' | nil,        -- Qbox permission group, not a FiveM ace
        keys        = { enabled = false },  -- uses door.id as the key tag
    }

    ── Dependency shape (stored as JSON in doorlocks.dependencies) ──
    {
        { type = 'door', id = 12, requiredState = 'unlocked' },
        { type = 'switch', id = 'lever_01', requiredState = 'on' },
    }
]]

DoorShared = {}

-- ────────────────────────────────────────────────────────────────
-- Door groups (§5) — doors sharing group_id toggle together.
-- ────────────────────────────────────────────────────────────────

--- Returns every door in `doors` (an array or id-keyed map of door rows)
--- that shares the given group_id, excluding nothing (includes self).
---@param doors table<number, table>
---@param groupId string
---@return table[]
function DoorShared.GetGroupMembers(doors, groupId)
    local members = {}
    if not groupId or groupId == '' then return members end
    for _, door in pairs(doors) do
        if door.group_id == groupId then
            members[#members + 1] = door
        end
    end
    return members
end

-- ────────────────────────────────────────────────────────────────
-- Dependency graph (§5) — vault-style multi-step unlocks.
-- A door with dependencies can only be locked/unlocked once every
-- dependency's `requiredState` is currently satisfied.
-- ────────────────────────────────────────────────────────────────

--- Evaluate whether all of a door's dependencies are currently satisfied.
---@param dependencies table[] array of {type, id, requiredState}
---@param doorsById table<number, table> id -> door row (needs .locked)
---@param switchStates table<any, string> switch id -> current state string
---@return boolean satisfied
---@return table|nil failedDependency the first dependency that failed, if any
function DoorShared.CheckDependencies(dependencies, doorsById, switchStates)
    if not dependencies or #dependencies == 0 then
        return true, nil
    end

    for _, dep in ipairs(dependencies) do
        if dep.type == 'door' then
            local target = doorsById[dep.id]
            if not target then
                -- Referenced door no longer exists; fail closed.
                return false, dep
            end
            local currentState = target.locked and 'locked' or 'unlocked'
            if currentState ~= dep.requiredState then
                return false, dep
            end
        elseif dep.type == 'switch' then
            local currentState = switchStates and switchStates[dep.id]
            if currentState ~= dep.requiredState then
                return false, dep
            end
        end
        -- Unknown dependency types are ignored rather than hard-failing,
        -- so future dependency kinds can be added without breaking
        -- doors created before they existed.
    end

    return true, nil
end

-- ────────────────────────────────────────────────────────────────
-- Small generic utilities
-- ────────────────────────────────────────────────────────────────

--- Shallow-safe JSON decode that never throws — returns `default` (or {})
--- on any failure. Used everywhere we pull JSON columns back out of MySQL.
function DoorShared.SafeDecode(raw, default)
    if raw == nil or raw == '' then return default or {} end
    if type(raw) == 'table' then return raw end -- oxmysql already decoded it
    local ok, decoded = pcall(json.decode, raw)
    if ok and decoded ~= nil then return decoded end
    return default or {}
end

--- Trims a string. Lua has no built-in trim.
function DoorShared.Trim(s)
    if type(s) ~= 'string' then return s end
    return s:match('^%s*(.-)%s*$')
end

--- Returns true if `tbl` is a non-empty table (array or map).
function DoorShared.NotEmpty(tbl)
    return type(tbl) == 'table' and next(tbl) ~= nil
end
