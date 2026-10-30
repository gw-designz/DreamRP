--[[
    fs-garages / client/main.lua

    Talking to the server, messages, and the garages on the map.
]]

local util = Garage.util

-- ── asking the server ──────────────────────────────────────────────────

local waiting = {}
local nextRequest = 0

RegisterNetEvent('fs-garages:client:response', function(requestId, ok, result)
    local slot = waiting[requestId]
    if slot then
        slot.ok, slot.result, slot.done = ok, result, true
    end
end)

--- Ask the server something and wait for the answer. Gives up after
--- `timeout` ms (default 8 s) with false, 'err_unknown'.
function Garage.request(action, data, timeout)
    nextRequest = nextRequest + 1
    local id = nextRequest
    local slot = {}
    waiting[id] = slot
    TriggerServerEvent('fs-garages:server:request', id, action, data)

    local deadline = GetGameTimer() + (timeout or 8000)
    while not slot.done and GetGameTimer() < deadline do Wait(50) end
    waiting[id] = nil

    if not slot.done then return false, 'err_unknown' end
    return slot.ok, slot.result
end

-- ── messages ───────────────────────────────────────────────────────────

--- Our ox_lib's notifications when it is there; the framework's own if not.
function Garage.notify(message, kind)
    if GetResourceState('ox_lib') == 'started' then
        local ok = pcall(function()
            exports.ox_lib:notify({ description = message, type = kind or 'inform' })
        end)
        if ok then return end
    end
    if Bridge then Bridge.notify(message, kind) end
end

--- A refusal code from the server, said in words.
function Garage.refused(code)
    Garage.notify(L(type(code) == 'string' and code or 'err_unknown'), 'error')
end

RegisterNetEvent('fs-garages:client:notify', function(message, kind)
    Garage.notify(message, kind)
end)

-- ── when the garages change ────────────────────────────────────────────

local listeners = {}

--- `fn` runs whenever an admin saves or deletes a garage.
function Garage.onGaragesChanged(fn)
    listeners[#listeners + 1] = fn
end

AddStateBagChangeHandler('fsGarages', 'global', function()
    -- The handler runs before the new list can be read; a tick later it can.
    SetTimeout(0, function()
        for _, fn in ipairs(listeners) do fn() end
    end)
end)

-- ── blips ──────────────────────────────────────────────────────────────

local blips = {}

local function makeBlips()
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    blips = {}
    if not (Config.Blips and Config.Blips.enabled) then return end
    for _, garage in ipairs(Garage.list()) do
        local k = garage.kiosk
        local look = Config.Blips[garage.kind == 'depot' and 'depot' or garage.type] or Config.Blips.car
        if k and look and garage.blip ~= false then
            local blip = AddBlipForCoord(k.x, k.y, k.z)
            SetBlipSprite(blip, look.sprite)
            SetBlipColour(blip, look.colour)
            SetBlipScale(blip, look.scale)
            SetBlipAsShortRange(blip, true)
            -- Each garage's own name on the map, as it was typed in the creator.
            local entry = 'FSG_' .. garage.id
            AddTextEntry(entry, garage.label)
            BeginTextCommandSetBlipName(entry)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end

CreateThread(makeBlips)
Garage.onGaragesChanged(makeBlips)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)

util.debug('client ready')
