Phone = Phone or {}

function Phone.dbg(...)
    if Config.Debug then
        print('[oph3z-phone]', ...)
    end
end

function Phone.hasItem()
    return HasPhoneItem()
end

local function zoneLabel()
    local coords = GetEntityCoords(PlayerPedId())
    local code = GetNameOfZone(coords.x, coords.y, coords.z)
    local label = code and GetLabelText(code) or nil
    if not label or label == 'NULL' then return code or '' end
    return label
end

function Phone.getTimeData()
    return {
        zone    = zoneLabel(),
        hours   = GetClockHours(),
        minutes = GetClockMinutes(),
        day     = GetClockDayOfMonth(),
        month   = GetClockMonth() + 1,
        weekday = GetClockDayOfWeek(),
        year    = GetClockYear(),
    }
end