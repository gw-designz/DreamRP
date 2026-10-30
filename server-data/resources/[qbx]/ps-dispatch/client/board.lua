-- Client half of the dispatch board (server/board.lua): relays roster and
-- log pushes to the NUI, loads the full state when the menu opens, and feeds
-- the compass / street strip while the menu is on screen.

local cfg = Config.Board or {}
local menuOpen = false

RegisterNetEvent('ps-dispatch:client:boardRoster', function(roster)
    SendNUIMessage({ action = 'boardRoster', data = roster })
end)

RegisterNetEvent('ps-dispatch:client:boardLog', function(entry)
    SendNUIMessage({ action = 'boardLogEntry', data = entry })
end)

local HEADINGS = { 'N', 'NW', 'W', 'SW', 'S', 'SE', 'E', 'NE' }
local function compass(heading)
    return HEADINGS[math.floor(((heading + 22.5) % 360) / 45) + 1]
end

local function streetHud()
    local ped = cache.ped
    local c = GetEntityCoords(ped)
    local streetHash, crossHash = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local cross = crossHash ~= 0 and GetStreetNameFromHashKey(crossHash) or ''
    local zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    return {
        heading = compass(GetEntityHeading(ped)),
        street = (cross ~= '' and street ~= '') and (street .. ' / ' .. cross) or street,
        zone = zone ~= 'NULL' and zone or '',
    }
end

-- Called from toggleUI in client/main.lua.
function BoardSetOpen(open)
    menuOpen = open
    if not open or cfg.Enabled == false then return end

    CreateThread(function()
        local state = lib.callback.await('ps-dispatch:callback:getBoard', false)
        if state then SendNUIMessage({ action = 'boardState', data = state }) end
    end)

    if cfg.StreetHud == false then return end
    CreateThread(function()
        while menuOpen do
            SendNUIMessage({ action = 'streetHud', data = streetHud() })
            Wait(500)
        end
        SendNUIMessage({ action = 'streetHud', data = false })
    end)
end

RegisterNUICallback('boardMessage', function(data, cb)
    if type(data) == 'table' and type(data.text) == 'string' then
        TriggerServerEvent('ps-dispatch:server:boardMessage', data.text)
    end
    cb('ok')
end)

-- Roster "locate" button: waypoint on another unit's current position.
RegisterNUICallback('locateUnit', function(data, cb)
    cb('ok')
    local at = lib.callback.await('ps-dispatch:callback:unitPosition', false, data and data.src)
    if at then
        SetNewWaypoint(at.x, at.y)
        lib.notify({ description = locale('waypoint_set'), position = 'top', type = 'success' })
    end
end)
