--[[
    Where the desktop sits on each laptop model's screen, as staff line it up
    in game with /laptopscreen. Saved in screens.json over the defaults in
    Config.Display.Screens and sent to every player, the way Renewed-Banking
    keeps its ATM screens.
]]

local FILE = 'screens.json'
local resource = GetCurrentResourceName()
local overrides = json.decode(LoadResourceFile(resource, FILE) or '') or {}

local function save()
    SaveResourceFile(resource, FILE, json.encode(overrides, { indent = true }), -1)
end

--- Staff by the framework's permission ACEs (Config.Display.EditGroups).
local function canEdit(source)
    for _, group in ipairs(Config.Display.EditGroups or { 'god', 'admin' }) do
        if IsPlayerAceAllowed(source, group) then return true end
    end
    return false
end

local function number(value, min, max)
    value = tonumber(value)
    if not value or value ~= value or value < min or value > max then return nil end
    return value
end

local function clean(screen)
    if type(screen) ~= 'table' then return nil end
    local out = {
        x = number(screen.x, -2, 2), y = number(screen.y, -2, 2), z = number(screen.z, -1, 2),
        width = number(screen.width, 0.03, 2), height = number(screen.height, 0.03, 2), tilt = number(screen.tilt, -89, 89),
    }
    for _, field in ipairs({ 'x', 'y', 'z', 'width', 'height', 'tilt' }) do
        if not out[field] then return nil end
    end
    return out
end

local function validName(name) return type(name) == 'string' and #name <= 64 and name:match('^[%w_]+$') ~= nil end

RegisterNetEvent('nova_laptop:server:screens', function()
    TriggerClientEvent('nova_laptop:client:screens', source, overrides)
end)

RegisterNetEvent('nova_laptop:server:canEditScreen', function()
    TriggerClientEvent('nova_laptop:client:canEditScreen', source, canEdit(source))
end)

RegisterNetEvent('nova_laptop:server:saveScreen', function(name, screen)
    local src = source
    if not canEdit(src) then return TriggerClientEvent('nova_laptop:client:screenSaved', src, false, 'Only staff can change laptop screens.') end
    local cleaned = validName(name) and clean(screen)
    if not cleaned then return TriggerClientEvent('nova_laptop:client:screenSaved', src, false, 'That screen could not be read.') end
    overrides[name] = cleaned
    save()
    TriggerClientEvent('nova_laptop:client:screen', -1, name, cleaned)
    TriggerClientEvent('nova_laptop:client:screenSaved', src, true, cleaned)
end)

RegisterNetEvent('nova_laptop:server:resetScreen', function(name)
    local src = source
    if not canEdit(src) or not validName(name) then return end
    overrides[name] = nil
    save()
    -- false: back to Config.Display.Screens, or the fit from the model's size.
    TriggerClientEvent('nova_laptop:client:screen', -1, name, false)
    TriggerClientEvent('nova_laptop:client:screenSaved', src, true, false)
end)
