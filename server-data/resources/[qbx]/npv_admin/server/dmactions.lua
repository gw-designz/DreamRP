DmActions = {}

local running = {}   -- list of { id, label, endsAt, stop = fn }
local nextRun = 1
local spawnedVehicles = {}
local MAX_VEHICLES = 20

local function ownedByScenario(ent)
    for _, s in pairs(Scenarios.Live) do
        for _, e in pairs(s.entities) do
            if e == ent then return true end
        end
    end
    return false
end

local function targets(src, coords, who)
    local list = {}
    if who.mode == 'everyone' then
        for _, id in ipairs(GetPlayers()) do list[#list + 1] = tonumber(id) end
    elseif who.mode == 'one' then
        local id = Players.Resolve(who.target)
        if id then list[1] = id end
    else
        local r = Utils.Num(who.radius, 2, 500) or Config.DefaultActionRange
        for _, id in ipairs(GetPlayers()) do
            id = tonumber(id)
            local ped = GetPlayerPed(id)
            if ped ~= 0 then
                local c = GetEntityCoords(ped)
                if Utils.Dist({ x = c.x, y = c.y, z = c.z }, coords) <= r then list[#list + 1] = id end
            end
        end
    end
    return list
end

local function toClients(list, name, payload)
    for _, id in ipairs(list) do TriggerClientEvent('npv_admin:client:dmaction', id, name, payload) end
end

local function seconds(p, default, max)
    return Utils.Num(p.seconds or default, 1, max or 120) or default
end

local function addRunning(label, duration, stop)
    local id = nextRun
    nextRun = nextRun + 1
    running[#running + 1] = { id = id, label = label, endsAt = GetGameTimer() + duration * 1000, stop = stop }
    SetTimeout(duration * 1000, function()
        for i, r in ipairs(running) do
            if r.id == id then
                table.remove(running, i)
                if stop then stop() end
                break
            end
        end
    end)
end

local A = {}

function A.narrate(src, coords, list, p)
    local text = Utils.Clean(p.text, 200)
    if not text or text == '' then return false, 'bad_text' end
    toClients(list, 'narrate', { text = text, seconds = seconds(p, 6, 30) })
    return true
end
function A.flash(_, _, list) toClients(list, 'flash', {}) return true end
function A.black_screen(_, _, list, p) toClients(list, 'black', { seconds = seconds(p, 4, 30) }) return true end
function A.blur(_, _, list, p) toClients(list, 'blur', { seconds = seconds(p, 5, 30) }) return true end
function A.shake(_, _, list, p) toClients(list, 'shake', { seconds = seconds(p, 3, 30) }) return true end
function A.knock_down(_, _, list, p) toClients(list, 'knockdown', { seconds = seconds(p, 5, 30) }) return true end
function A.freeze(_, _, list, p)
    local d = seconds(p, 10, 300)
    toClients(list, 'freeze', { on = true })
    addRunning('Freeze', d, function() toClients(list, 'freeze', { on = false }) end)
    return true
end
function A.heal(_, _, list) for _, id in ipairs(list) do TriggerClientEvent('npv_admin:client:heal', id) end return true end
function A.revive(_, _, list) for _, id in ipairs(list) do TriggerClientEvent('npv_admin:client:revive', id, Config.ReviveEvent) end return true end
function A.bring_to_me(src, _, list)
    local sped = GetPlayerPed(src)
    local c = GetEntityCoords(sped)
    for _, id in ipairs(list) do
        if id ~= src and Perms.CanTarget(src, id) then SetEntityCoords(GetPlayerPed(id), c.x, c.y, c.z, false, false, false, false) end
    end
    return true
end
function A.give_item(_, _, list, p)
    local item, count = Utils.Str(p.item, 50), Utils.Num(p.count or 1, 1, 1000)
    if not item or not item:match('^[%w_%-]+$') or not count then return false, 'bad_item' end
    if Config.Inventory ~= 'ox_inventory' then return false, 'inventory_disabled' end
    for _, id in ipairs(list) do exports.ox_inventory:AddItem(id, item, math.floor(count)) end
    return true
end
function A.lightning(_, _, list) toClients(list, 'lightning', {}) return true end
function A.blackout(_, _, list, p)
    local minutes = Utils.Num(p.minutes or 2, 0, 30) or 2
    GlobalState.npvBlackout = true
    TriggerClientEvent('npv_admin:client:dmaction', -1, 'blackout', { on = true })
    if minutes > 0 then
        addRunning('Blackout', minutes * 60, function()
            GlobalState.npvBlackout = false
            TriggerClientEvent('npv_admin:client:dmaction', -1, 'blackout', { on = false })
        end)
    end
    return true
end
function A.police_alert(_, coords, _, p)
    Config.PoliceAlert(vec3(coords.x, coords.y, coords.z), Utils.Clean(p.text, 100) or 'Staff-triggered alert')
    return true
end
function A.spawn_vehicle(_, coords, _, p)
    local model = Utils.Str(p.model, 40)
    if not model or not model:match('^[%w_]+$') then return false, 'bad_model' end
    for i = #spawnedVehicles, 1, -1 do
        if not DoesEntityExist(spawnedVehicles[i]) then table.remove(spawnedVehicles, i) end
    end
    if #spawnedVehicles >= MAX_VEHICLES then return false, 'vehicle_limit' end
    local veh = CreateVehicleServerSetter(joaat(model), 'automobile', coords.x, coords.y, coords.z, coords.h or 0.0)
    if not veh or veh == 0 then return false, 'could_not_spawn' end
    spawnedVehicles[#spawnedVehicles + 1] = veh
    return true
end
function A.clear_area(_, coords, _, p)
    local radius = Utils.Num(p.radius or 20, 2, 100) or 20
    local n = 0
    local function inRange(e)
        local c = GetEntityCoords(e)
        return #(c - vec3(coords.x, coords.y, coords.z)) <= radius
    end
    for _, v in ipairs(GetAllVehicles()) do
        if inRange(v) and not ownedByScenario(v) then
            local occupied = false
            for seat = -1, 6 do
                local ped = GetPedInVehicleSeat(v, seat)
                if ped ~= 0 and IsPedAPlayer(ped) then occupied = true break end
            end
            if not occupied then DeleteEntity(v) n = n + 1 end
        end
    end
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) and inRange(ped) and not ownedByScenario(ped) then DeleteEntity(ped) n = n + 1 end
    end
    return true, ('Removed %d'):format(n)
end
-- Explosion kinds -> GTA explosion type ids.
local EXPLOSION_KINDS = {
    grenade = 0, molotov = 3, rocket = 4, car_blast = 7, flame_jet = 12, water_jet = 13,
    smoke = 20, tear_gas = 21, flare = 22, gas_tank = 23,
}

---One client creates networked effects (explosions, fires); running them on every client would
---multiply them. Prefer the staff member, otherwise the first affected player, otherwise anyone.
local function effectClient(src, list)
    if src and src > 0 then return src end
    if list and list[1] then return list[1] end
    local first = GetPlayers()[1]
    return first and tonumber(first) or nil
end

function A.explosion(src, coords, list, p)
    local kind = EXPLOSION_KINDS[p.kind or 'grenade']
    if not kind then return false, 'bad_kind' end
    local size = Utils.Num(p.size or 1.0, 0.1, 3.0) or 1.0
    local count = math.floor(Utils.Num(p.count or 1, 1, 10) or 1)
    local spread = Utils.Num(p.spread or 0, 0, 20) or 0
    local client = effectClient(src, list)
    if not client then return false, 'no_client' end
    TriggerClientEvent('npv_admin:client:dmaction', client, 'explosion', { coords = coords, kind = kind, size = size, count = count, spread = spread })
    return true
end

function A.fire(src, coords, list)
    local client = effectClient(src, list)
    if not client then return false, 'no_client' end
    TriggerClientEvent('npv_admin:client:dmaction', client, 'fire', { coords = coords })
    return true
end

-- Sounds the DM can play at the spot (names live in Config.DmSounds so the client never trusts the page).
function A.sound(_, coords, list, p)
    local key = Utils.Str(p.sound or 'alarm', 20)
    if not key or not Config.DmSounds[key] then return false, 'bad_sound' end
    toClients(list, 'sound', { key = key, coords = coords })
    return true
end

-- NPC waves: armed NPCs that go for the nearest player. Tracked so they can be cleared.
local WAVE_MODELS = { gang = 'g_m_y_ballaeast_01', cartel = 'g_m_y_mexgoon_01', swat = 's_m_y_swat_01', cop = 's_m_y_cop_01' }
local WAVE_WEAPONS = { pistol = 'WEAPON_PISTOL', smg = 'WEAPON_SMG', shotgun = 'WEAPON_PUMPSHOTGUN', rifle = 'WEAPON_CARBINERIFLE' }
local MAX_WAVE_PEDS = 30
local wavePeds = {}

local function pruneWaves()
    for i = #wavePeds, 1, -1 do
        if not DoesEntityExist(wavePeds[i]) then table.remove(wavePeds, i) end
    end
end

function A.npc_wave(_, coords, _, p)
    local model = WAVE_MODELS[p.model or 'gang']
    local weapon = WAVE_WEAPONS[p.weapon or 'pistol']
    if not model or not weapon then return false, 'bad_wave' end
    local count = math.floor(Utils.Num(p.count or 3, 1, 10) or 3)
    local spread = Utils.Num(p.spread or 5, 1, 20) or 5
    pruneWaves()
    if #wavePeds + count > MAX_WAVE_PEDS then return false, 'wave_limit' end
    for _ = 1, count do
        local ox, oy = (math.random() * 2 - 1) * spread, (math.random() * 2 - 1) * spread
        local ped = CreatePed(4, joaat(model), coords.x + ox, coords.y + oy, coords.z, math.random(0, 359) + 0.0, true, true)
        if ped and ped ~= 0 then
            GiveWeaponToPed(ped, joaat(weapon), 250, false, true)
            SetEntityDistanceCullingRadius(ped, 800.0)
            Entity(ped).state:set('npv_alert', GetGameTimer(), true) -- client owner makes it attack
            wavePeds[#wavePeds + 1] = ped
        end
    end
    return true, ('Spawned %d NPC(s)'):format(count)
end

function A.clear_waves()
    local n = 0
    for _, ped in ipairs(wavePeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) n = n + 1 end
    end
    wavePeds = {}
    return true, ('Removed %d NPC(s)'):format(n)
end

DmActions.Handlers = A

function DmActions.Run(src, payload)
    if type(payload) ~= 'table' or type(A[payload.action]) ~= 'function' then return false, 'unknown_action' end
    local coords = Utils.ValidCoords(payload.coords)
    if not coords then return false, 'bad_coords' end
    local who = type(payload.who) == 'table' and payload.who or { mode = 'near' }
    local params = type(payload.params) == 'table' and payload.params or {}
    local list = targets(src, coords, who)
    local ok, res, msg = pcall(A[payload.action], src, coords, list, params)
    if not ok then print('^1[npv_admin] dm action error: ' .. tostring(res) .. '^7') return false, 'server_error' end
    Audit.Log(src, 'dm_' .. payload.action, res and 'ok' or 'failed', nil, { who = who.mode, count = #list })
    return res, msg
end

function DmActions.Running()
    local out, now = {}, GetGameTimer()
    for _, r in ipairs(running) do
        out[#out + 1] = { id = r.id, label = r.label, remaining = math.max(0, math.floor((r.endsAt - now) / 1000)) }
    end
    return out
end

function DmActions.Stop(id)
    for i, r in ipairs(running) do
        if r.id == id then
            table.remove(running, i)
            if r.stop then r.stop() end
            return true
        end
    end
    return false
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, v in ipairs(spawnedVehicles) do if DoesEntityExist(v) then DeleteEntity(v) end end
    for _, ped in ipairs(wavePeds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    GlobalState.npvBlackout = false
end)
