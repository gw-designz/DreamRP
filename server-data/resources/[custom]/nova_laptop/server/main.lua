local sessions, openTimes, actionTimes = {}, {}, {}
local allowedActions = { settings = true }
for name in pairs(News.Actions) do allowedActions[name] = true end

local function reply(src, id, data)
    TriggerClientEvent('nova_laptop:client:response', src, id, data)
end

local function openLaptop(src, via)
    local now = GetGameTimer()
    if openTimes[src] and now - openTimes[src] < Config.OpenCooldownMs then
        TriggerClientEvent('nova_laptop:client:denied', src, 'Please wait a moment before opening again.')
        return
    end
    openTimes[src] = now
    local context = Bridge.Context(src)
    local reason
    if not context then reason = 'Your character is not ready yet.'
    elseif Config.BlockWhenDead and context.dead then reason = 'You cannot use the laptop right now.'
    elseif via ~= 'item' and via ~= 'placed' and (via ~= 'command' or not Config.Command.Enabled) then reason = 'The laptop command is disabled.'
    elseif (via == 'item' or Config.Command.RequireItem) and not Bridge.HasItem(src, context) then
        reason = 'You need a laptop in your inventory.'
    end
    if reason then TriggerClientEvent('nova_laptop:client:denied', src, reason) return end
    -- On the prop, the laptop has to be set down first, and used where it stands.
    local laptop
    if Config.Display.Mode == 'world' then
        laptop = Placement.Near(src)
        if not laptop then return Placement.Grant(src, via) end
    end
    local data = Storage.Read(context.key)
    sessions[src] = { key = context.key, itemRequired = via == 'item' or Config.Command.RequireItem }
    TriggerClientEvent('nova_laptop:client:open', src, {
        player = { name = context.name or 'Resident', serverId = src },
        serverName = Config.ServerName, deviceName = Config.DeviceName,
        settings = data.settings, framework = context.framework
    }, laptop)
end

local function safeOpen(src, via)
    local ok, err = pcall(openLaptop, src, via)
    if not ok then
        print(('[nova_laptop] Open failed: %s'):format(err))
        TriggerClientEvent('nova_laptop:client:denied', src, 'The laptop could not open. Check the server console.')
    end
end

RegisterNetEvent('nova_laptop:server:open', function(via)
    safeOpen(source, via)
end)

RegisterNetEvent('nova_laptop:server:close', function()
    sessions[source] = nil
end)

local function perform(src, action, input)
    local session = sessions[src]
    local context = Bridge.Context(src)
    if not session or not context or session.key ~= context.key then
        sessions[src] = nil
        return { ok = false, error = 'Laptop session expired. Open the laptop again.' }
    end
    if (Config.BlockWhenDead and context.dead) or (session.itemRequired and not Bridge.HasItem(src, context)) then
        sessions[src] = nil
        TriggerClientEvent('nova_laptop:client:forceClose', src)
        return { ok = false, error = 'Laptop access is no longer available.' }
    end
    if News.Actions[action] then
        return News.Handle(src, context, action, input)
    elseif action == 'settings' then
        local settings, err = Storage.SaveSettings(context.key, input)
        return { ok = settings ~= nil, settings = settings, error = err }
    end
    return { ok = false, error = 'Unknown action.' }
end

RegisterNetEvent('nova_laptop:server:request', function(id, action, input)
    local src = source
    if type(id) ~= 'number' or id % 1 ~= 0 or id < 1 or id > 2147483647 then return end
    if type(action) ~= 'string' or not allowedActions[action] or type(input) ~= 'table' then
        reply(src, id, { ok = false, error = 'Invalid laptop request.' }) return
    end
    local now = GetGameTimer()
    -- Each action has its own limiter, so an app loading its list never blocks a save.
    actionTimes[src] = actionTimes[src] or {}
    local last = actionTimes[src][action]
    if last and now - last < 120 then
        reply(src, id, { ok = false, error = 'Please wait a moment and try again.' }) return
    end
    actionTimes[src][action] = now
    local ok, result = pcall(perform, src, action, input)
    if not ok then
        print(('[nova_laptop] Request failed: %s'):format(result))
        result = { ok = false, error = 'The server could not complete this action. Your changes have not been confirmed.' }
    end
    reply(src, id, result)
end)


AddEventHandler('playerDropped', function()
    sessions[source], openTimes[source], actionTimes[source] = nil, nil, nil
end)

CreateThread(function()
    Bridge.RegisterItem(function(src) safeOpen(src, 'item') end)
    print(('[nova_laptop] Ready. Framework: %s. Command: /%s'):format(Bridge.Framework(), Config.Command.Name))
end)

exports('OpenLaptop', function(src)
    safeOpen(src, 'command') -- observes command enable/require-item settings
end)
