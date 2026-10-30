-- Server handlers for the commands in config/commands_import.lua. Arguments arrive already
-- validated by Commands.Run (types, ranges, identifier-only names); the caller's permission,
-- rate limit and audit entry are handled there too. Handlers return ok, message.

local H = Commands.Handlers

local function player(id)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(id) end)
    return ok and p or nil
end

local function tell(target, text, kind)
    TriggerClientEvent('npv_admin:client:message', target, text, kind or 'info')
end

local function oxItems()
    return Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started'
end

local function itemExists(name)
    if not oxItems() then return false end
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and item ~= nil
end

local function allIds()
    local ids = {}
    for _, id in ipairs(GetPlayers()) do ids[#ids + 1] = tonumber(id) end
    return ids
end

-- Economy --------------------------------------------------------------------------------------

function H.give_money(src, a)
    local p = player(a.target)
    if not p then return false, 'no_character' end
    p.Functions.AddMoney(a.type, math.floor(a.amount), 'npv_admin')
    tell(a.target, ('Staff gave you $%d (%s).'):format(a.amount, a.type), 'info')
    return true, ('Gave $%d %s to %s'):format(a.amount, a.type, GetPlayerName(a.target))
end

function H.remove_money(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    local p = player(a.target)
    if not p then return false, 'no_character' end
    if not p.Functions.RemoveMoney(a.type, math.floor(a.amount), 'npv_admin') then return false, 'not_enough_money' end
    tell(a.target, ('Staff removed $%d (%s).'):format(a.amount, a.type), 'warn')
    return true, ('Removed $%d %s from %s'):format(a.amount, a.type, GetPlayerName(a.target))
end

function H.give_money_all(src, a)
    local n = 0
    for _, id in ipairs(allIds()) do
        local p = player(id)
        if p then
            p.Functions.AddMoney(a.type, math.floor(a.amount), 'npv_admin')
            tell(id, ('Staff gave you $%d (%s).'):format(a.amount, a.type), 'info')
            n = n + 1
        end
    end
    return true, ('Gave $%d %s to %d player(s)'):format(a.amount, a.type, n)
end

function H.give_item(src, a)
    if not itemExists(a.item) then return false, 'unknown_item' end
    if not exports.ox_inventory:AddItem(a.target, a.item, math.floor(a.amount)) then return false, 'could_not_give' end
    return true, ('Gave %dx %s to %s'):format(a.amount, a.item, GetPlayerName(a.target))
end

function H.give_item_all(src, a)
    if not itemExists(a.item) then return false, 'unknown_item' end
    local n = 0
    for _, id in ipairs(allIds()) do
        if exports.ox_inventory:AddItem(id, a.item, math.floor(a.amount)) then n = n + 1 end
    end
    return true, ('Gave %dx %s to %d player(s)'):format(a.amount, a.item, n)
end

local function setGroup(kind, src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    local p = player(a.target)
    if not p then return false, 'no_character' end
    local name, grade = a[kind], math.floor(a.grade)
    local ok, defs = pcall(function() return kind == 'job' and exports.qbx_core:GetJobs() or exports.qbx_core:GetGangs() end)
    local def = ok and defs and defs[name]
    if not def then return false, 'unknown_' .. kind end
    if not (def.grades and (def.grades[grade] or def.grades[tostring(grade)])) then return false, 'unknown_grade' end
    local done = kind == 'job' and p.Functions.SetJob(name, grade) or p.Functions.SetGang(name, grade)
    if not done then return false, 'could_not_set' end
    tell(a.target, ('Your %s was set to %s.'):format(kind, name), 'info')
    return true, ('Set %s %s to %s (%d)'):format(GetPlayerName(a.target), kind, name, grade)
end
function H.set_job(src, a) return setGroup('job', src, a) end
function H.set_gang(src, a) return setGroup('gang', src, a) end

function H.toggle_duty(src)
    local p = player(src)
    if not p or not p.PlayerData then return false, 'no_character' end
    local on = not p.PlayerData.job.onduty
    p.Functions.SetJobDuty(on)
    return true, on and 'You are on duty' or 'You are off duty'
end

function H.open_inventory(src, a)
    if not oxItems() then return false, 'inventory_disabled' end
    TriggerClientEvent('npv_admin:client:openInventory', src, 'player', a.target)
    return true
end

function H.clear_inventory(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    if not oxItems() then return false, 'inventory_disabled' end
    exports.ox_inventory:ClearInventory(a.target)
    tell(a.target, 'Staff cleared your inventory.', 'warn')
    return true, ('Cleared the inventory of %s'):format(GetPlayerName(a.target))
end

function H.open_stash(src, a)
    if not oxItems() then return false, 'inventory_disabled' end
    local id = 'npv_admin_stash_' .. a.stash
    exports.ox_inventory:RegisterStash(id, 'Stash ' .. a.stash, Config.StashSlots, Config.StashMaxWeight)
    TriggerClientEvent('npv_admin:client:openInventory', src, 'stash', id)
    return true
end

function H.open_trunk(src, a)
    if not oxItems() then return false, 'inventory_disabled' end
    local plate = a.plate:upper()
    if not plate:match('^[%w ]+$') then return false, 'bad_plate' end
    TriggerClientEvent('npv_admin:client:openInventory', src, 'trunk', plate)
    return true
end

-- Players --------------------------------------------------------------------------------------

function H.revive_all()
    local n = 0
    for _, id in ipairs(allIds()) do
        TriggerClientEvent('npv_admin:client:revive', id, Config.ReviveEvent)
        n = n + 1
    end
    return true, ('Revived %d player(s)'):format(n)
end

function H.make_drunk(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    TriggerClientEvent('npv_admin:client:drunk', a.target, 30000)
    return true
end

function H.mute_player(src, a)
    if GetResourceState('pma-voice') ~= 'started' then return false, 'pma_voice_missing' end
    TriggerClientEvent('npv_admin:client:mute', src, a.target)
    return true
end

function H.toggle_cuffs(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    if not Config.CuffEvent or Config.CuffEvent == '' then return false, 'cuffs_not_configured' end
    TriggerClientEvent(Config.CuffEvent, a.target, src)
    return true
end

local CLOTHING = {
    { 'illenium-appearance', 'illenium-appearance:client:openClothingShop' },
    { 'qb-clothing', 'qb-clothing:client:openMenu' },
}
function H.clothing_menu(src, a)
    for _, c in ipairs(CLOTHING) do
        if GetResourceState(c[1]) == 'started' then
            TriggerClientEvent(c[2], a.target, true)
            return true, ('Opened the clothing menu for %s'):format(GetPlayerName(a.target))
        end
    end
    return false, 'no_clothing_resource'
end

function H.remove_stress(src, a)
    local target = a.target or src
    local p = player(target)
    if not p then return false, 'no_character' end
    p.Functions.SetMetaData('stress', 0)
    TriggerClientEvent('hud:client:UpdateStress', target, 0)
    return true, ('Removed stress from %s'):format(GetPlayerName(target))
end

function H.get_bucket(src, a)
    return true, ('%s is in bucket %d'):format(GetPlayerName(a.target), GetPlayerRoutingBucket(a.target))
end

function H.fix_vehicle_for(src, a)
    TriggerClientEvent('npv_admin:client:exec', a.target, 'fix_vehicle', {})
    return true
end

-- Admin Car: persist the vehicle the staff member is sitting in to their garage.
local function giveVehicleKeys(src, veh, plate)
    pcall(function()
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            exports.qbx_vehiclekeys:GiveKeys(src, veh)
            return
        end
        if GetResourceState('qb-vehiclekeys') == 'started' then
            TriggerClientEvent('qb-vehiclekeys:client:AddKeys', src, plate)
        end
    end)
end

local function saveVehicleLegacy(p, model, props)
    local plate = props.plate
    local hash = tostring(joaat(model))
    local mods = json.encode(props)
    local exists = MySQL.scalar.await('SELECT id FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    if exists then
        MySQL.update.await(
            'UPDATE player_vehicles SET license = ?, citizenid = ?, vehicle = ?, hash = ?, mods = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?',
            {
                p.PlayerData.license, p.PlayerData.citizenid, model, hash, mods,
                math.floor(props.fuelLevel or 100), props.engineHealth or 1000, props.bodyHealth or 1000, plate,
            }
        )
        return true
    end
    MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            p.PlayerData.license, p.PlayerData.citizenid, model, hash, mods, plate, 'pillboxgarage',
            math.floor(props.fuelLevel or 100), props.engineHealth or 1000, props.bodyHealth or 1000, 0,
        }
    )
    return true
end

lib.callback.register('npv_admin:adminCar', function(src, payload)
    if not Perms.Has(src, 'vehicles') then return false, 'No permission' end
    if not Perms.RateOk(src) then return false, 'Rate limited' end
    local p = player(src)
    if not p or not p.PlayerData then return false, 'No character loaded' end

    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if not veh or veh == 0 then return false, 'You have to be in a vehicle' end

    payload = type(payload) == 'table' and payload or {}
    local props = payload.props
    if type(props) ~= 'table' or type(props.plate) ~= 'string' or props.plate == '' then
        return false, 'Could not read vehicle properties'
    end

    local model
    local hash = GetEntityModel(veh)
    local okList, byHash = pcall(function() return exports.qbx_core:GetVehiclesByHash() end)
    if okList and byHash and byHash[hash] and byHash[hash].model then
        model = byHash[hash].model
    else
        model = Utils.Str(payload.model, 60)
        if model then model = model:lower() end
    end
    if not model or not model:match('^[%w_]+$') then return false, 'Unknown vehicle' end

    local citizenid = p.PlayerData.citizenid
    local existingId = Entity(veh).state.vehicleid
    local errMsg

    if GetResourceState('qbx_vehicles') == 'started' then
        if existingId then
            local okSet, err = exports.qbx_vehicles:SetPlayerVehicleOwner(existingId, citizenid)
            if not okSet then errMsg = type(err) == 'table' and err.message or tostring(err or 'Could not transfer vehicle') end
        else
            local vehicleId, err = exports.qbx_vehicles:CreatePlayerVehicle({
                model = model,
                citizenid = citizenid,
                props = props,
            })
            if not vehicleId then
                errMsg = type(err) == 'table' and err.message or tostring(err or 'Could not save vehicle')
            else
                Entity(veh).state:set('vehicleid', vehicleId, true)
            end
        end
    else
        local okLegacy, why = pcall(saveVehicleLegacy, p, model, props)
        if not okLegacy then errMsg = tostring(why) end
    end

    if errMsg then
        Audit.Log(src, 'admin_car', 'failed', nil, { model = model, plate = props.plate, err = errMsg })
        return false, errMsg
    end

    giveVehicleKeys(src, veh, props.plate)
    Audit.Log(src, 'admin_car', 'ok', nil, { model = model, plate = props.plate })
    return true, 'This vehicle is now yours.'
end)

-- Server ---------------------------------------------------------------------------------------

function H.resource_control(src, a)
    local protected = false
    for _, r in ipairs(Config.ProtectedResources) do
        if r == a.resource then protected = true end
    end
    if protected and (a.action == 'stop' or a.action == 'restart') then return false, 'protected_resource' end
    local state = GetResourceState(a.resource)
    if state == 'missing' or state == 'unknown' then return false, 'resource_not_found' end
    ExecuteCommand(('%s %s'):format(a.action, a.resource))
    return true, ('%s %s'):format(a.action, a.resource)
end

-- Player blips: staff with players.view get everyone's position, polled while the overlay is on.
RegisterNetEvent('npv_admin:server:requestBlips', function()
    local src = source
    if not Perms.Has(src, 'players.view') then return end
    local list = {}
    for _, id in ipairs(allIds()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 then
            local c = GetEntityCoords(ped)
            list[#list + 1] = { id = id, name = GetPlayerName(id), x = c.x, y = c.y, z = c.z }
        end
    end
    TriggerClientEvent('npv_admin:client:blipsData', src, list)
end)
