RenewedBanking = RenewedBanking or {}
local RB = RenewedBanking

-- Where each ATM model's screen (and side buttons) sits, as admins line them up
-- in game with /atmscreen. Saved over the defaults in Config.atm.screens and sent
-- to every player, so nobody has to copy lines into config.lua.
local FILE = 'atm_screens.json'
local overrides = json.decode(LoadResourceFile(GetCurrentResourceName(), FILE) or '') or {}

local function save()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(overrides, { indent = true }), -1)
end

--- Staff by the framework's own groups (Config.atm.editGroups). Qbox and QBCore
--- keep their permission levels as ACEs ('god', 'admin'), the way their own
--- HasPermission checks them; ESX keeps a group on the player.
local function canEdit(source)
    local groups = Config.atm.editGroups or { 'god', 'admin' }
    if RB.Bridge.getName() == 'esx' then
        local player = RB.Bridge.getPlayerBySource(source)
        local group = player and player.getGroup and player.getGroup()
        for _, name in ipairs(groups) do
            if group == name then return true end
        end
        return false
    end
    for _, name in ipairs(groups) do
        if IsPlayerAceAllowed(source, name) then return true end
    end
    return false
end

local function number(value, min, max)
    value = tonumber(value)
    if not value or value ~= value or value < min or value > max then return nil end
    return value
end

local function span(value)
    if type(value) ~= 'table' then return nil end
    local a, b = number(value[1], -2, 3), number(value[2], -2, 3)
    if not a or not b or a >= b then return nil end
    return { a, b }
end

--- A screen as the client sent it, checked, or nil.
local function clean(screen)
    if type(screen) ~= 'table' then return nil end
    local out = {
        x = number(screen.x, -3, 3), y = number(screen.y, -3, 3), z = number(screen.z, -1, 4),
        width = number(screen.width, 0.05, 2), height = number(screen.height, 0.05, 2),
        tilt = number(screen.tilt, -89, 89)
    }
    for _, field in ipairs({ 'x', 'y', 'z', 'width', 'height', 'tilt' }) do
        if not out[field] then return nil end
    end
    if screen.keys ~= nil then
        local keys = screen.keys
        if type(keys) ~= 'table' or type(keys.rows) ~= 'table' or #keys.rows == 0 or #keys.rows > 8 then return nil end
        local rows = {}
        for i, centre in ipairs(keys.rows) do
            rows[i] = number(centre, -1, 2)
            if not rows[i] then return nil end
        end
        local height, left, right = number(keys.height, 0.01, 1), span(keys.left), span(keys.right)
        if not height or not left or not right then return nil end
        out.keys = { rows = rows, height = height, left = left, right = right }
    end
    return out
end

local function validName(name)
    return type(name) == 'string' and #name <= 64 and name:match('^[%w_]+$') ~= nil
end

lib.callback.register('Renewed-Banking:server:atmScreens', function()
    return overrides
end)

lib.callback.register('Renewed-Banking:server:canEditAtmScreens', function(source)
    return canEdit(source)
end)

lib.callback.register('Renewed-Banking:server:saveAtmScreen', function(source, name, screen)
    if not canEdit(source) then return RB.Result.fail(RB.Errors.UNAUTHORIZED) end
    local cleaned = validName(name) and clean(screen)
    if not cleaned then return RB.Result.fail(RB.Errors.INVALID_PAYLOAD) end
    overrides[name] = cleaned
    save()
    RB.Logger.info('atm_screen_saved', { source = source, model = name })
    TriggerClientEvent('Renewed-Banking:client:atmScreen', -1, name, cleaned)
    return RB.Result.ok(cleaned)
end)

lib.callback.register('Renewed-Banking:server:resetAtmScreen', function(source, name)
    if not canEdit(source) then return RB.Result.fail(RB.Errors.UNAUTHORIZED) end
    if not validName(name) then return RB.Result.fail(RB.Errors.INVALID_PAYLOAD) end
    overrides[name] = nil
    save()
    RB.Logger.info('atm_screen_reset', { source = source, model = name })
    -- false: back to the default in config.lua
    TriggerClientEvent('Renewed-Banking:client:atmScreen', -1, name, false)
    return RB.Result.ok(true)
end)
