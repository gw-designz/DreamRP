-- Locked doors. A door is a frozen prop that swings open when unlocked. The server owns every step:
-- whether the door is live and still shut, who is working on it, the items, the minigame result, and the
-- minimum time a thermite charge has to burn. Clients only play animations and effects.

Doors = {}

local failedAt = {} -- ["src:sid:oid"] = ms of the last failed hack
local SWING_STEPS = 20

local function find(sid, oid)
    local s = Scenarios.Live[sid]
    if not s then return nil end
    for _, o in ipairs(s.def.objects) do
        if o.id == oid and o.kind == 'door' then return s, o, s.doors[oid] end
    end
end

local function near(src, o)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local c = GetEntityCoords(ped)
    return Utils.Dist({ x = c.x, y = c.y, z = c.z }, o.anchor or o.coords) <= Config.Doors.MaxDistance
end

local function itemCount(src, item)
    if Config.Inventory ~= 'ox_inventory' then return 0 end
    local ok, n = pcall(function() return exports.ox_inventory:GetItemCount(src, item) end)
    return ok and tonumber(n) or 0
end

---Swing a door open (or shut). Every player's game animates it (a frozen server-made prop does not reliably
---show server-side movement); the server then sets the final heading so late arrivals see it where it ended.
local function swing(ent, from, to)
    TriggerClientEvent('npv_admin:client:doorSwing', -1, NetworkGetNetworkIdFromEntity(ent), from, to)
    SetTimeout(SWING_STEPS * 50 + 250, function()
        if DoesEntityExist(ent) then SetEntityHeading(ent, to % 360.0) end
    end)
end

---Which way a door should swing so it moves toward (or away from) a player. The player's own game knows the
---model's size; the answer is only used for the look of the swing. Returns the signed angle.
local function swingAngle(o, src)
    local angle = o.openAngle
    if o.openDir == 'fixed' or not (o.model or o.hash) then return angle end
    local target = src
    if not target or GetPlayerPed(target) == 0 then
        local best
        for _, id in ipairs(GetPlayers()) do
            local ped = GetPlayerPed(tonumber(id))
            if ped ~= 0 then
                local c = GetEntityCoords(ped)
                local d = Utils.Dist({ x = c.x, y = c.y, z = c.z }, o.coords)
                if d <= 40.0 and (not best or d < best.d) then best = { d = d, id = tonumber(id) } end
            end
        end
        target = best and best.id
    end
    if not target then return angle end
    local ok, sign = pcall(lib.callback.await, 'npv_admin:client:doorSwing', target, o.world and o.hash or o.model, o.coords, math.abs(angle), o.openDir)
    if ok and (sign == 1 or sign == -1) then return math.abs(angle) * sign end
    return angle
end

---Open (open = true) or shut a door. `src` is who did it, for scripts and the log.
function Doors.Set(sid, oid, open, src)
    local s, o, state = find(sid, oid)
    if not s or not state then return false end
    if state.open == open then return true end
    local angle = open and swingAngle(o, src) or state.angle or o.openAngle
    s, o, state = find(sid, oid) -- the scenario may have changed while the player's game answered
    if not s or not state or state.open == open then return state ~= nil end
    state.angle = angle
    state.open = open
    state.busy, state.stage = nil, nil
    state.token = (state.token or 0) + 1
    local token = state.token
    local ent = s.entities[oid]
    print(('[npv_admin] door %s %s: %s, angle %.0f'):format(o.label, open and 'opening' or 'closing', (ent and DoesEntityExist(ent)) and 'placed prop' or (o.world and 'map door' or 'NO ENTITY'), state.angle or 0))
    local closed = o.coords.h
    local opened = closed + (state.angle or o.openAngle)
    if o.world then
        -- Existing map door: every player's game moves its own copy of the object.
        TriggerClientEvent('npv_admin:client:worldDoorSwing', -1, sid .. ':' .. oid, open and closed or opened, open and opened or closed)
    elseif ent and DoesEntityExist(ent) then
        if open then swing(ent, closed, opened) else swing(ent, opened, closed) end
    end
    Scenarios.Broadcast()
    if open then
        Scripts.Dispatch(sid, 'unlocked', oid, { src = src, coords = o.coords })
        if o.relock > 0 then
            SetTimeout(math.floor(o.relock * 1000), function()
                local s2, _, st2 = find(sid, oid)
                if s2 == s and st2 == state and state.token == token and state.open then Doors.Set(sid, oid, false) end
            end)
        end
    end
    return true
end

---Put a door back to shut and locked (scenario reset / loot refill).
function Doors.Reset(sid, o)
    Doors.Set(sid, o.id, false)
end

local function busyWith(state, src, now)
    return state.busy and state.busy ~= src and GetPlayerName(state.busy) and (now - (state.touched or 0)) < Config.Doors.TimeoutMs
end

-- action: 'thermite_begin' | 'thermite_ignite' | 'thermite_done' | 'thermite_abort' | 'hack'
lib.callback.register('npv_admin:door', function(src, action, sid, oid)
    if type(action) ~= 'string' or type(sid) ~= 'string' or type(oid) ~= 'string' then return { ok = false, error = 'bad_request' } end
    local s, o, state = find(sid, oid)
    if not s or not state then return { ok = false, error = 'not_found' } end
    local now = GetGameTimer()

    if action == 'thermite_abort' then
        if state.busy == src then state.busy, state.stage = nil, nil end
        return { ok = true }
    end
    if state.open then return { ok = false, error = 'already_open' } end
    if not near(src, o) then return { ok = false, error = 'too_far' } end

    if action == 'thermite_begin' then
        local cfg = o.thermite
        if not cfg.enabled then return { ok = false, error = 'not_available' } end
        if busyWith(state, src, now) then return { ok = false, error = 'in_use' } end
        if cfg.item ~= '' then
            if itemCount(src, cfg.item) < 1 then return { ok = false, error = 'no_item', item = cfg.item } end
            if not exports.ox_inventory:RemoveItem(src, cfg.item, 1) then return { ok = false, error = 'no_item', item = cfg.item } end
        end
        state.busy, state.stage, state.touched = src, 'planted', now
        return { ok = true, burn = cfg.burn }
    end

    if action == 'thermite_ignite' then
        if state.busy ~= src or state.stage ~= 'planted' then return { ok = false, error = 'bad_state' } end
        local cfg = o.thermite
        local passed = true
        if cfg.game ~= 'none' then
            passed = Scripts.RunHack(src, { game = cfg.game, difficulty = cfg.difficulty, name = 'Thermite' }) == true
        end
        if state.busy ~= src or Scenarios.Live[sid] ~= s then return { ok = false, error = 'bad_state' } end
        if not passed then
            state.busy, state.stage = nil, nil -- the charge is spent
            Audit.Log(src, 'door_thermite', 'failed', nil, { scenario = sid, door = oid })
            return { ok = true, passed = false }
        end
        state.stage, state.burnAt, state.touched = 'burning', GetGameTimer(), GetGameTimer()
        return { ok = true, passed = true, burn = cfg.burn }
    end

    if action == 'thermite_done' then
        if state.busy ~= src or state.stage ~= 'burning' then return { ok = false, error = 'bad_state' } end
        if now - state.burnAt < o.thermite.burn * 1000 * 0.85 then return { ok = false, error = 'too_fast' } end
        Audit.Log(src, 'door_thermite', 'ok', nil, { scenario = sid, door = oid })
        Doors.Set(sid, oid, true, src)
        return { ok = true }
    end

    if action == 'hack' then
        local cfg = o.hack
        if not cfg.enabled then return { ok = false, error = 'not_available' } end
        if busyWith(state, src, now) then return { ok = false, error = 'in_use' } end
        local key = ('%d:%s:%s'):format(src, sid, oid)
        if failedAt[key] and now - failedAt[key] < Config.Doors.FailCooldownMs then return { ok = false, error = 'cooldown' } end
        if cfg.item ~= '' and itemCount(src, cfg.item) < 1 then return { ok = false, error = 'no_item', item = cfg.item } end
        state.busy, state.stage, state.touched = src, 'hacking', now
        local passed = Scripts.RunHack(src, { game = cfg.game, difficulty = cfg.difficulty, name = o.label }) == true
        if state.busy ~= src or Scenarios.Live[sid] ~= s then return { ok = false, error = 'bad_state' } end
        state.busy, state.stage = nil, nil
        if not passed then
            failedAt[key] = GetGameTimer()
            Audit.Log(src, 'door_hack', 'failed', nil, { scenario = sid, door = oid })
            return { ok = true, passed = false }
        end
        Audit.Log(src, 'door_hack', 'ok', nil, { scenario = sid, door = oid })
        Doors.Set(sid, oid, true, src)
        return { ok = true, passed = true }
    end

    return { ok = false, error = 'bad_action' }
end)

AddEventHandler('playerDropped', function()
    local src = source
    for _, s in pairs(Scenarios.Live) do
        for _, state in pairs(s.doors or {}) do
            if state.busy == src then state.busy, state.stage = nil, nil end
        end
    end
    for k in pairs(failedAt) do
        if k:match('^(%d+):') == tostring(src) then failedAt[k] = nil end
    end
end)
