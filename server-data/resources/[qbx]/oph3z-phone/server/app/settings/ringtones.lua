local function clean(value, maxLen)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if #value > maxLen then value = value:sub(1, maxLen) end
    return value
end

local function builtinRingtones()
    local res = GetCurrentResourceName()
    local out = {}
    for _, r in ipairs(Config.Ringtones or {}) do
        local url = r.url
        if (not url or url == '') and r.file then
            url = ('https://cfx-nui-%s/build/audio/%s'):format(res, r.file)
        end
        if url and url ~= '' then
            out[#out + 1] = { id = r.id or r.name, name = r.name, url = url, builtin = true }
        end
    end
    return out
end

Ringtones = Ringtones or {}

function Ringtones.UrlFor(citizenid)
    local picked = citizenid and DB.Settings(citizenid).ringtone
    if type(picked) == 'string' and picked ~= '' then return picked end
    return Config.RingtoneUrl
end

RegisterCallback('oph3z-phone:server:ringtones:get', function(src)
    local cid = DB.GetCitizenId(src)
    if not cid then return { ringtones = {}, selected = '' } end

    Sql.Wait()
    local list = builtinRingtones()
    for _, row in ipairs(Sql.Query('SELECT `id`, `name`, `url` FROM `oph3z_phone_ringtones` WHERE `citizenid` = ? ORDER BY `id` ASC', { cid })) do
        list[#list + 1] = { id = row.id, name = row.name, url = row.url, builtin = false }
    end

    return {
        ringtones = list,
        selected  = DB.Settings(cid).ringtone or '',
    }
end)

RegisterCallback('oph3z-phone:server:ringtones:add', function(src, input)
    local cid = DB.GetCitizenId(src)
    if not cid or type(input) ~= 'table' then return nil end

    local name = clean(input.name, 40)
    local url  = clean(input.url, 512)
    if name == '' or url == '' then return nil end

    Sql.Wait()
    local id = Sql.Insert(
        'INSERT INTO `oph3z_phone_ringtones` (`citizenid`, `name`, `url`) VALUES (?, ?, ?)',
        { cid, name, url }
    )
    if not id then return nil end
    return { id = id, name = name, url = url }
end)

RegisterCallback('oph3z-phone:server:ringtones:delete', function(src, id)
    local cid = DB.GetCitizenId(src)
    if not cid or not tonumber(id) then return false end

    Sql.Wait()
    local removedUrl = Sql.Scalar(
        'SELECT `url` FROM `oph3z_phone_ringtones` WHERE `id` = ? AND `citizenid` = ?',
        { tonumber(id), cid }
    )
    Sql.Execute('DELETE FROM `oph3z_phone_ringtones` WHERE `id` = ? AND `citizenid` = ?', { tonumber(id), cid })

    if removedUrl and DB.Settings(cid).ringtone == removedUrl then
        DB.ClearSetting(cid, 'ringtone')
    end
    return true
end)