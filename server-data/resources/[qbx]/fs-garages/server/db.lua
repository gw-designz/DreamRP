--[[
    fs-garages / server/db.lua

    Thin wrappers over oxmysql.

    Every query goes through pcall: an oxmysql error inside a coroutine
    otherwise kills that coroutine and nothing else, and the kiosk just
    waits for ever with no console output. The error is always printed,
    with a label saying which query it was.

    Nothing builds SQL by gluing values into the text: every call takes a
    parameter list. Table and column names only ever come from this
    script's own code.
]]

Garage = Garage or {}

local DB = {}
Garage.DB = DB

local util = Garage.util

local function run(kind, query, params, context)
    local ok, result = pcall(MySQL[kind].await, query, params or {})
    if not ok then
        util.error(('%s failed [%s]: %s'):format(kind, context or '?', tostring(result)))
        return nil
    end
    return result
end

function DB.query(query, params, context) return run('query', query, params, context) end
function DB.single(query, params, context) return run('single', query, params, context) end
function DB.scalar(query, params, context) return run('scalar', query, params, context) end
function DB.update(query, params, context) return run('update', query, params, context) end
function DB.insert(query, params, context) return run('insert', query, params, context) end

local columnCache = {}

--- The columns a table has, as a set ({ name = true }); empty when the
--- table is not there.
function DB.columns(name)
    if columnCache[name] then return columnCache[name] end
    local rows = DB.query([[
        SELECT `column_name` AS `name` FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = ?
    ]], { name }, 'db.columns')
    local set = {}
    for _, row in ipairs(rows or {}) do set[row.name] = true end
    columnCache[name] = set
    return set
end

--- Forget what is known about a table's columns (after adding one).
function DB.forget(name)
    columnCache[name] = nil
end
