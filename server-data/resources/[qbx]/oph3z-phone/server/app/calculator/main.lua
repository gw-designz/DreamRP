local MAX_HISTORY = 50

local function cidOf(src)
    return GetIdentifier(src)
end

RegisterCallback('oph3z-phone:server:calc:get', function(src)
    local cid = cidOf(src)
    if not cid then return {} end

    Sql.Wait()
    return Sql.Query(
        'SELECT `id`, `expr`, `value`, `ts` FROM `oph3z_phone_calc` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?',
        { cid, MAX_HISTORY }
    )
end)

RegisterCallback('oph3z-phone:server:calc:add', function(src, entry)
    local cid = cidOf(src)
    if not cid or type(entry) ~= 'table' then return nil end
    local expr = tostring(entry.expr or ''):sub(1, 120)
    local value = entry.value
    if expr == '' or type(value) ~= 'number' then return nil end

    Sql.Wait()
    local item = { expr = expr, value = value, ts = os.time() }
    item.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_calc` (`citizenid`, `expr`, `value`, `ts`) VALUES (?, ?, ?, ?)',
        { cid, expr, value, item.ts }
    )
    if not item.id then return nil end

    Sql.Execute(
        'DELETE FROM `oph3z_phone_calc` WHERE `citizenid` = ? AND `id` NOT IN ' ..
        '(SELECT `id` FROM (SELECT `id` FROM `oph3z_phone_calc` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?) AS keep)',
        { cid, cid, MAX_HISTORY }
    )
    return item
end)

RegisterCallback('oph3z-phone:server:calc:delete', function(src, id)
    local cid = cidOf(src)
    if not cid then return false end

    Sql.Wait()
    Sql.Execute('DELETE FROM `oph3z_phone_calc` WHERE `citizenid` = ? AND `id` = ?', { cid, id })
    return true
end)

RegisterCallback('oph3z-phone:server:calc:clear', function(src)
    local cid = cidOf(src)
    if not cid then return false end

    Sql.Wait()
    Sql.Execute('DELETE FROM `oph3z_phone_calc` WHERE `citizenid` = ?', { cid })
    return true
end)