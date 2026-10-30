local MAX_THREAD_ITEMS = 200
local TRIM_EVERY = 25

local function genId()
    return ('%d%04d'):format(os.time(), math.random(0, 9999))
end

local liveShares = {}

local function hydrate(rows)
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = {
            id   = row.msg_id,
            dir  = row.direction,
            type = row.type,
            body = row.body,
            meta = Sql.Decode(row.meta, nil),
            ts   = row.ts,
            read = Sql.Bool(row.is_read),
        }
    end
    return out
end

local function applyLivePositions(items)
    for _, m in ipairs(items) do
        if m.type == 'location' and m.meta and m.meta.sid then
            local sh = liveShares[m.meta.sid]
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

local function threadItems(citizenid, thread)
    local rows = Sql.Query(
        'SELECT `msg_id`, `direction`, `type`, `body`, `meta`, `ts`, `is_read` FROM `oph3z_phone_messages` ' ..
        'WHERE `citizenid` = ? AND `thread` = ? ORDER BY `id` DESC LIMIT ?',
        { citizenid, thread, MAX_THREAD_ITEMS }
    )
    local ordered = {}
    for i = #rows, 1, -1 do ordered[#ordered + 1] = rows[i] end
    return hydrate(ordered)
end

local function markThreadRead(citizenid, thread)
    Sql.Execute(
        'UPDATE `oph3z_phone_messages` SET `is_read` = 1 WHERE `citizenid` = ? AND `thread` = ? AND `is_read` = 0',
        { citizenid, thread }
    )
end

local function appendToThread(citizenid, thread, msg)
    Sql.Execute(
        'INSERT INTO `oph3z_phone_messages` (`citizenid`, `thread`, `msg_id`, `direction`, `type`, `body`, `meta`, `ts`, `is_read`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            citizenid, thread, msg.id, msg.dir, msg.type, msg.body,
            Sql.Encode(msg.meta), msg.ts, msg.read and 1 or 0,
        }
    )
    if math.random(TRIM_EVERY) == 1 then
        Sql.Execute(
            'DELETE FROM `oph3z_phone_messages` WHERE `citizenid` = ? AND `thread` = ? AND `id` NOT IN ' ..
            '(SELECT `id` FROM (SELECT `id` FROM `oph3z_phone_messages` WHERE `citizenid` = ? AND `thread` = ? ORDER BY `id` DESC LIMIT ?) AS keep)',
            { citizenid, thread, citizenid, thread, MAX_THREAD_ITEMS }
        )
    end
end

local function findMsg(citizenid, thread, msgId)
    local row = Sql.Single(
        'SELECT `id`, `direction`, `type`, `meta` FROM `oph3z_phone_messages` ' ..
        'WHERE `citizenid` = ? AND `thread` = ? AND `msg_id` = ? LIMIT 1',
        { citizenid, thread, tostring(msgId) }
    )
    if not row then return nil end
    row.meta = Sql.Decode(row.meta, {})
    return row
end

local function patchMeta(citizenid, thread, msgId, patch)
    local row = findMsg(citizenid, thread, msgId)
    if not row then return false end
    for key, value in pairs(patch) do
        row.meta[key] = value
    end
    Sql.Execute('UPDATE `oph3z_phone_messages` SET `meta` = ? WHERE `id` = ?', { json.encode(row.meta), row.id })
    return true
end

RegisterCallback('oph3z-phone:server:messages:threads', function(src)
    local cid = DB.GetCitizenId(src)
    if not cid then return {} end

    Sql.Wait()
    local rows = Sql.Query(
        'SELECT m.`thread`, m.`type`, m.`body`, m.`direction`, m.`ts`, ' ..
        '(SELECT COUNT(*) FROM `oph3z_phone_messages` u WHERE u.`citizenid` = m.`citizenid` ' ..
        'AND u.`thread` = m.`thread` AND u.`direction` = \'in\' AND u.`is_read` = 0) AS `unread` ' ..
        'FROM `oph3z_phone_messages` m INNER JOIN ' ..
        '(SELECT `thread`, MAX(`id`) AS `mid` FROM `oph3z_phone_messages` WHERE `citizenid` = ? GROUP BY `thread`) t ' ..
        'ON t.`thread` = m.`thread` AND t.`mid` = m.`id` WHERE m.`citizenid` = ?',
        { cid, cid }
    )

    local out = {}
    for _, row in ipairs(rows) do
        local contact = DB.ResolveContact(cid, row.thread)
        out[#out + 1] = {
            number   = row.thread,
            name     = contact and contact.name or DB.FormatNumber(row.thread),
            avatar   = contact and contact.img or nil,
            lastType = row.type or 'text',
            lastBody = row.body or '',
            lastDir  = row.direction or 'out',
            lastTs   = row.ts or 0,
            unread   = tonumber(row.unread) or 0,
        }
    end

    if Groups then
        for _, row in ipairs(Groups.ListForThreads(cid)) do
            out[#out + 1] = row
        end
    end

    table.sort(out, function(a, b) return (a.lastTs or 0) > (b.lastTs or 0) end)
    return out
end)

RegisterCallback('oph3z-phone:server:messages:open', function(src, input)
    local cid = DB.GetCitizenId(src)
    local number = DB.Digits(input and input.number)
    if not cid or number == '' then return nil end

    Sql.Wait()
    local items = threadItems(cid, number)
    markThreadRead(cid, number)

    local contact = DB.ResolveContact(cid, number)
    return {
        number = number,
        name   = contact and contact.name or DB.FormatNumber(number),
        avatar = contact and contact.img or nil,
        items  = applyLivePositions(items),
    }
end)

RegisterCallback('oph3z-phone:server:messages:delete', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' or type(input.numbers) ~= 'table' then return false end

    Sql.Wait()
    for _, number in ipairs(input.numbers) do
        Sql.Execute(
            'DELETE FROM `oph3z_phone_messages` WHERE `citizenid` = ? AND `thread` = ?',
            { cid, DB.Digits(number) }
        )
    end
    return true
end)

RegisterCallback('oph3z-phone:server:messages:read', function(src, input)
    local cid = DB.GetCitizenId(src)
    local number = DB.Digits(input and input.number)
    if not cid or number == '' then return false end

    Sql.Wait()
    markThreadRead(cid, number)
    return true
end)

local function notifBody(mtype, body, meta, lang)
    if mtype == 'image' then return Lang('notify.msg.photo', lang)
    elseif mtype == 'gif' then return Lang('notify.msg.gif', lang)
    elseif mtype == 'video' then return Lang('notify.msg.video', lang)
    elseif mtype == 'voice' then return Lang('notify.msg.voice', lang)
    elseif mtype == 'location' then return Lang('notify.msg.location', lang)
    elseif mtype == 'money' then return Lang('notify.msg.received', lang):format(meta and meta.amount or body)
    elseif mtype == 'request' then return Lang('notify.msg.requested', lang):format(meta and meta.amount or body)
    elseif mtype == 'contact' then return Lang('notify.msg.contact', lang):format((meta and meta.name) or Lang('notify.msg.contactFallback', lang))
    elseif mtype == 'appshare' then return (meta and meta.title) or Lang('notify.msg.shared', lang)
    else return body end
end

local function deliver(senderCid, toDigits, mtype, body, meta)
    local id = genId()
    local ts = os.time()

    Sql.Wait()
    local sender = DB.Player(senderCid)
    if not sender then return nil end
    local senderNumber = DB.Digits(sender.numberRaw)

    appendToThread(senderCid, toDigits, { id = id, dir = 'out', type = mtype, body = body, meta = meta, ts = ts, read = true })

    local recipCid = DB.GetCitizenIdByNumber(toDigits)
    if recipCid and recipCid ~= senderCid then
        if not DB.IsBlocked(recipCid, senderNumber) then
            local inMsg = { id = id, dir = 'in', type = mtype, body = body, meta = meta, ts = ts, read = false }
            appendToThread(recipCid, senderNumber, inMsg)

            local contact = DB.ResolveContact(recipCid, senderNumber)
            local senderName = contact and contact.name or DB.FormatNumber(senderNumber)
            local recipSettings = DB.Settings(recipCid)

            local recipPlayer = not recipSettings.airplane and GetPlayerByCitizenId(recipCid) or nil
            if recipPlayer then
                TriggerClientEvent('oph3z-phone:client:messages:incoming', recipPlayer.PlayerData.source, {
                    from   = senderNumber,
                    name   = senderName,
                    avatar = contact and contact.img or nil,
                    msg    = inMsg,
                })
            end

            if Notif then
                Notif.Push(recipCid, {
                    app   = 'message',
                    title = senderName,
                    body  = notifBody(mtype, body, meta, recipSettings.language),
                    route = { app = 'message', number = senderNumber },
                })
            end
        end
    end

    return { id = id, dir = 'out', type = mtype, body = body, meta = meta, ts = ts, read = true }
end

Messages = Messages or {}
function Messages.Send(senderCid, toNumber, mtype, body, meta)
    if not senderCid then return nil end
    local toDigits = DB.Digits(toNumber)
    if toDigits == '' then return nil end
    return deliver(senderCid, toDigits, tostring(mtype or 'text'), tostring(body or ''),
        type(meta) == 'table' and meta or nil)
end

-- Texts to 911 / 311 become ps-dispatch calls (911 -> police, 311 -> EMS).
-- The message still lands in the sender's thread so they can see what they sent.
local EMERGENCY_NUMBERS = { ['911'] = true, ['311'] = true }

local function relayEmergency(src, cid, toDigits, mtype, body)
    if not EMERGENCY_NUMBERS[toDigits] or mtype ~= 'text' then return end
    if GetResourceState('ps-dispatch') ~= 'started' then return end
    body = body:gsub('^%s+', ''):gsub('%s+$', '')
    if body == '' then return end
    -- ps-dispatch builds the alert client-side (position, street, phone check,
    -- cooldown), the same path as its /911 and /311 commands.
    TriggerClientEvent('ps-dispatch:client:sendEmergencyMsg', src, body, toDigits, false,
        { fromPhone = true, number = DB.NumberOf(cid) })
end

RegisterCallback('oph3z-phone:server:messages:send', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' then return nil end
    local toDigits = DB.Digits(input.to)
    if toDigits == '' then return nil end
    local mtype, body = tostring(input.type or 'text'), tostring(input.body or '')
    relayEmergency(src, cid, toDigits, mtype, body)
    return deliver(cid, toDigits, mtype, body,
        type(input.meta) == 'table' and input.meta or nil)
end)

RegisterCallback('oph3z-phone:server:messages:money', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid then return { ok = false, reason = 'error' } end

    local amount = math.floor(tonumber(input and input.amount) or 0)
    if amount <= 0 then return { ok = false, reason = 'amount' } end

    local toDigits = DB.Digits(input and input.to)
    local recipCid = toDigits ~= '' and DB.GetCitizenIdByNumber(toDigits) or nil
    if not recipCid or recipCid == cid then return { ok = false, reason = 'recipient' } end

    if not GetSourceById(recipCid) then return { ok = false, reason = 'offline' } end

    if Bank.Get(cid) < amount then return { ok = false, reason = 'funds' } end
    if not Bank.Remove(cid, amount, 'phone-transfer') then
        return { ok = false, reason = 'funds' }
    end
    Bank.Add(recipCid, amount, 'phone-transfer')

    local outMsg = deliver(cid, toDigits, 'money', tostring(amount), { amount = amount })
    return { ok = true, msg = outMsg }
end)

local function setStatusBoth(myCid, otherNumber, otherCid, myNumber, id, status)
    patchMeta(myCid, otherNumber, id, { status = status })
    if otherCid then
        patchMeta(otherCid, myNumber, id, { status = status })
    end
end

local function pushStatus(cid, number, id, status)
    if not cid then return end
    local player = GetPlayerByCitizenId(cid)
    if player then
        TriggerClientEvent('oph3z-phone:client:messages:update', player.PlayerData.source,
            { number = number, id = id, status = status })
    end
end

RegisterCallback('oph3z-phone:server:messages:request', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid then return nil end
    local toDigits = DB.Digits(input and input.to)
    local amount = math.floor(tonumber(input and input.amount) or 0)
    if toDigits == '' or amount <= 0 then return nil end

    local myNumber = DB.NumberOf(cid)
    return deliver(cid, toDigits, 'request', tostring(amount),
        { amount = amount, status = 'pending', payer = toDigits, payee = myNumber })
end)

RegisterCallback('oph3z-phone:server:messages:negotiate', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' then return { ok = false, reason = 'error' } end
    local otherNumber = DB.Digits(input.number)
    local id = input.id
    if otherNumber == '' or not id then return { ok = false, reason = 'error' } end

    Sql.Wait()
    local myNumber = DB.NumberOf(cid)
    local msg = findMsg(cid, otherNumber, id)
    if not msg or msg.type ~= 'request' or msg.direction ~= 'in' then return { ok = false, reason = 'gone' } end
    if msg.meta.status ~= 'pending' then return { ok = false, reason = 'gone' } end

    local otherCid = DB.GetCitizenIdByNumber(otherNumber)
    local payer, payee = msg.meta.payer, msg.meta.payee

    if input.action == 'decline' then
        setStatusBoth(cid, otherNumber, otherCid, myNumber, id, 'declined')
        pushStatus(cid, otherNumber, id, 'declined')
        pushStatus(otherCid, myNumber, id, 'declined')
        return { ok = true }
    end

    local amount = math.floor(tonumber(msg.meta.amount) or 0)
    if amount <= 0 then return { ok = false, reason = 'amount' } end
    local payerCid = DB.GetCitizenIdByNumber(payer)
    local payeeCid = DB.GetCitizenIdByNumber(payee)
    if not GetSourceById(payerCid) or not GetSourceById(payeeCid) then return { ok = false, reason = 'offline' } end
    if Bank.Get(payerCid) < amount then return { ok = false, reason = 'funds' } end
    if not Bank.Remove(payerCid, amount, 'phone-transfer') then
        return { ok = false, reason = 'funds' }
    end
    Bank.Add(payeeCid, amount, 'phone-transfer')

    setStatusBoth(cid, otherNumber, otherCid, myNumber, id, 'paid')
    pushStatus(cid, otherNumber, id, 'paid')
    pushStatus(otherCid, myNumber, id, 'paid')
    return { ok = true }
end)

local function pushLoc(cid, number, id, x, y, label, live, reason)
    if not cid then return end
    local p = GetPlayerByCitizenId(cid)
    if not p then return end
    local data = { number = number, id = id }
    if x ~= nil then data.x = x end
    if y ~= nil then data.y = y end
    if label ~= nil then data.label = label end
    if live ~= nil then data.live = live end
    if reason ~= nil then data.endReason = reason end
    TriggerClientEvent('oph3z-phone:client:messages:locupdate', p.PlayerData.source, data)
end

local function saveLoc(cid, number, id, x, y, label, live, reason)
    if not cid then return end
    local patch = {}
    if x ~= nil then patch.x = x end
    if y ~= nil then patch.y = y end
    if label ~= nil then patch.label = label end
    if live ~= nil then patch.live = live end
    if reason ~= nil then patch.endReason = reason end
    patchMeta(cid, number, id, patch)
end

local function endShare(sid, reason)
    local share = liveShares[sid]
    if not share then return end
    liveShares[sid] = nil
    reason = reason or 'expired'
    saveLoc(share.senderCid, share.recipNumber, share.id, share.lastX, share.lastY, share.lastLabel, false, reason)
    saveLoc(share.recipCid, share.senderNumber, share.id, share.lastX, share.lastY, share.lastLabel, false, reason)
    pushLoc(share.senderCid, share.recipNumber, share.id, share.lastX, share.lastY, share.lastLabel, false, reason)
    pushLoc(share.recipCid, share.senderNumber, share.id, share.lastX, share.lastY, share.lastLabel, false, reason)
    local sp = GetPlayerByCitizenId(share.senderCid)
    if sp then TriggerClientEvent('oph3z-phone:client:loc:stop', sp.PlayerData.source, { sid = sid }) end
end

RegisterCallback('oph3z-phone:server:messages:location', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' then return false end
    local toDigits = DB.Digits(input.to)
    if toDigits == '' then return false end

    local x = tonumber(input.x) or 0.0
    local y = tonumber(input.y) or 0.0
    local label = tostring(input.label or 'Shared Location')
    local live = input.live and true or false
    local meta = { x = x, y = y, label = label, live = live }

    if not live then
        return deliver(cid, toDigits, 'location', label, meta)
    end

    local sid = genId()
    meta.sid = sid
    local out = deliver(cid, toDigits, 'location', label, meta)
    if not out then return false end

    liveShares[sid] = {
        senderCid = cid,
        senderSrc = src,
        senderNumber = DB.NumberOf(cid),
        recipCid = DB.GetCitizenIdByNumber(toDigits),
        recipNumber = toDigits,
        id = out.id,
        lastX = x, lastY = y, lastLabel = label,
    }
    return out
end)

RegisterNetEvent('oph3z-phone:server:loc:update', function(sid, x, y, label)
    local src = source
    local share = liveShares[sid]
    if not share or share.senderSrc ~= src then return end
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return end
    share.lastX, share.lastY, share.lastLabel = x, y, label or share.lastLabel
    pushLoc(share.senderCid, share.recipNumber, share.id, x, y, label, nil)
    pushLoc(share.recipCid, share.senderNumber, share.id, x, y, label, nil)
end)

RegisterCallback('oph3z-phone:server:messages:locstop', function(src, input)
    local cid = DB.GetCitizenId(src)
    local sid = input and input.sid
    if not sid then return { ok = false } end
    local share = liveShares[sid]
    if share and share.senderCid ~= cid then return { ok = false } end
    endShare(sid, (input and input.reason) or 'stopped')
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    local src = source
    for sid, share in pairs(liveShares) do
        if share.senderSrc == src then endShare(sid, 'expired') end
    end
end)