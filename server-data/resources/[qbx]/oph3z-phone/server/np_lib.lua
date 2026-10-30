-- Shared helpers for the NoPixel-style apps' server code. Everything here derives identity from
-- the calling source; nothing trusts ids sent by the client.
NP = NP or {}

local function fw() return Config.Framework end
local function isQbox() return fw() == 'qbox' end
local function isQB() return fw() == 'qb' or fw() == 'oldqb' end
local function isESX() return fw() == 'esx' or fw() == 'oldesx' end

function NP.cid(src)
    return src and GetIdentifier(src) or nil
end

function NP.name(src)
    local first, last = GetCharName(src)
    local n = (('%s %s'):format(first or '', last or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if n == '' then
        local cid = NP.cid(src)
        local p = cid and DB.Player(cid)
        n = (p and p.name) or ('Citizen ' .. tostring(src))
    end
    return n
end

function NP.number(cid)
    return cid and DB.NumberOf(cid) or nil
end

function NP.srcOf(cid)
    return cid and GetSourceById(cid) or nil
end

function NP.clean(value, maxLen)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[%c]', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and #value > maxLen then value = value:sub(1, maxLen) end
    return value
end

function NP.cleanText(value, maxLen)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('\r', ''):gsub('[%z\1-\8\11\12\14-\31]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and #value > maxLen then value = value:sub(1, maxLen) end
    return value
end

function NP.url(value)
    if type(value) == 'string' and value:match('^https?://') and #value <= 512 then return value end
    return nil
end

-- { name, label, grade, gradeLabel, isboss, onduty } or nil
function NP.job(src)
    if isQbox() or isQB() then
        local p = isQbox() and exports.qbx_core:GetPlayer(src) or frameworkObject.Functions.GetPlayer(tonumber(src))
        local job = p and p.PlayerData and p.PlayerData.job
        if not job then return nil end
        local grade = type(job.grade) == 'table' and job.grade or {}
        return {
            name = job.name, label = job.label or job.name,
            grade = tonumber(grade.level) or 0, gradeLabel = grade.name or '',
            isboss = job.isboss == true or grade.isboss == true, onduty = job.onduty == true,
        }
    elseif isESX() then
        local xp = frameworkObject.GetPlayerFromId(tonumber(src))
        local job = xp and ((xp.getJob and xp.getJob()) or xp.job)
        if not job then return nil end
        return {
            name = job.name, label = job.label or job.name, grade = tonumber(job.grade) or 0,
            gradeLabel = job.grade_label or '', isboss = job.grade_name == 'boss', onduty = true,
        }
    end
    return nil
end

-- jobs: list of job names, or map { jobName = minGrade }. Empty / nil list = nobody.
function NP.hasJob(src, jobs)
    if type(jobs) ~= 'table' then return false end
    local job = NP.job(src)
    if not job or not job.name then return false end
    for k, v in pairs(jobs) do
        if type(k) == 'number' and v == job.name then return true end
        if type(k) == 'string' and k == job.name and job.grade >= (tonumber(v) or 0) then return true end
    end
    return false
end

function NP.isAdmin(src)
    return IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'command')
end

function NP.coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- nearest other player within maxDist metres: src, distance
function NP.nearest(src, maxDist)
    local me = NP.coords(src)
    if not me then return nil end
    local best, bestDist = nil, maxDist or 3.0
    for _, id in ipairs(GetPlayers()) do
        local other = tonumber(id)
        if other ~= tonumber(src) then
            local c = NP.coords(other)
            if c then
                local d = #(me - c)
                if d <= bestDist then best, bestDist = other, d end
            end
        end
    end
    return best, bestDist
end

function NP.notify(cid, app, title, body, route)
    if not cid or not Notif then return end
    Notif.Push(cid, { app = app, title = title, body = body, route = route or { app = app } })
end

-- Bank movements that also appear in the Bank app. Returns true on success.
function NP.charge(cid, amount, party, note)
    amount = math.floor(tonumber(amount) or 0)
    if not cid or amount <= 0 then return false end
    if Bank.Get(cid) < amount then return false end
    if not Bank.Remove(cid, amount, 'phone-' .. tostring(party or 'app')) then return false end
    if Wallet and Wallet.Log then Wallet.Log(cid, { kind = 'sent', amount = amount, party = party, note = note }) end
    return true
end

function NP.pay(cid, amount, party, note)
    amount = math.floor(tonumber(amount) or 0)
    if not cid or amount <= 0 then return false end
    if not Bank.Add(cid, amount, 'phone-' .. tostring(party or 'app')) then return false end
    if Wallet and Wallet.Log then Wallet.Log(cid, { kind = 'received', amount = amount, party = party, note = note }) end
    return true
end

-- simple per-player rate limit: returns true when allowed
local rl = {}
function NP.rate(src, key, seconds)
    local k = tostring(src) .. ':' .. key
    local now = GetGameTimer()
    if rl[k] and now - rl[k] < (seconds * 1000) then return false end
    rl[k] = now
    return true
end

AddEventHandler('playerDropped', function()
    local prefix = tostring(source) .. ':'
    for k in pairs(rl) do
        if k:sub(1, #prefix) == prefix then rl[k] = nil end
    end
end)

-- RegisterCallback with the np prefix + a guard that the caller has a character.
function NP.cb(name, fn)
    RegisterCallback('oph3z-phone:server:np:' .. name, function(src, data)
        local cid = NP.cid(src)
        if not cid then return { ok = false, reason = 'auth' } end
        return fn(src, cid, type(data) == 'table' and data or {})
    end)
end

function NP.now() return os.time() end
