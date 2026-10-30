-- RPC layer. The NUI never talks to the server directly: every call comes through the client
-- callback below, and every handler here authorises the *caller* (source) itself.

local RPC = {}

local function fail(reason) return { ok = false, error = reason } end
local function ok(data, message) return { ok = true, data = data, message = message } end

local function sessionFor(src)
    local rank = Perms.GetRank(src)
    if not rank then return nil end
    local cmds = {}
    for _, c in ipairs(Config.Commands) do
        if Perms.Has(src, c.perm) then cmds[#cmds + 1] = c end
    end
    return {
        rank = { name = rank.name, label = rank.label, level = rank.level },
        perms = Perms.List(src),
        commands = cmds,
        id = src,
        name = GetPlayerName(src),
        catalog = { npcs = Config.NpcCatalog, objects = Config.ObjectCatalog, anims = Config.NpcAnimations, roles = Config.DialogueRoles, hacks = Config.HackGames, trolleys = Config.Trolleys, doors = Config.Doors, moneyTypes = Config.MoneyTypes },
        limits = Config.Limits,
        dmKey = Config.DmKeyLabel,
    }
end

-- name = { perm = <required permission or nil>, fn = function(src, payload) -> response }
RPC.session = { perm = 'self', fn = function(src) return ok(sessionFor(src)) end }

RPC['players.list'] = { perm = 'players.view', fn = function() return ok(Players.List()) end }
RPC['players.details'] = { perm = 'players.view', fn = function(src, p)
    local id = Players.Resolve(p and p.id)
    if not id then return fail('player_offline') end
    local d = Players.Details(src, id)
    return d and ok(d) or fail('player_offline')
end }

RPC['command.run'] = { perm = 'self', fn = function(src, p)
    if type(p) ~= 'table' or type(p.id) ~= 'string' then return fail('bad_request') end
    local good, msg = Commands.Run(src, p.id, p.args)
    if good then return ok(nil, msg) end
    return fail(msg or 'failed')
end }

-- DM ------------------------------------------------------------------------------------------
local function idOf(p)
    return type(p) == 'table' and Utils.ValidId(p.id) and p.id or nil
end

RPC['dm.list'] = { perm = 'dm', fn = function(src)
    return ok({ scenarios = Scenarios.List(src), summary = Scenarios.Summary() })
end }
RPC['dm.get'] = { perm = 'dm', fn = function(src, p)
    local id = idOf(p); if not id then return fail('bad_id') end
    local s, why = Scenarios.Get(src, id)
    return s and ok(s) or fail(why)
end }
RPC['dm.create'] = { perm = 'dm', fn = function(src, p)
    local id, why = Scenarios.Create(src, p and p.name, p and p.category)
    return id and ok({ id = id }) or fail(why)
end }
RPC['dm.save'] = { perm = 'dm', fn = function(src, p)
    local id = idOf(p); if not id then return fail('bad_id') end
    local version, why = Scenarios.Save(src, id, p.name, p.definition)
    return version and ok({ version = version }) or fail(why)
end }
RPC['dm.delete'] = { perm = 'dm', fn = function(src, p)
    local id = idOf(p); if not id then return fail('bad_id') end
    local good, why = Scenarios.Delete(src, id)
    return good and ok() or fail(why)
end }
RPC['dm.duplicate'] = { perm = 'dm', fn = function(src, p)
    local id = idOf(p); if not id then return fail('bad_id') end
    local nid, why = Scenarios.Duplicate(src, id)
    return nid and ok({ id = nid }) or fail(why)
end }
RPC['dm.import'] = { perm = 'dm', fn = function(src, p)
    local n = Utils.Num(p and p.number, 1, 1e9)
    if not n then return fail('bad_id') end
    local row = MySQL.single.await('SELECT id FROM npv_dm_scenarios WHERE number = ?', { math.floor(n) })
    if not row then return fail('not_found') end
    local nid, why = Scenarios.Duplicate(src, row.id)
    return nid and ok({ id = nid }) or fail(why)
end }
-- Switching a scenario live affects other players, so it needs dm.publish.
RPC['dm.setLive'] = { perm = 'dm.publish', fn = function(src, p)
    local id = idOf(p); if not id then return fail('bad_id') end
    local good, why = Scenarios.SetLive(src, id, p.live == true)
    Audit.Log(src, p.live and 'dm_spawn' or 'dm_despawn', good and 'ok' or 'failed', nil, { id = id })
    return good and ok() or fail(why)
end }
RPC['dm.action'] = { perm = 'dm.run', fn = function(src, p)
    if not Perms.RateOk(src) then return fail('rate_limited') end
    local good, msg = DmActions.Run(src, p)
    return good and ok(nil, msg) or fail(msg)
end }
RPC['dm.running'] = { perm = 'dm.run', fn = function() return ok(DmActions.Running()) end }
RPC['dm.stopAction'] = { perm = 'dm.run', fn = function(_, p)
    return DmActions.Stop(tonumber(p and p.id)) and ok() or fail('not_found')
end }

-- ox_inventory item list for the storage contents picker (name + label), cached.
local itemCache
RPC['dm.items'] = { perm = 'dm', fn = function()
    if not itemCache then
        itemCache = {}
        if Config.Inventory == 'ox_inventory' and GetResourceState('ox_inventory') == 'started' then
            local ok, items = pcall(function() return exports.ox_inventory:Items() end)
            for name, def in pairs(ok and items or {}) do
                itemCache[#itemCache + 1] = { name = name, label = def.label or name }
            end
            table.sort(itemCache, function(a, b) return a.name < b.name end)
        end
    end
    return ok(itemCache)
end }
RPC['dm.refillLoot'] = { perm = 'dm.run', fn = function(src, p)
    local id = idOf(p); if not id then return fail('bad_id') end
    local good, n = Scenarios.RefillLoot(id)
    if not good then return fail(n) end
    Audit.Log(src, 'dm_refill_loot', 'ok', nil, { id = id })
    return ok(nil, ('Refilled %d storage(s)'):format(n))
end }

RPC['dm.scriptInfo'] = { perm = 'dm', fn = function(_, p)
    local id = idOf(p); if not id then return fail('bad_id') end
    local s = Scenarios.Live[id]
    if not s then return ok({ live = false }) end
    local runs = {}
    for sid, n in pairs(s.runs) do runs[sid] = { count = n, last = s.lastRun[sid] } end
    return ok({ live = true, vars = s.vars, runs = runs, now = os.time() })
end }
RPC['dm.resetVars'] = { perm = 'dm.run', fn = function(src, p)
    local id = idOf(p); if not id then return fail('bad_id') end
    local s = Scenarios.Live[id]
    if not s then return fail('not_live') end
    s.vars, s.playerVars = {}, {}
    Audit.Log(src, 'dm_reset_vars', 'ok', nil, { id = id })
    return ok()
end }
RPC['dm.runScript'] = { perm = 'dm.run', fn = function(src, p)
    local id = idOf(p); if not id or not Utils.ValidId(p.scriptId) then return fail('bad_id') end
    if not Perms.RateOk(src) then return fail('rate_limited') end
    local c = GetEntityCoords(GetPlayerPed(src))
    local good, why = Scripts.RunOne(id, p.scriptId, { src = src, coords = { x = c.x, y = c.y, z = c.z, h = 0.0 } })
    Audit.Log(src, 'dm_run_script', good and 'ok' or 'failed', nil, { id = id, script = p.scriptId })
    return good and ok() or fail(why)
end }

RPC['dm.libraryList'] = { perm = 'dm', fn = function()
    local rows = MySQL.query.await('SELECT id, name, owner_name, script FROM npv_dm_script_library ORDER BY id DESC LIMIT 100')
    for _, r in ipairs(rows) do r.script = json.decode(r.script) end
    return ok(rows)
end }
RPC['dm.librarySave'] = { perm = 'dm', fn = function(src, p)
    local script, why = Scripts.SanitizeScript(p and p.script)
    if not script then return fail(why) end
    MySQL.insert.await('INSERT INTO npv_dm_script_library (name, owner_name, script) VALUES (?, ?, ?)',
        { Utils.Clean(p.name, 60) or script.name, GetPlayerName(src), json.encode(script) })
    return ok()
end }

-- Entry point for the NUI (via the client). ------------------------------------------------------
lib.callback.register('npv_admin:rpc', function(src, name, payload)
    local entry = type(name) == 'string' and RPC[name]
    if not entry then return fail('unknown_rpc') end
    if entry.perm and not Perms.Has(src, entry.perm) then
        return fail('no_permission')
    end
    local good, res = pcall(entry.fn, src, payload)
    if not good then
        print(('^1[npv_admin] rpc %s error: %s^7'):format(name, res))
        return fail('server_error')
    end
    return res
end)

-- Dialogue is player-facing: no staff permission, but all state is validated inside Dialogue.*
lib.callback.register('npv_admin:dialogue', function(src, kind, a, b)
    if kind == 'open' and type(a) == 'string' and type(b) == 'string' then
        local v, why = Dialogue.Open(src, a, b)
        return v and { ok = true, view = v } or fail(why)
    elseif kind == 'reply' and type(a) == 'string' then
        return { ok = true, view = Dialogue.Reply(src, a) }
    end
    Dialogue.Close(src)
    return { ok = true }
end)

-- Quick check callback used by the client to know whether to bind staff keys.
lib.callback.register('npv_admin:isStaff', function(src)
    return Perms.GetRank(src) ~= nil
end)

CreateThread(function()
    DB.WaitReady()
    print('^2[npv_admin] started^7')
end)
