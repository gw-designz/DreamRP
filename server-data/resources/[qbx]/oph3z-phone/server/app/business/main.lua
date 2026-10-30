-- Business app: player-created businesses with owner / manager / employee roles, invites,
-- announcements and a member list. Every action checks the caller's role server-side.
local CFG = Config.Business or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_business` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(40) NOT NULL,
    `name` VARCHAR(40) NOT NULL,
    `description` VARCHAR(120) DEFAULT NULL,
    `owner_cid` VARCHAR(64) NOT NULL,
    `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_code` (`code`),
    KEY `idx_owner` (`owner_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_business_members` (
    `business_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `role` VARCHAR(16) NOT NULL DEFAULT 'employee',
    `hired_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`business_id`, `cid`),
    KEY `idx_cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_business_invites` (
    `business_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `invited_by` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`business_id`, `cid`),
    KEY `idx_cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_business_posts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `business_id` INT UNSIGNED NOT NULL,
    `author` VARCHAR(64) DEFAULT NULL,
    `text` VARCHAR(400) NOT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_business` (`business_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local RANK = { owner = 3, manager = 2, employee = 1 }

local function memberRow(bid, cid)
    return Sql.Single('SELECT `role`, `hired_at`, `name` FROM `oph3z_phone_np_business_members` WHERE `business_id` = ? AND `cid` = ?', { bid, cid })
end

local function roleOf(bid, cid)
    local row = memberRow(bid, cid)
    return row and row.role or nil
end

local function business(bid)
    return Sql.Single('SELECT * FROM `oph3z_phone_np_business` WHERE `id` = ?', { tonumber(bid) })
end

local function summary(b, myRole)
    local count = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_business_members` WHERE `business_id` = ?', { b.id })) or 0
    local owner = Sql.Single('SELECT `name` FROM `oph3z_phone_np_business_members` WHERE `business_id` = ? AND `role` = ?', { b.id, 'owner' })
    return {
        id = b.id, code = b.code, name = b.name, description = b.description or '',
        ownerName = owner and owner.name or '', members = count, myRole = myRole, createdAt = b.created_at,
    }
end

local function slug(name)
    local s = tostring(name or ''):lower():gsub('[^%w]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    if s == '' then s = 'business' end
    return s:sub(1, 30)
end

local function notifyMembers(bid, exceptCid, title, body)
    for _, m in ipairs(Sql.Query('SELECT `cid` FROM `oph3z_phone_np_business_members` WHERE `business_id` = ?', { bid })) do
        if m.cid ~= exceptCid then NP.notify(m.cid, 'business', title, body) end
    end
end

NP.cb('biz:list', function(src, cid)
    Sql.Wait()
    local out = {}
    for _, row in ipairs(Sql.Query(
        'SELECT b.*, m.`role` AS `my_role` FROM `oph3z_phone_np_business` b JOIN `oph3z_phone_np_business_members` m ' ..
        'ON m.`business_id` = b.`id` WHERE m.`cid` = ? ORDER BY b.`name`', { cid }
    )) do
        out[#out + 1] = summary(row, row.my_role)
    end
    local invites = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_business_invites` WHERE `cid` = ?', { cid })) or 0
    return { ok = true, businesses = out, invites = invites, me = NP.name(src) }
end)

NP.cb('biz:create', function(src, cid, data)
    if not NP.rate(src, 'bizcreate', 5) then return { ok = false, reason = 'slow' } end
    local name = NP.clean(data.name, 30)
    local desc = NP.clean(data.description, 42)
    if #name < 3 then return { ok = false, reason = 'name' } end
    Sql.Wait()
    local owned = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_business` WHERE `owner_cid` = ?', { cid })) or 0
    if owned >= (tonumber(CFG.MaxOwned) or 3) then return { ok = false, reason = 'limit' } end
    local cost = tonumber(CFG.CreateCost) or 0
    if cost > 0 and not NP.charge(cid, cost, 'Business registration', name) then return { ok = false, reason = 'funds' } end

    local base, code = slug(name), nil
    for i = 0, 50 do
        local try = i == 0 and base or (base:sub(1, 26) .. '_' .. math.random(10, 999))
        if not Sql.Scalar('SELECT `id` FROM `oph3z_phone_np_business` WHERE `code` = ?', { try }) then code = try break end
    end
    if not code then return { ok = false, reason = 'bad' } end
    local now = os.time()
    local id = Sql.Insert('INSERT INTO `oph3z_phone_np_business` (`code`, `name`, `description`, `owner_cid`, `created_at`) VALUES (?, ?, ?, ?, ?)',
        { code, name, desc, cid, now })
    if not id then return { ok = false, reason = 'bad' } end
    Sql.Execute('INSERT INTO `oph3z_phone_np_business_members` (`business_id`, `cid`, `name`, `role`, `hired_at`) VALUES (?, ?, ?, ?, ?)',
        { id, cid, NP.name(src), 'owner', now })
    return { ok = true, business = summary(business(id), 'owner') }
end)

NP.cb('biz:get', function(src, cid, data)
    local bid = tonumber(data.id)
    Sql.Wait()
    local b = bid and business(bid)
    local me = b and memberRow(bid, cid)
    if not b or not me then return { ok = false, reason = 'notmember' } end
    local members = {}
    for _, m in ipairs(Sql.Query('SELECT `cid`, `name`, `role`, `hired_at` FROM `oph3z_phone_np_business_members` WHERE `business_id` = ? ORDER BY `hired_at`', { bid })) do
        members[#members + 1] = { id = m.cid, name = m.name or 'Employee', role = m.role, hiredAt = m.hired_at, isMe = m.cid == cid, number = NP.number(m.cid) }
    end
    table.sort(members, function(a, c) return (RANK[a.role] or 0) > (RANK[c.role] or 0) end)
    local posts = Sql.Query('SELECT `id`, `author`, `text`, `ts` FROM `oph3z_phone_np_business_posts` WHERE `business_id` = ? ORDER BY `id` DESC LIMIT 40', { bid })
    local invites = Sql.Query('SELECT i.`cid`, i.`ts`, p.`name` FROM `oph3z_phone_np_business_invites` i LEFT JOIN `oph3z_phone_players` p ON p.`citizenid` = i.`cid` WHERE i.`business_id` = ?', { bid })
    return {
        ok = true,
        business = summary(b, me.role),
        me = { name = me.name, role = me.role, hiredAt = me.hired_at },
        members = members,
        posts = posts,
        pending = invites,
    }
end)

NP.cb('biz:invites', function(src, cid)
    Sql.Wait()
    local rows = Sql.Query(
        'SELECT b.`id`, b.`name`, b.`description`, b.`code`, i.`ts` FROM `oph3z_phone_np_business_invites` i ' ..
        'JOIN `oph3z_phone_np_business` b ON b.`id` = i.`business_id` WHERE i.`cid` = ? ORDER BY i.`ts` DESC', { cid })
    return { ok = true, invites = rows }
end)

NP.cb('biz:respond', function(src, cid, data)
    local bid = tonumber(data.id)
    Sql.Wait()
    local inv = bid and Sql.Single('SELECT `business_id` FROM `oph3z_phone_np_business_invites` WHERE `business_id` = ? AND `cid` = ?', { bid, cid })
    if not inv then return { ok = false, reason = 'gone' } end
    Sql.Execute('DELETE FROM `oph3z_phone_np_business_invites` WHERE `business_id` = ? AND `cid` = ?', { bid, cid })
    if data.accept == true and business(bid) and not memberRow(bid, cid) then
        Sql.Execute('INSERT INTO `oph3z_phone_np_business_members` (`business_id`, `cid`, `name`, `role`, `hired_at`) VALUES (?, ?, ?, ?, ?)',
            { bid, cid, NP.name(src), 'employee', os.time() })
        notifyMembers(bid, cid, business(bid).name, ('%s joined the business.'):format(NP.name(src)))
    end
    return { ok = true }
end)

NP.cb('biz:invite', function(src, cid, data)
    local bid = tonumber(data.id)
    Sql.Wait()
    local role = bid and roleOf(bid, cid)
    if (RANK[role] or 0) < RANK.manager then return { ok = false, reason = 'denied' } end
    local digits = DB.Digits(data.number or '')
    local target = digits ~= '' and DB.GetCitizenIdByNumber(digits) or nil
    if not target then return { ok = false, reason = 'notfound' } end
    if memberRow(bid, target) then return { ok = false, reason = 'member' } end
    local max = tonumber(CFG.MaxMembers) or 50
    local count = tonumber(Sql.Scalar('SELECT COUNT(*) FROM `oph3z_phone_np_business_members` WHERE `business_id` = ?', { bid })) or 0
    if count >= max then return { ok = false, reason = 'full' } end
    Sql.Execute('INSERT IGNORE INTO `oph3z_phone_np_business_invites` (`business_id`, `cid`, `invited_by`, `ts`) VALUES (?, ?, ?, ?)', { bid, target, cid, os.time() })
    local b = business(bid)
    NP.notify(target, 'business', b.name, 'You were invited to join. Open Business to accept.')
    return { ok = true }
end)

NP.cb('biz:post', function(src, cid, data)
    local bid = tonumber(data.id)
    local text = NP.cleanText(data.text, 400)
    if text == '' then return { ok = false, reason = 'empty' } end
    Sql.Wait()
    local role = bid and roleOf(bid, cid)
    if (RANK[role] or 0) < RANK.manager then return { ok = false, reason = 'denied' } end
    if not NP.rate(src, 'bizpost', 3) then return { ok = false, reason = 'slow' } end
    local id = Sql.Insert('INSERT INTO `oph3z_phone_np_business_posts` (`business_id`, `author`, `text`, `ts`) VALUES (?, ?, ?, ?)', { bid, NP.name(src), text, os.time() })
    notifyMembers(bid, cid, business(bid).name, text)
    return { ok = id ~= nil }
end)

NP.cb('biz:role', function(src, cid, data)
    local bid, target, role = tonumber(data.id), tostring(data.cid or ''), tostring(data.role or '')
    if role ~= 'manager' and role ~= 'employee' then return { ok = false, reason = 'bad' } end
    Sql.Wait()
    if roleOf(bid, cid) ~= 'owner' then return { ok = false, reason = 'denied' } end
    local cur = roleOf(bid, target)
    if not cur or cur == 'owner' then return { ok = false, reason = 'bad' } end
    Sql.Execute('UPDATE `oph3z_phone_np_business_members` SET `role` = ? WHERE `business_id` = ? AND `cid` = ?', { role, bid, target })
    return { ok = true }
end)

NP.cb('biz:fire', function(src, cid, data)
    local bid, target = tonumber(data.id), tostring(data.cid or '')
    Sql.Wait()
    local mine, theirs = roleOf(bid, cid), roleOf(bid, target)
    if not theirs or theirs == 'owner' or target == cid then return { ok = false, reason = 'bad' } end
    if (RANK[mine] or 0) <= (RANK[theirs] or 0) then return { ok = false, reason = 'denied' } end
    Sql.Execute('DELETE FROM `oph3z_phone_np_business_members` WHERE `business_id` = ? AND `cid` = ?', { bid, target })
    NP.notify(target, 'business', business(bid).name, 'You were removed from the business.')
    return { ok = true }
end)

NP.cb('biz:cancelInvite', function(src, cid, data)
    local bid = tonumber(data.id)
    Sql.Wait()
    if (RANK[roleOf(bid, cid)] or 0) < RANK.manager then return { ok = false, reason = 'denied' } end
    Sql.Execute('DELETE FROM `oph3z_phone_np_business_invites` WHERE `business_id` = ? AND `cid` = ?', { bid, tostring(data.cid or '') })
    return { ok = true }
end)

NP.cb('biz:leave', function(src, cid, data)
    local bid = tonumber(data.id)
    Sql.Wait()
    local role = roleOf(bid, cid)
    if not role then return { ok = true } end
    if role == 'owner' then return { ok = false, reason = 'owner' } end
    Sql.Execute('DELETE FROM `oph3z_phone_np_business_members` WHERE `business_id` = ? AND `cid` = ?', { bid, cid })
    return { ok = true }
end)

NP.cb('biz:edit', function(src, cid, data)
    local bid = tonumber(data.id)
    local name, desc = NP.clean(data.name, 30), NP.clean(data.description, 42)
    if #name < 3 then return { ok = false, reason = 'name' } end
    Sql.Wait()
    if roleOf(bid, cid) ~= 'owner' then return { ok = false, reason = 'denied' } end
    Sql.Execute('UPDATE `oph3z_phone_np_business` SET `name` = ?, `description` = ? WHERE `id` = ?', { name, desc, bid })
    return { ok = true }
end)

NP.cb('biz:delete', function(src, cid, data)
    local bid = tonumber(data.id)
    Sql.Wait()
    if roleOf(bid, cid) ~= 'owner' then return { ok = false, reason = 'denied' } end
    local b = business(bid)
    notifyMembers(bid, cid, b and b.name or 'Business', 'The business was closed by its owner.')
    Sql.Execute('DELETE FROM `oph3z_phone_np_business_posts` WHERE `business_id` = ?', { bid })
    Sql.Execute('DELETE FROM `oph3z_phone_np_business_invites` WHERE `business_id` = ?', { bid })
    Sql.Execute('DELETE FROM `oph3z_phone_np_business_members` WHERE `business_id` = ?', { bid })
    Sql.Execute('DELETE FROM `oph3z_phone_np_business` WHERE `id` = ?', { bid })
    return { ok = true }
end)
