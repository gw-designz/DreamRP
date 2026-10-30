Scripts = {}
Dialogue = {}

-- ---------------------------------------------------------------------------
-- Allowed block / trigger schema. The UI palette only offers what is here.
-- ---------------------------------------------------------------------------

local WHEN = { spawn = true, enter = true, leave = true, use = true, signal = true, unlocked = true }
local OPS = { ['='] = true, ['!='] = true, ['>'] = true, ['<'] = true, ['>='] = true, ['<='] = true }
local TARGETS = { player = true, near = true, everyone = true }

local function name(v, max) -- identifier-like string
    v = Utils.Clean(v, max or 40)
    return v and v:match('^[%w_%-%. ]+$') and v or nil
end

local function itemName(v)
    v = Utils.Str(v, 50)
    return v and v:match('^[%w_%-]+$') and v or nil
end

-- Leaf actions shared by script blocks and dialogue reply triggers.
local leaf = {}

function leaf.signal(b)
    local n = name(b.name); if not n then return nil end
    return { t = 'signal', name = n }
end
function leaf.notify(b)
    local text = Utils.Clean(b.text, Config.Limits.MaxNotifyChars)
    if not text or text == '' then return nil end
    return { t = 'notify', to = TARGETS[b.to] and b.to or 'player', text = text }
end
function leaf.police_alert(b)
    return { t = 'police_alert', text = Utils.Clean(b.text, 100) or 'Suspicious activity' }
end
function leaf.give_item(b)
    local item, count = itemName(b.item), Utils.Num(b.count or 1, 1, 1000)
    if not item or not count then return nil end
    return { t = 'give_item', item = item, count = math.floor(count) }
end
function leaf.take_item(b)
    local item, count = itemName(b.item), Utils.Num(b.count or 1, 1, 1000)
    if not item or not count then return nil end
    return { t = 'take_item', item = item, count = math.floor(count) }
end
function leaf.teleport(b)
    local c = Utils.ValidCoords(b)
    if not c then return nil end
    return { t = 'teleport', x = c.x, y = c.y, z = c.z, h = c.h }
end

local function soundName(v, max)
    v = Utils.Str(v, max or 60)
    return v and v:match('^[%w_]+$') and v or nil
end

function leaf.play_sound(b)
    local n = soundName(b.name)
    if not n then return nil end
    local set = Utils.Str(b.set, 60)
    return { t = 'play_sound', name = n, set = set and set:match('^[%w_]*$') and set or '', to = TARGETS[b.to] and b.to or 'near' }
end
function leaf.stop_sounds() return { t = 'stop_sounds' } end
function leaf.lock_door(b)
    local id = Utils.Num(b.doorId, 1, 100000)
    if not id then return nil end
    return { t = 'lock_door', doorId = math.floor(id), locked = b.locked ~= false }
end
function leaf.unlock_for(b)
    if not Utils.ValidId(b.objectId) then return nil end
    return { t = 'unlock_for', objectId = b.objectId, seconds = math.floor(Utils.Num(b.seconds or 0, 0, 86400) or 0) }
end
function leaf.door_state(b)
    if not Utils.ValidId(b.objectId) then return nil end
    return { t = 'door_state', objectId = b.objectId, open = b.open ~= false }
end
function leaf.reset_object(b)
    if not Utils.ValidId(b.objectId) then return nil end
    return { t = 'reset_object', objectId = b.objectId }
end
function leaf.alert_npc(b)
    if not Utils.ValidId(b.objectId) then return nil end
    return { t = 'alert_npc', objectId = b.objectId }
end
function leaf.set_npc_route(b)
    if not Utils.ValidId(b.objectId) then return nil end
    return { t = 'set_npc_route', objectId = b.objectId, on = b.on ~= false }
end
function leaf.spawn_vehicle(b)
    local model = soundName(b.model, 40)
    if not model or not Utils.ValidId(b.objectId) then return nil end
    return { t = 'spawn_vehicle', model = model, objectId = b.objectId, tag = name(b.tag, 30) or '' }
end
function leaf.remove_vehicle(b)
    return { t = 'remove_vehicle', tag = name(b.tag, 30) or '' }
end

-- Script-driven DM actions: only the ones that do not depend on a staff member being present.
local DM_ACTIONS = {
    narrate = true, flash = true, black_screen = true, blur = true, shake = true, knock_down = true, freeze = true,
    heal = true, revive = true, lightning = true, blackout = true, police_alert = true, explosion = true, fire = true, give_item = true,
}
function leaf.dm_action(b)
    if not DM_ACTIONS[b.action] then return nil end
    local out = { t = 'dm_action', action = b.action, to = TARGETS[b.to] and b.to or 'near' }
    out.text = Utils.Clean(b.text, 200)
    out.seconds = Utils.Num(b.seconds, 1, 300)
    out.count = Utils.Num(b.count, 1, 1000)
    out.minutes = Utils.Num(b.minutes, 0, 30)
    out.item = itemName(b.item)
    return out
end

function Scripts.SanitizeTrigger(t)
    if type(t) ~= 'table' then return nil end
    -- Dialogue replies keep the original small trigger set.
    if not ({ signal = true, give_item = true, take_item = true, teleport = true, police_alert = true })[t.t] then return nil end
    return leaf[t.t](t)
end

local function sanitizeBlocks(list, depth, counter)
    if type(list) ~= 'table' then return {} end
    if depth > Config.Limits.ScriptDepth then return nil, 'script_too_deep' end
    local out = {}
    for _, b in ipairs(list) do
        counter.n = counter.n + 1
        if counter.n > Config.Limits.ScriptBlocksPerScript then return nil, 'too_many_blocks' end
        if type(b) ~= 'table' then return nil, 'bad_block' end
        local clean
        local t = b.t
        if leaf[t] then
            clean = leaf[t](b)
        elseif t == 'wait' then
            local ms = Utils.Num(b.ms, 0, Config.Limits.MaxWaitMs)
            clean = ms and { t = 'wait', ms = math.floor(ms) }
        elseif t == 'stop' then
            clean = { t = 'stop' }
        elseif t == 'limit' then
            local max = Utils.Num(b.max, 1, 100000)
            clean = max and { t = 'limit', max = math.floor(max) }
        elseif t == 'set_var' or t == 'change_var' then
            local n = name(b.name)
            local value = Utils.Num(b.value, -1e9, 1e9)
            if n and value then clean = { t = t, name = n, value = value, scope = b.scope == 'player' and 'player' or 'shared' } end
        elseif t == 'lock' then
            if Utils.ValidId(b.objectId) then clean = { t = 'lock', objectId = b.objectId, locked = b.locked ~= false } end
        elseif t == 'spawn_scenario' or t == 'despawn_scenario' or t == 'reset_scenario' then
            if Utils.ValidId(b.id) then clean = { t = t, id = b.id } end
        elseif t == 'repeat' then
            local n = Utils.Num(b.n, 1, 100)
            local inner, why = sanitizeBlocks(b.blocks, depth + 1, counter)
            if not inner then return nil, why end
            clean = n and { t = 'repeat', n = math.floor(n), blocks = inner }
        elseif t == 'hack' then
            local diff = Utils.Num(b.difficulty or 3, 1, 5)
            local ok1, why1 = sanitizeBlocks(b.blocks, depth + 1, counter)
            if not ok1 then return nil, why1 end
            local ok2, why2 = sanitizeBlocks(b.failBlocks, depth + 1, counter)
            if not ok2 then return nil, why2 end
            local game = 'skill'
            for _, g in ipairs(Config.HackGames) do
                if g.id == b.game then game = g.id end
            end
            if diff then clean = { t = 'hack', name = name(b.name, 40) or 'Hack', game = game, difficulty = math.floor(diff), blocks = ok1, failBlocks = ok2 } end
        elseif t == 'if' then
            local n = name(b.name)
            local value = Utils.Num(b.value, -1e9, 1e9)
            local yes, why = sanitizeBlocks(b.blocks, depth + 1, counter)
            if not yes then return nil, why end
            local no, why2 = sanitizeBlocks(b.elseBlocks, depth + 1, counter)
            if not no then return nil, why2 end
            if n and value and OPS[b.op] then
                clean = { t = 'if', name = n, op = b.op, value = value, scope = b.scope == 'player' and 'player' or 'shared', blocks = yes, elseBlocks = no }
            end
        end
        if not clean then return nil, 'bad_block_' .. tostring(t) end
        out[#out + 1] = clean
    end
    return out
end

function Scripts.SanitizeScript(s)
    if type(s) ~= 'table' or not Utils.ValidId(s.id) then return nil, 'bad_script' end
    local when = type(s.when) == 'table' and s.when or {}
    if not WHEN[when.type] then return nil, 'bad_when' end
    local counter = { n = 0 }
    local blocks, why = sanitizeBlocks(s.blocks, 1, counter)
    if not blocks then return nil, why end
    return {
        id = s.id, name = Utils.Clean(s.name, 40) or 'Script',
        enabled = s.enabled ~= false,
        when = {
            type = when.type,
            objectId = Utils.ValidId(when.objectId) and when.objectId or nil,
            signal = when.type == 'signal' and name(when.signal) or nil,
        },
        blocks = blocks,
    }
end

-- ---------------------------------------------------------------------------
-- Runtime
-- ---------------------------------------------------------------------------

local running = {} -- [sid] = count of active script threads
local MAX_THREADS = 40

local function playerName(src)
    return GetPlayerName(src) or 'someone'
end

local function fill(text, s, ctx)
    return (text:gsub('{{([%w_%.]+)}}', function(key)
        local pn = key:match('^player%.(.+)$')
        if pn then
            if pn == 'name' then return playerName(ctx.src) end
            return tostring((s.playerVars[ctx.src] or {})[pn] or 0)
        end
        return tostring(s.vars[key] or 0)
    end))
end

local function compare(a, op, b)
    if op == '=' then return a == b elseif op == '!=' then return a ~= b
    elseif op == '>' then return a > b elseif op == '<' then return a < b
    elseif op == '>=' then return a >= b else return a <= b end
end

local function recipients(to, ctx)
    if to == 'everyone' then return GetPlayers() end
    if to == 'player' or not ctx.coords then return ctx.src and { ctx.src } or {} end
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(tonumber(id))
        if ped ~= 0 and #(GetEntityCoords(ped) - vec3(ctx.coords.x, ctx.coords.y, ctx.coords.z)) <= Config.DefaultActionRange then
            list[#list + 1] = id
        end
    end
    return list
end

local function varTable(s, scope, src)
    if scope == 'player' then
        s.playerVars[src] = s.playerVars[src] or {}
        return s.playerVars[src]
    end
    return s.vars
end

local exec

local act = {}
function act.notify(sid, s, b, ctx)
    local text = fill(b.text, s, ctx)
    for _, id in ipairs(recipients(b.to, ctx)) do
        TriggerClientEvent('npv_admin:client:message', tonumber(id), text, 'info')
    end
end
function act.police_alert(sid, s, b, ctx)
    local coords = ctx.coords or (ctx.src and GetEntityCoords(GetPlayerPed(ctx.src))) or vec3(0, 0, 0)
    Config.PoliceAlert(coords, fill(b.text, s, ctx))
end
function act.signal(sid, s, b, ctx)
    Scripts.Dispatch(sid, 'signal', nil, ctx, b.name)
end
function act.give_item(sid, s, b, ctx)
    if ctx.src and Config.Inventory == 'ox_inventory' then exports.ox_inventory:AddItem(ctx.src, b.item, b.count) end
end
function act.take_item(sid, s, b, ctx)
    if ctx.src and Config.Inventory == 'ox_inventory' then exports.ox_inventory:RemoveItem(ctx.src, b.item, b.count) end
end
function act.teleport(sid, s, b, ctx)
    if not ctx.src then return end
    local ped = GetPlayerPed(ctx.src)
    if ped ~= 0 then SetEntityCoords(ped, b.x, b.y, b.z, false, false, false, false) SetEntityHeading(ped, b.h or 0.0) end
end
function act.lock(sid, s, b) s.locks[b.objectId] = b.locked end

function act.unlock_for(sid, s, b, ctx)
    if not ctx.src then return end
    s.unlocked[b.objectId] = s.unlocked[b.objectId] or {}
    s.unlocked[b.objectId][ctx.src] = b.seconds > 0 and (GetGameTimer() + b.seconds * 1000) or math.huge
end

function act.door_state(sid, s, b, ctx)
    if Doors then Doors.Set(sid, b.objectId, b.open, ctx.src) end
end

function act.reset_object(sid, s, b)
    s.locks[b.objectId] = nil
    s.unlocked[b.objectId] = nil
    s.cooldowns = {}
end

function act.lock_door(sid, s, b)
    if GetResourceState('ox_doorlock') ~= 'started' then return end
    exports.ox_doorlock:setDoorState(b.doorId, b.locked and 1 or 0)
end

function act.play_sound(sid, s, b, ctx)
    for _, id in ipairs(recipients(b.to, ctx)) do
        TriggerClientEvent('npv_admin:client:scriptSound', tonumber(id), b.name, b.set, ctx.coords)
    end
end

function act.stop_sounds()
    TriggerClientEvent('npv_admin:client:stopSounds', -1)
end

function act.alert_npc(sid, s, b)
    local ent = s.entities[b.objectId]
    if ent and DoesEntityExist(ent) then Entity(ent).state:set('npv_alert', GetGameTimer(), true) end
end

function act.set_npc_route(sid, s, b)
    local ent = s.entities[b.objectId]
    if ent and DoesEntityExist(ent) then Entity(ent).state:set('npv_patrol', b.on, true) end
end

local MAX_SCRIPT_VEHICLES = 10
function act.spawn_vehicle(sid, s, b)
    for i = #s.vehicles, 1, -1 do
        if not DoesEntityExist(s.vehicles[i].ent) then table.remove(s.vehicles, i) end
    end
    if #s.vehicles >= MAX_SCRIPT_VEHICLES then return end
    local at
    for _, o in ipairs(s.def.objects) do
        if o.id == b.objectId then at = o.coords end
    end
    if not at then return end
    local veh = CreateVehicleServerSetter(joaat(b.model), 'automobile', at.x, at.y, at.z, at.h or 0.0)
    if veh and veh ~= 0 then s.vehicles[#s.vehicles + 1] = { ent = veh, tag = b.tag } end
end

function act.remove_vehicle(sid, s, b)
    for i = #s.vehicles, 1, -1 do
        local v = s.vehicles[i]
        if b.tag == '' or v.tag == b.tag then
            if DoesEntityExist(v.ent) then DeleteEntity(v.ent) end
            table.remove(s.vehicles, i)
        end
    end
end

function act.dm_action(sid, s, b, ctx)
    local handler = DmActions and DmActions.Handlers and DmActions.Handlers[b.action]
    if not handler then return end
    local coords = ctx.coords
    if not coords and ctx.src then
        local c = GetEntityCoords(GetPlayerPed(ctx.src))
        coords = { x = c.x, y = c.y, z = c.z, h = 0.0 }
    end
    if not coords then return end
    coords = { x = coords.x, y = coords.y, z = coords.z, h = coords.h or 0.0 }
    local list = {}
    for _, id in ipairs(recipients(b.to, ctx)) do list[#list + 1] = tonumber(id) end
    local params = { text = b.text and fill(b.text, s, ctx), seconds = b.seconds, count = b.count, minutes = b.minutes, item = b.item }
    handler(ctx.src or 0, coords, list, params)
end
function act.set_var(sid, s, b, ctx) varTable(s, b.scope, ctx.src)[b.name] = b.value end
function act.change_var(sid, s, b, ctx)
    local t = varTable(s, b.scope, ctx.src)
    t[b.name] = (t[b.name] or 0) + b.value
end

local function ownsTarget(s, id)
    local row = MySQL.single.await('SELECT owner_license FROM npv_dm_scenarios WHERE id = ?', { id })
    return row and row.owner_license == s.owner
end
function act.spawn_scenario(sid, s, b) if ownsTarget(s, b.id) then Scenarios.Spawn(b.id) end end
function act.despawn_scenario(sid, s, b) if ownsTarget(s, b.id) then Scenarios.Despawn(b.id) end end
function act.reset_scenario(sid, s, b) if ownsTarget(s, b.id) and Scenarios.Live[b.id] then Scenarios.Reset(b.id) end end

---Executes a block list. Returns true to signal "stop this script".
function exec(sid, s, script, blocks, ctx)
    for i, b in ipairs(blocks) do
        if Scenarios.Live[sid] ~= s then return true end -- scenario was despawned/reset mid-run
        local t = b.t
        if t == 'wait' then
            Wait(b.ms)
        elseif t == 'stop' then
            return true
        elseif t == 'limit' then
            local key = script.id .. ':' .. i
            s.usage[key] = (s.usage[key] or 0) + 1
            if s.usage[key] > b.max then return true end
        elseif t == 'repeat' then
            for _ = 1, b.n do
                if exec(sid, s, script, b.blocks, ctx) then return true end
            end
        elseif t == 'hack' then
            -- The player's own client runs the minigame; no player (signal/spawn) means it fails.
            local passed = false
            if ctx.src then passed = Scripts.RunHack(ctx.src, b) end
            if exec(sid, s, script, passed and b.blocks or b.failBlocks, ctx) then return true end
        elseif t == 'if' then
            local current = varTable(s, b.scope, ctx.src)[b.name] or 0
            if exec(sid, s, script, compare(current, b.op, b.value) and b.blocks or b.elseBlocks, ctx) then return true end
        elseif act[t] then
            local ok, err = pcall(act[t], sid, s, b, ctx)
            if not ok then print(('^1[npv_admin] scenario %s block %s failed: %s^7'):format(sid, t, err)) end
        end
    end
    return false
end

-- Hack minigames. 'skill' is an ox_lib skill check on the player's client; any other id is a
-- cortex-minigames game run as a server-issued attempt (the server gets the result, not the client).
local PRESET_FOR = { 'easy', 'normal', 'normal', 'hard', 'expert' }

function Scripts.RunHack(src, b)
    local game = b.game or 'skill'
    if game ~= 'skill' and GetResourceState(Config.HackProvider) == 'started' then
        local p = promise.new()
        local attemptId = exports[Config.HackProvider]:StartAttempt(src, {
            game = game, preset = PRESET_FOR[b.difficulty] or 'normal', title = b.name,
        }, function(result)
            if p.state == 0 then p:resolve(result ~= nil and result.status == 'success') end
        end)
        if not attemptId then return false end
        SetTimeout(Config.HackTimeoutMs, function() if p.state == 0 then p:resolve(false) end end)
        return Citizen.Await(p) == true
    end
    -- Built-in skill check (also the fallback when the minigame resource is not running).
    local ok, res = pcall(lib.callback.await, 'npv_admin:client:hack', src, false, b.difficulty, b.name)
    return ok and res == true
end

---Run every script in scenario `sid` whose "when" matches.
function Scripts.Dispatch(sid, eventType, objectId, ctx, signalName)
    local s = Scenarios.Live[sid]
    if not s then return end
    for _, script in ipairs(s.def.scripts) do
        local w = script.when
        if script.enabled ~= false and w.type == eventType and (not w.objectId or w.objectId == objectId) and (eventType ~= 'signal' or w.signal == signalName) then
            s.runs[script.id] = (s.runs[script.id] or 0) + 1
            s.lastRun[script.id] = os.time()
            if (running[sid] or 0) >= MAX_THREADS then
                print(('^3[npv_admin] scenario %s hit the script thread limit^7'):format(sid))
                return
            end
            running[sid] = (running[sid] or 0) + 1
            CreateThread(function()
                local ok, err = pcall(exec, sid, s, script, script.blocks, ctx)
                if not ok then print(('^1[npv_admin] script %s error: %s^7'):format(script.id, err)) end
                running[sid] = math.max(0, (running[sid] or 1) - 1)
            end)
        end
    end
end

---Run one script right now (the editor's play button). ctx.src is the staff member.
function Scripts.RunOne(sid, scriptId, ctx)
    local s = Scenarios.Live[sid]
    if not s then return false, 'not_live' end
    for _, script in ipairs(s.def.scripts) do
        if script.id == scriptId then
            s.runs[script.id] = (s.runs[script.id] or 0) + 1
            s.lastRun[script.id] = os.time()
            CreateThread(function()
                local ok, err = pcall(exec, sid, s, script, script.blocks, ctx)
                if not ok then print(('^1[npv_admin] script %s error: %s^7'):format(script.id, err)) end
            end)
            return true
        end
    end
    return false, 'not_found'
end

function Scripts.FireSpawn(sid)
    Scripts.Dispatch(sid, 'spawn', nil, {})
end

-- Client reports entering/leaving a box or using an object. The server verifies everything.
local function objectOf(s, oid)
    for _, o in ipairs(s.def.objects) do
        if o.id == oid then return o end
    end
end

local function near(src, o, extra)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local c = GetEntityCoords(ped)
    return Utils.Dist({ x = c.x, y = c.y, z = c.z }, o.coords) <= extra + Config.TriggerTolerance
end

local lastInteract = {}
RegisterNetEvent('npv_admin:server:interact', function(sid, oid, event)
    local src = source
    if type(sid) ~= 'string' or type(oid) ~= 'string' or type(event) ~= 'string' then return end
    local now = GetGameTimer()
    if (lastInteract[src] or 0) + 150 > now then return end
    lastInteract[src] = now
    local s = Scenarios.Live[sid]
    local o = s and objectOf(s, oid)
    if not o then return end

    local reach
    if o.kind == 'trigger' and (event == 'enter' or event == 'leave') then
        reach = math.max(o.size.x, o.size.y, o.size.z)
    elseif (o.kind == 'interactive' or o.kind == 'storage') and event == 'use' then
        reach = Config.TalkDistance + 1.0
    else
        return
    end
    if not near(src, o, reach) then return end

    if event == 'use' then
        local pass = s.unlocked[oid] and s.unlocked[oid][src]
        if pass and pass ~= math.huge and pass < GetGameTimer() then s.unlocked[oid][src] = nil pass = nil end
        if s.locks[oid] and not pass then
            return TriggerClientEvent('npv_admin:client:message', src, 'It is locked.', 'warn')
        end
        local key = ('%s:%s'):format(oid, src)
        local now = GetGameTimer()
        if (o.cooldown or 0) > 0 and s.cooldowns[key] and now - s.cooldowns[key] < o.cooldown * 1000 then return end
        s.cooldowns[key] = now
        if o.kind == 'storage' and Config.Inventory == 'ox_inventory' then
            TriggerClientEvent('ox_inventory:openInventory', src, 'stash', ('npv_%s_%s'):format(sid, oid))
        end
    end
    Scripts.Dispatch(sid, event, oid, { src = src, coords = o.coords })
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, s in pairs(Scenarios.Live) do s.playerVars[src] = nil end
    Dialogue.sessions[src] = nil
    lastInteract[src] = nil
end)

-- ---------------------------------------------------------------------------
-- Dialogue
-- ---------------------------------------------------------------------------

Dialogue.sessions = {}

local function jobOf(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p and p.PlayerData and p.PlayerData.job and p.PlayerData.job.name or nil
end

local function roleAllowed(src, roles)
    if not roles or #roles == 0 then return true end
    local job = jobOf(src)
    for _, rid in ipairs(roles) do
        for _, r in ipairs(Config.DialogueRoles) do
            if r.id == rid then
                for _, j in ipairs(r.jobs) do if j == job then return true end end
            end
        end
    end
    return false
end

local function view(src, o, node)
    local replies = {}
    for _, r in ipairs(node.replies) do
        if r.label ~= '' and roleAllowed(src, r.roles) then replies[#replies + 1] = { id = r.id, label = r.label } end
    end
    return { name = o.label, role = o.role, text = node.text, replies = replies }
end

function Dialogue.Open(src, sid, oid)
    local s = Scenarios.Live[sid]
    local o = s and objectOf(s, oid)
    if not o or o.kind ~= 'npc' or not o.dialogue then return nil, 'no_dialogue' end
    if not near(src, o, Config.TalkDistance) then return nil, 'too_far' end
    Dialogue.sessions[src] = { sid = sid, oid = oid, node = 'start' }
    return view(src, o, o.dialogue.nodes.start)
end

function Dialogue.Reply(src, replyId)
    local sess = Dialogue.sessions[src]
    local s = sess and Scenarios.Live[sess.sid]
    local o = s and objectOf(s, sess.oid)
    if not o then Dialogue.sessions[src] = nil return { closed = true } end
    if not near(src, o, Config.TalkDistance + 2.0) then Dialogue.sessions[src] = nil return { closed = true } end

    local node = o.dialogue.nodes[sess.node]
    local reply
    for _, r in ipairs(node and node.replies or {}) do
        if r.id == replyId then reply = r end
    end
    if not reply or not roleAllowed(src, reply.roles) then return { closed = true } end

    local ctx = { src = src, coords = o.coords }
    for _, t in ipairs(reply.triggers) do
        if act[t.t] then pcall(act[t.t], sess.sid, s, t, ctx) end
    end

    local nextId = reply.jump or reply.target
    if nextId == 'end' or not nextId or not o.dialogue.nodes[nextId] then
        Dialogue.sessions[src] = nil
        return { closed = true }
    end
    sess.node = nextId
    return view(src, o, o.dialogue.nodes[nextId])
end

function Dialogue.Close(src)
    Dialogue.sessions[src] = nil
end
