Sql = Sql or {}

Sql.ready = false

local LIB = tostring(Config.MySQL or 'oxmysql'):lower()
local IS_ASYNC = LIB == 'mysql-async'
local IS_GHMATTI = LIB == 'ghmattimysql'
local PROVIDER = IS_GHMATTI and 'ghmattimysql' or 'oxmysql'

local function await(fn)
    local p = promise.new()
    local settled = false
    fn(function(result)
        if settled then return end
        settled = true
        p:resolve(result)
    end)
    return Citizen.Await(p)
end

local function bind(query, params)
    if type(params) ~= 'table' then return query, {} end

    local out, i = {}, 0
    local bound = query:gsub('%?', function()
        i = i + 1
        local value = params[i]
        if value == nil then return 'NULL' end
        out[#out + 1] = value
        return '?'
    end)
    return bound, out
end

function Sql.Query(query, params)
    query, params = bind(query, params)
    local rows = await(function(cb)
        if IS_ASYNC then
            MySQL.Async.fetchAll(query, params or {}, cb)
        else
            exports[PROVIDER]:execute(query, params or {}, cb)
        end
    end)
    return type(rows) == 'table' and rows or {}
end

function Sql.Single(query, params)
    return Sql.Query(query, params)[1]
end

function Sql.Execute(query, params)
    query, params = bind(query, params)
    local res = await(function(cb)
        if IS_ASYNC then
            MySQL.Async.execute(query, params or {}, cb)
        else
            exports[PROVIDER]:execute(query, params or {}, cb)
        end
    end)
    if type(res) == 'table' then
        return tonumber(res.affectedRows) or 0
    end
    return tonumber(res) or 0
end

function Sql.Insert(query, params)
    query, params = bind(query, params)
    local res = await(function(cb)
        if IS_ASYNC then
            MySQL.Async.insert(query, params or {}, cb)
        elseif IS_GHMATTI then
            exports.ghmattimysql:execute(query, params or {}, cb)
        else
            exports.oxmysql:insert(query, params or {}, cb)
        end
    end)
    if type(res) == 'table' then
        return tonumber(res.insertId) or tonumber(res.id) or tonumber(res[1])
    end
    return tonumber(res)
end

function Sql.Scalar(query, params)
    query, params = bind(query, params)
    local res = await(function(cb)
        if IS_ASYNC then
            MySQL.Async.fetchScalar(query, params or {}, cb)
        else
            exports[PROVIDER]:scalar(query, params or {}, cb)
        end
    end)
    if type(res) == 'table' then
        for _, v in pairs(res) do return v end
        return nil
    end
    return res
end

function Sql.Wait()
    while not Sql.ready do Wait(50) end
end

function Sql.Encode(value)
    if value == nil then return nil end
    return (json.encode(value))
end

function Sql.Decode(raw, fallback)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return fallback end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return fallback
end

function Sql.Bool(value)
    return value == 1 or value == true or value == '1'
end

function Sql.Num(value, fallback)
    return tonumber(value) or fallback
end

function Sql.Placeholders(count)
    local out = {}
    for i = 1, count do out[i] = '?' end
    return table.concat(out, ', ')
end