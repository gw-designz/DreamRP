-- NUI <-> server bridge for the NoPixel-style apps, plus the client-only pieces they need
-- (vehicle names, waypoints, zone names, config values, the Config.Apps hand-off).

local function bridge(nuiEvent, serverEvent, wrap)
    RegisterNUICallback(nuiEvent, function(data, cb)
        local payload = type(data) == 'table' and data or {}
        if wrap then payload = wrap(payload) end
        cb(TriggerCallback(serverEvent, payload) or { ok = false, reason = 'error' })
    end)
end
NPBridge = bridge

-- simple server-backed endpoints: phone:np:<name>  ->  oph3z-phone:server:np:<name>
for _, name in ipairs({
    'licenses', 'licenses:show',
    'garage:keys', 'garage:takeout',
    -- business
    'biz:list', 'biz:create', 'biz:get', 'biz:invites', 'biz:respond', 'biz:invite', 'biz:post',
    'biz:role', 'biz:fire', 'biz:cancelInvite', 'biz:leave', 'biz:edit', 'biz:delete',
    -- crypto
    'crypto:home', 'crypto:history', 'crypto:buy', 'crypto:sell', 'crypto:transfer',
    -- calendar / government / news / events
    'cal:month', 'cal:add', 'cal:delete',
    'gov:home', 'gov:list', 'gov:post', 'gov:delete', 'gov:ballot', 'gov:vote',
    'news:list', 'news:get', 'news:publish', 'news:delete',
    'ev:list', 'ev:create', 'ev:join', 'ev:vote', 'ev:delete',
    -- property / real estate
    'prop:buy', 'prop:sell', 'prop:keys', 'prop:giveKey', 'prop:removeKey',
    -- guber
    'guber:state', 'guber:cancel', 'guber:online', 'guber:decline', 'guber:complete', 'guber:rate', 'guber:profile',
    -- roach / grey book / scoot-e
    'roach:state', 'roach:open', 'roach:save', 'roach:sites', 'roach:publish', 'roach:unpublish','gb:list', 'gb:save', 'gb:remove', 'scoot:state',
}) do
    bridge('phone:np:' .. name, 'oph3z-phone:server:np:' .. name)
end

-- Vehicle display names only exist on the client, so resolve them here.
local function vehicleLabel(model, hash)
    local h = tonumber(hash)
    if not h and type(model) == 'string' and model ~= '' then h = joaat(model) end
    if h and IsModelInCdimage(h) then
        local code = GetDisplayNameFromVehicleModel(h)
        local make = GetMakeNameFromVehicleModel and GetMakeNameFromVehicleModel(h) or nil
        local label = code and GetLabelText(code) or nil
        if label and label ~= 'NULL' then
            local makeLabel = make and make ~= '' and GetLabelText(make) or nil
            if makeLabel and makeLabel ~= 'NULL' then return makeLabel .. ' ' .. label end
            return label
        end
    end
    return type(model) == 'string' and model ~= '' and model or 'Vehicle'
end

RegisterNUICallback('phone:np:garage', function(_, cb)
    local res = TriggerCallback('oph3z-phone:server:np:garage')
    if type(res) ~= 'table' or not res.ok then
        cb(res or { ok = false })
        return
    end
    for _, v in ipairs(res.vehicles or {}) do
        v.label = vehicleLabel(v.model, v.hash)
        v.model, v.hash = nil, nil
    end
    cb(res)
end)

RegisterNUICallback('phone:np:garage:track', function(data, cb)
    local res = TriggerCallback('oph3z-phone:server:np:garage:track', type(data) == 'table' and data or {})
    if type(res) == 'table' and res.ok and res.x then SetNewWaypoint(res.x + 0.0, res.y + 0.0) end
    cb(res or { ok = false })
end)

RegisterNUICallback('phone:np:waypoint', function(data, cb)
    if type(data) == 'table' and tonumber(data.x) and tonumber(data.y) then
        SetNewWaypoint(tonumber(data.x) + 0.0, tonumber(data.y) + 0.0)
        cb({ ok = true })
        return
    end
    cb({ ok = false })
end)

RegisterNetEvent('oph3z-phone:client:np:licenseShown', function(card)
    if type(card) ~= 'table' then return end
    local text = ('%s shows you their %s · State ID %s · DOB %s'):format(
        tostring(card.name or '?'), tostring(card.label or 'ID'), tostring(card.stateId or '?'), tostring(card.dob or '?'))
    Notify(text, 'inform')
    if Phone.isOpen then
        SendNUIMessage({ action = 'phone:toast', data = { title = card.label or 'ID', body = card.name .. ' · ' .. tostring(card.stateId or '') } })
    end
end)

-- Config values the apps need (config.lua is shared, so the client can read it directly).
local CONFIG_KEYS = {
    lemon = function() return (Config.LemonList and Config.LemonList.Categories) or {} end,
    garage = function()
        local g = Config.Garage or {}
        return { takeOut = type(g.TakeOutEvent) == 'string' and g.TakeOutEvent ~= '', keys = g.ShareKeys ~= false }
    end,
}
NPConfigKeys = CONFIG_KEYS

RegisterNUICallback('phone:np:config', function(data, cb)
    local fn = type(data) == 'table' and CONFIG_KEYS[data.key]
    cb({ ok = fn ~= nil, value = fn and fn() or nil })
end)

local function appEntry(id)
    for _, a in ipairs(Config.Apps or {}) do
        if a.id == id then return a end
    end
    return nil
end

RegisterNUICallback('phone:np:bridge', function(data, cb)
    local entry = type(data) == 'table' and appEntry(data.id) or nil
    if not entry or not (entry.clientEvent or entry.command) then
        cb({ ok = false })
        return
    end
    cb({ ok = true })
    if not entry.keepOpen then Phone.close() end
    if entry.clientEvent then
        TriggerEvent(entry.clientEvent, entry.eventArgs)
    elseif entry.command then
        ExecuteCommand(entry.command)
    end
end)

-- ---------------------------------------------------------------- Guber
local function zoneAt(x, y, z)
    local code = GetNameOfZone(x + 0.0, y + 0.0, (z or 0.0) + 0.0)
    local label = code and GetLabelText(code) or nil
    if not label or label == 'NULL' then return code or '' end
    return label
end

local function withWaypoint(res)
    if type(res) == 'table' and res.ok and type(res.waypoint) == 'table' and res.waypoint.x then
        SetNewWaypoint(res.waypoint.x + 0.0, res.waypoint.y + 0.0)
    end
    return res
end

RegisterNUICallback('phone:np:guber:request', function(data, cb)
    data = type(data) == 'table' and data or {}
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local payload = { index = data.index, pickupLabel = zoneAt(c.x, c.y, c.z) }
    if data.waypoint then
        local blip = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blip) then
            cb({ ok = false, reason = 'nowaypoint' })
            return
        end
        local w = GetBlipInfoIdCoord(blip)
        payload.x, payload.y = w.x, w.y
        payload.label = zoneAt(w.x, w.y, w.z)
    end
    cb(TriggerCallback('oph3z-phone:server:np:guber:request', payload) or { ok = false })
end)

for _, name in ipairs({ 'guber:accept', 'guber:pickup' }) do
    RegisterNUICallback('phone:np:' .. name, function(data, cb)
        cb(withWaypoint(TriggerCallback('oph3z-phone:server:np:' .. name, type(data) == 'table' and data or {})) or { ok = false })
    end)
end

RegisterNetEvent('oph3z-phone:client:np:guber', function(payload)
    SendNUIMessage({ action = 'phone:np:guber', data = payload })
end)

-- ---------------------------------------------------------------- waypoint endpoints
-- server returns { ok, x, y } and the client sets the GPS waypoint
for _, name in ipairs({ 'ev:locate', 'prop:locate' }) do
    RegisterNUICallback('phone:np:' .. name, function(data, cb)
        local res = TriggerCallback('oph3z-phone:server:np:' .. name, type(data) == 'table' and data or {})
        if type(res) == 'table' and res.ok and res.x then SetNewWaypoint(res.x + 0.0, res.y + 0.0) end
        cb(res or { ok = false })
    end)
end

-- Property list: add the distance from the player to each listing (Real Estate sort/filter).
RegisterNUICallback('phone:np:prop:list', function(_, cb)
    local res = TriggerCallback('oph3z-phone:server:np:prop:list')
    if type(res) == 'table' and res.ok then
        local c = GetEntityCoords(PlayerPedId())
        for _, l in ipairs(res.listings or {}) do
            if l.x then
                local dx, dy = l.x - c.x, l.y - c.y
                l.distance = math.floor(math.sqrt(dx * dx + dy * dy))
            end
        end
    end
    cb(res or { ok = false })
end)

-- ---------------------------------------------------------------- Scoot-E
local scooter = nil

local function deleteScooter()
    if scooter and DoesEntityExist(scooter) then
        SetEntityAsMissionEntity(scooter, true, true)
        DeleteVehicle(scooter)
    end
    scooter = nil
end

RegisterNUICallback('phone:np:scoot:rent', function(_, cb)
    local res = TriggerCallback('oph3z-phone:server:np:scoot:rent')
    if type(res) ~= 'table' or not res.ok then
        cb(res or { ok = false })
        return
    end
    local cfg = Config.ScootE or {}
    local hash = joaat(res.model or 'faggio')
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(20) end
    if not HasModelLoaded(hash) then
        TriggerCallback('oph3z-phone:server:np:scoot:end')
        cb({ ok = false, reason = 'model' })
        return
    end
    local ped = PlayerPedId()
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
    deleteScooter()
    scooter = CreateVehicle(hash, c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleOnGroundProperly(scooter)
    local plate = ('SCOOT%03d'):format(math.random(0, 999))
    SetVehicleNumberPlateText(scooter, plate)
    SetVehicleFuelLevel(scooter, 100.0)
    Entity(scooter).state:set('fuel', 100.0, true)
    if cfg.KeysEvent then TriggerEvent(cfg.KeysEvent, plate) end
    if cfg.WarpIn ~= false then TaskWarpPedIntoVehicle(ped, scooter, -1) end
    res.plate = plate
    cb(res)
end)

RegisterNUICallback('phone:np:scoot:end', function(_, cb)
    deleteScooter()
    cb(TriggerCallback('oph3z-phone:server:np:scoot:end') or { ok = true })
end)

RegisterNUICallback('phone:np:scoot:locate', function(_, cb)
    if scooter and DoesEntityExist(scooter) then
        local c = GetEntityCoords(scooter)
        SetNewWaypoint(c.x, c.y)
        cb({ ok = true })
        return
    end
    cb({ ok = false, reason = 'gone' })
end)

RegisterNetEvent('oph3z-phone:client:np:scootEnd', function(reason)
    deleteScooter()
    SendNUIMessage({ action = 'phone:np:scootEnd', data = { reason = reason } })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then deleteScooter() end
end)
