-- Calendar: personal events per character, optionally shared so everyone sees them.
local CFG = Config.Calendar or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_calendar` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `cid` VARCHAR(64) NOT NULL,
    `owner_name` VARCHAR(64) DEFAULT NULL,
    `title` VARCHAR(60) NOT NULL,
    `note` VARCHAR(300) DEFAULT NULL,
    `day` CHAR(10) NOT NULL,
    `time` CHAR(5) DEFAULT NULL,
    `shared` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner_day` (`cid`, `day`),
    KEY `idx_shared_day` (`shared`, `day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function validDay(d)
    local y, m, dd = tostring(d or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, dd = tonumber(y), tonumber(m), tonumber(dd)
    return y and m >= 1 and m <= 12 and dd >= 1 and dd <= 31 and y >= 2000 and y <= 2200
end

local function validTime(t)
    if t == nil or t == '' then return true end
    local h, mi = tostring(t):match('^(%d%d):(%d%d)$')
    return h and tonumber(h) < 24 and tonumber(mi) < 60
end

NP.cb('cal:month', function(src, cid, data)
    local y, m = tonumber(data.year), tonumber(data.month)
    if not y or not m or m < 1 or m > 12 then return { ok = false, reason = 'bad' } end
    local prefix = ('%04d-%02d-%%'):format(y, m)
    Sql.Wait()
    local rows = Sql.Query(
        'SELECT `id`, `cid`, `owner_name`, `title`, `note`, `day`, `time`, `shared` FROM `oph3z_phone_np_calendar` ' ..
        'WHERE `day` LIKE ? AND (`cid` = ? OR `shared` = 1) ORDER BY `day`, `time`', { prefix, cid })
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = r.id, title = r.title, note = r.note or '', day = r.day, time = r.time or '',
            shared = Sql.Bool(r.shared), mine = r.cid == cid, owner = r.owner_name,
        }
    end
    return { ok = true, events = out }
end)

NP.cb('cal:add', function(src, cid, data)
    local title = NP.clean(data.title, 60)
    if title == '' then return { ok = false, reason = 'title' } end
    if not validDay(data.day) or not validTime(data.time) then return { ok = false, reason = 'date' } end
    if not NP.rate(src, 'caladd', 1) then return { ok = false, reason = 'slow' } end
    Sql.Wait()
    local count = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_calendar` WHERE `cid` = ?', { cid })) or 0
    if count >= (tonumber(CFG.MaxEvents) or 200) then return { ok = false, reason = 'limit' } end
    local shared = data.shared == true and CFG.AllowShared ~= false
    local id = Sql.Insert(
        'INSERT INTO `oph3z_phone_np_calendar` (`cid`, `owner_name`, `title`, `note`, `day`, `time`, `shared`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { cid, NP.name(src), title, NP.cleanText(data.note, 300), data.day, (data.time ~= '' and data.time) or nil, shared and 1 or 0, os.time() })
    return { ok = id ~= nil, id = id }
end)

NP.cb('cal:delete', function(src, cid, data)
    Sql.Wait()
    local n = Sql.Execute('DELETE FROM `oph3z_phone_np_calendar` WHERE `id` = ? AND `cid` = ?', { tonumber(data.id), cid })
    return { ok = (tonumber(n) or 0) > 0 }
end)
