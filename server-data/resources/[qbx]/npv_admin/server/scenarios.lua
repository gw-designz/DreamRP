Scenarios = {}

local KINDS = { object = true, npc = true, trigger = true, interactive = true, storage = true, rope = true, trolley = true, door = true }
local NO_ENTITY = { trigger = true, rope = true } -- exist only as zones / client-side visuals

---@type table<string, table>
local Live = {} -- [scenarioId] = { def, entities = {[objId]=entity}, vars = {}, playerVars = {}, locks = {}, owner = license }
Scenarios.Live = Live

local function license(src)
    return GetPlayerIdentifierByType(src, 'license')
end

-- ---------------------------------------------------------------------------
-- Definition sanitising. Everything a client can save passes through here.
-- ---------------------------------------------------------------------------

local function cleanBool(v) return v == true end

local function sanitizeDialogue(d)
    if type(d) ~= 'table' or type(d.nodes) ~= 'table' then return nil end
    local nodes, count = {}, 0
    for id, n in pairs(d.nodes) do
        if Utils.ValidId(id) and type(n) == 'table' then
            count = count + 1
            if count > 60 then break end
            local replies = {}
            for _, r in ipairs(type(n.replies) == 'table' and n.replies or {}) do
                if #replies >= 8 then break end
                local triggers = {}
                for _, t in ipairs(type(r.triggers) == 'table' and r.triggers or {}) do
                    local clean = Scripts.SanitizeTrigger(t)
                    if clean and #triggers < 6 then triggers[#triggers + 1] = clean end
                end
                local roles = {}
                for _, role in ipairs(type(r.roles) == 'table' and r.roles or {}) do
                    if type(role) == 'string' and #roles < 8 then roles[#roles + 1] = Utils.Clean(role, 20) end
                end
                replies[#replies + 1] = {
                    id = Utils.ValidId(r.id) and r.id or ('r' .. #replies + 1),
                    label = Utils.Clean(r.label, 80) or '',
                    target = Utils.ValidId(r.target) and r.target or nil,
                    jump = Utils.ValidId(r.jump) and r.jump or nil,
                    roles = roles,
                    triggers = triggers,
                    x = Utils.Num(r.x), y = Utils.Num(r.y),
                }
            end
            nodes[id] = { id = id, text = Utils.Clean(n.text, 300) or '', replies = replies, x = Utils.Num(n.x), y = Utils.Num(n.y) }
        end
    end
    if not nodes.start then return nil end
    return { nodes = nodes }
end

-- Freemode appearance (heritage, face, hair, overlays, clothing, props). Every number is clamped to
-- the range the game accepts; unknown keys are dropped. See client/appearance.lua for the format.
local FREEMODE = { mp_m_freemode_01 = true, mp_f_freemode_01 = true }

local function clampNum(v, lo, hi, default)
    local n = tonumber(v)
    if not Utils.IsFiniteNumber(n) then return default end
    return math.max(lo, math.min(hi, n))
end
local function clampInt(v, lo, hi, default) return math.floor(clampNum(v, lo, hi, default)) end

local function sanitizeAppearance(a)
    a = type(a) == 'table' and a or {}
    local b = type(a.blend) == 'table' and a.blend or {}
    local out = {
        blend = {
            s1 = clampInt(b.s1, 0, 45, 0), s2 = clampInt(b.s2, 0, 45, 0), k1 = clampInt(b.k1, 0, 45, 0), k2 = clampInt(b.k2, 0, 45, 0),
            sm = clampNum(b.sm, 0, 1, 0.5), km = clampNum(b.km, 0, 1, 0.5),
        },
        face = {}, overlays = {}, comps = {}, props = {},
        autoTorso = a.autoTorso ~= false,
    }
    local face = type(a.face) == 'table' and a.face or {}
    for n = 1, 20 do out.face[n] = clampNum(face[n], -1, 1, 0.0) end
    local overlays = type(a.overlays) == 'table' and a.overlays or {}
    for id = 0, 11 do
        local o = overlays[tostring(id)]
        if type(o) == 'table' then
            out.overlays[tostring(id)] = { i = clampInt(o.i, 0, 255, 255), o = clampNum(o.o, 0, 1, 1.0), c = clampInt(o.c, 0, 63, 0), c2 = clampInt(o.c2, 0, 63, 0) }
        end
    end
    local h = type(a.hair) == 'table' and a.hair or {}
    out.hair = { s = clampInt(h.s, 0, 1000, 0), t = clampInt(h.t, 0, 255, 0), c = clampInt(h.c, 0, 63, 0), h = clampInt(h.h, 0, 63, 0) }
    out.eye = clampInt(a.eye, 0, 31, 0)
    local comps = type(a.comps) == 'table' and a.comps or {}
    for _, comp in ipairs({ 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do
        local v = comps[tostring(comp)]
        if type(v) == 'table' then out.comps[tostring(comp)] = { d = clampInt(v.d, 0, 5000, 0), t = clampInt(v.t, 0, 255, 0) } end
    end
    local props = type(a.props) == 'table' and a.props or {}
    for _, prop in ipairs({ 0, 1, 2, 6, 7 }) do
        local v = props[tostring(prop)]
        if type(v) == 'table' then out.props[tostring(prop)] = { d = clampInt(v.d, -1, 5000, -1), t = clampInt(v.t, 0, 255, 0) } end
    end
    return out
end

local function sanitizeObject(o)
    if type(o) ~= 'table' or not Utils.ValidId(o.id) or not KINDS[o.kind] then return nil, 'bad_object' end
    local coords = Utils.ValidCoords(o.coords)
    if not coords then return nil, 'bad_coords' end
    local model = Utils.Str(o.model, 60)
    local world = o.kind == 'door' and o.world == true -- an existing map / MLO door: nothing is spawned for it
    if not NO_ENTITY[o.kind] and not world and (not model or not model:match('^[%w_]+$')) then return nil, 'bad_model' end
    local out = {
        id = o.id, kind = o.kind, model = model, label = Utils.Clean(o.label, 60) or model or o.kind,
        coords = coords,
    }
    if o.kind == 'npc' then
        out.role = Utils.Clean(o.role, 60) or ''
        out.anim = Utils.Clean(o.anim, 40) or ''
        out.ai = o.ai == 'npc' and 'npc' or 'statue'
        out.greet = cleanBool(o.greet)
        local voice = Utils.Str(o.voice, 40)
        out.voice = voice and voice:match('^[%w_]*$') and voice or ''
        out.chatter = math.floor(Utils.Num(o.chatter or 0, 0, 3) or 0)
        out.chatNpcs = o.chatNpcs ~= false
        out.patrol = {}
        for _, p in ipairs(type(o.patrol) == 'table' and o.patrol or {}) do
            local pc = Utils.ValidCoords(p)
            if pc and #out.patrol < 12 then out.patrol[#out.patrol + 1] = { x = pc.x, y = pc.y, z = pc.z } end
        end
        out.dialogue = sanitizeDialogue(o.dialogue)
        -- Only freemode models can be dressed; they always carry an appearance so the head is never blank.
        if FREEMODE[model] then out.appearance = sanitizeAppearance(o.appearance) end
    elseif o.kind == 'trolley' then
        -- Heist trolley players can grab from. Everything about the payout is decided here, never by a client.
        local emptyModel = Utils.Str(o.emptyModel, 60)
        out.emptyModel = emptyModel and emptyModel:match('^[%w_]+$') and emptyModel or nil
        out.ttype = Utils.Clean(o.ttype, 30) or 'custom'
        out.stacks = math.floor(clampNum(o.stacks, 1, 100, 8))
        out.seconds = clampNum(o.seconds, 2, 30, 6.0)
        out.prompt = Utils.Clean(o.prompt, 40) or 'Grab'
        out.anim = Config.TrolleyAnims[o.anim] and o.anim or 'cash'
        local r = type(o.reward) == 'table' and o.reward or {}
        local mode = r.mode == 'item' and 'item' or 'money'
        local account = 'cash'
        for _, t in ipairs(Config.MoneyTypes) do if t == r.account then account = t end end
        local item = Utils.Str(r.item, 60)
        local lo = math.floor(clampNum(r.min, 0, 1000000, 1))
        local hi = math.floor(clampNum(r.max, 0, 1000000, lo))
        out.reward = {
            mode = mode, account = account, item = item and item:match('^[%w_%-]+$') and item or '',
            min = math.min(lo, hi), max = math.max(lo, hi),
        }
    elseif o.kind == 'door' then
        -- A locked door. The unlock rules live here so that no client can loosen them.
        out.openAngle = clampNum(o.openAngle, -180, 180, (o.openAngle == nil and o.openRatio == -1) and -90 or 90)
        if world then
            local hash = tonumber(o.hash)
            if not hash or not Utils.IsFiniteNumber(hash) or hash ~= math.floor(hash) or hash < -2147483648 or hash > 4294967295 then return nil, 'bad_door_hash' end
            out.world, out.hash, out.model = true, hash, nil
            local a = type(o.anchor) == 'table' and o.anchor or {}
            out.anchor = { x = clampNum(a.x, -10000, 10000, coords.x), y = clampNum(a.y, -10000, 10000, coords.y), z = clampNum(a.z, -1000, 3000, coords.z) }
        end
        out.relock = clampNum(o.relock, 0, 3600, 0)
        out.openDir = (o.openDir == 'away' or o.openDir == 'fixed') and o.openDir or 'toward' -- which way it swings, relative to whoever unlocked it
        local function game(v, allowNone)
            if allowNone and v == 'none' then return 'none' end
            for _, g in ipairs(Config.HackGames) do if g.id == v then return g.id end end
            return 'skill'
        end
        local function item(v, default)
            v = Utils.Str(v, 60)
            if v == nil then return default end
            return v:match('^[%w_%-]*$') and v or default
        end
        local t, h = type(o.thermite) == 'table' and o.thermite or {}, type(o.hack) == 'table' and o.hack or {}
        out.thermite = {
            enabled = t.enabled ~= false, item = item(t.item, Config.Doors.Thermite.item),
            burn = clampNum(t.burn, 3, 60, Config.Doors.Thermite.burn), game = game(t.game, true), difficulty = clampInt(t.difficulty, 1, 5, Config.Doors.Thermite.difficulty),
        }
        out.hack = {
            enabled = h.enabled ~= false, item = item(h.item, Config.Doors.Hack.item),
            game = game(h.game, false), difficulty = clampInt(h.difficulty, 1, 5, Config.Doors.Hack.difficulty),
        }
    elseif o.kind == 'rope' then
        out.length = Utils.Num(o.length or 20, 3, 150) or 20
        out.prompt = Utils.Clean(o.prompt, 40) or 'Rappel down'
    elseif o.kind == 'trigger' then
        local sx, sy, sz = Utils.Num(o.size and o.size.x, 0.5, 100), Utils.Num(o.size and o.size.y, 0.5, 100), Utils.Num(o.size and o.size.z, 0.5, 50)
        out.size = { x = sx or 3.0, y = sy or 3.0, z = sz or 3.0 }
    elseif o.kind == 'interactive' then
        out.prompt = Utils.Clean(o.prompt, 40) or 'Use'
        out.cooldown = Utils.Num(o.cooldown or 0, 0, 3600) or 0
    elseif o.kind == 'storage' then
        out.slots = Utils.Num(o.slots or 30, 1, 100) or 30
        out.weight = Utils.Num(o.weight or 50000, 1000, 500000) or 50000
        -- Starting contents: { item, count, chance% }. Validated again against ox_inventory when filled.
        out.loot = {}
        for _, e in ipairs(type(o.loot) == 'table' and o.loot or {}) do
            local item = Utils.Str(type(e) == 'table' and e.item, 60)
            local count = type(e) == 'table' and Utils.Num(e.count, 1, 10000)
            if item and item:match('^[%w_%-]+$') and count and #out.loot < 40 then
                out.loot[#out.loot + 1] = { item = item, count = math.floor(count), chance = math.floor(Utils.Num(e.chance or 100, 1, 100) or 100) }
            end
        end
    end
    return out
end

---Returns a clean definition or nil, reason.
function Scenarios.Sanitize(def)
    if type(def) ~= 'table' then return nil, 'bad_definition' end
    local out = { objects = {}, scripts = {} }
    local seen, people = {}, 0
    for _, o in ipairs(type(def.objects) == 'table' and def.objects or {}) do
        if #out.objects >= Config.Limits.ObjectsPerScenario then return nil, 'too_many_objects' end
        local clean, why = sanitizeObject(o)
        if not clean then return nil, why end
        if seen[clean.id] then return nil, 'duplicate_object_id' end
        seen[clean.id] = true
        if clean.kind == 'npc' then people = people + 1 end
        out.objects[#out.objects + 1] = clean
    end
    if people > Config.Limits.PeoplePerScenario then return nil, 'too_many_people' end
    for _, s in ipairs(type(def.scripts) == 'table' and def.scripts or {}) do
        local clean, why = Scripts.SanitizeScript(s)
        if not clean then return nil, why end
        out.scripts[#out.scripts + 1] = clean
    end
    return out
end

-- ---------------------------------------------------------------------------
-- CRUD
-- ---------------------------------------------------------------------------

local function decode(row)
    if not row then return nil end
    local ok, def = pcall(json.decode, row.definition or '{}')
    row.definition = ok and def or { objects = {}, scripts = {} }
    return row
end

local function canEdit(src, row)
    return row.owner_license == license(src) or Perms.Has(src, 'dm.publish')
end

local function listEntry(row)
    local def = row.definition
    local liveEntry = Live[row.id]
    return {
        id = row.id, number = row.number, name = row.name, owner = row.owner_name, category = row.category,
        status = liveEntry and 'live' or 'draft', version = row.version,
        objectCount = def and def.objects and #def.objects or 0,
        mine = row.owner_license == nil,
    }
end

function Scenarios.List(src)
    local rows = MySQL.query.await('SELECT id, number, name, owner_license, owner_name, category, version, definition FROM npv_dm_scenarios ORDER BY number DESC')
    local mine, out = license(src), {}
    local canSeeAll = Perms.Has(src, 'dm.publish')
    for _, row in ipairs(rows) do
        if canSeeAll or row.owner_license == mine or Live[row.id] then
            decode(row)
            local e = listEntry(row)
            e.mine = row.owner_license == mine
            out[#out + 1] = e
        end
    end
    return out
end

function Scenarios.Get(src, id)
    local row = decode(MySQL.single.await('SELECT * FROM npv_dm_scenarios WHERE id = ?', { id }))
    if not row then return nil, 'not_found' end
    if not (canEdit(src, row) or Live[id]) then return nil, 'no_permission' end
    return {
        id = row.id, number = row.number, name = row.name, owner = row.owner_name, category = row.category,
        status = Live[id] and 'live' or 'draft', version = row.version, definition = row.definition,
        canEdit = canEdit(src, row),
    }
end

local function newId()
    return ('sc_%s'):format(string.format('%x', os.time()) .. math.random(100, 999))
end

function Scenarios.Create(src, name, category)
    name = Utils.Clean(name, 60)
    if not name or #name < 1 then return nil, 'bad_name' end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM npv_dm_scenarios WHERE owner_license = ?', { license(src) })
    if count >= Config.Limits.ScenariosPerOwner then return nil, 'too_many_scenarios' end
    local id = newId()
    MySQL.insert.await('INSERT INTO npv_dm_scenarios (id, name, owner_license, owner_name, category, definition) VALUES (?, ?, ?, ?, ?, ?)',
        { id, name, license(src), GetPlayerName(src), Utils.Clean(category, 40), json.encode({ objects = {}, scripts = {} }) })
    return id
end

function Scenarios.Save(src, id, name, definition)
    local row = decode(MySQL.single.await('SELECT * FROM npv_dm_scenarios WHERE id = ?', { id }))
    if not row then return nil, 'not_found' end
    if not canEdit(src, row) then return nil, 'no_permission' end
    local clean, why = Scenarios.Sanitize(definition)
    if not clean then return nil, why end
    local newName = name and Utils.Clean(name, 60) or row.name
    -- Keep a history row of the version we are replacing.
    MySQL.insert('INSERT INTO npv_dm_scenario_versions (scenario_id, version, definition, saved_by) VALUES (?, ?, ?, ?)',
        { id, row.version, json.encode(row.definition), GetPlayerName(src) })
    MySQL.update.await('UPDATE npv_dm_scenarios SET name = ?, definition = ?, version = version + 1 WHERE id = ?', { newName, json.encode(clean), id })
    if Live[id] then Scenarios.Despawn(id) Scenarios.Spawn(id) end -- live edits re-apply
    return row.version + 1
end

function Scenarios.Delete(src, id)
    local row = MySQL.single.await('SELECT * FROM npv_dm_scenarios WHERE id = ?', { id })
    if not row then return false, 'not_found' end
    if not canEdit(src, row) then return false, 'no_permission' end
    Scenarios.Despawn(id)
    MySQL.update.await('DELETE FROM npv_dm_scenarios WHERE id = ?', { id })
    MySQL.update('DELETE FROM npv_dm_scenario_versions WHERE scenario_id = ?', { id })
    return true
end

function Scenarios.Duplicate(src, id)
    local row = MySQL.single.await('SELECT * FROM npv_dm_scenarios WHERE id = ?', { id })
    if not row then return nil, 'not_found' end
    if not (canEdit(src, row) or Live[id]) then return nil, 'no_permission' end
    local nid = newId()
    MySQL.insert.await('INSERT INTO npv_dm_scenarios (id, name, owner_license, owner_name, category, definition) VALUES (?, ?, ?, ?, ?, ?)',
        { nid, (row.name .. ' copy'):sub(1, 80), license(src), GetPlayerName(src), row.category, row.definition })
    return nid
end

-- ---------------------------------------------------------------------------
-- Live lifecycle
-- ---------------------------------------------------------------------------

local function worldLoad()
    local n = 0
    for _, s in pairs(Live) do n = n + #s.def.objects end
    return n
end
Scenarios.WorldLoad = worldLoad

local function buildInteractables()
    local list = {}
    for sid, s in pairs(Live) do
        for _, o in ipairs(s.def.objects) do
            if o.kind == 'trigger' or o.kind == 'interactive' or o.kind == 'storage' or o.kind == 'rope' or (o.kind == 'npc' and o.dialogue) or o.kind == 'door' or (o.kind == 'trolley' and s.trolleys[o.id] and s.trolleys[o.id].left > 0) then
                list[#list + 1] = { sid = sid, oid = o.id, kind = o.kind, label = o.label, prompt = o.prompt, coords = (o.kind == 'door' and o.world) and o.anchor or o.coords, world = o.world, hash = o.hash, ox = o.world and o.coords.x or nil, oy = o.world and o.coords.y or nil, oz = o.world and o.coords.z or nil, ch = o.world and o.coords.h or nil, ah = (o.world and s.doors[o.id] and s.doors[o.id].open) and (o.coords.h + (s.doors[o.id].angle or o.openAngle)) or nil, size = o.size, length = o.length, talk = o.kind == 'npc', locked = o.kind == 'door' and not (s.doors[o.id] and s.doors[o.id].open) or false, tmt = o.kind == 'door' and o.thermite.enabled or false, hck = o.kind == 'door' and o.hack.enabled or false, netId = ((o.kind == 'npc' or o.kind == 'trolley' or o.kind == 'door') and s.entities[o.id] and DoesEntityExist(s.entities[o.id])) and NetworkGetNetworkIdFromEntity(s.entities[o.id]) or nil }
            end
        end
    end
    return list
end

local function broadcastInteractables()
    local n = 0
    for _ in pairs(Live) do n = n + 1 end
    GlobalState.npvLive = n
    TriggerClientEvent('npv_admin:client:interactables', -1, buildInteractables())
end
Scenarios.Broadcast = broadcastInteractables

---Register a storage object's stash and (re)fill it with its configured contents. The stash is
---cleared first, so every spawn / refill puts it back to exactly what the editor says.
function Scenarios.FillStash(sid, o)
    if Config.Inventory ~= 'ox_inventory' or GetResourceState('ox_inventory') ~= 'started' then return 0 end
    local stashId = ('npv_%s_%s'):format(sid, o.id)
    local ok = pcall(function()
        exports.ox_inventory:RegisterStash(stashId, o.label, o.slots, o.weight, false)
        exports.ox_inventory:ClearInventory(stashId)
    end)
    if not ok then return 0 end
    local added = 0
    for _, e in ipairs(o.loot or {}) do
        if math.random(100) <= (e.chance or 100) then
            local exists = pcall(function() assert(exports.ox_inventory:Items(e.item)) end)
            if exists and exports.ox_inventory:AddItem(stashId, e.item, e.count) then added = added + 1
            elseif not exists then print(('^3[npv_admin] %s: unknown item "%s" in %s^7'):format(sid, e.item, o.label)) end
        end
    end
    return added
end

---Put every storage in a live scenario back to its configured contents.
function Scenarios.RefillLoot(sid)
    local s = Live[sid]
    if not s then return false, 'not_live' end
    local n = 0
    for _, o in ipairs(s.def.objects) do
        if o.kind == 'storage' then Scenarios.FillStash(sid, o) n = n + 1 end
        if o.kind == 'trolley' and Trolleys then Trolleys.Reset(sid, o) n = n + 1 end
        if o.kind == 'door' and Doors then Doors.Reset(sid, o) n = n + 1 end
    end
    return true, n
end

function Scenarios.Spawn(id)
    if Live[id] then return true end
    local row = decode(MySQL.single.await('SELECT * FROM npv_dm_scenarios WHERE id = ?', { id }))
    if not row then return false, 'not_found' end
    local def, why = Scenarios.Sanitize(row.definition)
    if not def then return false, why end
    if worldLoad() + #def.objects > Config.Limits.WorldRenderLoad then return false, 'world_load_exceeded' end

    local s = { def = def, entities = {}, trolleys = {}, doors = {}, vars = {}, playerVars = {}, locks = {}, owner = row.owner_license, name = row.name, cooldowns = {}, usage = {}, unlocked = {}, vehicles = {}, runs = {}, lastRun = {} }
    for _, o in ipairs(def.objects) do
        local ent
        local c = o.coords
        if o.kind == 'npc' then
            ent = CreatePed(4, joaat(o.model), c.x, c.y, c.z, c.h, true, true)
        elseif not NO_ENTITY[o.kind] and not o.world then
            ent = CreateObjectNoOffset(joaat(o.model), c.x, c.y, c.z, true, true, false)
            if ent and ent ~= 0 then
                SetEntityHeading(ent, c.h)
                FreezeEntityPosition(ent, true)
            end
        end
        if ent and ent ~= 0 then
            SetEntityDistanceCullingRadius(ent, 800.0)
            s.entities[o.id] = ent
            if o.kind == 'npc' then
                Entity(ent).state:set('npv_npc', { anim = o.anim, ai = o.ai, label = o.label, h = c.h, voice = o.voice, greet = o.greet, chatter = o.chatter, chatNpcs = o.chatNpcs, patrol = o.patrol, appearance = o.appearance }, true)
            end
        elseif not NO_ENTITY[o.kind] and not o.world then
            print(('^3[npv_admin] scenario %s: could not create %s (%s)^7'):format(id, o.id, o.model))
        end
        if o.kind == 'storage' then Scenarios.FillStash(id, o) end
        if o.kind == 'trolley' then s.trolleys[o.id] = { left = o.stacks } end
        if o.kind == 'door' then s.doors[o.id] = { open = false } end
    end
    Live[id] = s
    broadcastInteractables()
    Scripts.FireSpawn(id)
    return true
end

function Scenarios.Despawn(id)
    local s = Live[id]
    if not s then return false end
    for _, ent in pairs(s.entities) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    for _, v in ipairs(s.vehicles or {}) do
        if DoesEntityExist(v.ent) then DeleteEntity(v.ent) end
    end
    Live[id] = nil
    broadcastInteractables()
    return true
end

function Scenarios.Reset(id)
    if not Live[id] then return false end
    Scenarios.Despawn(id)
    return Scenarios.Spawn(id)
end

function Scenarios.SetLive(src, id, live)
    local row = MySQL.single.await('SELECT owner_license FROM npv_dm_scenarios WHERE id = ?', { id })
    if not row then return false, 'not_found' end
    if not canEdit(src, row) then return false, 'no_permission' end
    MySQL.update('UPDATE npv_dm_scenarios SET status = ? WHERE id = ?', { live and 'live' or 'draft', id })
    if live then return Scenarios.Spawn(id) end
    return Scenarios.Despawn(id)
end

-- Scenarios that were live when the server stopped come back up.
CreateThread(function()
    DB.WaitReady()
    Wait(2000)
    local rows = MySQL.query.await("SELECT id FROM npv_dm_scenarios WHERE status = 'live'")
    for _, r in ipairs(rows or {}) do
        local ok, why = Scenarios.Spawn(r.id)
        if not ok then print(('^3[npv_admin] could not restore scenario %s: %s^7'):format(r.id, tostring(why))) end
    end
end)

function Scenarios.Summary()
    local s = { live = 0, objects = 0, people = 0 }
    for _, sc in pairs(Live) do
        s.live = s.live + 1
        for _, o in ipairs(sc.def.objects) do
            s.objects = s.objects + 1
            if o.kind == 'npc' then s.people = s.people + 1 end
        end
    end
    s.worldLoad = s.objects
    s.worldLoadCap = Config.Limits.WorldRenderLoad
    return s
end

---Counts for one scenario (the builder header bars).
function Scenarios.Counts(def)
    local objects, people = 0, 0
    for _, o in ipairs(def.objects or {}) do
        if o.kind == 'npc' then people = people + 1 else objects = objects + 1 end
    end
    return { objects = objects, people = people, worldLoad = worldLoad(), worldLoadCap = Config.Limits.WorldRenderLoad }
end

-- Players joining after a scenario went live need the interactable list.
RegisterNetEvent('npv_admin:server:requestInteractables', function()
    TriggerClientEvent('npv_admin:client:interactables', source, buildInteractables())
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(Live) do Scenarios.Despawn(id) end
end)
