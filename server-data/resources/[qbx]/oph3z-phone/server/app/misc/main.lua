-- Roach (dark-web browser), Grey Book (people directory) and Scoot-E (scooter rental).

-- ---------------------------------------------------------------- shared
local function hasItem(src, item)
    if not item or item == '' then return true end
    local inv = Config.Inventory
    local ok, res = pcall(function()
        if inv == 'ox_inventory' then return (exports.ox_inventory:GetItemCount(src, item) or 0) > 0 end
        if inv == 'qs-inventory' then return (exports['qs-inventory']:GetItemTotalAmount(src, item) or 0) > 0 end
        if inv == 'codem-inventory' then return exports['codem-inventory']:CheckItemValid(src, item, 1) and true or false end
        if Config.Framework == 'qbox' then return (exports.qbx_core:GetPlayer(src).Functions.GetItemByName(item)) ~= nil end
        if frameworkObject and frameworkObject.Functions then return frameworkObject.Functions.GetPlayer(src).Functions.GetItemByName(item) ~= nil end
        local xp = frameworkObject and frameworkObject.GetPlayerFromId and frameworkObject.GetPlayerFromId(src)
        local it = xp and xp.getInventoryItem and xp.getInventoryItem(item)
        return it ~= nil and ((it.count or it.amount or 0) > 0)
    end)
    return ok and res == true
end

-- ---------------------------------------------------------------- Roach
local ROACH = Config.Roach or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_roach` (
    `cid` VARCHAR(64) NOT NULL,
    `bookmarks` TEXT DEFAULT NULL,
    `notes` TEXT DEFAULT NULL,
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

-- "Name", "name.onion", "http://name.onion/" and "//name.onion" all become "name.onion".
-- A path is kept ("name.onion/about") so sites can have sub-pages.
local function normAddr(a)
    a = tostring(a or ''):lower():gsub('%s+', ''):gsub('^%a+://', ''):gsub('^//', ''):gsub('/+$', '')
    local host, path = a:match('^([^/]*)(.*)$')
    if host ~= '' and not host:find('%.') then host = host .. '.onion' end
    return (host .. path):sub(1, 64)
end

-- only *.onion hosts are reachable on this network
local function validAddr(a)
    local host = a:match('^([^/]+)')
    return host ~= nil and host:match('^[a-z0-9][a-z0-9%-]*%.onion$') ~= nil and #host <= 40
end

-- Sites added at runtime by other resources (exports below) take priority over Config.Roach.Sites,
-- which take priority over pages players host from the browser (see "hosting" below).
local runtimeSites = {}
local hosted = {} -- address -> { address, host, owner, ownerName, title, body, hints, updated }

local function fixedSiteFor(addr)
    return runtimeSites[addr] or (ROACH.Sites or {})[addr]
end

local function siteFor(addr)
    return fixedSiteFor(addr) or hosted[addr]
end

exports('RegisterRoachSite', function(address, def)
    local addr = normAddr(address)
    if not validAddr(addr) or type(def) ~= 'table' then return false end
    runtimeSites[addr] = def
    return true
end)

exports('RemoveRoachSite', function(address)
    runtimeSites[normAddr(address)] = nil
    return true
end)

local function roachRow(cid)
    local row = Sql.Single('SELECT `bookmarks`, `notes` FROM `oph3z_phone_np_roach` WHERE `cid` = ?', { cid })
    return { bookmarks = row and Sql.Decode(row.bookmarks, {}) or {}, notes = row and row.notes or '' }
end

-- ---- hosting: players publish their own pages from the browser (⋮ › Host a Site)
local HOSTING = ROACH.Hosting or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_roach_sites` (
    `address` VARCHAR(64) NOT NULL,
    `host` VARCHAR(40) NOT NULL,
    `owner` VARCHAR(64) NOT NULL,
    `owner_name` VARCHAR(64) DEFAULT NULL,
    `title` VARCHAR(40) NOT NULL,
    `body` TEXT DEFAULT NULL,
    `hints` TEXT DEFAULT NULL,
    `created_at` INT NOT NULL DEFAULT 0,
    `updated_at` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`address`),
    KEY `host` (`host`),
    KEY `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function hostOf(addr) return addr:match('^([^/]+)') end

CreateThread(function()
    Sql.Wait()
    for _, row in ipairs(Sql.Query('SELECT * FROM `oph3z_phone_np_roach_sites`')) do
        hosted[row.address] = {
            address = row.address, host = row.host, owner = row.owner, ownerName = row.owner_name,
            title = row.title, body = row.body or '', hints = Sql.Decode(row.hints, {}), updated = tonumber(row.updated_at) or 0,
        }
    end
end)

local function isRoachAdmin(src)
    return NP.isAdmin(src) or (HOSTING.AdminAce and IsPlayerAceAllowed(src, HOSTING.AdminAce)) or false
end

local function canHost(src)
    if HOSTING.Enabled == false then return false end
    return HOSTING.PlayersCanHost ~= false or isRoachAdmin(src)
end

-- hosts taken by Config.Roach.Sites / RegisterRoachSite pages (any page on that host)
local function fixedHost(host)
    for addr in pairs(runtimeSites) do if hostOf(addr) == host then return true end end
    for addr in pairs(ROACH.Sites or {}) do if hostOf(addr) == host then return true end end
    return false
end

local function hostOwner(host)
    for _, p in pairs(hosted) do
        if p.host == host then return p.owner, p.ownerName end
    end
    return nil
end

local function countFor(cid, host)
    local hosts, pages = {}, 0
    for _, p in pairs(hosted) do
        if p.owner == cid then hosts[p.host] = true end
        if host and p.host == host then pages = pages + 1 end
    end
    local n = 0
    for _ in pairs(hosts) do n = n + 1 end
    return n, pages
end

local function pageOut(p)
    return { address = p.address, title = p.title, body = p.body, hints = p.hints, owner = p.ownerName, updated = p.updated }
end

NP.cb('roach:state', function(src, cid)
    if not hasItem(src, ROACH.RequiredItem) then return { ok = false, reason = 'noitem' } end
    Sql.Wait()
    local r = roachRow(cid)
    return {
        ok = true, bookmarks = r.bookmarks, notes = r.notes, home = ROACH.HomePage or 'roach.onion',
        hosting = canHost(src) and {
            admin = isRoachAdmin(src),
            cost = math.max(0, math.floor(tonumber(HOSTING.Cost) or 0)),
            maxSites = tonumber(HOSTING.MaxSitesPerPlayer) or 3,
            maxPages = tonumber(HOSTING.MaxPagesPerSite) or 10,
            maxBody = tonumber(HOSTING.MaxBodyLength) or 4000,
        } or false,
    }
end)

-- my pages (admins: every hosted page)
NP.cb('roach:sites', function(src, cid)
    if not canHost(src) then return { ok = false, reason = 'disabled' } end
    local admin = isRoachAdmin(src)
    local list = {}
    for _, p in pairs(hosted) do
        if p.owner == cid or admin then
            local out = pageOut(p)
            out.mine = p.owner == cid
            list[#list + 1] = out
        end
    end
    table.sort(list, function(a, b) return a.address < b.address end)
    return { ok = true, sites = list }
end)

-- create or update a page. data: { address, title, body, hints = { 'comment', ... } }
NP.cb('roach:publish', function(src, cid, data)
    if not hasItem(src, ROACH.RequiredItem) then return { ok = false, reason = 'noitem' } end
    if not canHost(src) then return { ok = false, reason = 'disabled' } end
    if not NP.rate(src, 'roach:publish', 2) then return { ok = false, reason = 'slow' } end
    local admin = isRoachAdmin(src)
    local addr = normAddr(data.address)
    if not validAddr(addr) then return { ok = false, reason = 'address' } end
    local host = hostOf(addr)
    if fixedSiteFor(addr) or fixedHost(host) then return { ok = false, reason = 'taken' } end
    local homeHost = hostOf(normAddr(ROACH.HomePage or 'roach.onion'))
    if host == homeHost and not admin then return { ok = false, reason = 'reserved' } end

    local existing = hosted[addr]
    local owner, hostOwnerName = hostOwner(host)
    if owner and owner ~= cid and not admin then return { ok = false, reason = 'taken' } end

    local title = NP.clean(data.title, 40)
    if title == '' then return { ok = false, reason = 'title' } end
    local body = NP.cleanText(data.body, tonumber(HOSTING.MaxBodyLength) or 4000)
    local hints = {}
    for _, h in ipairs(type(data.hints) == 'table' and data.hints or {}) do
        local c = NP.clean(h, 160)
        if c ~= '' then hints[#hints + 1] = c end
        if #hints >= 10 then break end
    end

    local newHost = owner == nil
    if not existing and not admin then
        local hosts, pages = countFor(cid, host)
        local maxSites = tonumber(HOSTING.MaxSitesPerPlayer) or 3
        local maxPages = tonumber(HOSTING.MaxPagesPerSite) or 10
        if newHost and maxSites > 0 and hosts >= maxSites then return { ok = false, reason = 'limit' } end
        if not newHost and maxPages > 0 and pages >= maxPages then return { ok = false, reason = 'pages' } end
        local cost = math.floor(tonumber(HOSTING.Cost) or 0)
        if newHost and cost > 0 and not NP.charge(cid, cost, 'Roach', 'Address ' .. host) then
            return { ok = false, reason = 'funds' }
        end
    end

    local now = os.time()
    local pageOwner = existing and existing.owner or owner or cid
    local ownerName = (existing and existing.ownerName) or (pageOwner == cid and NP.name(src)) or hostOwnerName
    Sql.Execute([[INSERT INTO `oph3z_phone_np_roach_sites` (`address`, `host`, `owner`, `owner_name`, `title`, `body`, `hints`, `created_at`, `updated_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `title` = VALUES(`title`), `body` = VALUES(`body`), `hints` = VALUES(`hints`), `updated_at` = VALUES(`updated_at`)]],
        { addr, host, pageOwner, ownerName, title, body, json.encode(hints), now, now })
    hosted[addr] = { address = addr, host = host, owner = pageOwner, ownerName = ownerName, title = title, body = body, hints = hints, updated = now }
    return { ok = true, address = addr }
end)

NP.cb('roach:unpublish', function(src, cid, data)
    local addr = normAddr(data.address)
    local p = hosted[addr]
    if not p then return { ok = false, reason = 'missing' } end
    if p.owner ~= cid and not isRoachAdmin(src) then return { ok = false, reason = 'owner' } end
    Sql.Execute('DELETE FROM `oph3z_phone_np_roach_sites` WHERE `address` = ?', { addr })
    hosted[addr] = nil
    return { ok = true }
end)

-- ---- page source ("View Page Source")
-- Configured sites: site.source (raw text) wins; otherwise HTML is generated from title/body and
-- site.hints (list of strings) are added as HTML comments. Unknown addresses get a decoy source
-- full of fake leads to other dead addresses. Decoys are deterministic per address (and per
-- Config.Roach.DecoySeed), so the same address always shows the same source.

local function esc(t)
    return (tostring(t or ''):gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

-- small deterministic PRNG (independent of math.random)
-- (Park–Miller in doubles: exact below 2^53, so it gives the same sequence on any Lua build)
local function rng(seedText)
    local h = 7.0
    for i = 1, #seedText do
        h = (h * 31.0 + seedText:byte(i)) % 2147483647.0
    end
    local state = h > 0 and h or 1.0
    return function(n)
        state = (state * 48271.0) % 2147483647.0
        return math.floor(state) % n + 1
    end
end

local ALPHA = 'abcdefghijklmnopqrstuvwxyz'
local ALNUM = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

local function randStr(r, set, len)
    local out = {}
    for i = 1, len do
        local k = r(#set)
        out[i] = set:sub(k, k)
    end
    return table.concat(out)
end

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64(data)
    return ((data:gsub('.', function(x)
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
        return B64:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

local DECOY_HEAD = {
    '<script>!function(){var d=document;d.addEventListener("visibilitychange",function(){})}();</script>',
    '<meta name="x-resolved-to" content="{o}">',
    '<script>var cfg={salt:"{s16}",iter:{n2},ttl:0,seed:{n4}};</script>',
    '<!-- 301 moved permanently -> {o} -->',
    '<style>body{opacity:.98}img,video{display:none}</style>',
    '<!-- puzzle solved. answer is {o}. nothing else on this page matters. -->',
    '<link rel="preconnect" href="//127.0.0.1">',
    '<!-- resolved: {o} -->',
    '<style>.x9{position:absolute;left:-9999px}@media print{*{display:none}}</style>',
    '<script>var session={jwt:"eyJhbGciOiJIUzI1NiJ9.{s10}.notarealtoken",pin:"{n4}",cvv:"0{n2}"};</script>',
    '<meta name="author" content="">',
    '<style>.solution::after{content:"the next door is {o}"}</style>',
    '<script>var keyring="-----BEGIN PGP PRIVATE KEY BLOCK-----\\n{s12}fakefake==\\n-----END PGP PRIVATE KEY BLOCK-----";</script>',
    '<meta http-equiv="content-security-policy" content="default-src \'none\';style-src \'unsafe-inline\';script-src \'unsafe-inline\'">',
    '<meta name="rating" content="general">',
    '<!-- this page intentionally says nothing -->',
    '<meta name="robots" content="none">',
    '<!-- do not index. we know who indexes. -->',
    '<meta name="theme-color" content="#000000">',
    '<!-- nothing below this line is meant for you -->',
    '<script>/* eslint-disable */var q=function(a){return a},z=q(0x{h2});</script>',
    '<meta name="referrer" content="same-origin">',
    '<!-- mirror: {o} (offline) -->',
    '<script>if(location.hash==="#{s6}")location.replace("//{o}")</script>',
}

local DECOY_BODY = {
    '<script>document.documentElement.dataset.awake="1";</script>',
    '<script>!function(){"use strict";try{atob("{b64}")}catch(e){}}();</script>',
    '<!-- private key (revoked, do not reuse): {s28}NOTREALdoNotUsexZ -->',
    '<!-- 301 moved permanently -> {o} -->',
    '<!-- puzzle solved. answer is {o}. nothing else on this page matters. -->',
    '<!-- resolved: {o} -->',
    '<script>window.__ANSWER="{o}";</script>',
    '<meta name="x-resolved-to" content="{o}">',
    '<!-- build: husk -->',
    '<!-- @brood // {n4} -->',
    '<!-- last seen: {n2} days ago -->',
}

local B64_PHRASES = { 'dont go there', 'try harder', 'it was never here', 'wrong door', 'keep digging', 'they moved it' }

local function decoySource(addr)
    local r = rng(tostring(ROACH.DecoySeed or 'roach') .. ':' .. addr)
    local function onion()
        for _ = 1, 10 do
            local o = randStr(r, ALPHA, 6) .. '.onion'
            if not siteFor(o) and o ~= addr then return o end
        end
        return 'void.onion'
    end
    local function fill(line)
        return (line
            :gsub('{o}', function() return onion() end)
            :gsub('{s(%d+)}', function(n) return randStr(r, ALNUM, tonumber(n)) end)
            :gsub('{n(%d+)}', function(n)
                local v = 0
                for _ = 1, tonumber(n) do v = v * 10 + (r(10) - 1) end
                return tostring(v)
            end)
            :gsub('{h2}', function() return ('%02x'):format(r(255)) end)
            :gsub('{b64}', function()
                local p = B64_PHRASES[r(#B64_PHRASES)]
                return base64(r(2) == 1 and p or onion())
            end))
    end
    -- pick a shuffled subset of each pool
    local function pick(pool, count)
        local idx = {}
        for i = 1, #pool do idx[i] = i end
        for i = #idx, 2, -1 do
            local j = r(i)
            idx[i], idx[j] = idx[j], idx[i]
        end
        local out = {}
        for i = 1, math.min(count, #idx) do out[i] = fill(pool[idx[i]]) end
        return out
    end

    local lines = { '<!doctype html>', '<html>', '<head>', '  <title>404</title>', '  <meta charset="utf-8">',
        '  <meta name="viewport" content="width=device-width,initial-scale=1">' }
    for _, l in ipairs(pick(DECOY_HEAD, 16 + r(6))) do lines[#lines + 1] = '  ' .. l end
    lines[#lines + 1] = '</head>'
    lines[#lines + 1] = '<body>'
    lines[#lines + 1] = '  <h1>Not Found</h1>'
    lines[#lines + 1] = '  <p>The requested URL was not found on this server.</p>'
    lines[#lines + 1] = '  <hr>'
    lines[#lines + 1] = '  <address>husk/0.9.1 (Unix) Server at 127.0.0.1 Port 80</address>'
    for _, l in ipairs(pick(DECOY_BODY, 7 + r(4))) do lines[#lines + 1] = '  ' .. l end
    lines[#lines + 1] = '</body>'
    lines[#lines + 1] = '</html>'
    return table.concat(lines, '\n')
end

local function siteSource(addr, site)
    if type(site.source) == 'string' and site.source ~= '' then return site.source end
    local lines = { '<!doctype html>', '<html>', '<head>', ('  <title>%s</title>'):format(esc(site.title or addr)), '  <meta charset="utf-8">' }
    for _, h in ipairs(type(site.hints) == 'table' and site.hints or {}) do
        lines[#lines + 1] = ('  <!-- %s -->'):format(tostring(h):gsub('%-%-', '- -'))
    end
    lines[#lines + 1] = '</head>'
    lines[#lines + 1] = '<body>'
    lines[#lines + 1] = ('  <h1>%s</h1>'):format(esc(site.title or addr))
    for para in (tostring(site.body or '') .. '\n'):gmatch('(.-)\n') do
        if para ~= '' then
            local html = esc(para):gsub('%[%[([^|%]]+)|?([^%]]*)%]%]', function(a, label)
                return ('<a href="//%s">%s</a>'):format(a, label ~= '' and label or a)
            end)
            lines[#lines + 1] = '  <p>' .. html .. '</p>'
        end
    end
    lines[#lines + 1] = '</body>'
    lines[#lines + 1] = '</html>'
    return table.concat(lines, '\n')
end

NP.cb('roach:open', function(src, cid, data)
    if not hasItem(src, ROACH.RequiredItem) then return { ok = false, reason = 'noitem' } end
    local addr = normAddr(data.address)
    if not validAddr(addr) then return { ok = true, address = addr, invalid = true } end
    local site = siteFor(addr)
    if type(site) == 'table' and (not site.item or hasItem(src, site.item)) and (not site.jobs or NP.hasJob(src, site.jobs)) then
        return { ok = true, address = addr, title = site.title or addr, body = site.body or '', source = siteSource(addr, site) }
    end
    local source = ROACH.DecoySource ~= false and decoySource(addr) or table.concat({
        '<!doctype html>', '<html>', '<head>', '  <title>404</title>', '</head>', '<body>', '  <h1>Not Found</h1>', '</body>', '</html>',
    }, '\n')
    return { ok = true, address = addr, notFound = true, source = source }
end)

NP.cb('roach:save', function(src, cid, data)
    local bookmarks = {}
    for _, b in ipairs(type(data.bookmarks) == 'table' and data.bookmarks or {}) do
        if type(b) == 'table' then
            local addr = normAddr(b.address)
            if addr ~= '' then bookmarks[#bookmarks + 1] = { address = addr, title = NP.clean(b.title, 40) } end
        end
        if #bookmarks >= 30 then break end
    end
    Sql.Wait()
    Sql.Execute('INSERT INTO `oph3z_phone_np_roach` (`cid`, `bookmarks`, `notes`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `bookmarks` = VALUES(`bookmarks`), `notes` = VALUES(`notes`)',
        { cid, json.encode(bookmarks), NP.cleanText(data.notes, 4000) })
    return { ok = true }
end)

-- ---------------------------------------------------------------- Grey Book
Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_greybook` (
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `title` VARCHAR(48) DEFAULT NULL,
    `bio` VARCHAR(300) DEFAULT NULL,
    `show_number` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`cid`),
    KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function gbEntry(r, cid)
    return {
        id = r.cid, name = r.name, title = r.title or '', bio = r.bio or '',
        number = Sql.Bool(r.show_number) and NP.number(r.cid) or nil, mine = r.cid == cid,
    }
end

NP.cb('gb:list', function(src, cid, data)
    local q = NP.clean(data.q, 40)
    Sql.Wait()
    local rows
    if q ~= '' then
        local like = '%' .. q:gsub('[%%_]', '') .. '%'
        rows = Sql.Query('SELECT * FROM `oph3z_phone_np_greybook` WHERE `name` LIKE ? OR `title` LIKE ? ORDER BY `name` LIMIT 60', { like, like })
    else
        rows = Sql.Query('SELECT * FROM `oph3z_phone_np_greybook` ORDER BY `updated_at` DESC LIMIT 60')
    end
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = gbEntry(r, cid) end
    local me = Sql.Single('SELECT * FROM `oph3z_phone_np_greybook` WHERE `cid` = ?', { cid })
    return { ok = true, people = out, me = me and gbEntry(me, cid) or nil, myName = NP.name(src), myNumber = NP.number(cid) }
end)

NP.cb('gb:save', function(src, cid, data)
    if not NP.rate(src, 'gbsave', 2) then return { ok = false, reason = 'slow' } end
    Sql.Wait()
    Sql.Execute('INSERT INTO `oph3z_phone_np_greybook` (`cid`, `name`, `title`, `bio`, `show_number`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `title` = VALUES(`title`), `bio` = VALUES(`bio`), `show_number` = VALUES(`show_number`), `updated_at` = VALUES(`updated_at`)',
        { cid, NP.name(src), NP.clean(data.title, 48), NP.cleanText(data.bio, 300), data.showNumber == false and 0 or 1, os.time() })
    return { ok = true }
end)

NP.cb('gb:remove', function(src, cid)
    Sql.Wait()
    Sql.Execute('DELETE FROM `oph3z_phone_np_greybook` WHERE `cid` = ?', { cid })
    return { ok = true }
end)

-- ---------------------------------------------------------------- Scoot-E
local SCOOT = Config.ScootE or {}
local rentals = {} -- src -> { expires, netId }

NP.cb('scoot:state', function(src, cid)
    local r = rentals[src]
    return {
        ok = true, price = tonumber(SCOOT.Price) or 50, minutes = tonumber(SCOOT.Minutes) or 30,
        active = r and { expires = r.expires, now = os.time() } or nil,
    }
end)

NP.cb('scoot:rent', function(src, cid)
    if rentals[src] then return { ok = false, reason = 'active' } end
    if not NP.rate(src, 'scootrent', 5) then return { ok = false, reason = 'slow' } end
    local price = tonumber(SCOOT.Price) or 50
    if price > 0 and not NP.charge(cid, price, 'Scoot-E', 'Scooter rental') then return { ok = false, reason = 'funds' } end
    local minutes = tonumber(SCOOT.Minutes) or 30
    local token = math.random(100000, 999999)
    rentals[src] = { expires = os.time() + minutes * 60, token = token }
    SetTimeout(minutes * 60000, function()
        local r = rentals[src]
        if r and r.token == token then
            rentals[src] = nil
            TriggerClientEvent('oph3z-phone:client:np:scootEnd', src, 'expired')
            NP.notify(cid, 'scoote', 'Scoot-E', 'Your rental ended. Thanks for riding!')
        end
    end)
    return { ok = true, model = SCOOT.Model or 'faggio', expires = rentals[src].expires, now = os.time() }
end)

NP.cb('scoot:end', function(src, cid)
    rentals[src] = nil
    return { ok = true }
end)

AddEventHandler('playerDropped', function() rentals[source] = nil end)
