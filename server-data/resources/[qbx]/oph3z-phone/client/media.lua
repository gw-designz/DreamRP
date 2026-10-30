Phone = Phone or {}
Phone.nowPlaying = nil

local mediaVolume = 70

local function pushNowPlaying()
    SendNUIMessage({ action = 'phone:media:nowplaying', data = Phone.nowPlaying or false })
end

exports('SetNowPlaying', function(data)
    if type(data) ~= 'table' then return false end
    local title = data.title
    if type(title) ~= 'string' or title == '' then return false end

    Phone.nowPlaying = {
        appId    = data.appId,
        title    = title,
        artist   = type(data.artist) == 'string' and data.artist or '',
        artwork  = type(data.artwork) == 'string' and data.artwork or nil,
        position = tonumber(data.position) or 0,
        duration = tonumber(data.duration) or 0,
        playing  = data.playing == true,
        hasNext  = data.hasNext == true,
        hasPrev  = data.hasPrev == true,
        owner    = GetInvokingResource() or GetCurrentResourceName(),
    }
    pushNowPlaying()
    return true
end)

exports('ClearNowPlaying', function()
    if not Phone.nowPlaying then return false end
    Phone.nowPlaying = nil
    pushNowPlaying()
    return true
end)

exports('GetMediaVolume', function()
    return mediaVolume
end)

RegisterNUICallback('phone:media:state', function(_, cb)
    cb(Phone.nowPlaying or false)
end)

RegisterNUICallback('phone:media:command', function(data, cb)
    local action = data and data.action
    if type(action) == 'string' and Phone.nowPlaying then
        TriggerEvent('oph3z-phone:media:command', action, data.value)
    end
    cb('ok')
end)

RegisterNUICallback('phone:media:volume', function(data, cb)
    local v = tonumber(data and data.volume)
    if v then
        mediaVolume = v
        TriggerEvent('oph3z-phone:media:volume', v)
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if Phone.nowPlaying and Phone.nowPlaying.owner == res then
        Phone.nowPlaying = nil
        pushNowPlaying()
    end
end)