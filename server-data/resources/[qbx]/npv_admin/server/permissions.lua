Perms = {}

local rankCache = {} -- [src] = { rank = <entry|false>, at = ms }
local CACHE_MS = 30000

local function holdsGroup(src, group)
    local ok, has = pcall(function() return exports.qbx_core:HasPermission(src, group) end)
    if ok and has then return true end
    return IsPlayerAceAllowed(src, ('group.%s'):format(group))
end

---Highest rank the player holds, or nil.
function Perms.GetRank(src)
    local c = rankCache[src]
    if c and GetGameTimer() - c.at < CACHE_MS then return c.rank or nil end
    local found = false
    for i = 1, #Config.Ranks do -- ordered highest first
        local r = Config.Ranks[i]
        if holdsGroup(src, r.group) then found = r break end
    end
    rankCache[src] = { rank = found, at = GetGameTimer() }
    return found or nil
end

function Perms.Level(src)
    local r = Perms.GetRank(src)
    return r and r.level or 0
end

function Perms.Has(src, perm)
    local r = Perms.GetRank(src)
    if not r then return false end
    if r.perms == '*' then return true end
    for i = 1, #r.perms do
        if r.perms[i] == perm then return true end
    end
    return false
end

---Permission list for the NUI (UI hint only; the server re-checks every call).
function Perms.List(src)
    local r = Perms.GetRank(src)
    if not r then return {} end
    if r.perms == '*' then
        return { '*' }
    end
    return r.perms
end

---A staff member may act on a target only if they outrank them (or are peer-level and trusted).
function Perms.CanTarget(src, target)
    if src == target then return true end
    local mine, theirs = Perms.Level(src), Perms.Level(target)
    if theirs == 0 then return true end
    if mine > theirs then return true end
    return mine == theirs and mine >= Config.PeerActionLevel
end

---Sliding window rate limit. Returns true when the call is allowed.
local buckets = {}
function Perms.RateOk(src)
    local now = GetGameTimer()
    local b = buckets[src]
    if not b or now - b.start > 60000 then
        b = { start = now, n = 0 }
        buckets[src] = b
    end
    b.n = b.n + 1
    return b.n <= Config.Limits.ActionsPerMinute
end

AddEventHandler('playerDropped', function()
    local src = source
    rankCache[src] = nil
    buckets[src] = nil
end)

-- Group changes (txAdmin, qbx commands) should take effect without waiting for the cache.
RegisterNetEvent('npv_admin:server:refreshRank', function()
    rankCache[source] = nil
end)
