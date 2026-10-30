--[[
    fs-garages / client/creator.lua

    /garagecreator: making and changing garages in game, for admins (the
    server decides who may).

    The creator is a window on the admin's screen. It lists the garages; a
    garage has a name, a type (cars, boats, aircraft), who may use it, a
    kiosk and its parking spaces. The kiosk and each space are put down by
    looking at the ground: the window steps aside, a copy follows wherever
    the admin looks, the mouse wheel turns it, and a click puts it there.
    A space can also be taken from where the admin's own car stands, so the
    lines of a real car park are matched exactly.

    While a garage is open in the window, the world shows it as it is in
    the window, not as it was saved, so what is seen is what will be saved.
]]

local util = Garage.util

local open = false
local placing = false
local kioskGhost = nil   -- the see-through kiosk of the garage being edited

local ACCENT = { 64, 140, 255 }
local KIOSK = GetHashKey('fs_garage_kiosk')

--- How big a space is drawn, by garage type (width, length, in metres).
local SIZE = { car = { 2.6, 5.4 }, boat = { 4.5, 11.0 }, air = { 10.0, 10.0 } }

local function words()
    local out = {}
    for key, value in pairs(Locales['en'] or {}) do
        if key:sub(1, 5) == 'ui_c_' then out[key:sub(6)] = value end
    end
    for key, value in pairs(Locales[Config.Locale] or {}) do
        if key:sub(1, 5) == 'ui_c_' then out[key:sub(6)] = value end
    end
    return out
end

local function loadKiosk()
    if not IsModelInCdimage(KIOSK) then return false end
    RequestModel(KIOSK)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(KIOSK) and GetGameTimer() < deadline do Wait(50) end
    return HasModelLoaded(KIOSK)
end

--- A see-through kiosk nobody can bump into.
local function ghost(place)
    local object = CreateObjectNoOffset(KIOSK, place.x, place.y, place.z, false, false, false)
    SetEntityHeading(object, place.w + 0.0)
    FreezeEntityPosition(object, true)
    SetEntityCollision(object, false, false)
    SetEntityAlpha(object, 215, false)
    return object
end

local function removeGhost()
    if kioskGhost and DoesEntityExist(kioskGhost) then DeleteEntity(kioskGhost) end
    kioskGhost = nil
end

--- The outline of a space on the ground, with an arrow the way the car faces.
local function outline(spot, kind, r, g, b)
    local size = SIZE[kind] or SIZE.car
    local hw, hl = size[1] / 2, size[2] / 2
    local rad = math.rad(spot.w)
    local c, s = math.cos(rad), math.sin(rad)
    local function at(x, y) return spot.x + x * c - y * s, spot.y + x * s + y * c end
    local z = spot.z + 0.05
    local corners = { { at(-hw, -hl) }, { at(hw, -hl) }, { at(hw, hl) }, { at(-hw, hl) } }
    for i = 1, 4 do
        local p, q = corners[i], corners[i % 4 + 1]
        DrawLine(p[1], p[2], z, q[1], q[2], z, r, g, b, 230)
    end
    local tipX, tipY = at(0, hl - 0.4)
    local leftX, leftY = at(-0.5, hl - 1.2)
    local rightX, rightY = at(0.5, hl - 1.2)
    DrawLine(leftX, leftY, z, tipX, tipY, z, r, g, b, 230)
    DrawLine(rightX, rightY, z, tipX, tipY, z, r, g, b, 230)
end

local function label3d(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextFont(4)
    SetTextScale(0.0, 0.38)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local draft = nil
local skipSpot = nil   -- the space being moved, hidden while its copy follows the view

--- Shows the garage the window is editing: its kiosk as a see-through copy.
local function showDraft(skipKiosk)
    removeGhost()
    if type(draft) == 'table' and type(draft.kiosk) == 'table' and not skipKiosk and loadKiosk() then
        kioskGhost = ghost(draft.kiosk)
    end
end

-- The spaces of the garage being edited, outlined and numbered while the window is open.
CreateThread(function()
    while true do
        if open and type(draft) == 'table' and type(draft.spots) == 'table' and #draft.spots > 0 then
            for i, spot in ipairs(draft.spots) do
                if skipSpot ~= i then
                    outline(spot, draft.type, 255, 255, 255)
                    label3d(spot.x, spot.y, spot.z + 0.6, tostring(i))
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

local function close()
    if not open then return end
    open = false
    placing = false
    draft = nil
    Garage.editing = nil
    removeGhost()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'creator', open = false })
end

RegisterNetEvent('fs-garages:creator', function()
    if open then return end
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'creator', open = true, garages = Garage.list(), words = words() })
end)

-- The window is kept up to date when the list changes under it.
Garage.onGaragesChanged(function()
    if open then SendNUIMessage({ action = 'creator', garages = Garage.list() }) end
end)

RegisterNetEvent('fs-garages:creator:saved', function(id, problem)
    if not open then return end
    if problem then
        SendNUIMessage({ action = 'saved', id = false, problem = L(problem) })
    else
        SendNUIMessage({ action = 'saved', id = id })
    end
end)

RegisterNUICallback('creator:close', function(_, cb)
    close()
    cb({})
end)

--- The garage the window has open, or none (nil id and no draft).
RegisterNUICallback('creator:edit', function(data, cb)
    cb({})
    if not open or type(data) ~= 'table' then return end
    Garage.editing = type(data.id) == 'string' and data.id or (data.draft and '__new' or nil)
    draft = data.draft
    if not placing then showDraft(false) end
end)

RegisterNUICallback('creator:goto', function(data, cb)
    cb({})
    local c = type(data) == 'table' and data.place
    if open and c and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then
        local ped = PlayerPedId()
        -- A step back from it, so the admin is not stood inside it.
        local r = math.rad((tonumber(c.w) or 0.0) + 0.0)
        SetEntityCoords(ped, c.x - math.sin(r) * 2.5, c.y + math.cos(r) * 2.5, c.z + 0.1, false, false, false, false)
    end
end)

--- Where the admin's own car stands, as a space: middle of the car on the
--- ground, facing the way the car faces.
RegisterNUICallback('creator:here', function(_, cb)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        cb({ place = false, problem = L('ui_c_need_car') })
        return
    end
    local c = GetEntityCoords(vehicle)
    local found, ground = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
    local z = (found and math.abs(ground - c.z) < 3.0) and ground or (c.z - GetEntityHeightAboveGround(vehicle))
    -- A boat floats: its space is on the water where it is.
    if Garage.typeOfVehicle(vehicle) == 'boat' then z = c.z - 0.5 end
    cb({ place = { x = c.x, y = c.y, z = z, w = GetEntityHeading(vehicle) % 360.0 } })
end)

RegisterNUICallback('creator:save', function(data, cb)
    cb({})
    if open and type(data) == 'table' then TriggerServerEvent('fs-garages:creator:save', data.id, data.def) end
end)

RegisterNUICallback('creator:delete', function(data, cb)
    cb({})
    if open and type(data) == 'table' then TriggerServerEvent('fs-garages:creator:delete', data.id) end
end)

-- ════════════════════════════════════════════════════════════════════════
--  Putting a kiosk or a space on the ground
-- ════════════════════════════════════════════════════════════════════════

local KEY = { place = 24, cancel = 25, back = 177, wheelUp = 15, wheelDown = 14, left = 174, right = 175, fine = 21 }

--- Where the admin is looking: the first thing a line from the camera runs
--- into, and which way that surface faces. For boats, water counts.
local function lookingAt(onWater)
    local from = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local reach = onWater and 60.0 or 25.0
    local to = from + dir * reach
    -- 1 is the map and buildings, 16 is objects standing in them.
    local probe = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 17, PlayerPedId(), 7)
    local _, hit, at, normal = GetShapeTestResult(probe)
    if onWater then
        local wet, height = TestProbeAgainstWater(from.x, from.y, from.z, to.x, to.y, to.z)
        if wet and (hit ~= 1 and hit ~= true or #(height - from) < #(at - from)) then
            return height, vector3(0.0, 0.0, 1.0)
        end
    end
    if hit ~= 1 and hit ~= true then return nil end
    return at, normal
end

local function hints(kind)
    SendNUIMessage({
        action = 'hints',
        items = kind and {
            { key = 'MOUSE L', label = L('ui_c_hint_place') },
            { key = 'SCROLL', label = L(kind == 'kiosk' and 'ui_c_hint_turn_kiosk' or 'ui_c_hint_turn_spot') },
            { key = 'SHIFT', label = L('ui_c_hint_fine') },
            { key = 'MOUSE R', label = L('ui_c_hint_cancel') },
        } or {},
    })
end

--- Returns { x, y, z, w } where it was put, or nil when cancelled. `from`
--- is where it stood before, if it is being moved.
local function placeOnGround(kind, from)
    if kind == 'kiosk' and not loadKiosk() then
        Garage.notify(L('ui_c_models_missing'), 'error')
        return nil
    end
    hints(kind)
    local garageType = type(draft) == 'table' and draft.type or 'car'
    local yaw = GetGameplayCamRot(2).z
    -- A kiosk turns its screen to the admin; a space faces away from them,
    -- the way a car drives into it.
    local heading = from and from.w or (kind == 'kiosk' and (yaw + 180.0) % 360.0 or yaw % 360.0)
    local preview = nil
    local result = nil
    local nextTurn = 0

    while placing do
        Wait(0)
        DisablePlayerFiring(PlayerId(), true)
        for _, control in ipairs({ KEY.place, KEY.cancel, KEY.wheelUp, KEY.wheelDown, KEY.left, KEY.right, 140, 141, 142, 37, 16, 17 }) do
            DisableControlAction(0, control, true)
        end

        local now = GetGameTimer()
        local step = IsControlPressed(0, KEY.fine) and 1.0 or 5.0
        if IsDisabledControlJustPressed(0, KEY.wheelUp) then heading = (heading + step) % 360.0 end
        if IsDisabledControlJustPressed(0, KEY.wheelDown) then heading = (heading - step) % 360.0 end
        if now >= nextTurn then
            if IsDisabledControlPressed(0, KEY.left) then heading, nextTurn = (heading + step) % 360.0, now + 60 end
            if IsDisabledControlPressed(0, KEY.right) then heading, nextTurn = (heading - step) % 360.0, now + 60 end
        end

        local at, normal = lookingAt(kind == 'spot' and garageType == 'boat')
        local spot = nil
        if at and normal.z > 0.75 then
            spot = { x = at.x, y = at.y, z = at.z, w = heading }
        end

        local hand = GetEntityCoords(PlayerPedId()) + vector3(0.0, 0.0, 0.35)
        if spot then
            DrawLine(hand.x, hand.y, hand.z, spot.x, spot.y, spot.z, ACCENT[1], ACCENT[2], ACCENT[3], 255)
            if kind == 'kiosk' then
                if preview and DoesEntityExist(preview) then
                    SetEntityCoordsNoOffset(preview, spot.x, spot.y, spot.z, false, false, false)
                    SetEntityHeading(preview, spot.w)
                else
                    preview = ghost(spot)
                end
            else
                outline(spot, garageType, ACCENT[1], ACCENT[2], ACCENT[3])
            end
        else
            if at then DrawLine(hand.x, hand.y, hand.z, at.x, at.y, at.z, 255, 59, 82, 255) end
            if preview and DoesEntityExist(preview) then DeleteEntity(preview) end
            preview = nil
        end

        if IsDisabledControlJustPressed(0, KEY.place) and spot then
            result = spot
            placing = false
        elseif IsDisabledControlJustPressed(0, KEY.cancel) or IsControlJustPressed(0, KEY.back) then
            placing = false
        end
    end

    if preview and DoesEntityExist(preview) then DeleteEntity(preview) end
    hints(nil)
    return result
end

RegisterNUICallback('creator:place', function(data, cb)
    cb({})
    if not open or placing or type(data) ~= 'table' then return end
    local kind, key = data.kind, tostring(data.key or '')
    if kind ~= 'kiosk' and kind ~= 'spot' then return end
    local from = type(data.from) == 'table' and tonumber(data.from.w) and data.from or nil

    placing = true
    -- The window steps aside so the ground can be seen and pointed at.
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'creator', hidden = true })

    CreateThread(function()
        -- The one being moved steps out of sight while its copy follows the view.
        if kind == 'kiosk' then showDraft(true) else skipSpot = tonumber(key:match('^spot(%d+)$')) end
        local place = placeOnGround(kind, from)
        placing = false
        skipSpot = nil
        if open then
            showDraft(false)
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'creator', hidden = false })
            SendNUIMessage({ action = 'placed', key = key, kind = kind, place = place or false })
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    placing = false
    if open then SetNuiFocus(false, false) end
    removeGhost()
end)

util.debug('creator ready')
