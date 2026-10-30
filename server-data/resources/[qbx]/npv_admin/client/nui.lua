Nui = { open = false, view = nil }

function Nui.Send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local blurred = false
---Blur (or clear) the game behind the menu. No-op when Config.ScreenBlur is off.
function Nui.Blur(on)
    if not Config.ScreenBlur or on == blurred then return end
    blurred = on
    if on then TriggerScreenblurFadeIn(250) else TriggerScreenblurFadeOut(250) end
end

function Nui.Focus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

function Nui.Close()
    if not Nui.open then return end
    Nui.open = false
    Nui.view = nil
    Nui.Focus(false)
    Nui.Blur(false)
    Nui.Send('close')
    TriggerEvent('npv_admin:client:closed')
end

---Open a view ('admin' | 'dm'). Staff only; the session call fails for everyone else.
---`edit` ({ sid, oid }) opens the DM tool straight onto that placed object.
function Nui.Open(view, edit)
    if Nui.open then return end
    local res = lib.callback.await('npv_admin:rpc', false, 'session')
    if not res or not res.ok or not res.data then
        lib.notify({ type = 'error', description = 'You do not have access to the admin menu.' })
        return
    end
    Nui.open = true
    Nui.view = view
    Nui.Focus(true)
    Nui.Blur(true)
    Nui.Send('open', { view = view, session = res.data, adminMode = AdminMode == true, edit = edit })
end

-- Generic server RPC bridge. The NUI cannot reach the server any other way.
RegisterNUICallback('rpc', function(data, cb)
    local ok, res = pcall(function()
        return lib.callback.await('npv_admin:rpc', false, data.name, data.payload)
    end)
    cb(ok and res or { ok = false, error = 'rpc_failed' })
end)

RegisterNUICallback('close', function(_, cb)
    Nui.Close()
    cb({ ok = true })
end)

-- Client-side helpers the NUI may ask for (coordinates, clipboard, placement...).
local ClientCalls = {}
Nui.ClientCalls = ClientCalls

RegisterNUICallback('client', function(data, cb)
    local fn = type(data.name) == 'string' and ClientCalls[data.name]
    if not fn then return cb({ ok = false, error = 'unknown_client_call' }) end
    local ok, res = pcall(fn, data.payload or {})
    if not ok then
        print('[npv_admin] client call ' .. data.name .. ' failed: ' .. tostring(res))
        return cb({ ok = false, error = 'client_error' })
    end
    cb({ ok = true, data = res })
end)

-- Close on resource stop / player events so focus is never stuck.
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetNuiFocus(false, false) if blurred then TriggerScreenblurFadeOut(0) end end
end)

-- UI sounds. The NUI only sends a kind ('hover' | 'click' | 'enter' | 'back'); the sound itself
-- comes from Config.Sounds, so the page cannot ask for arbitrary sounds.
ClientCalls['sound'] = function(p)
    local s = Config.Sounds
    if not s or not s.enabled or type(p.kind) ~= 'string' then return true end
    local def = s[p.kind]
    if type(def) == 'table' then PlaySoundFrontend(-1, def[1], def[2], true) end
    return true
end

ClientCalls['blur'] = function(p)
    if Nui.open then Nui.Blur(p.on == true) end
    return true
end
