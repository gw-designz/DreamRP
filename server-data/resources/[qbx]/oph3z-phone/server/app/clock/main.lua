local ClockCfg   = Config.Clock or {}
local RANGE      = ClockCfg.Range or 12.0
local VOLUME     = ClockCfg.Volume or 0.5
local RING_SECS  = ClockCfg.RingSeconds or 45
local MAX_ALARMS = 30
local MAX_RECENT = 12

local DEFAULT_ALARM_URL = ('https://cfx-nui-%s/build/audio/alarm.mp3'):format(GetCurrentResourceName())

Clock = Clock or {}
Clock.state = {}

local function cidOf(src)
    return GetIdentifier(src)
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function saveState(src)
    local st = Clock.state[src]
    if not st then return end

    Sql.Wait()
    local cid = st.cid
    local tm = st.timer

    Sql.Execute(
        'INSERT INTO `oph3z_phone_clock` (`citizenid`, `alarm_ringtone`, `timer_ends_at`, `timer_total`, ' ..
        '`timer_remaining`, `timer_paused`, `timer_label`, `timer_from_recent`, `timer_active`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE ' ..
        '`alarm_ringtone` = VALUES(`alarm_ringtone`), `timer_ends_at` = VALUES(`timer_ends_at`), ' ..
        '`timer_total` = VALUES(`timer_total`), `timer_remaining` = VALUES(`timer_remaining`), ' ..
        '`timer_paused` = VALUES(`timer_paused`), `timer_label` = VALUES(`timer_label`), ' ..
        '`timer_from_recent` = VALUES(`timer_from_recent`), `timer_active` = VALUES(`timer_active`)',
        {
            cid, st.alarmRingtone or '',
            tm and tm.endsAt or nil, tm and tm.total or nil, tm and tm.remaining or nil,
            (tm and tm.paused) and 1 or 0, tm and tm.label or nil,
            (tm and tm.fromRecent) and 1 or 0, tm and 1 or 0,
        }
    )

    Sql.Execute('DELETE FROM `oph3z_phone_timer_recents` WHERE `citizenid` = ?', { cid })
    if #st.recents > 0 then
        local groups, params = {}, {}
        for _, r in ipairs(st.recents) do
            groups[#groups + 1] = '(?, ?, ?, ?)'
            params[#params + 1] = cid
            params[#params + 1] = r.h or 0
            params[#params + 1] = r.m or 0
            params[#params + 1] = r.s or 0
        end
        Sql.Execute(
            'INSERT INTO `oph3z_phone_timer_recents` (`citizenid`, `h`, `m`, `s`) VALUES ' .. table.concat(groups, ', '),
            params
        )
    end
end

local function saveAlarm(cid, alarm)
    Sql.Execute(
        'UPDATE `oph3z_phone_alarms` SET `hour` = ?, `minute` = ?, `label` = ?, `enabled` = ? WHERE `id` = ? AND `citizenid` = ?',
        { alarm.hour, alarm.min, alarm.label, alarm.enabled and 1 or 0, alarm.id, cid }
    )
end

local function alarmUrl(st)
    if st.alarmRingtone and st.alarmRingtone ~= '' then return st.alarmRingtone end
    return DEFAULT_ALARM_URL
end

local function alarmToneList(st)
    local out = { { id = 'default', name = 'Alarm', url = DEFAULT_ALARM_URL, builtin = true } }
    for _, c in ipairs(st.alarmTones) do
        out[#out + 1] = { id = c.id, name = c.name, url = c.url, builtin = false }
    end
    return out
end

function Clock.Ensure(src)
    local existing = Clock.state[src]
    if existing then return existing end

    local cid = cidOf(src)
    if not cid then return nil end

    Sql.Wait()
    local row = Sql.Single('SELECT * FROM `oph3z_phone_clock` WHERE `citizenid` = ?', { cid })

    local timer
    if row and Sql.Bool(row.timer_active) then
        timer = {
            endsAt     = Sql.Num(row.timer_ends_at),
            total      = Sql.Num(row.timer_total, 0),
            paused     = Sql.Bool(row.timer_paused),
            remaining  = Sql.Num(row.timer_remaining, 0),
            label      = row.timer_label or '',
            fromRecent = Sql.Bool(row.timer_from_recent),
        }
    end

    local alarms = {}
    for _, a in ipairs(Sql.Query(
        'SELECT `id`, `hour`, `minute`, `label`, `enabled` FROM `oph3z_phone_alarms` WHERE `citizenid` = ? ORDER BY `id` ASC',
        { cid }
    )) do
        alarms[#alarms + 1] = {
            id = a.id, hour = a.hour, min = a.minute,
            label = a.label or '', enabled = Sql.Bool(a.enabled),
        }
    end

    local recents = {}
    for _, r in ipairs(Sql.Query(
        'SELECT `h`, `m`, `s` FROM `oph3z_phone_timer_recents` WHERE `citizenid` = ? ORDER BY `id` ASC',
        { cid }
    )) do
        recents[#recents + 1] = { h = r.h, m = r.m, s = r.s }
    end

    local st = {
        cid           = cid,
        alarms        = alarms,
        recents       = recents,
        timer         = timer,
        alarmRingtone = (row and row.alarm_ringtone) or '',
        alarmTones    = Sql.Query('SELECT `id`, `name`, `url` FROM `oph3z_phone_alarm_tones` WHERE `citizenid` = ? ORDER BY `id` ASC', { cid }),
        alarmLast     = {},
        ring          = nil,
    }
    Clock.state[src] = st

    local tm = st.timer

    if tm and not tm.paused and tm.endsAt and tm.endsAt <= os.time() then
        if not tm.fromRecent then Clock.AddRecent(st, tm.total) end
        st.timer = nil
        saveState(src)
    end

    return st
end

function Clock.AddRecent(st, totalSecs)
    totalSecs = tonumber(totalSecs) or 0
    if totalSecs <= 0 then return end
    local h = math.floor(totalSecs / 3600)
    local m = math.floor((totalSecs % 3600) / 60)
    local s = totalSecs % 60

    for i = #st.recents, 1, -1 do
        local r = st.recents[i]
        if r.h == h and r.m == m and r.s == s then table.remove(st.recents, i) end
    end

    table.insert(st.recents, 1, { h = h, m = m, s = s })

    while #st.recents > MAX_RECENT do table.remove(st.recents) end
end

local function startRing(src, st, kind, meta)
    local coords = pedCoords(src)
    if not coords then return end
    if st.ring then exports.xsound:Destroy(-1, st.ring.name) end
    local name = ('oph3z_clock_%d'):format(src)
    st.ring = { name = name, expires = os.time() + RING_SECS, kind = kind }
    exports.xsound:PlayUrlPos(-1, name, alarmUrl(st), VOLUME, coords, true)
    exports.xsound:Distance(-1, name, RANGE)
    TriggerClientEvent('oph3z-phone:client:clock:ring', src, {
        name = name, kind = kind, meta = meta,
    })
end

function Clock.StopRing(src)
    local st = Clock.state[src]
    if not st or not st.ring then return end
    exports.xsound:Destroy(-1, st.ring.name)
    st.ring = nil
    TriggerClientEvent('oph3z-phone:client:clock:ringStop', src)
end

CreateThread(function()
    while true do
        local now = os.time()
        local nowT = os.date('*t')
        local minuteKey = ('%04d%02d%02d%02d%02d'):format(nowT.year, nowT.month, nowT.day, nowT.hour, nowT.min)

        for src, st in pairs(Clock.state) do
            local tm = st.timer
            if tm and not tm.paused and tm.endsAt and now >= tm.endsAt then
                if not tm.fromRecent then Clock.AddRecent(st, tm.total) end
                st.timer = nil
                saveState(src)
                startRing(src, st, 'timer', { total = tm.total, label = tm.label })
                TriggerClientEvent('oph3z-phone:client:clock:timerDone', src, {
                    recents = st.recents,
                })
            end

            for _, a in ipairs(st.alarms) do
                if a.enabled and a.hour == nowT.hour and a.min == nowT.min then
                    if st.alarmLast[a.id] ~= minuteKey then
                        st.alarmLast[a.id] = minuteKey
                        a.enabled = false
                        saveAlarm(st.cid, a)
                        startRing(src, st, 'alarm', { id = a.id, label = a.label, hour = a.hour, min = a.min })
                        TriggerClientEvent('oph3z-phone:client:clock:alarmFire', src, {
                            id = a.id, label = a.label, hour = a.hour, min = a.min,
                        })
                    end
                end
            end

            if st.ring and now >= st.ring.expires then
                Clock.StopRing(src)
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    Clock.StopRing(src)
    Clock.state[src] = nil
end)

RegisterCallback('oph3z-phone:server:clock:get', function(src)
    local st = Clock.Ensure(src)
    if not st then return nil end
    return {
        alarms        = st.alarms,
        timer         = st.timer,
        recents       = st.recents,
        alarmRingtone = st.alarmRingtone,
        alarmTones    = alarmToneList(st),
        now           = os.time(),
    }
end)

RegisterCallback('oph3z-phone:server:clock:addAlarm', function(src, data)
    local st = Clock.Ensure(src)
    if not st or type(data) ~= 'table' then return nil end
    if #st.alarms >= MAX_ALARMS then return nil end
    local hour = math.max(0, math.min(23, math.floor(tonumber(data.hour) or 0)))
    local min  = math.max(0, math.min(59, math.floor(tonumber(data.min) or 0)))
    local label = tostring(data.label or ''):sub(1, 40)

    Sql.Wait()
    local id = Sql.Insert(
        'INSERT INTO `oph3z_phone_alarms` (`citizenid`, `hour`, `minute`, `label`, `enabled`) VALUES (?, ?, ?, ?, 1)',
        { st.cid, hour, min, label }
    )
    if not id then return nil end

    local alarm = { id = id, hour = hour, min = min, label = label, enabled = true }
    st.alarms[#st.alarms + 1] = alarm
    return alarm
end)

RegisterCallback('oph3z-phone:server:clock:toggleAlarm', function(src, id)
    local st = Clock.Ensure(src)
    if not st then return nil end
    for _, a in ipairs(st.alarms) do
        if a.id == id then
            a.enabled = not a.enabled
            if not a.enabled then st.alarmLast[a.id] = nil end
            Sql.Wait()
            saveAlarm(st.cid, a)
            return a.enabled
        end
    end
    return nil
end)

RegisterCallback('oph3z-phone:server:clock:deleteAlarm', function(src, id)
    local st = Clock.Ensure(src)
    if not st then return false end
    for i = #st.alarms, 1, -1 do
        if st.alarms[i].id == id then
            table.remove(st.alarms, i)
            st.alarmLast[id] = nil
            Sql.Wait()
            Sql.Execute('DELETE FROM `oph3z_phone_alarms` WHERE `id` = ? AND `citizenid` = ?', { id, st.cid })
            return true
        end
    end
    return false
end)

RegisterCallback('oph3z-phone:server:clock:startTimer', function(src, data)
    local st = Clock.Ensure(src)
    if not st or type(data) ~= 'table' then return nil end
    local total = math.max(1, math.min(24 * 3600, math.floor(tonumber(data.total) or 0)))
    st.timer = {
        endsAt     = os.time() + total,
        total      = total,
        paused     = false,
        remaining  = total,
        label      = tostring(data.label or ''):sub(1, 40),
        fromRecent = data.fromRecent and true or false,
    }
    saveState(src)
    return st.timer
end)

RegisterCallback('oph3z-phone:server:clock:pauseTimer', function(src)
    local st = Clock.Ensure(src)
    if not st or not st.timer or st.timer.paused then return st and st.timer or nil end
    local tm = st.timer
    tm.remaining = math.max(0, (tm.endsAt or os.time()) - os.time())
    tm.paused = true
    tm.endsAt = nil
    saveState(src)
    return tm
end)

RegisterCallback('oph3z-phone:server:clock:resumeTimer', function(src)
    local st = Clock.Ensure(src)
    if not st or not st.timer or not st.timer.paused then return st and st.timer or nil end
    local tm = st.timer
    tm.endsAt = os.time() + math.max(1, tm.remaining or 1)
    tm.paused = false
    saveState(src)
    return tm
end)

RegisterCallback('oph3z-phone:server:clock:cancelTimer', function(src)
    local st = Clock.Ensure(src)
    if not st then return false end
    st.timer = nil
    saveState(src)
    return true
end)

RegisterCallback('oph3z-phone:server:clock:deleteRecent', function(src, index)
    local st = Clock.Ensure(src)
    if not st then return false end
    index = tonumber(index)
    if index and st.recents[index] then
        table.remove(st.recents, index)
        saveState(src)
        return true
    end
    return false
end)

RegisterCallback('oph3z-phone:server:clock:stopRing', function(src)
    Clock.StopRing(src)
    return true
end)

RegisterCallback('oph3z-phone:server:clock:setAlarmTone', function(src, url)
    local st = Clock.Ensure(src)
    if not st then return false end
    st.alarmRingtone = (type(url) == 'string') and url or ''
    saveState(src)
    return true
end)

RegisterCallback('oph3z-phone:server:clock:addAlarmTone', function(src, input)
    local st = Clock.Ensure(src)
    if not st or type(input) ~= 'table' then return nil end
    local name = tostring(input.name or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 40)
    local url  = tostring(input.url or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 512)
    if name == '' or url == '' then return nil end

    Sql.Wait()
    local id = Sql.Insert(
        'INSERT INTO `oph3z_phone_alarm_tones` (`citizenid`, `name`, `url`) VALUES (?, ?, ?)',
        { st.cid, name, url }
    )
    if not id then return nil end

    local item = { id = id, name = name, url = url }
    st.alarmTones[#st.alarmTones + 1] = item
    return item
end)

RegisterCallback('oph3z-phone:server:clock:deleteAlarmTone', function(src, id)
    local st = Clock.Ensure(src)
    if not st or not tonumber(id) then return false end
    id = tonumber(id)

    local removedUrl
    for i = #st.alarmTones, 1, -1 do
        if st.alarmTones[i].id == id then
            removedUrl = st.alarmTones[i].url
            table.remove(st.alarmTones, i)
        end
    end

    Sql.Wait()
    Sql.Execute('DELETE FROM `oph3z_phone_alarm_tones` WHERE `id` = ? AND `citizenid` = ?', { id, st.cid })
    if removedUrl and st.alarmRingtone == removedUrl then
        st.alarmRingtone = ''
        saveState(src)
    end
    return true
end)