local MAX_MAILBOX = 100

local function cidOf(src)
    return GetIdentifier(src)
end

local function clean(value, maxLen)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if #value > maxLen then value = value:sub(1, maxLen) end
    return value
end

local function cleanAttachments(list)
    if type(list) ~= 'table' then return nil end
    local out = {}
    for _, a in ipairs(list) do
        if type(a) == 'table' and a.url then
            out[#out + 1] = {
                url = tostring(a.url):sub(1, 512),
                type = (a.type == 'video') and 'video' or 'image',
                thumb = a.thumb and tostring(a.thumb):sub(1, 512) or nil,
            }
            if #out >= 6 then break end
        end
    end
    if #out == 0 then return nil end
    return out
end

local function trimMailbox(citizenid, folder)
    Sql.Execute(
        'DELETE FROM `oph3z_phone_mail` WHERE `citizenid` = ? AND `folder` = ? AND `id` NOT IN ' ..
        '(SELECT `id` FROM (SELECT `id` FROM `oph3z_phone_mail` WHERE `citizenid` = ? AND `folder` = ? ORDER BY `id` DESC LIMIT ?) AS keep)',
        { citizenid, folder, citizenid, folder, MAX_MAILBOX }
    )
end

local function listFolder(citizenid, folder)
    local rows = Sql.Query(
        'SELECT `id`, `addr`, `addr_name`, `subject`, `body`, `attachments`, `is_system`, `is_read`, `ts` ' ..
        'FROM `oph3z_phone_mail` WHERE `citizenid` = ? AND `folder` = ? ORDER BY `id` DESC LIMIT ?',
        { citizenid, folder, MAX_MAILBOX }
    )
    local out = {}
    for _, row in ipairs(rows) do
        local item = {
            id          = row.id,
            subject     = row.subject,
            body        = row.body,
            attachments = Sql.Decode(row.attachments, nil),
            ts          = row.ts,
        }
        if folder == 'sent' then
            item.to = row.addr
            item.toName = row.addr_name
        else
            item.from = row.addr
            item.fromName = row.addr_name
            item.system = Sql.Bool(row.is_system)
            item.read = Sql.Bool(row.is_read)
        end
        out[#out + 1] = item
    end
    return out
end

local function nameOf(cid)
    local player = DB.Player(cid)
    return player and player.name or nil
end

local function deliverToInbox(recipCid, mail)
    Sql.Wait()
    local item = {
        from        = mail.from,
        fromName    = mail.fromName,
        subject     = mail.subject,
        body        = mail.body,
        attachments = mail.attachments,
        system      = mail.system or false,
        read        = false,
        ts          = os.time(),
    }
    item.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_mail` (`citizenid`, `folder`, `addr`, `addr_name`, `subject`, `body`, `attachments`, `is_system`, `is_read`, `ts`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)',
        {
            recipCid, 'inbox', item.from, item.fromName, item.subject, item.body,
            Sql.Encode(item.attachments), item.system and 1 or 0, item.ts,
        }
    )
    if not item.id then return nil end
    trimMailbox(recipCid, 'inbox')

    local player = GetPlayerByCitizenId(recipCid)
    if player then
        TriggerClientEvent('oph3z-phone:client:mail:incoming', player.PlayerData.source, item)
    end
    if Notif then
        Notif.Push(recipCid, {
            app   = 'mail',
            title = item.fromName or item.from or 'Mail',
            body  = (item.subject ~= '' and item.subject) or item.body or '',
            route = { app = 'mail', id = item.id },
        })
    end
    return item
end

RegisterCallback('oph3z-phone:server:mail:get', function(src)
    local cid = cidOf(src)
    if not cid then return {} end

    local player = DB.Player(cid)
    if not player then return {} end

    Sql.Wait()
    return {
        address = player.mail,
        inbox   = listFolder(cid, 'inbox'),
        sent    = listFolder(cid, 'sent'),
    }
end)

RegisterCallback('oph3z-phone:server:mail:send', function(src, data)
    local cid = cidOf(src)
    if not cid or type(data) ~= 'table' then return { ok = false, reason = 'bad' } end

    local toAddr = clean(data.to, 120):lower()
    local subject = clean(data.subject, 140)
    local body = clean(data.body, 5000)
    local attachments = cleanAttachments(data.attachments)
    if toAddr == '' then return { ok = false, reason = 'noaddr' } end
    if subject == '' and body == '' and not attachments then return { ok = false, reason = 'empty' } end

    local recipCid = DB.GetCitizenIdByMail(toAddr)
    if not recipCid then return { ok = false, reason = 'notfound' } end

    local sender = DB.Player(cid)
    if not sender then return { ok = false, reason = 'bad' } end

    local fromAddr = sender.mail
    local fromName = sender.name or fromAddr

    Sql.Wait()
    local sentItem = {
        to          = toAddr,
        toName      = nameOf(recipCid) or toAddr,
        subject     = subject,
        body        = body,
        attachments = attachments,
        ts          = os.time(),
    }
    sentItem.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_mail` (`citizenid`, `folder`, `addr`, `addr_name`, `subject`, `body`, `attachments`, `is_system`, `is_read`, `ts`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, 0, 1, ?)',
        { cid, 'sent', sentItem.to, sentItem.toName, subject, body, Sql.Encode(attachments), sentItem.ts }
    )
    trimMailbox(cid, 'sent')

    deliverToInbox(recipCid, {
        from = fromAddr, fromName = fromName,
        subject = subject, body = body, attachments = attachments, system = false,
    })

    return { ok = true, sent = sentItem }
end)

RegisterCallback('oph3z-phone:server:mail:read', function(src, id)
    local cid = cidOf(src)
    if not cid then return false end

    Sql.Wait()
    Sql.Execute(
        'UPDATE `oph3z_phone_mail` SET `is_read` = 1 WHERE `citizenid` = ? AND `id` = ?',
        { cid, id }
    )
    return true
end)

RegisterCallback('oph3z-phone:server:mail:delete', function(src, data)
    local cid = cidOf(src)
    if not cid or type(data) ~= 'table' then return false end

    Sql.Wait()
    Sql.Execute(
        'DELETE FROM `oph3z_phone_mail` WHERE `citizenid` = ? AND `folder` = ? AND `id` = ?',
        { cid, (data.folder == 'sent') and 'sent' or 'inbox', data.id }
    )
    return true
end)

Mail = Mail or {}

function Mail.SendSystem(recipCid, opts)
    if not recipCid or type(opts) ~= 'table' then return nil end
    return deliverToInbox(recipCid, {
        from        = opts.fromAddress and clean(tostring(opts.fromAddress), 120) or 'system',
        fromName    = clean(opts.from or 'System', 60),
        subject     = clean(opts.subject or '', 140),
        body        = clean(opts.body or '', 5000),
        attachments = cleanAttachments(opts.attachments),
        system      = true,
    })
end