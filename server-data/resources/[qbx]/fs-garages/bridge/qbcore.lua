--[[
    fs-garages / bridge/qbcore.lua

    QBCore. Registers itself into Garage.Adapters; bridge/init.lua decides
    whether it is the one used. Nothing outside bridge/ mentions QBCore.
]]

Garage = Garage or {}
Garage.Adapters = Garage.Adapters or {}

local adapter = { name = 'qbcore', label = 'QBCore' }

function adapter.detect()
    return GetResourceState(Config.FrameworkResources.qbcore or 'qb-core') == 'started'
end

local QBCore

function adapter.getCore()
    if QBCore then return QBCore end
    local ok, core = pcall(function()
        return exports[Config.FrameworkResources.qbcore or 'qb-core']:GetCoreObject()
    end)
    if ok and core then QBCore = core end
    return QBCore
end

-- ── the cars (player_vehicles, the same for QBCore and Qbox) ───────────
-- state: 0 out in the city, 1 in a garage (garage = which), 2 at the
-- impound (depotprice = what it costs to get back). The car's look is the
-- JSON in `mods`; fuel, engine and body have their own columns.

local STATES = { [0] = 'out', [1] = 'garaged', [2] = 'impounded' }

local function decode(text)
    if type(text) ~= 'string' or text == '' then return {} end
    local ok, value = pcall(json.decode, text)
    return ok and type(value) == 'table' and value or {}
end

local Cars = {}
adapter.cars = Cars

local function columns()
    local cols = Garage.DB.columns('player_vehicles')
    local pick = { '`plate`', '`citizenid`' }
    for _, name in ipairs({ 'vehicle', 'hash', 'mods', 'garage', 'state', 'fuel', 'engine', 'body', 'depotprice' }) do
        if cols[name] then pick[#pick + 1] = ('`%s`'):format(name) end
    end
    return table.concat(pick, ', '), cols
end

local function record(row)
    local props = decode(row.mods)
    -- The look is kept without the fuel and health in some versions; the
    -- columns carry them then.
    props.fuelLevel = props.fuelLevel or tonumber(row.fuel)
    props.engineHealth = props.engineHealth or tonumber(row.engine)
    props.bodyHealth = props.bodyHealth or tonumber(row.body)
    return {
        plate = Garage.util.plate(row.plate), owner = row.citizenid, model = row.vehicle or tonumber(row.hash) or props.model,
        props = props, state = STATES[tonumber(row.state)] or 'out', garage = row.garage,
        fee = tonumber(row.depotprice), kind = nil,
    }
end

function Cars.install()
    if not Garage.DB.columns('player_vehicles').citizenid then
        Garage.util.error('player_vehicles was not found: is this a QBCore or Qbox database?')
        return false
    end
    return true
end

function Cars.vehicles(identifier)
    local pick = columns()
    local rows = Garage.DB.query(('SELECT %s FROM `player_vehicles` WHERE `citizenid` = ? LIMIT 200'):format(pick), { identifier }, 'qb.vehicles') or {}
    local out = {}
    for i, row in ipairs(rows) do out[i] = record(row) end
    return out
end

function Cars.vehicle(plate)
    local pick = columns()
    local row = Garage.DB.single(('SELECT %s FROM `player_vehicles` WHERE TRIM(`plate`) = ? LIMIT 1'):format(pick), { plate }, 'qb.vehicle')
    return row and record(row) or nil
end

function Cars.park(plate, garage, props)
    local _, cols = columns()
    local sets, params = { '`state` = 1', '`garage` = ?', '`mods` = ?' }, { garage, json.encode(props) }
    if cols.fuel then sets[#sets + 1] = '`fuel` = ?'; params[#params + 1] = math.floor(tonumber(props.fuelLevel) or 100) end
    if cols.engine then sets[#sets + 1] = '`engine` = ?'; params[#params + 1] = math.floor(tonumber(props.engineHealth) or 1000) end
    if cols.body then sets[#sets + 1] = '`body` = ?'; params[#params + 1] = math.floor(tonumber(props.bodyHealth) or 1000) end
    params[#params + 1] = plate
    return (Garage.DB.update(('UPDATE `player_vehicles` SET %s WHERE TRIM(`plate`) = ?'):format(table.concat(sets, ', ')), params, 'qb.park') or 0) > 0
end

function Cars.claim(plate)
    return (Garage.DB.update('UPDATE `player_vehicles` SET `state` = 0 WHERE TRIM(`plate`) = ? AND `state` = 1', { plate }, 'qb.claim') or 0) == 1
end

--- Back from the impound: out in the city again, with nothing left to pay.
function Cars.release(plate)
    local _, cols = columns()
    local sets = cols.depotprice and '`state` = 0, `depotprice` = 0' or '`state` = 0'
    return Garage.DB.update(('UPDATE `player_vehicles` SET %s WHERE TRIM(`plate`) = ?'):format(sets), { plate }, 'qb.release') ~= nil
end

function Cars.move(plate, garage)
    return (Garage.DB.update('UPDATE `player_vehicles` SET `garage` = ? WHERE TRIM(`plate`) = ? AND `state` = 1', { garage, plate }, 'qb.move') or 0) == 1
end

--- Model hash -> model name, for the car pictures, from a list of model names.
function Cars.modelNames(names)
    local out = {}
    for name in pairs(names or {}) do
        if type(name) == 'string' then Garage.util.nameHash(out, name) end
    end
    return out
end

if IsDuplicityVersion() then
    local S = {}
    adapter.server = S

    function S.getName(src)
        local player = S.getPlayer(src)
        local info = player and player.PlayerData.charinfo
        if info and info.firstname then return ('%s %s'):format(info.firstname, info.lastname or '') end
        return GetPlayerName(src)
    end

    function S.getJob(src)
        local player = S.getPlayer(src)
        local job = player and player.PlayerData.job
        return job and { name = job.name, grade = tonumber(type(job.grade) == 'table' and job.grade.level or job.grade) or 0 } or nil
    end

    function S.sourceOf(identifier)
        local core = adapter.getCore()
        local player = core and core.Functions.GetPlayerByCitizenId(identifier)
        return player and player.PlayerData.source or nil
    end

    S.install, S.vehicles, S.vehicle, S.park, S.claim, S.move = Cars.install, Cars.vehicles, Cars.vehicle, Cars.park, Cars.claim, Cars.move
    S.release = Cars.release

    function S.modelNames()
        local core = adapter.getCore()
        return Cars.modelNames(core and core.Shared and core.Shared.Vehicles)
    end

    function S.getPlayer(src)
        local core = adapter.getCore()
        return core and core.Functions.GetPlayer(src) or nil
    end

    function S.getIdentifier(src)
        local player = S.getPlayer(src)
        return player and player.PlayerData.citizenid or nil
    end

    --- QBCore keeps 'cash' and 'bank' side by side in PlayerData.money.
    function S.getMoney(src, account)
        local player = S.getPlayer(src)
        if not player then return 0 end
        return player.PlayerData.money[account] or 0
    end

    function S.removeMoney(src, account, amount)
        local player = S.getPlayer(src)
        if not player then return false end
        -- The framework lets some accounts go below zero (the bank, out of
        -- the box), so it is asked first rather than trusted to refuse.
        if (player.PlayerData.money[account] or 0) < amount then return false end
        return player.Functions.RemoveMoney(account, amount, 'fs-garages') and true or false
    end

    function S.addMoney(src, account, amount)
        local player = S.getPlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(account, amount, 'fs-garages') and true or false
    end

    function S.isAdmin(src)
        local core = adapter.getCore()
        if not core then return false end
        for _, group in ipairs(Config.AdminGroups or {}) do
            if core.Functions.HasPermission(src, group) then return true end
        end
        return false
    end
else
    local C = {}
    adapter.client = C

    function C.isLoggedIn()
        return LocalPlayer.state.isLoggedIn == true
    end

    function C.notify(message, kind)
        local core = adapter.getCore()
        if core and core.Functions.Notify then core.Functions.Notify(message, kind or 'primary') end
    end
end

Garage.Adapters.qbcore = adapter
