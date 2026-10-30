-- Dispatch board: on-duty roster (Police / EMS panels), the dispatch log
-- (duty changes, attaches, operator messages) and radio channel grouping.
-- Everything here is pushed only to on-duty members of Config.Jobs.

-- Framework: qbx_core exports directly; qb-core only as a fallback.
local getPlayers, getPlayer
if GetResourceState('qbx_core') ~= 'missing' then
    getPlayers = function() return exports.qbx_core:GetQBPlayers() end
    getPlayer = function(src) return exports.qbx_core:GetPlayer(src) end
else
    local ok, QBCore = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and QBCore then
        getPlayers = function() return QBCore.Functions.GetQBPlayers() end
        getPlayer = function(src) return QBCore.Functions.GetPlayer(src) end
    end
end

local cfg = Config.Board or {}
if cfg.Enabled == false or not getPlayers then return end

local LOG_SIZE = cfg.LogSize or 100
local log = {}
local logId = 0
local roster = {}
local lastRosterJson = nil
local onDuty = {}   -- src -> { name, callsign } as of the last tick

local function jobAllowed(job)
    if not job then return false end
    return lib.table.contains(Config.Jobs, JobType(job)) or lib.table.contains(Config.Jobs, job.name)
end

local function isMember(player)
    local job = player and player.PlayerData and player.PlayerData.job
    return jobAllowed(job) and (Config.OnDutyOnly == false or job.onduty)
end

-- "Chad Thunder" -> "C. Thunder", the way the log names people.
local function shortName(charinfo)
    if not charinfo then return 'Unknown' end
    local first = charinfo.firstname or ''
    local last = charinfo.lastname or ''
    if first == '' then return last end
    return first:sub(1, 1) .. '. ' .. last
end

local function pushToMembers(event, payload)
    for src, player in pairs(getPlayers()) do
        if isMember(player) then
            TriggerClientEvent(event, src, payload)
        end
    end
end

local function addLog(entry)
    logId = logId + 1
    entry.id = logId
    entry.time = os.time() * 1000
    log[#log + 1] = entry
    if #log > LOG_SIZE then table.remove(log, 1) end
    pushToMembers('ps-dispatch:client:boardLog', entry)
end

local VEHICLE_KIND = {
    automobile = 'car', bike = 'bike', heli = 'heli', plane = 'plane',
    boat = 'boat', submarine = 'boat', train = 'car', trailer = 'car',
}

-- citizenid -> call id, from the live call list in server/main.lua.
local function callByCitizen()
    local map = {}
    local calls = DispatchCallsRef and DispatchCallsRef() or {}
    for i = 1, #calls do
        for _, unit in ipairs(calls[i].units or {}) do
            if unit.citizenid then map[unit.citizenid] = calls[i].id end
        end
    end
    return map
end

local function buildRoster()
    local out = {}
    local onCall = callByCitizen()
    for src, player in pairs(getPlayers()) do
        if isMember(player) then
            local pd = player.PlayerData
            local job = pd.job
            local ped = GetPlayerPed(src)
            local veh = ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
            local radio = Player(src).state.radioChannel
            out[#out + 1] = {
                src = src,
                citizenid = pd.citizenid,
                callsign = pd.metadata and pd.metadata.callsign or nil,
                name = shortName(pd.charinfo),
                fullName = pd.charinfo and ((pd.charinfo.firstname or '') .. ' ' .. (pd.charinfo.lastname or '')) or 'Unknown',
                dept = JobType(job) == 'ems' and 'ems' or 'leo',
                job = job.label or job.name,
                grade = job.grade and job.grade.name or nil,
                command = job.isboss == true,
                callId = onCall[pd.citizenid],
                vehicle = veh ~= 0 and (VEHICLE_KIND[GetVehicleType(veh)] or 'car') or nil,
                radio = (tonumber(radio) or 0) > 0 and radio or nil,
            }
        end
    end
    table.sort(out, function(a, b)
        return (tonumber(a.callsign) or 9e9) < (tonumber(b.callsign) or 9e9)
    end)
    return out
end

-- One tick: rebuild the roster, log anyone who went on/off duty since the
-- last tick, and push the roster only when it actually changed.
local function tick()
    roster = buildRoster()

    local now = {}
    for _, u in ipairs(roster) do
        now[u.src] = { name = u.name, callsign = u.callsign }
        if not onDuty[u.src] then
            addLog({ kind = 'duty', callsign = u.callsign, text = u.name .. ' is 10-41 (On Duty)' })
        end
    end
    for src, was in pairs(onDuty) do
        if not now[src] then
            local gone = GetPlayerName(src) == nil
            addLog({ kind = 'duty', callsign = was.callsign, text = was.name .. (gone and ' disconnected (Off Duty)' or ' is 10-42 (Off Duty)') })
        end
    end
    onDuty = now

    local encoded = json.encode(roster)
    if encoded ~= lastRosterJson then
        lastRosterJson = encoded
        pushToMembers('ps-dispatch:client:boardRoster', roster)
    end
end

CreateThread(function()
    -- Seed silently: people already on duty when the resource starts are not
    -- "coming on duty", so they should not flood the log.
    roster = buildRoster()
    for _, u in ipairs(roster) do onDuty[u.src] = { name = u.name, callsign = u.callsign } end
    lastRosterJson = json.encode(roster)
    while true do
        Wait(cfg.RefreshMs or 3000)
        tick()
    end
end)

lib.callback.register('ps-dispatch:callback:getBoard', function(source)
    if not isMember(getPlayer(source)) then return nil end
    return { roster = roster, log = log }
end)

-- Position of another unit, for the roster's "locate" button.
lib.callback.register('ps-dispatch:callback:unitPosition', function(source, target)
    if not isMember(getPlayer(source)) then return nil end
    target = tonumber(target)
    if not target or not isMember(getPlayer(target)) then return nil end
    local c = GetEntityCoords(GetPlayerPed(target))
    return { x = c.x, y = c.y, z = c.z }
end)

-- Operator messages typed into the log panel.
local lastMessage = {}
RegisterNetEvent('ps-dispatch:server:boardMessage', function(text)
    local src = source
    local player = getPlayer(src)
    if not isMember(player) then return end
    if type(text) ~= 'string' then return end
    text = text:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return end
    local t = os.clock()
    if lastMessage[src] and t - lastMessage[src] < (cfg.MessageCooldown or 1.5) then return end
    lastMessage[src] = t
    local pd = player.PlayerData
    addLog({
        kind = 'msg',
        callsign = pd.metadata and pd.metadata.callsign or nil,
        author = shortName(pd.charinfo),
        text = text:sub(1, cfg.MessageLength or 200),
    })
end)

-- Attach/detach lines. main.lua owns the actual state change; these only
-- narrate it, using the server's own record of who the sender is.
local function callLabel(id)
    local calls = DispatchCallsRef and DispatchCallsRef() or {}
    for i = 1, #calls do
        if calls[i].id == id then return ('#%s %s'):format(id, calls[i].message or '') end
    end
    return '#' .. tostring(id)
end

local function narrate(src, verb, id)
    if cfg.LogAttach == false then return end
    local player = getPlayer(src)
    if not isMember(player) then return end
    local pd = player.PlayerData
    addLog({ kind = 'call', callsign = pd.metadata and pd.metadata.callsign or nil, text = shortName(pd.charinfo) .. ' ' .. verb .. ' ' .. callLabel(id) })
end

RegisterNetEvent('ps-dispatch:server:attach', function(id) narrate(source, 'attached to', id) end)
RegisterNetEvent('ps-dispatch:server:detach', function(id) narrate(source, 'detached from', id) end)

AddEventHandler('playerDropped', function()
    lastMessage[source] = nil
end)
