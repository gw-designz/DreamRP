-- Government: state + local notices (legislation, court docket, announcements, budget rates)
-- and ballots with one vote per character. Only Config.Government.Editors jobs (or admins)
-- can publish or open ballots.
local CFG = Config.Government or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_gov_posts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `region` VARCHAR(24) NOT NULL,
    `section` VARCHAR(24) NOT NULL,
    `title` VARCHAR(80) NOT NULL,
    `body` TEXT DEFAULT NULL,
    `author` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_section` (`region`, `section`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_gov_ballots` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `region` VARCHAR(24) NOT NULL,
    `title` VARCHAR(80) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `options` TEXT NOT NULL,
    `closes_at` INT UNSIGNED NOT NULL DEFAULT 0,
    `author` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_region` (`region`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_gov_votes` (
    `ballot_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `choice` TINYINT UNSIGNED NOT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`ballot_id`, `cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local SECTIONS = { legislation = 'state', docket = 'state', announcements = 'local', budget = 'local' }

local function regionValid(r)
    if r == 'state' then return true end
    for _, reg in ipairs(CFG.Regions or {}) do
        if reg.id == r then return true end
    end
    return false
end

local function canEdit(src)
    return NP.hasJob(src, CFG.Editors) or (CFG.AdminsCanEdit ~= false and NP.isAdmin(src))
end

NP.cb('gov:home', function(src, cid)
    return { ok = true, name = NP.name(src), canEdit = canEdit(src), regions = CFG.Regions or {} }
end)

NP.cb('gov:list', function(src, cid, data)
    local section = tostring(data.section or '')
    local region = tostring(data.region or '')
    Sql.Wait()
    if section == 'ballots' then
        local now = os.time()
        local out = {}
        for _, b in ipairs(Sql.Query('SELECT * FROM `oph3z_phone_np_gov_ballots` WHERE `region` IN (?, ?) ORDER BY `id` DESC LIMIT 30', { 'state', region })) do
            local options = Sql.Decode(b.options, {})
            local tallies = {}
            for i = 1, #options do tallies[i] = 0 end
            for _, v in ipairs(Sql.Query('SELECT `choice`, COUNT(*) AS `n` FROM `oph3z_phone_np_gov_votes` WHERE `ballot_id` = ? GROUP BY `choice`', { b.id })) do
                tallies[tonumber(v.choice)] = tonumber(v.n) or 0
            end
            local mine = Sql.Scalar('SELECT `choice` FROM `oph3z_phone_np_gov_votes` WHERE `ballot_id` = ? AND `cid` = ?', { b.id, cid })
            local open = (b.closes_at or 0) > now
            out[#out + 1] = {
                id = b.id, title = b.title, description = b.description or '', options = options,
                closesAt = b.closes_at, open = open, myVote = tonumber(mine),
                -- results are visible once you voted or the ballot closed
                tallies = (mine or not open) and tallies or nil, author = b.author, ts = b.ts,
            }
        end
        return { ok = true, ballots = out }
    end
    if not SECTIONS[section] then return { ok = false, reason = 'bad' } end
    if SECTIONS[section] == 'state' then region = 'state' end
    if not regionValid(region) then return { ok = false, reason = 'bad' } end
    local rows = Sql.Query('SELECT `id`, `title`, `body`, `author`, `ts` FROM `oph3z_phone_np_gov_posts` WHERE `region` = ? AND `section` = ? ORDER BY `id` DESC LIMIT 50', { region, section })
    return { ok = true, posts = rows }
end)

NP.cb('gov:post', function(src, cid, data)
    if not canEdit(src) then return { ok = false, reason = 'denied' } end
    local section = tostring(data.section or '')
    local region = SECTIONS[section] == 'state' and 'state' or tostring(data.region or '')
    if not SECTIONS[section] or not regionValid(region) then return { ok = false, reason = 'bad' } end
    local title = NP.clean(data.title, 80)
    local body = NP.cleanText(data.body, 3000)
    if title == '' then return { ok = false, reason = 'title' } end
    Sql.Wait()
    local id = Sql.Insert('INSERT INTO `oph3z_phone_np_gov_posts` (`region`, `section`, `title`, `body`, `author`, `ts`) VALUES (?, ?, ?, ?, ?, ?)',
        { region, section, title, body, NP.name(src), os.time() })
    return { ok = id ~= nil }
end)

NP.cb('gov:delete', function(src, cid, data)
    if not canEdit(src) then return { ok = false, reason = 'denied' } end
    Sql.Wait()
    if data.ballot then
        Sql.Execute('DELETE FROM `oph3z_phone_np_gov_votes` WHERE `ballot_id` = ?', { tonumber(data.id) })
        Sql.Execute('DELETE FROM `oph3z_phone_np_gov_ballots` WHERE `id` = ?', { tonumber(data.id) })
    else
        Sql.Execute('DELETE FROM `oph3z_phone_np_gov_posts` WHERE `id` = ?', { tonumber(data.id) })
    end
    return { ok = true }
end)

NP.cb('gov:ballot', function(src, cid, data)
    if not canEdit(src) then return { ok = false, reason = 'denied' } end
    local region = tostring(data.region or 'state')
    if not regionValid(region) then return { ok = false, reason = 'bad' } end
    local title = NP.clean(data.title, 80)
    local options = {}
    for _, o in ipairs(type(data.options) == 'table' and data.options or {}) do
        local s = NP.clean(o, 60)
        if s ~= '' then options[#options + 1] = s end
        if #options >= 6 then break end
    end
    if title == '' or #options < 2 then return { ok = false, reason = 'options' } end
    local days = math.max(1, math.min(30, math.floor(tonumber(data.days) or 3)))
    Sql.Wait()
    local id = Sql.Insert('INSERT INTO `oph3z_phone_np_gov_ballots` (`region`, `title`, `description`, `options`, `closes_at`, `author`, `ts`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { region, title, NP.cleanText(data.description, 1000), json.encode(options), os.time() + days * 86400, NP.name(src), os.time() })
    return { ok = id ~= nil }
end)

NP.cb('gov:vote', function(src, cid, data)
    local id = tonumber(data.id)
    local choice = math.floor(tonumber(data.choice) or 0)
    Sql.Wait()
    local b = id and Sql.Single('SELECT `options`, `closes_at` FROM `oph3z_phone_np_gov_ballots` WHERE `id` = ?', { id })
    if not b then return { ok = false, reason = 'gone' } end
    if (b.closes_at or 0) <= os.time() then return { ok = false, reason = 'closed' } end
    local options = Sql.Decode(b.options, {})
    if choice < 1 or choice > #options then return { ok = false, reason = 'bad' } end
    local n = Sql.Execute('INSERT IGNORE INTO `oph3z_phone_np_gov_votes` (`ballot_id`, `cid`, `choice`, `ts`) VALUES (?, ?, ?, ?)', { id, cid, choice, os.time() })
    if (tonumber(n) or 0) == 0 then return { ok = false, reason = 'voted' } end
    return { ok = true }
end)
