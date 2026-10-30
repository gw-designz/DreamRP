RegisterNUICallback('phone:close', function(_, cb)
    Phone.close()
    cb('ok')
end)

RegisterNUICallback('phone:saveSettings', function(patch, cb)
    if type(patch) == 'table' and patch.language then Phone.setLanguage(patch.language) end
    local ok = TriggerCallback('oph3z-phone:server:saveSettings', patch)
    cb({ ok = ok })
end)

-- UI sounds (Config.UI.Sounds). The NUI only names the event; the native sound comes from config.
local SOUND_KEYS = { hover = 'Hover', click = 'Click', enter = 'Enter', back = 'Back', open = 'Open', home = 'Home' }

RegisterNUICallback('phone:sound', function(data, cb)
    cb('ok')
    local cfg = Config.UI and Config.UI.Sounds
    if type(cfg) ~= 'table' or cfg.Enabled == false or type(data) ~= 'table' then return end
    local s = cfg[SOUND_KEYS[data.kind] or '']
    if type(s) == 'table' and s[1] then
        PlaySoundFrontend(-1, s[1], s[2] or 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end)

RegisterNUICallback('phone:home:save', function(layout, cb)
    cb(TriggerCallback('oph3z-phone:server:home:save', layout) or false)
end)

RegisterNUICallback('phone:flashlight', function(data, cb)
    Phone.setFlashlight(data and data.on)
    cb('ok')
end)

RegisterNUICallback('phone:ready', function(_, cb)
    Phone.dbg('NUI ready')
    cb('ok')
end)

RegisterNUICallback('phone:phone:getState', function(_, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:getState') or {})
end)

RegisterNUICallback('phone:phone:addContact', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:addContact', data) or false)
end)

RegisterNUICallback('phone:phone:updateContact', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:updateContact', data) or false)
end)

RegisterNUICallback('phone:phone:deleteContact', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:deleteContact', data and data.id) or false)
end)

RegisterNUICallback('phone:phone:deleteRecent', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:deleteRecent', data and data.id) or false)
end)

RegisterNUICallback('phone:phone:clearRecents', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:clearRecents', data and data.scope) or false)
end)

RegisterNUICallback('phone:phone:setFavorite', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:setFavorite', data) or false)
end)

RegisterNUICallback('phone:phone:block', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:block', data and data.number) or {})
end)

RegisterNUICallback('phone:phone:unblock', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:unblock', data and data.number) or {})
end)

RegisterNUICallback('phone:phone:setAirplane', function(data, cb)
    cb(TriggerCallback('oph3z-phone:server:phone:setAirplane', data and data.value))
end)

RegisterNUICallback('phone:call:start', function(data, cb)
    TriggerServerEvent('oph3z-phone:call:start', data and data.number, data and data.video)
    cb('ok')
end)

RegisterNUICallback('phone:call:accept', function(data, cb)
    TriggerServerEvent('oph3z-phone:call:accept', data and data.callId)
    cb('ok')
end)

RegisterNUICallback('phone:call:decline', function(data, cb)
    TriggerServerEvent('oph3z-phone:call:decline', data and data.callId)
    cb('ok')
end)

RegisterNUICallback('phone:call:hangup', function(data, cb)
    TriggerServerEvent('oph3z-phone:call:hangup', data and data.callId)
    cb('ok')
end)

RegisterNUICallback('phone:call:mute', function(data, cb)
    if data then TriggerServerEvent('oph3z-phone:call:mute', data.callId, data.muted) end
    cb('ok')
end)

RegisterNUICallback('phone:call:speaker', function(data, cb)
    if data then TriggerServerEvent('oph3z-phone:call:speaker', data.callId, data.on) end
    cb('ok')
end)