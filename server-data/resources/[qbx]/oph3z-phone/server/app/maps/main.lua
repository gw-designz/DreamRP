RegisterCallback('oph3z-phone:server:maps:get', function(source)
    local cid = DB.GetCitizenId(source)
    if not cid then return {} end

    Sql.Wait()
    return Sql.Query(
        'SELECT `id`, `label`, `x`, `y`, `ts` FROM `oph3z_phone_blips` WHERE `citizenid` = ? ORDER BY `id` ASC',
        { cid }
    )
end)

RegisterCallback('oph3z-phone:server:maps:add', function(source, input)
    local cid = DB.GetCitizenId(source)
    if not cid or type(input) ~= 'table' or not input.x or not input.y then return nil end

    Sql.Wait()
    local blip = {
        label = tostring(input.label or 'Saved place'):sub(1, 40),
        x     = tonumber(input.x) + 0.0,
        y     = tonumber(input.y) + 0.0,
        ts    = os.time(),
    }
    blip.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_blips` (`citizenid`, `label`, `x`, `y`, `ts`) VALUES (?, ?, ?, ?, ?)',
        { cid, blip.label, blip.x, blip.y, blip.ts }
    )
    if not blip.id then return nil end
    return blip
end)

RegisterCallback('oph3z-phone:server:maps:move', function(source, input)
    local cid = DB.GetCitizenId(source)
    if not cid or type(input) ~= 'table' or not input.id then return false end

    Sql.Wait()
    return Sql.Execute(
        'UPDATE `oph3z_phone_blips` SET `x` = ?, `y` = ? WHERE `id` = ? AND `citizenid` = ?',
        { tonumber(input.x) + 0.0, tonumber(input.y) + 0.0, input.id, cid }
    ) > 0
end)

RegisterCallback('oph3z-phone:server:maps:delete', function(source, id)
    local cid = DB.GetCitizenId(source)
    if not cid or not id then return false end

    Sql.Wait()
    Sql.Execute('DELETE FROM `oph3z_phone_blips` WHERE `citizenid` = ? AND `id` = ?', { cid, id })
    return true
end)