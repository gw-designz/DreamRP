--[[
    fs-garages / server/main.lua

    The one door into the server for the kiosks and parking. A player's
    game asks through 'fs-garages:server:request' with a number of its own,
    and the answer comes back on 'fs-garages:client:response' with the same
    number.

    Every request is held to a speed limit per player, so pressing Take Out
    fifty times does fifty times nothing, not fifty cars.
]]

local util = Garage.util

--- The shortest gap allowed between two requests of the same kind, in ms.
local GAPS = { ['kiosk:open'] = 500, retrieve = 2000, transfer = 2000, park = 1500, recover = 2000 }

--- And no more than this many requests of any kind in ten seconds.
local BURST = 25

local handlers = {
    ['kiosk:open'] = function(src, data) return Garage.openKiosk(src, data) end,
    retrieve = function(src, data) return Garage.retrieve(src, data) end,
    transfer = function(src, data) return Garage.transfer(src, data) end,
    recover = function(src, data) return Garage.recover(src, data) end,
    park = function(src, data) return Garage.park(src, data) end,
}

local seen = {}

local function allowed(src, action)
    local now = GetGameTimer()
    local mine = seen[src]
    if not mine then
        mine = { window = now, count = 0 }
        seen[src] = mine
    end
    if now - mine.window > 10000 then
        mine.window, mine.count = now, 0
    end
    mine.count = mine.count + 1
    if mine.count > BURST then return false end

    local last = mine[action]
    if last and now - last < (GAPS[action] or 500) then return false end
    mine[action] = now
    return true
end

RegisterNetEvent('fs-garages:server:request', function(requestId, action, data)
    local src = source
    if not util.number(requestId) or type(action) ~= 'string' then return end

    local handler = handlers[action]
    if not handler then return end

    if not Bridge then
        TriggerClientEvent('fs-garages:client:response', src, requestId, false, 'err_unknown')
        return
    end
    if not allowed(src, action) then
        TriggerClientEvent('fs-garages:client:response', src, requestId, false, 'err_slow')
        return
    end

    local ok, success, result = pcall(handler, src, type(data) == 'table' and data or {})
    if not ok then
        util.error(('%s from player %s failed: %s'):format(action, src, tostring(success)))
        success, result = false, 'err_unknown'
    end
    TriggerClientEvent('fs-garages:client:response', src, requestId, success == true, result)
end)

AddEventHandler('playerDropped', function()
    seen[source] = nil
end)


-- The database is made ready for the garages once the framework is known
-- (ESX without esx_garage gets the two columns the garages keep).
AddEventHandler('fs-garages:bridgeReady', function()
    CreateThread(function()
        Bridge.install()
    end)
end)
