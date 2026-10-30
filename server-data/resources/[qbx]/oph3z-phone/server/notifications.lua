local MAX_NOTIFS = 50
local TRIM_EVERY = 25

Notif = Notif or {}

local function hydrate(rows)
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = {
            id    = row.id,
            app   = row.app,
            title = row.title,
            body  = row.body,
            icon  = row.icon,
            route = Sql.Decode(row.route, nil),
            ts    = row.ts,
            read  = Sql.Bool(row.is_read),
        }
    end
    return out
end

function Notif.Push(citizenid, data)
    if not citizenid or type(data) ~= 'table' then return end

    Sql.Wait()
    local s = DB.Settings(citizenid)
    if s.notifMaster == false then return end
    local appId = data.app or 'system'
    if s.notifApps and s.notifApps[appId] == false then return end

    local lang = s.language or Config.DefaultLocale or 'en'
    local function loc(key, args)
        local str = Lang(key, lang)
        if args and #args > 0 then
            local ok, res = pcall(string.format, str, table.unpack(args))
            if ok then return res end
        end
        return str
    end
    local title = data.title or (data.titleKey and loc(data.titleKey, data.titleArgs)) or ''
    local body  = data.body or (data.bodyKey and loc(data.bodyKey, data.bodyArgs)) or ''

    local queued = (s.airplane == true)
    local item = {
        app   = appId,
        title = tostring(title):sub(1, 160),
        body  = tostring(body),
        icon  = data.icon,
        route = data.route,
        ts    = os.time(),
        read  = false,
        queued = queued or nil,
    }

    item.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_notifications` (`citizenid`, `app`, `title`, `body`, `icon`, `route`, `ts`, `is_read`, `queued`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)',
        { citizenid, item.app, item.title, item.body, item.icon, Sql.Encode(item.route), item.ts, queued and 1 or 0 }
    )
    if not item.id then return end

    if math.random(TRIM_EVERY) == 1 then
        Sql.Execute(
            'DELETE FROM `oph3z_phone_notifications` WHERE `citizenid` = ? AND `id` NOT IN ' ..
            '(SELECT `id` FROM (SELECT `id` FROM `oph3z_phone_notifications` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?) AS keep)',
            { citizenid, citizenid, MAX_NOTIFS }
        )
    end

    if queued then return end

    local player = GetPlayerByCitizenId(citizenid)
    if player then
        TriggerClientEvent('oph3z-phone:client:notify', player.PlayerData.source, item)
    end
end

function Notif.Release(citizenid)
    if not citizenid then return false end
    Sql.Wait()
    return Sql.Execute(
        'UPDATE `oph3z_phone_notifications` SET `queued` = 0 WHERE `citizenid` = ? AND `queued` = 1',
        { citizenid }
    ) > 0
end

RegisterCallback('oph3z-phone:server:notifications:get', function(src)
    local cid = DB.GetCitizenId(src)
    if not cid then return {} end

    Sql.Wait()
    return hydrate(Sql.Query(
        'SELECT `id`, `app`, `title`, `body`, `icon`, `route`, `ts`, `is_read` FROM `oph3z_phone_notifications` ' ..
        'WHERE `citizenid` = ? AND `queued` = 0 ORDER BY `id` DESC LIMIT ?',
        { cid, MAX_NOTIFS }
    ))
end)

RegisterCallback('oph3z-phone:server:notifications:read', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' then return false end

    Sql.Wait()
    if input.all then
        Sql.Execute('UPDATE `oph3z_phone_notifications` SET `is_read` = 1 WHERE `citizenid` = ?', { cid })
    elseif input.id then
        Sql.Execute('UPDATE `oph3z_phone_notifications` SET `is_read` = 1 WHERE `citizenid` = ? AND `id` = ?', { cid, input.id })
    elseif input.app then
        Sql.Execute('UPDATE `oph3z_phone_notifications` SET `is_read` = 1 WHERE `citizenid` = ? AND `app` = ?', { cid, input.app })
    elseif input.number then
        Sql.Execute(
            'UPDATE `oph3z_phone_notifications` SET `is_read` = 1 WHERE `citizenid` = ? AND `route` LIKE ?',
            { cid, ('%%"number":"%s"%%'):format(tostring(input.number)) }
        )
    elseif input.gid then
        Sql.Execute(
            'UPDATE `oph3z_phone_notifications` SET `is_read` = 1 WHERE `citizenid` = ? AND `route` LIKE ?',
            { cid, ('%%"gid":"%s"%%'):format(tostring(input.gid)) }
        )
    end
    return true
end)

RegisterCallback('oph3z-phone:server:notifications:clear', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid then return false end

    Sql.Wait()
    if input and input.id then
        Sql.Execute('DELETE FROM `oph3z_phone_notifications` WHERE `citizenid` = ? AND `id` = ?', { cid, input.id })
    elseif input and input.app then
        Sql.Execute('DELETE FROM `oph3z_phone_notifications` WHERE `citizenid` = ? AND `app` = ?', { cid, input.app })
    elseif input and input.number then
        Sql.Execute(
            'DELETE FROM `oph3z_phone_notifications` WHERE `citizenid` = ? AND `route` LIKE ?',
            { cid, ('%%"number":"%s"%%'):format(tostring(input.number)) }
        )
    elseif input and input.gid then
        Sql.Execute(
            'DELETE FROM `oph3z_phone_notifications` WHERE `citizenid` = ? AND `route` LIKE ?',
            { cid, ('%%"gid":"%s"%%'):format(tostring(input.gid)) }
        )
    else
        Sql.Execute('DELETE FROM `oph3z_phone_notifications` WHERE `citizenid` = ?', { cid })
    end
    return true
end)