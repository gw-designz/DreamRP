-- Player-facing conversation UI. All state lives on the server; this only relays clicks.

local active = false

local function close()
    if not active then return end
    active = false
    lib.callback.await('npv_admin:dialogue', false, 'close')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'dialogue', data = nil })
end

function OpenDialogue(sid, oid)
    if active or Nui.open then return end
    local res = lib.callback.await('npv_admin:dialogue', false, 'open', sid, oid)
    if not res or not res.ok then return end
    active = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'dialogue', data = res.view })
end

RegisterNUICallback('dialogue:reply', function(data, cb)
    if not active then return cb({ ok = false }) end
    local res = lib.callback.await('npv_admin:dialogue', false, 'reply', data.id)
    if not res or not res.view or res.view.closed then
        active = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'dialogue', data = nil })
    else
        SendNUIMessage({ action = 'dialogue', data = res.view })
    end
    cb({ ok = true })
end)

RegisterNUICallback('dialogue:close', function(_, cb)
    close()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and active then SetNuiFocus(false, false) end
end)
