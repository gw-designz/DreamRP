--[[
    fs-garages / bridge/esx.lua

    ESX Legacy. Registers itself into Garage.Adapters; bridge/init.lua decides
    whether it is the one used. Nothing outside bridge/ mentions ESX.
]]

Garage = Garage or {}
Garage.Adapters = Garage.Adapters or {}

local adapter = { name = 'esx', label = 'ESX Legacy' }

function adapter.detect()
    return GetResourceState(Config.FrameworkResources.esx or 'es_extended') == 'started'
end

local ESX

function adapter.getCore()
    if ESX then return ESX end
    local ok, core = pcall(function()
        return exports[Config.FrameworkResources.esx or 'es_extended']:getSharedObject()
    end)
    if ok and core then ESX = core end
    return ESX
end

if IsDuplicityVersion() then
    local S = {}
    adapter.server = S

    function S.getPlayer(src)
        local core = adapter.getCore()
        return core and core.GetPlayerFromId(src) or nil
    end

    function S.getIdentifier(src)
        local xPlayer = S.getPlayer(src)
        return xPlayer and xPlayer.identifier or nil
    end

    --- 'cash' is the money in the pocket; anything else is an account name.
    function S.getMoney(src, account)
        local xPlayer = S.getPlayer(src)
        if not xPlayer then return 0 end
        if account == 'cash' then return xPlayer.getMoney() or 0 end
        local held = xPlayer.getAccount(account)
        return held and held.money or 0
    end

    function S.removeMoney(src, account, amount)
        local xPlayer = S.getPlayer(src)
        if not xPlayer then return false end
        if S.getMoney(src, account) < amount then return false end
        if account == 'cash' then
            xPlayer.removeMoney(amount, 'fs-garages')
        else
            xPlayer.removeAccountMoney(account, amount, 'fs-garages')
        end
        return true
    end

    function S.addMoney(src, account, amount)
        local xPlayer = S.getPlayer(src)
        if not xPlayer then return false end
        if account == 'cash' then
            xPlayer.addMoney(amount, 'fs-garages')
        else
            xPlayer.addAccountMoney(account, amount, 'fs-garages')
        end
        return true
    end

    function S.isAdmin(src)
        local xPlayer = S.getPlayer(src)
        local group = xPlayer and xPlayer.getGroup and xPlayer.getGroup()
        return group ~= nil and Garage.util.contains(Config.AdminGroups, group)
    end

    function S.getName(src)
        local xPlayer = S.getPlayer(src)
        if not xPlayer then return nil end
        local first, last = xPlayer.get('firstName'), xPlayer.get('lastName')
        if first and first ~= '' then return ('%s %s'):format(first, last or '') end
        return xPlayer.getName and xPlayer.getName() or GetPlayerName(src)
    end

    function S.getJob(src)
        local xPlayer = S.getPlayer(src)
        local job = xPlayer and xPlayer.getJob()
        return job and { name = job.name, grade = tonumber(job.grade) or 0 } or nil
    end

    function S.sourceOf(identifier)
        local core = adapter.getCore()
        local xPlayer = core and core.GetPlayerFromIdentifier(identifier)
        return xPlayer and xPlayer.source or nil
    end

    -- ── the cars (owned_vehicles, kept the way esx_garage keeps them) ────
    -- stored: 0 out in the city, 1 in a garage (parking = which), 2 at the
    -- impound (pound = which). The car's look is the JSON in `vehicle`.

    -- The database helper loads after the bridge, so it is looked up when used.
    local DB = setmetatable({}, { __index = function(_, key) return Garage.DB[key] end })

    local function decode(text)
        if type(text) ~= 'string' or text == '' then return {} end
        local ok, value = pcall(json.decode, text)
        return ok and type(value) == 'table' and value or {}
    end

    local STATES = { [0] = 'out', [1] = 'garaged', [2] = 'impounded' }
    local KINDS = { car = 'car', boat = 'boat', aircraft = 'air', air = 'air', plane = 'air', heli = 'air' }

    local function record(row)
        local props = decode(row.vehicle)
        return {
            plate = Garage.util.plate(row.plate), owner = row.owner, model = props.model, props = props,
            state = STATES[tonumber(row.stored)] or 'out', garage = row.parking, lot = row.pound,
            kind = KINDS[tostring(row.type or 'car')] or 'car', job = row.job,
        }
    end

    local COLUMNS = '`plate`, `owner`, `vehicle`, `type`, `job`, `stored`, `parking`, `pound`'

    --- esx_garage adds `parking` and `pound`; a server without it gets them here.
    function S.install()
        local cols = DB.columns('owned_vehicles')
        if not cols.owner then
            Garage.util.error('owned_vehicles was not found: is this an ESX database?')
            return false
        end
        for name, definition in pairs({ parking = 'VARCHAR(60) NULL DEFAULT NULL', pound = 'VARCHAR(60) NULL DEFAULT NULL' }) do
            if not cols[name] then
                DB.update(('ALTER TABLE `owned_vehicles` ADD COLUMN `%s` %s'):format(name, definition), {}, 'esx.addColumn')
                DB.forget('owned_vehicles')
            end
        end
        return true
    end

    function S.vehicles(identifier)
        local rows = DB.query(('SELECT %s FROM `owned_vehicles` WHERE `owner` = ? LIMIT 200'):format(COLUMNS), { identifier }, 'esx.vehicles') or {}
        local out = {}
        for i, row in ipairs(rows) do out[i] = record(row) end
        return out
    end

    function S.vehicle(plate)
        local row = DB.single(('SELECT %s FROM `owned_vehicles` WHERE TRIM(`plate`) = ? LIMIT 1'):format(COLUMNS), { plate }, 'esx.vehicle')
        return row and record(row) or nil
    end

    --- In this garage now, with the look it was parked with.
    function S.park(plate, garage, props)
        return (DB.update('UPDATE `owned_vehicles` SET `stored` = 1, `parking` = ?, `pound` = NULL, `vehicle` = ? WHERE TRIM(`plate`) = ?',
            { garage, json.encode(props), plate }, 'esx.park') or 0) > 0
    end

    --- Out of the garage, only if it was still in one: two people at two
    --- kiosks cannot both take it.
    function S.claim(plate)
        return (DB.update('UPDATE `owned_vehicles` SET `stored` = 0 WHERE TRIM(`plate`) = ? AND `stored` = 1', { plate }, 'esx.claim') or 0) == 1
    end

    --- Back from the impound: out in the city again, no longer lost or held.
    function S.release(plate)
        return DB.update('UPDATE `owned_vehicles` SET `stored` = 0, `pound` = NULL WHERE TRIM(`plate`) = ?', { plate }, 'esx.release') ~= nil
    end

    function S.move(plate, garage)
        return (DB.update('UPDATE `owned_vehicles` SET `parking` = ? WHERE TRIM(`plate`) = ? AND `stored` = 1', { garage, plate }, 'esx.move') or 0) == 1
    end

    --- Model hash -> model name, for the car pictures, from the vehicle shop's list.
    function S.modelNames()
        local out = {}
        if DB.columns('vehicles').model then
            for _, row in ipairs(DB.query('SELECT `model` FROM `vehicles`', {}, 'esx.models') or {}) do
                if row.model then Garage.util.nameHash(out, row.model) end
            end
        end
        return out
    end
else
    local C = {}
    adapter.client = C

    function C.isLoggedIn()
        local core = adapter.getCore()
        return core and core.IsPlayerLoaded and core.IsPlayerLoaded() or false
    end

    function C.notify(message, kind)
        local core = adapter.getCore()
        if core and core.ShowNotification then core.ShowNotification(message) end
    end
end

Garage.Adapters.esx = adapter
