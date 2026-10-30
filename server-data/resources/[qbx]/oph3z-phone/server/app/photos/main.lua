local function listPhotos(citizenid)
    Sql.Wait()
    local rows = Sql.Query(
        'SELECT `id`, `url`, `type`, `thumb`, `duration`, `favorite`, `ts`, `place` FROM `oph3z_phone_photos` ' ..
        'WHERE `citizenid` = ? ORDER BY `id` ASC',
        { citizenid }
    )
    for _, row in ipairs(rows) do
        row.favorite = Sql.Bool(row.favorite)
        row.duration = Sql.Num(row.duration)
    end
    return rows
end

RegisterCallback('oph3z-phone:server:photos:get', function(source)
    local cid = DB.GetCitizenId(source)
    if not cid then return {} end
    return listPhotos(cid)
end)

Photos = Photos or {}

function Photos.Add(citizenid, input)
    if not citizenid or type(input) ~= 'table' or not input.url then return nil end

    Sql.Wait()
    local photo = {
        url      = tostring(input.url):sub(1, 512),
        type     = (input.type == 'video') and 'video' or 'image',
        thumb    = input.thumb and tostring(input.thumb):sub(1, 512) or nil,
        duration = tonumber(input.duration) or nil,
        favorite = false,
        ts       = os.time(),
        place    = type(input.place) == 'string' and input.place ~= '' and input.place:sub(1, 64) or nil,
    }
    photo.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_photos` (`citizenid`, `url`, `type`, `thumb`, `duration`, `favorite`, `ts`, `place`) ' ..
        'VALUES (?, ?, ?, ?, ?, 0, ?, ?)',
        { citizenid, photo.url, photo.type, photo.thumb, photo.duration, photo.ts, photo.place }
    )
    if not photo.id then return nil end
    return photo
end

RegisterCallback('oph3z-phone:server:photos:add', function(source, input)
    return Photos.Add(DB.GetCitizenId(source), input)
end)

RegisterCallback('oph3z-phone:server:photos:setFavorite', function(source, data)
    local cid = DB.GetCitizenId(source)
    if not cid or type(data) ~= 'table' then return false end

    Sql.Wait()
    return Sql.Execute(
        'UPDATE `oph3z_phone_photos` SET `favorite` = ? WHERE `id` = ? AND `citizenid` = ?',
        { data.favorite and 1 or 0, data.id, cid }
    ) > 0
end)

RegisterCallback('oph3z-phone:server:photos:delete', function(source, ids)
    local cid = DB.GetCitizenId(source)
    if not cid or type(ids) ~= 'table' or #ids == 0 then return false end

    local params = { cid }
    for _, id in ipairs(ids) do params[#params + 1] = id end

    Sql.Wait()
    Sql.Execute(
        ('DELETE FROM `oph3z_phone_photos` WHERE `citizenid` = ? AND `id` IN (%s)'):format(Sql.Placeholders(#ids)),
        params
    )
    return true
end)