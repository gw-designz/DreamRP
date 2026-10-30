--[[
    fs-garages / client/parking.lua

    Parking: drive into one of a garage's spaces, stop, and press E.

    While the player drives near a garage that keeps their kind of vehicle,
    its spaces are outlined on the ground. Stopped inside one, the prompt
    to park shows. The look of the car is read off it here and sent with
    the request; the server checks the rest (whose car, which space) and
    puts it away.
]]

local util = Garage.util

--- How big a space is drawn, by garage type (width, length, in metres).
local SIZE = { car = { 2.6, 5.4 }, boat = { 4.5, 11.0 }, air = { 10.0, 10.0 } }

--- The garage type a vehicle belongs in, from the game's own class.
local function typeOf(vehicle)
    local class = GetVehicleClass(vehicle)
    if class == 14 then return 'boat' end
    if class == 15 or class == 16 then return 'air' end
    return 'car'
end
Garage.typeOfVehicle = typeOf

--- The outline of a space, flat on the ground.
local function outline(spot, kind, free)
    local size = SIZE[kind] or SIZE.car
    local hw, hl = size[1] / 2, size[2] / 2
    local r = math.rad(spot.w)
    local c, s = math.cos(r), math.sin(r)
    local function at(x, y) return spot.x + x * c - y * s, spot.y + x * s + y * c end
    local z = spot.z + 0.05
    local corners = { { at(-hw, -hl) }, { at(hw, -hl) }, { at(hw, hl) }, { at(-hw, hl) } }
    local cr, cg, cb = 255, 255, 255
    if not free then cr, cg, cb = 120, 120, 120 end
    for i = 1, 4 do
        local a, b = corners[i], corners[i % 4 + 1]
        DrawLine(a[1], a[2], z, b[1], b[2], z, cr, cg, cb, 200)
    end
end

local parking = false

local function park(vehicle, garage)
    if parking then return end
    parking = true
    local plate = GetVehicleNumberPlateText(vehicle)
    -- Taken now: the car is gone once the server has parked it.
    local display = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local props = Garage.Props.get(vehicle)
    local ok, result = Garage.request('park', { garage = garage.id, net = NetworkGetNetworkIdFromEntity(vehicle), props = props }, 10000)
    if ok then
        Garage.Integrations.call('keys', 'clientRemove', vehicle, util.plate(plate), display)
        Garage.notify(L('parked', garage.label), 'success')
    else
        Garage.refused(result)
    end
    Wait(800)
    parking = false
end

--- The garage near the player that keeps their kind of vehicle.
local function nearestGarage(pos, kind)
    local best, bestGap
    for _, garage in ipairs(Garage.list()) do
        if garage.type == kind and garage.kind ~= 'depot' and garage.spots and #garage.spots > 0 then
            local gap = util.flat(pos, garage.kiosk)
            for _, spot in ipairs(garage.spots) do gap = math.min(gap, util.flat(pos, spot)) end
            if gap < 60.0 and (not bestGap or gap < bestGap) then best, bestGap = garage, gap end
        end
    end
    return best
end

--- The space of that garage the car stands in, if any.
local function spotAt(garage, pos)
    local reach = Config.Parking.reach or 2.5
    for _, spot in ipairs(garage.spots) do
        if math.abs(pos.z - spot.z) < 3.0 and util.flat(pos, spot) <= reach then return spot end
    end
end

local shown = nil   -- { key, handle } of the seated prompt on show

local function hide()
    if shown then Prompt.remove(shown.handle) end
    shown = nil
end

--[[
    What the drawing needs, worked out twice a second: the garage close by
    and which of its spaces have a car in them. Looking through every garage
    and asking the game about every space each frame cost far more than the
    drawing itself.
]]
local near = nil    -- { garage, kind, vehicle, taken = { [index] = true } }

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local found = nil
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            local kind = typeOf(vehicle)
            local garage = nearestGarage(GetEntityCoords(vehicle), kind)
            if garage then
                local taken = {}
                if Config.Parking.showSpaces ~= false then
                    for i, s in ipairs(garage.spots) do
                        taken[i] = IsAnyVehicleNearPoint(s.x, s.y, s.z, 1.8)
                    end
                end
                found = { garage = garage, kind = kind, vehicle = vehicle, taken = taken }
            end
        end
        near = found
        Wait(found and 500 or 1500)
    end
end)

CreateThread(function()
    while true do
        local now = near
        local ped = PlayerPedId()
        if not now or GetVehiclePedIsIn(ped, false) ~= now.vehicle then
            hide()
            Wait(250)
        else
            local vehicle, garage = now.vehicle, now.garage
            local pos = GetEntityCoords(vehicle)
            local spot = spotAt(garage, pos)
            if Config.Parking.showSpaces ~= false then
                for i, s in ipairs(garage.spots) do
                    -- The car's own space counts as free: it is the one being parked in.
                    if util.flat(pos, s) < 40.0 then outline(s, now.kind, s == spot or not now.taken[i]) end
                end
            end
            local slow = GetEntitySpeed(vehicle) * 3.6 <= (Config.Parking.maxSpeed or 3)
            if spot and slow then
                local key = garage.id
                if not shown or shown.key ~= key then
                    hide()
                    shown = { key = key, handle = Prompt.seated(vector3(spot.x, spot.y, spot.z + 1.0), {
                        label = L('park'),
                        icon = 'square-parking',
                        show = function() return not parking end,
                        action = function() park(vehicle, garage) end,
                    }) }
                end
                if not shown.handle and not parking then
                    Prompt.draw(vector3(pos.x, pos.y, pos.z + 1.2), ('[E] %s'):format(L('park'):upper()))
                    if IsControlJustPressed(0, Config.Key) and not IsNuiFocused() then
                        CreateThread(function() park(vehicle, garage) end)
                    end
                end
            else
                hide()
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then hide() end
end)
