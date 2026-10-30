-- Heist trolleys. A player begins a grab, receives one payout per stack as the animation plays, and the
-- trolley becomes empty (or swaps to its empty model) when its stacks run out. The server decides
-- everything that matters: whether the trolley is live and not empty, who is grabbing it, that the
-- player stays close, that enough time passed between payouts, and what each payout is.

Trolleys = {}

local lastTouch = {} -- [src] = ms of the last begin/stack, for rate checks

local function find(sid, oid)
    local s = Scenarios.Live[sid]
    if not s then return nil end
    for _, o in ipairs(s.def.objects) do
        if o.id == oid and o.kind == 'trolley' then return s, o, s.trolleys[oid] end
    end
end

local function near(src, o)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local c = GetEntityCoords(ped)
    return Utils.Dist({ x = c.x, y = c.y, z = c.z }, o.coords) <= Config.TrolleyMaxDistance
end

local function createEntity(model, o)
    local c = o.coords
    local ent = CreateObjectNoOffset(joaat(model), c.x, c.y, c.z, true, true, false)
    if ent and ent ~= 0 then
        SetEntityHeading(ent, c.h)
        FreezeEntityPosition(ent, true)
        SetEntityDistanceCullingRadius(ent, 800.0)
        return ent
    end
end

---Swap to the empty model (or remove the trolley when it has none).
local function deplete(sid, s, o)
    local old = s.entities[o.id]
    if old and DoesEntityExist(old) then DeleteEntity(old) end
    s.entities[o.id] = nil
    if o.emptyModel then
        local ent = createEntity(o.emptyModel, o)
        if ent then s.entities[o.id] = ent end
    end
    Scenarios.Broadcast()
end

---Put a trolley back to full (used when the scenario is spawned again or loot is refilled).
function Trolleys.Reset(sid, o)
    local s = Scenarios.Live[sid]
    if not s then return end
    local state = s.trolleys[o.id] or {}
    local wasEmpty = state.left == 0
    s.trolleys[o.id] = { left = o.stacks }
    if wasEmpty then
        local old = s.entities[o.id]
        if old and DoesEntityExist(old) then DeleteEntity(old) end
        local ent = createEntity(o.model, o)
        if ent then s.entities[o.id] = ent end
    end
    Scenarios.Broadcast()
end

local function grant(src, o)
    local r = o.reward
    local amount = math.random(r.min, r.max)
    if amount <= 0 then return true, 'nothing' end
    if r.mode == 'money' then
        local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if not ok or not player then return false end
        player.Functions.AddMoney(r.account, amount, 'npv_trolley')
        return true, ('$%d'):format(amount)
    end
    if Config.Inventory ~= 'ox_inventory' or r.item == '' then return false end
    local exists = pcall(function() assert(exports.ox_inventory:Items(r.item)) end)
    if not exists then
        print(('^3[npv_admin] trolley %s pays unknown item "%s"^7'):format(o.label, r.item))
        return false
    end
    if not exports.ox_inventory:AddItem(src, r.item, amount) then return false end
    return true, ('%dx %s'):format(amount, r.item)
end

-- Entry point for the grab flow. action: 'begin' | 'stack' | 'end'.
lib.callback.register('npv_admin:trolley', function(src, action, sid, oid)
    if type(sid) ~= 'string' or type(oid) ~= 'string' then return { ok = false, error = 'bad_request' } end
    local s, o, state = find(sid, oid)
    if not s or not state then return { ok = false, error = 'not_found' } end
    local now = GetGameTimer()

    if action == 'end' then
        if state.busy == src then state.busy = nil end
        return { ok = true }
    end

    if state.left <= 0 then return { ok = false, error = 'empty' } end
    if not near(src, o) then return { ok = false, error = 'too_far' } end

    if action == 'begin' then
        local busyFor = state.busy and state.busy ~= src and GetPlayerName(state.busy) and (now - (state.touched or 0)) < Config.TrolleyTimeoutMs
        if busyFor then return { ok = false, error = 'in_use' } end
        state.busy, state.touched, state.lastPayout = src, now, now
        lastTouch[src] = now
        return {
            ok = true, left = state.left, total = o.stacks, seconds = o.seconds, anim = Config.TrolleyAnims[o.anim],
            label = o.label, prompt = o.prompt,
        }
    end

    if action == 'stack' then
        if state.busy ~= src then return { ok = false, error = 'not_grabbing' } end
        -- One payout per stack, and never faster than the configured grab time (with a little slack for latency).
        if now - (state.lastPayout or 0) < o.seconds * 1000 * 0.8 then return { ok = false, error = 'too_fast' } end
        local paid, text = grant(src, o)
        if not paid then
            state.busy = nil
            return { ok = false, error = 'could_not_pay' }
        end
        state.left = state.left - 1
        state.lastPayout, state.touched = now, now
        Audit.Log(src, 'trolley_grab', 'ok', nil, { scenario = sid, trolley = oid, got = text })
        if state.left <= 0 then
            state.busy = nil
            deplete(sid, s, o)
        end
        return { ok = true, left = state.left, got = text }
    end

    return { ok = false, error = 'bad_action' }
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastTouch[src] = nil
    for _, s in pairs(Scenarios.Live) do
        for _, state in pairs(s.trolleys or {}) do
            if state.busy == src then state.busy = nil end
        end
    end
end)
