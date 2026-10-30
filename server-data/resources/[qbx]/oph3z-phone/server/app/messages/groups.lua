local MAX_ITEMS = 200

local function genId()
    return ('%d%04d'):format(os.time(), math.random(0, 9999))
end

local function validGid(gid)
    return type(gid) == 'string' and gid:match('^[%w_-]+$') ~= nil
end

local function selfNumber(cid)
    return DB.NumberOf(cid)
end

local function loadGroup(gid)
    if not validGid(gid) then return nil end

    Sql.Wait()
    local row = Sql.Single(
        'SELECT `gid`, `name`, `photo`, `owner`, `created_at` FROM `oph3z_phone_groups` WHERE `gid` = ?',
        { gid }
    )
    if not row then return nil end

    local group = {
        gid = row.gid,
        name = row.name,
        photo = row.photo,
        owner = row.owner,
        createdAt = row.created_at,
        members = {},
        items = {},
        reads = {},
    }

    for _, m in ipairs(Sql.Query(
        'SELECT `number`, `name`, `joined_at` FROM `oph3z_phone_group_members` WHERE `gid` = ? ORDER BY `joined_at` ASC',
        { gid }
    )) do
        group.members[#group.members + 1] = { number = m.number, name = m.name, joinedAt = m.joined_at }
    end

    local byId = {}
    for _, m in ipairs(Sql.Query(
        'SELECT `id`, `from_number`, `type`, `body`, `meta`, `ts` FROM `oph3z_phone_group_messages` ' ..
        'WHERE `gid` = ? ORDER BY `id` ASC',
        { gid }
    )) do
        local item = {
            id = m.id,
            from = m.from_number or '',
            type = m.type,
            body = m.body,
            meta = Sql.Decode(m.meta, nil),
            ts = m.ts,
        }
        group.items[#group.items + 1] = item
        byId[m.id] = item
    end

    for _, r in ipairs(Sql.Query(
        'SELECT r.`msg_id`, r.`number`, r.`emoji` FROM `oph3z_phone_group_reactions` r ' ..
        'INNER JOIN `oph3z_phone_group_messages` m ON m.`id` = r.`msg_id` WHERE m.`gid` = ?',
        { gid }
    )) do
        local item = byId[r.msg_id]
        if item then
            item.reactions = item.reactions or {}
            item.reactions[r.number] = r.emoji
        end
    end

    for _, r in ipairs(Sql.Query('SELECT `number`, `last_id` FROM `oph3z_phone_group_reads` WHERE `gid` = ?', { gid })) do
        group.reads[r.number] = r.last_id
    end

    return group
end

local function saveGroupRow(group)
    Sql.Execute(
        'UPDATE `oph3z_phone_groups` SET `name` = ?, `photo` = ?, `owner` = ? WHERE `gid` = ?',
        { group.name, group.photo, group.owner, group.gid }
    )
end

local function deleteGroup(gid)
    if not validGid(gid) then return end
    Sql.Execute(
        'DELETE r FROM `oph3z_phone_group_reactions` r INNER JOIN `oph3z_phone_group_messages` m ' ..
        'ON m.`id` = r.`msg_id` WHERE m.`gid` = ?',
        { gid }
    )
    Sql.Execute('DELETE FROM `oph3z_phone_group_messages` WHERE `gid` = ?', { gid })
    Sql.Execute('DELETE FROM `oph3z_phone_group_members` WHERE `gid` = ?', { gid })
    Sql.Execute('DELETE FROM `oph3z_phone_group_reads` WHERE `gid` = ?', { gid })
    Sql.Execute('DELETE FROM `oph3z_phone_groups` WHERE `gid` = ?', { gid })
end

local function addMemberRow(gid, number)
    Sql.Execute(
        'INSERT INTO `oph3z_phone_group_members` (`gid`, `number`, `joined_at`) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `gid` = `gid`',
        { gid, number, os.time() }
    )
end

local function removeMemberRow(gid, number)
    Sql.Execute('DELETE FROM `oph3z_phone_group_members` WHERE `gid` = ? AND `number` = ?', { gid, number })
    Sql.Execute('DELETE FROM `oph3z_phone_group_reads` WHERE `gid` = ? AND `number` = ?', { gid, number })
end

local function setRead(gid, number, lastId)
    Sql.Execute(
        'INSERT INTO `oph3z_phone_group_reads` (`gid`, `number`, `last_id`) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `last_id` = VALUES(`last_id`)',
        { gid, number, lastId }
    )
end

local function memberEntry(group, number)
    for _, m in ipairs(group.members) do
        if m.number == number then return m end
    end
    return nil
end

local function isMember(group, number)
    return memberEntry(group, number) ~= nil
end

local function onlineSrc(number)
    local cid = DB.GetCitizenIdByNumber(number)
    if not cid then return nil, nil end
    local p = GetPlayerByCitizenId(cid)
    return p and p.PlayerData.source or nil, cid
end

local function resolvePerson(viewerCid, number, snapshotName)
    local contact = DB.ResolveContact(viewerCid, number)
    if contact then
        return contact.name, contact.img
    end
    return snapshotName or DB.FormatNumber(number), nil
end

local function broadcast(group, item)
    local preview = item.body or ''
    if item.type == 'image' then preview = '📷 Photo'
    elseif item.type == 'gif' then preview = '🎞️ GIF'
    elseif item.type == 'video' then preview = '📹 Video'
    elseif item.type == 'voice' then preview = '🎤 Voice message'
    elseif item.type == 'location' then preview = '📍 Location'
    elseif item.type == 'system' then preview = item.body end

    for _, m in ipairs(group.members) do
        if m.number ~= item.from then
            local src, cid = onlineSrc(m.number)
            local senderName = item.from ~= '' and select(1, resolvePerson(cid or '', item.from, nil)) or ''
            if src then
                TriggerClientEvent('oph3z-phone:client:groups:incoming', src, {
                    gid = group.gid,
                    name = group.name,
                    photo = group.photo,
                    msg = item,
                    senderName = senderName,
                })
            end

            if cid and Notif and item.type ~= 'system' then
                Notif.Push(cid, {
                    app = 'message',
                    title = group.name,
                    body = senderName ~= '' and (senderName .. ': ' .. preview) or preview,
                    route = { app = 'message', gid = group.gid },
                })
            end
        end
    end
end

local function appendItem(group, from, mtype, body, meta)
    Sql.Wait()
    local ts = os.time()
    local id = Sql.Insert(
        'INSERT INTO `oph3z_phone_group_messages` (`gid`, `from_number`, `type`, `body`, `meta`, `ts`) VALUES (?, ?, ?, ?, ?, ?)',
        { group.gid, from ~= '' and from or nil, mtype, body, Sql.Encode(meta), ts }
    )
    if not id then return nil end

    Sql.Execute(
        'DELETE FROM `oph3z_phone_group_messages` WHERE `gid` = ? AND `id` NOT IN ' ..
        '(SELECT `id` FROM (SELECT `id` FROM `oph3z_phone_group_messages` WHERE `gid` = ? ORDER BY `id` DESC LIMIT ?) AS keep)',
        { group.gid, group.gid, MAX_ITEMS }
    )

    local item = { id = id, from = from, type = mtype, body = body, meta = meta, ts = ts }
    group.items[#group.items + 1] = item
    if from ~= '' then
        group.reads[from] = id
        setRead(group.gid, from, id)
    end
    broadcast(group, item)
    return item
end

local function pushSystem(group, text)
    return appendItem(group, '', 'system', text, nil)
end

local groupShares = {}

local function applyGroupLive(items)
    for _, m in ipairs(items) do
        if m.type == 'location' and m.meta and m.meta.sid then
            local sh = groupShares[m.meta.sid]
            if sh then
                m.meta.x = sh.lastX
                m.meta.y = sh.lastY
                m.meta.label = sh.lastLabel or m.meta.label
                m.meta.live = true
            end
        end
    end
    return items
end

local function serializeMembers(group, viewerCid)
    local out = {}
    for _, m in ipairs(group.members) do
        local name, avatar = resolvePerson(viewerCid, m.number, m.name)
        out[#out + 1] = {
            number = m.number,
            name = name,
            avatar = avatar,
            isOwner = (group.owner == m.number),
            lastReadId = group.reads[m.number] or nil,
        }
    end
    return out
end

local function serializeItems(group, viewerCid, myNumber)
    applyGroupLive(group.items)
    local out = {}
    for _, m in ipairs(group.items) do
        local senderName, senderAvatar
        if m.type ~= 'system' and m.from ~= '' then
            senderName, senderAvatar = resolvePerson(viewerCid, m.from, nil)
        end
        out[#out + 1] = {
            id = m.id, from = m.from, mine = (m.from == myNumber),
            type = m.type, body = m.body, meta = m.meta, ts = m.ts,
            reactions = m.reactions, senderName = senderName, senderAvatar = senderAvatar,
        }
    end
    return out
end

Groups = Groups or {}

function Groups.ListForThreads(cid)
    local myNumber = selfNumber(cid)
    if myNumber == '' then return {} end

    Sql.Wait()
    local summaries = Sql.Query(
        'SELECT g.`gid`, g.`name`, g.`photo`, g.`created_at`, ' ..
        '(SELECT COUNT(*) FROM `oph3z_phone_group_members` c WHERE c.`gid` = g.`gid`) AS `member_count`, ' ..
        'l.`from_number` AS `last_from`, l.`type` AS `last_type`, l.`body` AS `last_body`, l.`ts` AS `last_ts`, ' ..
        '(SELECT COUNT(*) FROM `oph3z_phone_group_messages` u WHERE u.`gid` = g.`gid` ' ..
        'AND u.`type` <> \'system\' AND u.`from_number` IS NOT NULL AND u.`from_number` <> ? ' ..
        'AND u.`id` > COALESCE(r.`last_id`, 0)) AS `unread` ' ..
        'FROM `oph3z_phone_groups` g ' ..
        'INNER JOIN `oph3z_phone_group_members` m ON m.`gid` = g.`gid` AND m.`number` = ? ' ..
        'LEFT JOIN `oph3z_phone_group_reads` r ON r.`gid` = g.`gid` AND r.`number` = ? ' ..
        'LEFT JOIN `oph3z_phone_group_messages` l ON l.`id` = ' ..
        '(SELECT MAX(x.`id`) FROM `oph3z_phone_group_messages` x WHERE x.`gid` = g.`gid`)',
        { myNumber, myNumber, myNumber }
    )

    local rows = {}
    for _, s in ipairs(summaries) do
        local lastFrom = s.last_from or ''
        local lastSender
        if s.last_type and s.last_type ~= 'system' and lastFrom ~= '' and lastFrom ~= myNumber then
            lastSender = select(1, resolvePerson(cid, lastFrom, nil))
        end

        rows[#rows + 1] = {
            isGroup = true,
            gid = s.gid,
            name = s.name,
            photo = s.photo,
            members = tonumber(s.member_count) or 0,
            lastType = s.last_type or 'text',
            lastBody = s.last_body or '',
            lastDir = (lastFrom == myNumber) and 'out' or 'in',
            lastSender = lastSender,
            lastTs = s.last_ts or s.created_at or 0,
            unread = tonumber(s.unread) or 0,
        }
    end
    return rows
end

RegisterCallback('oph3z-phone:server:groups:create', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' then return nil end

    local myNumber = selfNumber(cid)
    if myNumber == '' then return nil end

    local name = tostring(input.name or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = 'New Group' end
    name = name:sub(1, 64)

    local seen = { [myNumber] = true }
    local numbers = { myNumber }
    if type(input.members) == 'table' then
        for _, raw in ipairs(input.members) do
            local d = DB.Digits(raw)
            if d ~= '' and not seen[d] then
                seen[d] = true
                numbers[#numbers + 1] = d
            end
        end
    end
    if #numbers < 2 then return nil end

    Sql.Wait()
    local gid = 'g' .. genId()
    local photo = type(input.photo) == 'string' and input.photo ~= '' and input.photo or nil

    Sql.Execute(
        'INSERT INTO `oph3z_phone_groups` (`gid`, `name`, `photo`, `owner`, `created_at`) VALUES (?, ?, ?, ?, ?)',
        { gid, name, photo, myNumber, os.time() }
    )
    for _, number in ipairs(numbers) do addMemberRow(gid, number) end

    local group = loadGroup(gid)
    if not group then return nil end

    pushSystem(group, 'Group created')
    for _, number in ipairs(numbers) do
        if number ~= myNumber then
            local _, mcid = onlineSrc(number)
            mcid = mcid or DB.GetCitizenIdByNumber(number)
            if mcid and Notif then
                Notif.Push(mcid, {
                    app = 'message',
                    title = group.name,
                    bodyKey = 'notify.addedToGroup',
                    route = { app = 'message', gid = group.gid },
                })
            end
        end
    end

    return { gid = group.gid }
end)

local function markGroupRead(group, myNumber)
    local last = group.items[#group.items]
    if not last or group.reads[myNumber] == last.id then return end

    group.reads[myNumber] = last.id
    setRead(group.gid, myNumber, last.id)
    for _, m in ipairs(group.members) do
        if m.number ~= myNumber then
            local s = onlineSrc(m.number)
            if s then
                TriggerClientEvent('oph3z-phone:client:groups:read', s,
                    { gid = group.gid, number = myNumber, lastReadId = last.id })
            end
        end
    end
end

RegisterCallback('oph3z-phone:server:groups:open', function(src, input)
    local cid = DB.GetCitizenId(src)
    local gid = input and input.gid
    if not cid or not gid then return nil end

    local group = loadGroup(gid)
    if not group then return nil end
    local myNumber = selfNumber(cid)
    if not isMember(group, myNumber) then return nil end

    markGroupRead(group, myNumber)

    return {
        gid = group.gid,
        name = group.name,
        photo = group.photo,
        owner = group.owner,
        isOwner = (group.owner == myNumber),
        selfNumber = myNumber,
        members = serializeMembers(group, cid),
        items = serializeItems(group, cid, myNumber),
    }
end)

RegisterCallback('oph3z-phone:server:groups:send', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' or not input.gid then return nil end

    local group = loadGroup(input.gid)
    if not group then return nil end
    local myNumber = selfNumber(cid)
    if not isMember(group, myNumber) then return nil end

    local mtype = tostring(input.type or 'text')
    local meta = type(input.meta) == 'table' and input.meta or nil
    local item = appendItem(group, myNumber, mtype, tostring(input.body or ''), meta)
    if not item then return nil end

    return {
        id = item.id, from = myNumber, mine = true, type = item.type,
        body = item.body, meta = item.meta, ts = item.ts,
    }
end)

RegisterCallback('oph3z-phone:server:groups:read', function(src, input)
    local cid = DB.GetCitizenId(src)
    local gid = input and input.gid
    if not cid or not gid then return false end
    local group = loadGroup(gid)
    if not group then return false end
    markGroupRead(group, selfNumber(cid))
    return true
end)

RegisterCallback('oph3z-phone:server:groups:react', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' or not input.gid or not input.id then return false end
    local group = loadGroup(input.gid)
    if not group then return false end
    local myNumber = selfNumber(cid)
    if not isMember(group, myNumber) then return false end

    local target
    for _, m in ipairs(group.items) do
        if m.id == input.id then target = m; break end
    end
    if not target then return false end

    target.reactions = target.reactions or {}
    local emoji = input.emoji
    if not emoji or emoji == '' or target.reactions[myNumber] == emoji then
        target.reactions[myNumber] = nil
        Sql.Execute(
            'DELETE FROM `oph3z_phone_group_reactions` WHERE `msg_id` = ? AND `number` = ?',
            { target.id, myNumber }
        )
    else
        target.reactions[myNumber] = tostring(emoji):sub(1, 32)
        Sql.Execute(
            'INSERT INTO `oph3z_phone_group_reactions` (`msg_id`, `number`, `emoji`) VALUES (?, ?, ?) ' ..
            'ON DUPLICATE KEY UPDATE `emoji` = VALUES(`emoji`)',
            { target.id, myNumber, target.reactions[myNumber] }
        )
    end

    for _, m in ipairs(group.members) do
        local s = onlineSrc(m.number)
        if s then
            TriggerClientEvent('oph3z-phone:client:groups:react', s, {
                gid = input.gid, id = input.id, number = myNumber,
                emoji = target.reactions[myNumber] or false,
            })
        end
    end
    return true
end)

RegisterCallback('oph3z-phone:server:groups:manage', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' or not input.gid then return { ok = false } end

    local group = loadGroup(input.gid)
    if not group then return { ok = false, reason = 'gone' } end
    local myNumber = selfNumber(cid)
    if not isMember(group, myNumber) then return { ok = false, reason = 'member' } end

    local myName = select(1, resolvePerson(cid, myNumber, nil))
    local action = input.action

    if action == 'add' and type(input.members) == 'table' then
        for _, raw in ipairs(input.members) do
            local d = DB.Digits(raw)
            if d ~= '' and not isMember(group, d) then
                addMemberRow(group.gid, d)
                group.members[#group.members + 1] = { number = d, joinedAt = os.time() }
                local _, mcid = onlineSrc(d)
                mcid = mcid or DB.GetCitizenIdByNumber(d)
                if mcid and Notif then
                    Notif.Push(mcid, {
                        app = 'message', title = group.name,
                        bodyKey = 'notify.addedToGroup',
                        route = { app = 'message', gid = group.gid },
                    })
                end
            end
        end
        pushSystem(group, myName .. ' added new members')

    elseif action == 'remove' and input.number then
        local d = DB.Digits(input.number)
        if group.owner ~= myNumber then return { ok = false, reason = 'owner' } end
        if d == group.owner then return { ok = false, reason = 'owner' } end
        local entry = memberEntry(group, d)
        local removedName = select(1, resolvePerson(cid, d, entry and entry.name))

        removeMemberRow(group.gid, d)
        local out = {}
        for _, m in ipairs(group.members) do
            if m.number ~= d then out[#out + 1] = m end
        end
        group.members = out

        pushSystem(group, removedName .. ' was removed')
        local s = onlineSrc(d)
        if s then TriggerClientEvent('oph3z-phone:client:groups:removed', s, { gid = group.gid }) end

    elseif action == 'leave' then
        removeMemberRow(group.gid, myNumber)
        local out = {}
        for _, m in ipairs(group.members) do
            if m.number ~= myNumber then out[#out + 1] = m end
        end
        group.members = out

        if #group.members == 0 then
            deleteGroup(group.gid)
            return { ok = true, left = true }
        end

        if group.owner == myNumber then
            group.owner = group.members[1].number
            saveGroupRow(group)
        end
        pushSystem(group, myName .. ' left the group')
        return { ok = true, left = true }

    elseif action == 'rename' then
        local name = tostring(input.name or ''):gsub('^%s+', ''):gsub('%s+$', '')
        if name == '' then return { ok = false, reason = 'name' } end
        group.name = name:sub(1, 64)
        saveGroupRow(group)
        pushSystem(group, myName .. ' named the group "' .. group.name .. '"')

    elseif action == 'setphoto' then
        group.photo = type(input.photo) == 'string' and input.photo ~= '' and input.photo or nil
        saveGroupRow(group)
        pushSystem(group, myName .. ' changed the group photo')

    elseif action == 'delete' then
        if group.owner ~= myNumber then return { ok = false, reason = 'owner' } end
        for _, m in ipairs(group.members) do
            if m.number ~= myNumber then
                local s = onlineSrc(m.number)
                if s then TriggerClientEvent('oph3z-phone:client:groups:removed', s, { gid = group.gid }) end
            end
        end
        deleteGroup(group.gid)
        return { ok = true, deleted = true }

    else
        return { ok = false, reason = 'action' }
    end

    return {
        ok = true,
        group = {
            gid = group.gid, name = group.name, photo = group.photo, owner = group.owner,
            isOwner = (group.owner == myNumber), selfNumber = myNumber,
            members = serializeMembers(group, cid),
            items = serializeItems(group, cid, myNumber),
        },
    }
end)

local function pushGroupLoc(group, data)
    for _, m in ipairs(group.members) do
        local s = onlineSrc(m.number)
        if s then TriggerClientEvent('oph3z-phone:client:groups:locupdate', s, data) end
    end
end

local function endGroupShare(sid, reason)
    local sh = groupShares[sid]
    if not sh then return end
    groupShares[sid] = nil

    local group = loadGroup(sh.gid)
    if not group then return end

    for _, item in ipairs(group.items) do
        if item.id == sh.id then
            item.meta = item.meta or {}
            item.meta.x, item.meta.y, item.meta.label = sh.lastX, sh.lastY, sh.lastLabel
            item.meta.live = false
            item.meta.endReason = reason or 'expired'
            Sql.Execute('UPDATE `oph3z_phone_group_messages` SET `meta` = ? WHERE `id` = ?',
                { json.encode(item.meta), item.id })
            break
        end
    end

    pushGroupLoc(group, {
        gid = sh.gid, id = sh.id, x = sh.lastX, y = sh.lastY,
        label = sh.lastLabel, live = false, endReason = reason or 'expired',
    })
    local sSrc = onlineSrc(sh.senderNumber)
    if sSrc then TriggerClientEvent('oph3z-phone:client:loc:stop', sSrc, { sid = sid }) end
end

RegisterCallback('oph3z-phone:server:groups:location', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' or not input.gid then return false end
    local group = loadGroup(input.gid)
    if not group then return false end
    local myNumber = selfNumber(cid)
    if not isMember(group, myNumber) then return false end

    local x = tonumber(input.x) or 0.0
    local y = tonumber(input.y) or 0.0
    local label = tostring(input.label or 'Shared Location')
    local live = input.live and true or false
    local meta = { x = x, y = y, label = label, live = live }

    if live then meta.sid = 'g' .. genId() end
    local item = appendItem(group, myNumber, 'location', label, meta)
    if not item then return false end

    if live then
        groupShares[meta.sid] = {
            gid = group.gid, senderNumber = myNumber, senderSrc = src,
            id = item.id, lastX = x, lastY = y, lastLabel = label,
        }
    end

    return {
        id = item.id, from = myNumber, mine = true, type = 'location',
        body = item.body, meta = item.meta, ts = item.ts,
    }
end)

RegisterNetEvent('oph3z-phone:server:groups:locupdate', function(sid, x, y, label)
    local src = source
    local sh = groupShares[sid]
    if not sh or sh.senderSrc ~= src then return end
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return end
    sh.lastX, sh.lastY, sh.lastLabel = x, y, label or sh.lastLabel
    local group = loadGroup(sh.gid)
    if group then
        pushGroupLoc(group, { gid = sh.gid, id = sh.id, x = x, y = y, label = label })
    end
end)

RegisterCallback('oph3z-phone:server:groups:locstop', function(src, input)
    local cid = DB.GetCitizenId(src)
    local sid = input and input.sid
    if not sid then return { ok = false } end
    local sh = groupShares[sid]
    if sh and DB.GetCitizenIdByNumber(sh.senderNumber) ~= cid then return { ok = false } end
    endGroupShare(sid, (input and input.reason) or 'stopped')
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local src = source
    for sid, sh in pairs(groupShares) do
        if sh.senderSrc == src then endGroupShare(sid, 'expired') end
    end
end)