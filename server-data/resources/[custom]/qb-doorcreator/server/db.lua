--[[
    server/db.lua

    Thin persistence layer around oxmysql. Nothing in here knows about
    access-rule evaluation (see server/access.lua) or native door calls
    (those only exist client-side) — this file's only job is turning
    `doorlocks` rows into plain Lua tables and back.

    Auto-migration: DoorDB.Init() runs a CREATE TABLE IF NOT EXISTS on
    resource start (see server/main.lua), so a fresh database gets the
    schema with zero manual steps. sql/install.sql contains the exact
    same statement for reference/manual import.
]]

DoorDB = {}

local TABLE_SQL = [[
CREATE TABLE IF NOT EXISTS `doorlocks` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `label`       VARCHAR(100) NOT NULL DEFAULT 'Unnamed Door',
    `door_hash`   VARCHAR(64)  NOT NULL,
    `model`       BIGINT NOT NULL,
    `coords`      JSON NOT NULL,
    `locked`      TINYINT(1) NOT NULL DEFAULT 1,
    `group_id`    VARCHAR(64) NULL DEFAULT NULL,
    `access`      JSON NOT NULL,
    `dependencies` JSON NOT NULL DEFAULT ('[]'),
    `auto_close`  INT UNSIGNED NULL DEFAULT NULL,
    `fallback`    TINYINT(1) NOT NULL DEFAULT 0,
    `created_by`  VARCHAR(64) NOT NULL,
    `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_door_hash` (`door_hash`),
    KEY `idx_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]]

--- Runs the migration synchronously (blocks resource start briefly,
--- which is fine — it only happens once at boot). Safe to call every
--- start; IF NOT EXISTS makes it a no-op after the first run.
function DoorDB.Init()
    local ok, err = pcall(function()
        MySQL.query.await(TABLE_SQL, {})
    end)
    if not ok then
        print(('^1[qb-doorcreator] Failed to run doorlocks migration: %s^0'):format(tostring(err)))
        return false
    end
    return true
end

--- Converts a raw MySQL row into a normalized door table:
---   JSON columns decoded, locked/fallback coerced to real booleans.
local function rowToDoor(row)
    if not row then return nil end
    return {
        id = row.id,
        label = row.label,
        door_hash = row.door_hash,
        model = tonumber(row.model),
        coords = DoorShared.SafeDecode(row.coords, { x = 0.0, y = 0.0, z = 0.0, heading = 0.0 }),
        locked = row.locked == 1 or row.locked == true,
        group_id = row.group_id,
        access = DoorShared.SafeDecode(row.access, {}),
        dependencies = DoorShared.SafeDecode(row.dependencies, {}),
        auto_close = row.auto_close and tonumber(row.auto_close) or 0,
        fallback = row.fallback == 1 or row.fallback == true,
        created_by = row.created_by,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

--- Returns every door row, decoded, as an array.
function DoorDB.GetAll()
    local rows = MySQL.query.await('SELECT * FROM doorlocks ORDER BY id ASC', {}) or {}
    local out = {}
    for i = 1, #rows do
        out[i] = rowToDoor(rows[i])
    end
    return out
end

--- Returns a single decoded door row by id, or nil.
function DoorDB.GetById(id)
    local rows = MySQL.query.await('SELECT * FROM doorlocks WHERE id = ? LIMIT 1', { id })
    if not rows or not rows[1] then return nil end
    return rowToDoor(rows[1])
end

--[[
    Inserts a new door. `data` fields expected:
        label, model, coords{x,y,z,heading}, group_id, access,
        dependencies, auto_close, fallback, created_by

    door_hash can't be known until we have the auto-increment id, so
    this does: INSERT placeholder -> compute stable hash from the new
    id -> UPDATE the row. Both queries are awaited so the function
    returns the FULLY populated door row, ready to hand to the native
    door system / broadcast to clients.
]]
function DoorDB.Insert(data)
    local insertId = MySQL.insert.await([[
        INSERT INTO doorlocks
            (label, door_hash, model, coords, locked, group_id, access, dependencies, auto_close, fallback, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.label or 'Unnamed Door',
        'pending', -- placeholder, replaced below once we know the id
        data.model,
        json.encode(data.coords),
        data.locked ~= false and 1 or 0,
        data.group_id ~= '' and data.group_id or nil,
        json.encode(data.access or {}),
        json.encode(data.dependencies or {}),
        (data.auto_close and data.auto_close > 0) and data.auto_close or nil,
        data.fallback and 1 or 0,
        data.created_by,
    })

    if not insertId then return nil end

    -- Stable per-row string key so the native door system id is
    -- deterministic across restarts (same DB row -> same hash, every
    -- boot) without us having to persist the raw numeric hash key.
    local doorHash = tostring(GetHashKey('qbdc_door_' .. insertId))
    MySQL.update.await('UPDATE doorlocks SET door_hash = ? WHERE id = ?', { doorHash, insertId })

    return DoorDB.GetById(insertId)
end

--- Updates an existing door's editable fields. Does NOT touch
--- door_hash, created_by, or created_at. Returns the refreshed row.
function DoorDB.Update(id, data)
    MySQL.update.await([[
        UPDATE doorlocks SET
            label = ?,
            model = ?,
            coords = ?,
            group_id = ?,
            access = ?,
            dependencies = ?,
            auto_close = ?,
            fallback = ?
        WHERE id = ?
    ]], {
        data.label or 'Unnamed Door',
        data.model,
        json.encode(data.coords),
        data.group_id ~= '' and data.group_id or nil,
        json.encode(data.access or {}),
        json.encode(data.dependencies or {}),
        (data.auto_close and data.auto_close > 0) and data.auto_close or nil,
        data.fallback and 1 or 0,
        id,
    })
    return DoorDB.GetById(id)
end

--- Persists a locked/unlocked flip. Kept as its own cheap query since
--- this is the hottest write path (every player interaction).
function DoorDB.SetLocked(id, locked)
    MySQL.update.await('UPDATE doorlocks SET locked = ? WHERE id = ?', { locked and 1 or 0, id })
end

function DoorDB.Delete(id)
    MySQL.update.await('DELETE FROM doorlocks WHERE id = ?', { id })
end
