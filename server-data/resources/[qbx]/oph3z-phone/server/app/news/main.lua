-- Weazel News: articles published by the news job (Config.News.Jobs) or, if allowed, anyone.
-- Breaking news sends a phone notification to everyone online.
local CFG = Config.News or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_news` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category` VARCHAR(24) NOT NULL,
    `headline` VARCHAR(120) NOT NULL,
    `image` VARCHAR(512) DEFAULT NULL,
    `body` TEXT DEFAULT NULL,
    `author` VARCHAR(64) DEFAULT NULL,
    `author_cid` VARCHAR(64) DEFAULT NULL,
    `breaking` TINYINT(1) NOT NULL DEFAULT 0,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function categoryValid(c)
    for _, cat in ipairs(CFG.Categories or {}) do
        if cat.id == c then return true end
    end
    return false
end

local function canPublish(src)
    if CFG.AnyoneCanPublish then return true end
    return NP.hasJob(src, CFG.Jobs) or (CFG.AdminsCanPublish ~= false and NP.isAdmin(src))
end

local function canModerate(src)
    return NP.hasJob(src, CFG.EditorJobs or CFG.Jobs) or NP.isAdmin(src)
end

NP.cb('news:list', function(src, cid, data)
    local cat = tostring(data.category or 'all')
    Sql.Wait()
    local rows
    if cat == 'all' then
        rows = Sql.Query('SELECT `id`, `category`, `headline`, `image`, `author`, `author_cid`, `breaking`, `ts` FROM `oph3z_phone_np_news` ORDER BY `id` DESC LIMIT 60')
    else
        rows = Sql.Query('SELECT `id`, `category`, `headline`, `image`, `author`, `author_cid`, `breaking`, `ts` FROM `oph3z_phone_np_news` WHERE `category` = ? ORDER BY `id` DESC LIMIT 60', { cat })
    end
    local mod = canModerate(src)
    for _, r in ipairs(rows) do
        r.breaking = Sql.Bool(r.breaking)
        r.canDelete = mod or r.author_cid == cid
        r.author_cid = nil
    end
    return { ok = true, articles = rows, canPublish = canPublish(src), categories = CFG.Categories or {} }
end)

NP.cb('news:get', function(src, cid, data)
    Sql.Wait()
    local a = Sql.Single('SELECT * FROM `oph3z_phone_np_news` WHERE `id` = ?', { tonumber(data.id) })
    if not a then return { ok = false, reason = 'gone' } end
    a.breaking = Sql.Bool(a.breaking)
    a.canDelete = canModerate(src) or a.author_cid == cid
    a.author_cid = nil
    return { ok = true, article = a }
end)

NP.cb('news:publish', function(src, cid, data)
    if not canPublish(src) then return { ok = false, reason = 'denied' } end
    if not NP.rate(src, 'newspub', 10) then return { ok = false, reason = 'slow' } end
    local cat = tostring(data.category or '')
    if not categoryValid(cat) then return { ok = false, reason = 'category' } end
    local headline = NP.clean(data.headline, 120)
    local body = NP.cleanText(data.body, 6000)
    if #headline < 5 or #body < 10 then return { ok = false, reason = 'short' } end
    local breaking = data.breaking == true
    Sql.Wait()
    local id = Sql.Insert('INSERT INTO `oph3z_phone_np_news` (`category`, `headline`, `image`, `body`, `author`, `author_cid`, `breaking`, `ts`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { cat, headline, NP.url(data.image), body, NP.name(src), cid, breaking and 1 or 0, os.time() })
    if not id then return { ok = false, reason = 'db' } end
    if breaking then
        for _, p in ipairs(GetPlayers()) do
            local other = NP.cid(tonumber(p))
            if other then NP.notify(other, 'news', 'Breaking News', headline, { app = 'news' }) end
        end
    end
    return { ok = true, id = id }
end)

NP.cb('news:delete', function(src, cid, data)
    Sql.Wait()
    local a = Sql.Single('SELECT `author_cid` FROM `oph3z_phone_np_news` WHERE `id` = ?', { tonumber(data.id) })
    if not a then return { ok = true } end
    if a.author_cid ~= cid and not canModerate(src) then return { ok = false, reason = 'denied' } end
    Sql.Execute('DELETE FROM `oph3z_phone_np_news` WHERE `id` = ?', { tonumber(data.id) })
    return { ok = true }
end)
