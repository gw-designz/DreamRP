Commands = {}

local broughtFrom = {} -- [targetSrc] = { coords, bucket }
local frozen = {}

---Validate raw NUI args against the command's schema. Returns cleaned table or nil, reason.
local function sanitize(cmd, raw)
    raw = type(raw) == 'table' and raw or {}
    local out = {}
    for _, a in ipairs(cmd.args or {}) do
        local v = raw[a.name]
        if a.type == 'player' then
            if v == nil or v == '' then
                if not a.optional then return nil, 'missing_' .. a.name end
            else
                local id = Players.Resolve(v)
                if not id then return nil, 'player_offline' end
                out[a.name] = id
            end
        elseif a.type == 'text' then
            v = Utils.Clean(v, a.max or 200)
            if not v or v == '' then return nil, 'missing_' .. a.name end
            out[a.name] = v
        elseif a.type == 'number' then
            local n = Utils.Num(v == nil and a.default or v, a.min, a.max)
            if not n then return nil, 'bad_' .. a.name end
            out[a.name] = n
        elseif a.type == 'select' then
            v = v == nil and a.default or v
            local okOpt = false
            for _, o in ipairs(a.options) do if o == v then okOpt = true end end
            if not okOpt then return nil, 'bad_' .. a.name end
            out[a.name] = v
        elseif a.type == 'name' then
            -- identifiers only: items, jobs, gangs, resources, stash ids
            v = Utils.Str(v == nil and a.default or v, a.max or 60)
            if not v or v == '' or not v:match('^[%w_%-]+$') then return nil, 'bad_' .. a.name end
            out[a.name] = v
        elseif a.type == 'model' then
            v = Utils.Str(v, 60)
            if not v or not v:match('^[%w_]+$') then return nil, 'bad_model' end
            out[a.name] = v
        elseif a.type == 'duration' then
            -- seconds; 0 = permanent. The UI offers presets, the server just bounds it.
            local n = Utils.Num(v or 0, 0, 3153600000)
            if not n then return nil, 'bad_duration' end
            out[a.name] = math.floor(n)
        end
    end
    return out
end

local function setCoords(ped, c)
    SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
end

local function revive(target)
    TriggerClientEvent('npv_admin:client:revive', target, Config.ReviveEvent)
end

local H = {}
Commands.Handlers = H -- server/commands_import.lua adds more handlers here

local kicking = {} -- [targetSrc] = drop reason while the kidnap scene plays

function H.kick(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    if kicking[a.target] then return false, 'already_kicking' end
    Audit.Log(src, 'kick', 'ok', a.target, { reason = a.reason, style = a.style })
    local reason = 'Kicked: ' .. a.reason
    if a.style ~= 'kidnap' or GetPlayerPed(a.target) == 0 then
        DropPlayer(a.target, reason)
        return true
    end
    -- The client drops itself out of the scene early via kickSceneDone; the timeout is the fallback.
    local target = a.target
    kicking[target] = reason
    TriggerClientEvent('npv_admin:client:kickScene', target)
    SetTimeout(Config.KickSceneTimeout or 15000, function()
        if kicking[target] then
            kicking[target] = nil
            DropPlayer(target, reason)
        end
    end)
    return true, 'Kidnapping player...'
end

RegisterNetEvent('npv_admin:server:kickSceneDone', function()
    local src = source
    local reason = kicking[src]
    if not reason then return end
    kicking[src] = nil
    DropPlayer(src, reason)
end)

function H.warn(src, a)
    local cid = Players.CitizenId(a.target)
    if cid then
        MySQL.insert('INSERT INTO npv_admin_notes (citizenid, kind, staff_name, text) VALUES (?, ?, ?, ?)', { cid, 'warn', GetPlayerName(src), a.reason })
    end
    TriggerClientEvent('npv_admin:client:message', a.target, 'Warning: ' .. a.reason, 'warn')
    return true
end

function H.note(src, a)
    local cid = Players.CitizenId(a.target)
    if not cid then return false, 'no_character' end
    MySQL.insert('INSERT INTO npv_admin_notes (citizenid, kind, staff_name, text) VALUES (?, ?, ?, ?)', { cid, 'note', GetPlayerName(src), a.text })
    return true
end

function H.ban(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    local ok, res = Moderation.Ban(src, a.target, a.duration, a.reason)
    if not ok then return false, res end
    return true, ('Ban #%s created'):format(res)
end

function H.unban(src, a)
    if not Moderation.Unban(math.floor(a.banId)) then return false, 'ban_not_found' end
    return true
end

function H.bring(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    local sped, tped = GetPlayerPed(src), GetPlayerPed(a.target)
    if sped == 0 or tped == 0 then return false, 'no_ped' end
    broughtFrom[a.target] = { coords = GetEntityCoords(tped), bucket = GetPlayerRoutingBucket(a.target) }
    SetPlayerRoutingBucket(a.target, GetPlayerRoutingBucket(src))
    local c = GetEntityCoords(sped)
    setCoords(tped, c)
    return true
end

H['return'] = function(src, a)
    local back = broughtFrom[a.target]
    if not back then return false, 'nothing_to_return' end
    SetPlayerRoutingBucket(a.target, back.bucket)
    setCoords(GetPlayerPed(a.target), back.coords)
    broughtFrom[a.target] = nil
    return true
end

H['goto'] = function(src, a)
    local tped, sped = GetPlayerPed(a.target), GetPlayerPed(src)
    if tped == 0 or sped == 0 then return false, 'no_ped' end
    SetPlayerRoutingBucket(src, GetPlayerRoutingBucket(a.target))
    setCoords(sped, GetEntityCoords(tped))
    return true
end

function H.heal(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    TriggerClientEvent('npv_admin:client:heal', a.target)
    return true
end

function H.revive(src, a)
    revive(a.target)
    return true
end

function H.revive_range(src)
    local sped = GetPlayerPed(src)
    local c = GetEntityCoords(sped)
    local n = 0
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        local ped = GetPlayerPed(id)
        if ped ~= 0 and #(GetEntityCoords(ped) - c) <= Config.ReviveRange then
            revive(id)
            n = n + 1
        end
    end
    return true, ('Revived %d player(s)'):format(n)
end

function H.freeze(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    frozen[a.target] = not frozen[a.target]
    FreezeEntityPosition(GetPlayerPed(a.target), frozen[a.target])
    TriggerClientEvent('npv_admin:client:freeze', a.target, frozen[a.target])
    return true, frozen[a.target] and 'Frozen' or 'Unfrozen'
end

function H.message(src, a)
    TriggerClientEvent('npv_admin:client:message', a.target, ('%s: %s'):format(GetPlayerName(src), a.message), 'info')
    return true
end

function H.announce(src, a)
    TriggerClientEvent('npv_admin:client:announce', -1, a.message, math.floor(a.seconds))
    return true
end

function H.spectate(src, a)
    if not a.target then
        TriggerClientEvent('npv_admin:client:spectate', src, nil)
        return true, 'Stopped spectating'
    end
    if a.target == src then return false, 'cannot_spectate_self' end
    local ped = GetPlayerPed(a.target)
    TriggerClientEvent('npv_admin:client:spectate', src, a.target, NetworkGetNetworkIdFromEntity(ped), GetEntityCoords(ped))
    return true
end

function H.change_model(src, a)
    if not Perms.CanTarget(src, a.target) then return false, 'higher_rank' end
    TriggerClientEvent('npv_admin:client:exec', a.target, 'change_my_model', { model = a.model }, true)
    return true
end

function H.weather(src, a)
    Config.WeatherSync.setWeather(a.type)
    return true, ('Weather set to %s'):format(a.type)
end

function H.time(src, a)
    local hour, minute = math.floor(a.hour), math.floor(a.minute)
    Config.WeatherSync.setTime(hour, minute)
    return true, ('Time set to %02d:%02d'):format(hour, minute)
end

function H.routing_bucket(src, a)
    local target = a.target or src
    if not Perms.CanTarget(src, target) then return false, 'higher_rank' end
    SetPlayerRoutingBucket(target, math.floor(a.bucket))
    return true
end

---Entry used by the RPC layer. Returns ok, message.
function Commands.Run(src, id, raw)
    local cmd = Utils.CommandById(id)
    if not cmd then return false, 'unknown_command' end
    if not Perms.Has(src, cmd.perm) then
        Audit.Log(src, id, 'denied')
        return false, 'no_permission'
    end
    if not Perms.RateOk(src) then return false, 'rate_limited' end

    local args, why = sanitize(cmd, raw)
    if not args then return false, why end

    if cmd.exec == 'client' then
        TriggerClientEvent('npv_admin:client:exec', src, id, args)
        Audit.Log(src, id, 'ok', nil, args)
        return true
    end

    local handler = H[id]
    if not handler then return false, 'not_implemented' end
    local ok, res, msg = pcall(handler, src, args)
    if not ok then
        print(('^1[npv_admin] %s failed: %s^7'):format(id, res))
        Audit.Log(src, id, 'error', args.target, { err = tostring(res) })
        return false, 'server_error'
    end
    Audit.Log(src, id, res and 'ok' or 'failed', args.target, args)
    return res, msg
end

-- Startup self-check: every registry entry needs a handler.
CreateThread(function()
    Wait(0)
    for _, cmd in ipairs(Config.Commands) do
        if cmd.exec == 'server' and not H[cmd.id] then
            print(('^1[npv_admin] command %s has no server handler^7'):format(cmd.id))
        end
    end
end)

AddEventHandler('playerDropped', function()
    broughtFrom[source] = nil
    frozen[source] = nil
    kicking[source] = nil
end)
