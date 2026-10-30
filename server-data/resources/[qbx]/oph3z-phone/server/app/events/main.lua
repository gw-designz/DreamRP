-- Events: players propose events (location = where they stand), the city votes them in, then
-- everyone can join and get a waypoint. Host jobs (Config.Events.HostJobs) schedule directly.
local CFG = Config.Events or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_events` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(60) NOT NULL,
    `description` VARCHAR(400) DEFAULT NULL,
    `location` VARCHAR(64) DEFAULT NULL,
    `x` DOUBLE DEFAULT NULL,
    `y` DOUBLE DEFAULT NULL,
    `starts_at` INT UNSIGNED NOT NULL DEFAULT 0,
    `status` VARCHAR(12) NOT NULL DEFAULT 'voting',
    `creator_cid` VARCHAR(64) NOT NULL,
    `creator_name` VARCHAR(64) DEFAULT NULL,
    `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_status` (`status`, `starts_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_event_members` (
    `event_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`event_id`, `cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_event_votes` (
    `event_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    PRIMARY KEY (`event_id`, `cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function isHost(src)
    return NP.hasJob(src, CFG.HostJobs) or NP.isAdmin(src)
end

local function serialize(e, cid)
    local members = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_event_members` WHERE `event_id` = ?', { e.id })) or 0
    local votes = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_event_votes` WHERE `event_id` = ?', { e.id })) or 0
    return {
        id = e.id, title = e.title, description = e.description or '', location = e.location or '',
        startsAt = e.starts_at, status = e.status, creator = e.creator_name, mine = e.creator_cid == cid,
        participants = members, votes = votes, votesNeeded = tonumber(CFG.VotesToSchedule) or 5,
        joined = Sql.Scalar('SELECT 1 FROM `oph3z_phone_np_event_members` WHERE `event_id` = ? AND `cid` = ?', { e.id, cid }) ~= nil,
        voted = Sql.Scalar('SELECT 1 FROM `oph3z_phone_np_event_votes` WHERE `event_id` = ? AND `cid` = ?', { e.id, cid }) ~= nil,
        hasLocation = e.x ~= nil,
    }
end

NP.cb('ev:list', function(src, cid, data)
    local tab = tostring(data.tab or 'home')
    local keepEnded = os.time() - (tonumber(CFG.KeepEndedMinutes) or 120) * 60
    Sql.Wait()
    local rows
    if tab == 'voting' then
        rows = Sql.Query('SELECT * FROM `oph3z_phone_np_events` WHERE `status` = ? AND `starts_at` > ? ORDER BY `starts_at`', { 'voting', os.time() })
    elseif tab == 'mine' then
        rows = Sql.Query(
            'SELECT DISTINCT e.* FROM `oph3z_phone_np_events` e LEFT JOIN `oph3z_phone_np_event_members` m ON m.`event_id` = e.`id` AND m.`cid` = ? ' ..
            'WHERE (e.`creator_cid` = ? OR m.`cid` IS NOT NULL) AND e.`starts_at` > ? ORDER BY e.`starts_at` DESC', { cid, cid, keepEnded })
    else
        rows = Sql.Query('SELECT * FROM `oph3z_phone_np_events` WHERE `status` = ? AND `starts_at` > ? ORDER BY `starts_at`', { 'scheduled', keepEnded })
    end
    local out = {}
    for _, e in ipairs(rows) do out[#out + 1] = serialize(e, cid) end
    return { ok = true, events = out, isHost = isHost(src), now = os.time() }
end)

NP.cb('ev:create', function(src, cid, data)
    local title = NP.clean(data.title, 60)
    if #title < 3 then return { ok = false, reason = 'title' } end
    local minutes = math.floor(tonumber(data.startsIn) or 0)
    if minutes < 5 or minutes > (tonumber(CFG.MaxDaysAhead) or 7) * 1440 then return { ok = false, reason = 'time' } end
    if not NP.rate(src, 'evcreate', 30) then return { ok = false, reason = 'slow' } end
    Sql.Wait()
    local open = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_events` WHERE `creator_cid` = ? AND `starts_at` > ?', { cid, os.time() })) or 0
    if open >= (tonumber(CFG.MaxOpenPerPlayer) or 3) then return { ok = false, reason = 'limit' } end
    local c = NP.coords(src)
    local status = isHost(src) and 'scheduled' or 'voting'
    if not isHost(src) and CFG.AnyoneCanPropose == false then return { ok = false, reason = 'denied' } end
    local id = Sql.Insert(
        'INSERT INTO `oph3z_phone_np_events` (`title`, `description`, `location`, `x`, `y`, `starts_at`, `status`, `creator_cid`, `creator_name`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { title, NP.cleanText(data.description, 400), NP.clean(data.location, 64), c and c.x or nil, c and c.y or nil,
          os.time() + minutes * 60, status, cid, NP.name(src), os.time() })
    if id then
        Sql.Execute('INSERT IGNORE INTO `oph3z_phone_np_event_members` (`event_id`, `cid`, `name`, `ts`) VALUES (?, ?, ?, ?)', { id, cid, NP.name(src), os.time() })
    end
    return { ok = id ~= nil, status = status }
end)

local function event(id) return Sql.Single('SELECT * FROM `oph3z_phone_np_events` WHERE `id` = ?', { tonumber(id) }) end

NP.cb('ev:join', function(src, cid, data)
    Sql.Wait()
    local e = event(data.id)
    if not e or e.status ~= 'scheduled' or e.starts_at < os.time() then return { ok = false, reason = 'closed' } end
    if data.on == false then
        Sql.Execute('DELETE FROM `oph3z_phone_np_event_members` WHERE `event_id` = ? AND `cid` = ?', { e.id, cid })
        return { ok = true, joined = false }
    end
    local max = tonumber(CFG.MaxParticipants) or 0
    if max > 0 then
        local n = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_event_members` WHERE `event_id` = ?', { e.id })) or 0
        if n >= max then return { ok = false, reason = 'full' } end
    end
    Sql.Execute('INSERT IGNORE INTO `oph3z_phone_np_event_members` (`event_id`, `cid`, `name`, `ts`) VALUES (?, ?, ?, ?)', { e.id, cid, NP.name(src), os.time() })
    return { ok = true, joined = true }
end)

NP.cb('ev:vote', function(src, cid, data)
    Sql.Wait()
    local e = event(data.id)
    if not e or e.status ~= 'voting' or e.starts_at < os.time() then return { ok = false, reason = 'closed' } end
    if e.creator_cid == cid then return { ok = false, reason = 'own' } end
    Sql.Execute('INSERT IGNORE INTO `oph3z_phone_np_event_votes` (`event_id`, `cid`) VALUES (?, ?)', { e.id, cid })
    local votes = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_event_votes` WHERE `event_id` = ?', { e.id })) or 0
    if votes >= (tonumber(CFG.VotesToSchedule) or 5) then
        Sql.Execute('UPDATE `oph3z_phone_np_events` SET `status` = ? WHERE `id` = ?', { 'scheduled', e.id })
        NP.notify(e.creator_cid, 'events', 'Events', ('"%s" got enough votes and is now scheduled.'):format(e.title))
    end
    return { ok = true, votes = votes }
end)

NP.cb('ev:locate', function(src, cid, data)
    Sql.Wait()
    local e = event(data.id)
    if not e or not e.x then return { ok = false, reason = 'nolocation' } end
    return { ok = true, x = e.x, y = e.y }
end)

NP.cb('ev:delete', function(src, cid, data)
    Sql.Wait()
    local e = event(data.id)
    if not e then return { ok = true } end
    if e.creator_cid ~= cid and not NP.isAdmin(src) then return { ok = false, reason = 'denied' } end
    for _, m in ipairs(Sql.Query('SELECT `cid` FROM `oph3z_phone_np_event_members` WHERE `event_id` = ?', { e.id })) do
        if m.cid ~= cid then NP.notify(m.cid, 'events', 'Events', ('"%s" was cancelled.'):format(e.title)) end
    end
    Sql.Execute('DELETE FROM `oph3z_phone_np_event_members` WHERE `event_id` = ?', { e.id })
    Sql.Execute('DELETE FROM `oph3z_phone_np_event_votes` WHERE `event_id` = ?', { e.id })
    Sql.Execute('DELETE FROM `oph3z_phone_np_events` WHERE `id` = ?', { e.id })
    return { ok = true }
end)
