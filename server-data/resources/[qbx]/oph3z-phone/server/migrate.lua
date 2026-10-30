Migrate = Migrate or {}

local RESOURCE = GetCurrentResourceName()
local LEGACY = Config.DataFolder or 'data'
local DONE_KEY = 'json_import'

local function readJson(path)
    local raw = LoadResourceFile(RESOURCE, path)
    if not raw or raw == '' then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

local function safeKey(citizenid)
    return (tostring(citizenid):gsub('[^%w%-_]', '_'))
end

local function digits(value)
    return (tostring(value or ''):gsub('%D', ''))
end

local function bit(value)
    return value and 1 or 0
end

local function trim(value, len)
    if value == nil then return nil end
    return tostring(value):sub(1, len)
end

local function insertRows(tbl, columns, rows)
    if #rows == 0 then return end
    local colSql = '`' .. table.concat(columns, '`, `') .. '`'
    local width = #columns
    local chunk = 150

    for start = 1, #rows, chunk do
        local stop = math.min(start + chunk - 1, #rows)
        local groups, params, n = {}, {}, 0
        for i = start, stop do
            groups[#groups + 1] = '(' .. Sql.Placeholders(width) .. ')'
            for c = 1, width do
                n = n + 1
                params[n] = rows[i][c]
            end
        end
        Sql.Execute(
            ('INSERT INTO `%s` (%s) VALUES %s'):format(tbl, colSql, table.concat(groups, ', ')),
            params
        )
    end
end

local function importPlayer(citizenid, doc, groupIds)
    local phone = doc.phone or {}
    local profile = doc.profile or {}
    local mail = doc.mail or {}
    local number = digits(phone.numberRaw)

    Sql.Execute(
        'INSERT INTO `oph3z_phone_players` (`citizenid`, `number`, `mail`, `name`, `avatar`, `settings`, `home`, `created_at`, `updated_at`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `citizenid` = `citizenid`',
        {
            citizenid,
            number ~= '' and number or nil,
            mail.address and tostring(mail.address):lower() or nil,
            trim(profile.name, 64),
            trim(profile.avatar, 512),
            Sql.Encode(doc.settings),
            Sql.Encode(doc.home),
            Sql.Num(doc.createdAt, 0),
            Sql.Num(doc.updatedAt, 0),
        }
    )

    local rows = {}
    for _, c in ipairs(phone.contacts or {}) do
        rows[#rows + 1] = { citizenid, trim(c.name, 64) or '', trim(c.number, 24) or '', trim(c.notes, 300), trim(c.img, 512), bit(c.favorite) }
    end
    insertRows('oph3z_phone_contacts', { 'citizenid', 'name', 'number', 'notes', 'img', 'favorite' }, rows)

    rows = {}
    for i = #(phone.recents or {}), 1, -1 do
        local r = phone.recents[i]
        rows[#rows + 1] = { citizenid, trim(r.number, 24), trim(r.name, 64), trim(r.img, 512), r.direction == 'out' and 'out' or 'in', bit(r.missed), bit(r.video), Sql.Num(r.ts, 0) }
    end
    insertRows('oph3z_phone_recents', { 'citizenid', 'number', 'name', 'img', 'direction', 'missed', 'video', 'ts' }, rows)

    rows = {}
    for key, b in pairs(phone.blocked or {}) do
        rows[#rows + 1] = { citizenid, trim(key, 24), trim(b.number, 64), trim(b.name, 64), Sql.Num(b.ts, 0) }
    end
    insertRows('oph3z_phone_blocked', { 'citizenid', 'number', 'label', 'name', 'ts' }, rows)

    rows = {}
    for thread, t in pairs((doc.messages or {}).threads or {}) do
        for _, m in ipairs(t.items or {}) do
            rows[#rows + 1] = {
                citizenid, trim(thread, 24), trim(m.id, 32), m.dir == 'out' and 'out' or 'in',
                trim(m.type, 16) or 'text', m.body and tostring(m.body) or nil,
                Sql.Encode(m.meta), Sql.Num(m.ts, 0), bit(m.read),
            }
        end
    end
    table.sort(rows, function(a, b) return (a[8] or 0) < (b[8] or 0) end)
    insertRows('oph3z_phone_messages', { 'citizenid', 'thread', 'msg_id', 'direction', 'type', 'body', 'meta', 'ts', 'is_read' }, rows)

    rows = {}
    for i = #(mail.inbox or {}), 1, -1 do
        local m = mail.inbox[i]
        rows[#rows + 1] = { citizenid, 'inbox', trim(m.from, 160), trim(m.fromName, 64), trim(m.subject, 160), m.body, Sql.Encode(m.attachments), bit(m.system), bit(m.read), Sql.Num(m.ts, 0) }
    end
    for i = #(mail.sent or {}), 1, -1 do
        local m = mail.sent[i]
        rows[#rows + 1] = { citizenid, 'sent', trim(m.to, 160), trim(m.toName, 64), trim(m.subject, 160), m.body, Sql.Encode(m.attachments), 0, 1, Sql.Num(m.ts, 0) }
    end
    insertRows('oph3z_phone_mail', { 'citizenid', 'folder', 'addr', 'addr_name', 'subject', 'body', 'attachments', 'is_system', 'is_read', 'ts' }, rows)

    rows = {}
    for _, p in ipairs((doc.photos or {}).items or {}) do
        rows[#rows + 1] = { citizenid, trim(p.url, 512) or '', p.type == 'video' and 'video' or 'image', trim(p.thumb, 512), Sql.Num(p.duration), bit(p.favorite), Sql.Num(p.ts, 0) }
    end
    insertRows('oph3z_phone_photos', { 'citizenid', 'url', 'type', 'thumb', 'duration', 'favorite', 'ts' }, rows)

    rows = {}
    for _, n in ipairs((doc.notifications or {}).items or {}) do
        rows[#rows + 1] = { citizenid, trim(n.app, 32) or 'system', trim(n.title, 160), n.body, trim(n.icon, 512), Sql.Encode(n.route), Sql.Num(n.ts, 0), bit(n.read), bit(n.queued) }
    end
    insertRows('oph3z_phone_notifications', { 'citizenid', 'app', 'title', 'body', 'icon', 'route', 'ts', 'is_read', 'queued' }, rows)

    rows = {}
    for i = #((doc.calc or {}).history or {}), 1, -1 do
        local h = doc.calc.history[i]
        rows[#rows + 1] = { citizenid, trim(h.expr, 140) or '', Sql.Num(h.value, 0), Sql.Num(h.ts, 0) }
    end
    insertRows('oph3z_phone_calc', { 'citizenid', 'expr', 'value', 'ts' }, rows)

    rows = {}
    for _, b in ipairs((doc.maps or {}).blips or {}) do
        rows[#rows + 1] = { citizenid, trim(b.label, 64) or 'Saved place', Sql.Num(b.x, 0), Sql.Num(b.y, 0), Sql.Num(b.ts, 0) }
    end
    insertRows('oph3z_phone_blips', { 'citizenid', 'label', 'x', 'y', 'ts' }, rows)

    rows = {}
    for _, r in ipairs((doc.ringtones or {}).items or {}) do
        rows[#rows + 1] = { citizenid, trim(r.name, 64) or '', trim(r.url, 512) or '' }
    end
    insertRows('oph3z_phone_ringtones', { 'citizenid', 'name', 'url' }, rows)

    rows = {}
    for i = #((doc.wallet or {}).transactions or {}), 1, -1 do
        local t = doc.wallet.transactions[i]
        rows[#rows + 1] = { citizenid, trim(t.kind, 16) or 'sent', math.floor(Sql.Num(t.amount, 0)), trim(t.party, 64), trim(t.number, 24), trim(t.note, 120), Sql.Num(t.ts, 0) }
    end
    insertRows('oph3z_phone_transactions', { 'citizenid', 'kind', 'amount', 'party', 'number', 'note', 'ts' }, rows)

    rows = {}
    for _, t in ipairs((doc.airdrops or {}).pending or {}) do
        rows[#rows + 1] = { citizenid, json.encode(t), Sql.Num(t.ts, os.time()) }
    end
    insertRows('oph3z_phone_airdrops', { 'citizenid', 'payload', 'ts' }, rows)

    local clock = doc.clock
    if clock then
        local timer = clock.timer
        Sql.Execute(
            'INSERT INTO `oph3z_phone_clock` (`citizenid`, `alarm_ringtone`, `timer_ends_at`, `timer_total`, `timer_remaining`, `timer_paused`, `timer_label`, `timer_from_recent`, `timer_active`) ' ..
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `citizenid` = `citizenid`',
            {
                citizenid, trim(clock.alarmRingtone, 512),
                timer and Sql.Num(timer.endsAt) or nil,
                timer and Sql.Num(timer.total) or nil,
                timer and Sql.Num(timer.remaining) or nil,
                bit(timer and timer.paused),
                timer and trim(timer.label, 64) or nil,
                bit(timer and timer.fromRecent),
                bit(timer ~= nil),
            }
        )

        rows = {}
        for _, a in ipairs(clock.alarms or {}) do
            rows[#rows + 1] = { citizenid, Sql.Num(a.hour, 0), Sql.Num(a.min, 0), trim(a.label, 64), bit(a.enabled) }
        end
        insertRows('oph3z_phone_alarms', { 'citizenid', 'hour', 'minute', 'label', 'enabled' }, rows)

        rows = {}
        for i = #(clock.recents or {}), 1, -1 do
            local r = clock.recents[i]
            rows[#rows + 1] = { citizenid, Sql.Num(r.h, 0), Sql.Num(r.m, 0), Sql.Num(r.s, 0) }
        end
        insertRows('oph3z_phone_timer_recents', { 'citizenid', 'h', 'm', 's' }, rows)

        rows = {}
        for _, t in ipairs((clock.alarmTones or {}).items or {}) do
            rows[#rows + 1] = { citizenid, trim(t.name, 64) or '', trim(t.url, 512) or '' }
        end
        insertRows('oph3z_phone_alarm_tones', { 'citizenid', 'name', 'url' }, rows)
    end

    if doc.x and doc.x.accountId then
        Sql.Execute(
            'INSERT INTO `oph3z_phone_twexa_link` (`citizenid`, `account_id`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `account_id` = VALUES(`account_id`)',
            { citizenid, Sql.Num(doc.x.accountId, 0) }
        )
    end

    for _, gid in ipairs((doc.messages or {}).groupIds or {}) do
        groupIds[gid] = true
    end
end

local function importGroup(gid)
    local group = readJson(('%s/group_%s.json'):format(LEGACY, gid))
    if not group or not group.gid then return end

    Sql.Execute(
        'INSERT INTO `oph3z_phone_groups` (`gid`, `name`, `photo`, `owner`, `created_at`) VALUES (?, ?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `gid` = `gid`',
        { trim(group.gid, 32), trim(group.name, 64) or 'Group', trim(group.photo, 512), trim(group.owner, 24), Sql.Num(group.createdAt, 0) }
    )

    local rows = {}
    for _, m in ipairs(group.members or {}) do
        rows[#rows + 1] = { trim(group.gid, 32), trim(m.number, 24) or '', trim(m.name, 64), Sql.Num(m.joinedAt, 0) }
    end
    insertRows('oph3z_phone_group_members', { 'gid', 'number', 'name', 'joined_at' }, rows)

    local idMap = {}
    local reactions = {}
    for _, item in ipairs(group.items or {}) do
        local newId = Sql.Insert(
            'INSERT INTO `oph3z_phone_group_messages` (`gid`, `from_number`, `type`, `body`, `meta`, `ts`) VALUES (?, ?, ?, ?, ?, ?)',
            {
                trim(group.gid, 32),
                (item.from ~= '' and trim(item.from, 24)) or nil,
                trim(item.type, 16) or 'text',
                item.body and tostring(item.body) or nil,
                Sql.Encode(item.meta),
                Sql.Num(item.ts, 0),
            }
        )
        if newId then
            if item.id then idMap[tostring(item.id)] = newId end
            for number, emoji in pairs(item.reactions or {}) do
                reactions[#reactions + 1] = { newId, trim(number, 24), trim(emoji, 32) }
            end
        end
    end
    insertRows('oph3z_phone_group_reactions', { 'msg_id', 'number', 'emoji' }, reactions)

    rows = {}
    for number, lastId in pairs(group.reads or {}) do
        local mapped = idMap[tostring(lastId)]
        if mapped then
            rows[#rows + 1] = { trim(group.gid, 32), trim(number, 24), mapped }
        end
    end
    insertRows('oph3z_phone_group_reads', { 'gid', 'number', 'last_id' }, rows)
end

local function importTwexa()
    local accounts = readJson(('%s/x/accounts.json'):format(LEGACY))
    local posts = readJson(('%s/x/posts.json'):format(LEGACY))
    local notifs = readJson(('%s/x/notifs.json'):format(LEGACY))

    local follows = {}
    if accounts then
        local rows = {}
        for _, acc in pairs(accounts) do
            if acc and acc.id then
                rows[#rows + 1] = {
                    Sql.Num(acc.id, 0), trim(acc.handle, 32) or '', trim(acc.name, 64),
                    acc.email and tostring(acc.email):lower() or nil,
                    trim(acc.passSalt, 32), trim(acc.passHash, 64), trim(acc.bio, 400),
                    trim(acc.avatar, 512), trim(acc.banner, 512),
                    acc.badge == 'gold' and 'gold' or nil,
                    trim(acc.lastCid, 64), Sql.Num(acc.createdAt, 0),
                }
                for targetId in pairs(acc.following or {}) do
                    follows[#follows + 1] = { Sql.Num(acc.id, 0), Sql.Num(targetId, 0) }
                end
            end
        end
        insertRows('oph3z_phone_twexa_accounts',
            { 'id', 'handle', 'name', 'email', 'pass_salt', 'pass_hash', 'bio', 'avatar', 'banner', 'badge', 'last_cid', 'created_at' }, rows)
        insertRows('oph3z_phone_twexa_follows', { 'follower_id', 'target_id' }, follows)
    end

    if posts then
        local rows, likes, reposts = {}, {}, {}
        for _, p in pairs(posts) do
            if p and p.id then
                rows[#rows + 1] = {
                    Sql.Num(p.id, 0), Sql.Num(p.author, 0), trim(p.text, 800),
                    Sql.Encode(p.media), Sql.Num(p.parentId), Sql.Num(p.rootId),
                    Sql.Num(p.replyCount, 0), Sql.Num(p.createdAt, 0),
                }
                for accId in pairs(p.likes or {}) do
                    likes[#likes + 1] = { Sql.Num(p.id, 0), Sql.Num(accId, 0) }
                end
                for accId, ts in pairs(p.reposts or {}) do
                    reposts[#reposts + 1] = { Sql.Num(p.id, 0), Sql.Num(accId, 0), Sql.Num(ts, 0) }
                end
            end
        end
        table.sort(rows, function(a, b) return (a[1] or 0) < (b[1] or 0) end)
        insertRows('oph3z_phone_twexa_posts',
            { 'id', 'author', 'text', 'media', 'parent_id', 'root_id', 'reply_count', 'created_at' }, rows)
        insertRows('oph3z_phone_twexa_likes', { 'post_id', 'account_id' }, likes)
        insertRows('oph3z_phone_twexa_reposts', { 'post_id', 'account_id', 'ts' }, reposts)
    end

    if notifs then
        local rows = {}
        for accountId, list in pairs(notifs) do
            for i = #list, 1, -1 do
                local n = list[i]
                rows[#rows + 1] = {
                    Sql.Num(accountId, 0), trim(n.type, 16) or 'like',
                    Sql.Num(n.actor), Sql.Num(n.postId), bit(n.read), Sql.Num(n.ts, 0),
                }
            end
        end
        insertRows('oph3z_phone_twexa_notifs', { 'account_id', 'type', 'actor', 'post_id', 'is_read', 'ts' }, rows)
    end
end

local function importMarketplace()
    local listings = readJson(('%s/marketplace/listings.json'):format(LEGACY))
    if not listings then return end

    local rows = {}
    for _, l in pairs(listings) do
        if l and l.id then
            rows[#rows + 1] = {
                Sql.Num(l.id, 0), trim(l.sellerCid, 64) or '', trim(l.category, 16) or 'other',
                trim(l.title, 100) or '', trim(l.desc, 1400), math.floor(Sql.Num(l.price, 0)),
                Sql.Encode(l.media), Sql.Encode(l.seller), bit(l.allowCalls), bit(l.allowMsg),
                Sql.Num(l.createdAt, 0), Sql.Num(l.updatedAt, 0),
            }
        end
    end
    table.sort(rows, function(a, b) return (a[1] or 0) < (b[1] or 0) end)
    insertRows('oph3z_phone_listings',
        { 'id', 'seller_cid', 'category', 'title', 'description', 'price', 'media', 'seller', 'allow_calls', 'allow_msg', 'created_at', 'updated_at' }, rows)
end

function Migrate.Run()
    if Schema.GetMeta(DONE_KEY) then return end

    local numbers = readJson(('%s/_numbers.json'):format(LEGACY))
    local mails = readJson(('%s/_mails.json'):format(LEGACY))

    local citizenids = {}
    for _, cid in pairs(numbers or {}) do
        if type(cid) == 'string' then citizenids[cid] = true end
    end
    for _, cid in pairs(mails or {}) do
        if type(cid) == 'string' then citizenids[cid] = true end
    end

    local hasLegacy = numbers ~= nil or mails ~= nil
        or readJson(('%s/x/accounts.json'):format(LEGACY)) ~= nil
        or readJson(('%s/marketplace/listings.json'):format(LEGACY)) ~= nil

    if not hasLegacy then
        Schema.SetMeta(DONE_KEY, os.time())
        return
    end

    print('^3[oph3z-phone] importing your old JSON data into MySQL. This runs once, do not stop the server.^0')

    local players, groupIds = 0, {}
    for citizenid in pairs(citizenids) do
        local doc = readJson(('%s/%s.json'):format(LEGACY, safeKey(citizenid)))
        if doc then
            local ok, err = pcall(importPlayer, citizenid, doc, groupIds)
            if ok then
                players = players + 1
            else
                print(('^1[oph3z-phone] could not import %s: %s^0'):format(citizenid, tostring(err)))
            end
        end
    end

    local groups = 0
    for gid in pairs(groupIds) do
        local ok = pcall(importGroup, gid)
        if ok then groups = groups + 1 end
    end

    pcall(importTwexa)
    pcall(importMarketplace)

    Schema.SetMeta(DONE_KEY, os.time())
    print(('^2[oph3z-phone] import finished: %d players, %d group chats. Your data/ folder was not touched and can be deleted once you have checked everything.^0')
        :format(players, groups))
end