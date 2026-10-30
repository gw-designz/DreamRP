Moderation = {}

local function identifiersOf(src)
    local ids = {}
    for _, v in ipairs(GetPlayerIdentifiers(src)) do
        if not v:find('^ip:') then ids[#ids + 1] = v end
    end
    return ids
end

function Moderation.Ban(staff, target, durationSeconds, reason)
    local license = GetPlayerIdentifierByType(target, 'license')
    if not license then return false, 'target_has_no_license' end
    local expires = durationSeconds and durationSeconds > 0 and (os.time() + durationSeconds) or nil
    local staffName = staff > 0 and GetPlayerName(staff) or 'console'
    local id = MySQL.insert.await('INSERT INTO npv_admin_bans (name, license, identifiers, reason, expires, banned_by) VALUES (?, ?, ?, ?, ?, ?)',
        { GetPlayerName(target), license, json.encode(identifiersOf(target)), reason, expires, staffName })
    DropPlayer(target, ('You are banned%s.\nReason: %s\nBan ID: %s'):format(
        expires and (' until ' .. os.date('%Y-%m-%d %H:%M', expires)) or ' permanently', reason, id))
    return true, id
end

function Moderation.Unban(banId)
    local n = MySQL.update.await('UPDATE npv_admin_bans SET lifted = 1 WHERE id = ? AND lifted = 0', { banId })
    return n > 0
end

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    DB.WaitReady()
    local ids = {}
    for _, v in ipairs(GetPlayerIdentifiers(src)) do
        if not v:find('^ip:') then ids[#ids + 1] = v end
    end
    local license = GetPlayerIdentifierByType(src, 'license')
    local rows = MySQL.query.await('SELECT id, reason, expires, identifiers FROM npv_admin_bans WHERE lifted = 0 AND (expires IS NULL OR expires > ?) AND (license = ? OR identifiers LIKE ?)',
        { os.time(), license or '', '%' .. (ids[1] or 'none') .. '%' })
    if rows and rows[1] then
        local b = rows[1]
        return deferrals.done(('You are banned%s.\nReason: %s\nBan ID: %s'):format(
            b.expires and (' until ' .. os.date('%Y-%m-%d %H:%M', b.expires)) or ' permanently', b.reason, b.id))
    end
    deferrals.done()
end)
