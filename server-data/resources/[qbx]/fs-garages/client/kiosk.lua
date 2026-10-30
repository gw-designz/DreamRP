--[[
    fs-garages / client/kiosk.lua

    The kiosk at each garage, its screen painted on it for everyone walking
    past. [E] (or the target) brings the camera up to the screen and frees
    the mouse; the player picks their car on the kiosk itself.

    The screen is a page (web/build/kiosk.html) the game opens off screen
    and paints onto the kiosk's glass. shared/kiosk.lua decides what is on
    it, where, and what a press does; this file places the kiosks, paints
    them, turns the mouse into a point on the glass, and asks the server.

    Each garage's idle screen shows its name; the player's own screen is a
    picture of its own while they use a kiosk.
]]

local util = Garage.util

local MODEL = GetHashKey('fs_garage_kiosk')
local TXD = 'fs_garage_kiosk_dui'
local URL = ('nui://%s/web/build/kiosk.html'):format(GetCurrentResourceName())

-- The glass on the model, in its own coordinates (scratchpad/garages/
-- build_kiosk.py): 0.54 x 0.72 m, facing +Y. Seen from the front, the
-- model's +X is on the viewer's left.
local GLASS = { x = 0.27, bottom = 1.03, top = 1.75, out = 0.068 }
local PLACE_DISTANCE, PAINT_DISTANCE = 90.0, 30.0
local FOV = 45.0

local function words()
    local out = {}
    for key, value in pairs(Locales['en'] or {}) do
        if key:sub(1, 3) == 'ui_' then out[key:sub(4)] = value end
    end
    for key, value in pairs(Locales[Config.Locale] or {}) do
        if key:sub(1, 3) == 'ui_' then out[key:sub(4)] = value end
    end
    return out
end

-- ── what kind of vehicle a model is ────────────────────────────────────

--- The game's own vehicle type, as the server needs it to make the car.
local function vehicleType(hash)
    if IsThisModelAHeli(hash) then return 'heli' end
    if IsThisModelAPlane(hash) then return 'plane' end
    if IsThisModelAnAmphibiousCar(hash) then return 'amphibious_automobile' end
    if IsThisModelAnAmphibiousQuadbike(hash) then return 'amphibious_quadbike' end
    if IsThisModelABoat(hash) or IsThisModelAJetski(hash) then return 'boat' end
    if IsThisModelAQuadbike(hash) then return 'quadbike' end
    if IsThisModelABike(hash) or IsThisModelABicycle(hash) then return 'bike' end
    if GetVehicleClassFromName(hash) == 14 then return 'submarine' end
    return 'automobile'
end

--- Which garage type keeps a vehicle type.
local GARAGE_OF = {
    heli = 'air', plane = 'air', boat = 'boat', submarine = 'boat',
    automobile = 'car', bike = 'car', quadbike = 'car', amphibious_automobile = 'car', amphibious_quadbike = 'car',
}

local function hashOf(model)
    if type(model) == 'string' then return GetHashKey(model) end
    return tonumber(model)
end

--- The name players know a model by ("Sultan"), from the game.
local function nameOf(hash, fallback)
    local display = hash and GetDisplayNameFromVehicleModel(hash) or nil
    if display and display ~= '' and display ~= 'CARNOTFOUND' then
        local text = GetLabelText(display)
        return text ~= 'NULL' and text or display
    end
    return fallback
end

--- The server's answer, made ready for the screen: only the cars this
--- garage keeps, each with its name and picture.
local function prepare(data)
    local garage = data.garage or {}
    local cars, types = {}, {}
    for _, car in ipairs(data.cars or {}) do
        local hash = hashOf(car.model)
        local known = hash and IsModelInCdimage(hash)
        local kind = known and vehicleType(hash) or 'automobile'
        -- The model itself is the surest answer: ESX writes 'car' for
        -- anything bought at the ordinary shop, helicopters included. The
        -- written kind only decides for a model the game does not have.
        local fits
        if known then fits = GARAGE_OF[kind] == garage.type else fits = (car.kind or 'car') == garage.type end
        if fits then
            types[car.plate] = kind
            cars[#cars + 1] = {
                plate = car.plate,
                label = nameOf(hash, car.name or car.plate),
                model = car.name,
                image = car.name and (Config.CarPictures or ''):gsub('{model}', car.name) or nil,
                place = car.place, at = car.at,
                recover = car.recover or nil,
                recoverFee = car.recover and ((car.recoverFee or 0) > 0 and util.money(car.recoverFee) or '') or nil,
                fuel = car.fuel or 100,
                engine = (car.engine or 1000) / 10,
                body = (car.body or 1000) / 10,
            }
        end
    end
    table.sort(cars, function(a, b) return a.label < b.label end)
    return { garage = garage, cars = cars, fee = util.money(data.fee or 0) }, types
end

-- ── the pictures ───────────────────────────────────────────────────────

local txd = nil
local sheets = {}   -- name -> { dui, name, ready }

local function send(sheet, view)
    if sheet and sheet.ready then SendDuiMessage(sheet.dui, json.encode({ action = 'view', view = view })) end
end

local function makeSheet(name, firstView)
    if sheets[name] then return sheets[name] end
    local sheet = { name = name, ready = false }
    sheets[name] = sheet
    sheet.dui = CreateDui(URL, Kiosk.W, Kiosk.H)
    if not txd then txd = CreateRuntimeTxd(TXD) end
    CreateRuntimeTextureFromDuiHandle(txd, name, GetDuiHandle(sheet.dui))
    CreateThread(function()
        local waited = 0
        while not IsDuiAvailable(sheet.dui) and waited < 8000 do
            Wait(100)
            waited = waited + 100
        end
        -- A moment more for the page inside it to be listening.
        Wait(600)
        sheet.ready = true
        send(sheet, firstView)
    end)
    return sheet
end

--- The resting screen of one garage's kiosk, with its name on it.
local function idleSheet(garage)
    return makeSheet('idle_' .. garage.id, Kiosk.view(Kiosk.new({ garage = { label = garage.label } }), nil, words()))
end

--- Paint a picture on four corners in the world: top left, top right,
--- bottom right, bottom left. Both ways round, because the game only paints
--- one face of a triangle.
local function paint(c, name)
    local a, b, d, e = c[1], c[2], c[3], c[4]
    DrawTexturedPoly(a.x, a.y, a.z, b.x, b.y, b.z, d.x, d.y, d.z, 255, 255, 255, 255, TXD, name, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
    DrawTexturedPoly(a.x, a.y, a.z, d.x, d.y, d.z, e.x, e.y, e.z, 255, 255, 255, 255, TXD, name, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawTexturedPoly(d.x, d.y, d.z, b.x, b.y, b.z, a.x, a.y, a.z, 255, 255, 255, 255, TXD, name, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
    DrawTexturedPoly(e.x, e.y, e.z, d.x, d.y, d.z, a.x, a.y, a.z, 255, 255, 255, 255, TXD, name, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0)
end

local function cornersOf(object)
    local function at(x, z) return GetOffsetFromEntityInWorldCoords(object, x, GLASS.out, z) end
    return { at(GLASS.x, GLASS.top), at(-GLASS.x, GLASS.top), at(-GLASS.x, GLASS.bottom), at(GLASS.x, GLASS.bottom) }
end

-- ── the kiosks in the world ────────────────────────────────────────────

local placed = {}   -- garage id -> { object, prompt }
local using = nil   -- { garage, object, state, types, corners, hover, lastSent }
local opening = false
local use

local function place(garage)
    if not IsModelInCdimage(MODEL) then return end
    RequestModel(MODEL)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(MODEL) and GetGameTimer() < deadline do Wait(50) end
    if not HasModelLoaded(MODEL) then return end
    local k = garage.kiosk
    local object = CreateObjectNoOffset(MODEL, k.x, k.y, k.z, false, false, false)
    SetEntityHeading(object, (k.w or 0.0) + 0.0)
    FreezeEntityPosition(object, true)
    SetEntityInvincible(object, true)
    SetModelAsNoLongerNeeded(MODEL)
    local id = garage.id
    placed[id] = {
        object = object,
        -- Half a metre in front of the screen, about chest high.
        prompt = Prompt.entity(object, vec3(0.0, 0.5, 1.2), { {
            label = L('use_kiosk'), icon = 'square-parking',
            show = function() return using == nil and not opening end,
            action = function() use(id) end,
        } }),
    }
end

local function clear(id)
    local entry = placed[id]
    if not entry then return end
    Prompt.remove(entry.prompt)
    if DoesEntityExist(entry.object) then DeleteEntity(entry.object) end
    placed[id] = nil
end

Garage.onGaragesChanged(function()
    for id in pairs(placed) do clear(id) end
end)

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local known = {}
        for _, garage in ipairs(Garage.list()) do
            known[garage.id] = true
            local k = garage.kiosk
            local far = #(me - vec3(k.x, k.y, k.z))
            local entry = placed[garage.id]
            if Garage.editing == garage.id then
                clear(garage.id)
            elseif far < PLACE_DISTANCE and not (entry and DoesEntityExist(entry.object)) then
                clear(garage.id)
                place(garage)
            elseif far > PLACE_DISTANCE + 20.0 and entry then
                clear(garage.id)
            end
        end
        for id in pairs(placed) do
            if not known[id] then clear(id) end
        end
        Wait(1000)
    end
end)

-- ── a car coming out ───────────────────────────────────────────────────

--- The car the server just made in a space: its look put back on and its
--- keys handed over.
local function receive(data)
    local deadline = GetGameTimer() + 5000
    while not NetworkDoesNetworkIdExist(data.net) and GetGameTimer() < deadline do Wait(50) end
    local vehicle = NetworkDoesNetworkIdExist(data.net) and NetToVeh(data.net) or 0
    if vehicle == 0 then return end
    deadline = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
        NetworkRequestControlOfEntity(vehicle)
        Wait(50)
    end
    Garage.Props.set(vehicle, data.props)
    SetVehicleNumberPlateText(vehicle, data.plate)
    SetVehicleDoorsLocked(vehicle, 1)
    Garage.Integrations.call('keys', 'client', vehicle, data.plate)
end

-- ── using one ──────────────────────────────────────────────────────────

local function push(force)
    if not using then return end
    local view = Kiosk.view(using.state, using.hover, words())
    local text = json.encode(view)
    if not force and text == using.lastSent then return end
    using.lastSent = text
    send(sheets.live, view)
end

local function failed(code)
    if not using then return end
    using.state.busy = false
    Kiosk.showError(using.state, L(type(code) == 'string' and code or 'err_unknown'), GetGameTimer())
    push(true)
end

--- Asks the kiosk's list again (after a car left or came over).
local function refresh(mine)
    local ok, fresh = Garage.request('kiosk:open', { garage = mine.garage })
    if ok and using == mine then
        local data, types = prepare(fresh)
        mine.types = types
        Kiosk.update(mine.state, data)
        push(false)
    end
end

--- Typing a search: ox_lib's box when the server has it, the game's own otherwise.
local function ask(title, current)
    if GetResourceState('ox_lib') == 'started' then
        local ok, input = pcall(function() return exports.ox_lib:inputDialog(title, { { type = 'input', default = current } }) end)
        if ok then return input and input[1] or nil end
    end
    AddTextEntry('FSG_SEARCH', title)
    DisplayOnscreenKeyboard(1, 'FSG_SEARCH', '', current or '', '', '', '', 24)
    while UpdateOnscreenKeyboard() == 0 do Wait(0) end
    if UpdateOnscreenKeyboard() == 1 then return GetOnscreenKeyboardResult() end
    return nil
end

local function handle(effect)
    if not effect or not using then return end
    local mine = using
    local s = mine.state

    if effect.kind == 'search' then
        CreateThread(function()
            local text = ask(L('ui_search'), s.q)
            if text and using == mine then
                Kiosk.search(s, text)
                push(false)
            end
        end)
    elseif effect.kind == 'retrieve' or effect.kind == 'recover' then
        s.busy = true
        push(true)
        CreateThread(function()
            local ok, data = Garage.request(effect.kind, { garage = mine.garage, plate = effect.plate, type = mine.types[effect.plate] }, 12000)
            if not ok then return failed(data) end
            if using == mine then
                s.busy = false
                Kiosk.showDone(s, L(effect.kind == 'recover' and 'ui_back_done' or 'ui_out_done'), GetGameTimer())
                push(true)
            end
            -- The camera comes back while the car is readied in its space.
            SetTimeout(900, function() if using == mine then using = nil end end)
            receive(data)
        end)
    elseif effect.kind == 'transfer' then
        s.busy = true
        push(true)
        CreateThread(function()
            local ok, data = Garage.request('transfer', { garage = mine.garage, plate = effect.plate }, 10000)
            if not ok then return failed(data) end
            if using == mine then
                s.busy = false
                Kiosk.showDone(s, L('ui_moved_done'), GetGameTimer())
                push(true)
                refresh(mine)
            end
        end)
    end
end

--- Where the camera stands: square on to the glass, back far enough that
--- the screen fills nine tenths of the view's height.
local function cameraFor(corners, object)
    local middle = (corners[1] + corners[3]) / 2
    local height = #(corners[1] - corners[4])
    local distance = (height / 0.9 / 2) / math.tan(math.rad(FOV / 2))
    return middle + GetEntityForwardVector(object) * distance, middle
end

local KEY = { click = 24, wheelUp = 241, wheelDown = 242, q = 44, e = 38, esc = 200, back = 202, rclick = 25 }

use = function(garageId)
    local entry = placed[garageId]
    local object = entry and entry.object
    if using or opening or not object or not DoesEntityExist(object) then return end
    opening = true
    -- Made when a kiosk first comes near; a visit straight away waits for it.
    local live = makeSheet('live', nil)
    local deadline = GetGameTimer() + 8000
    while not live.ready and GetGameTimer() < deadline do Wait(100) end
    if not live.ready then
        opening = false
        return Garage.notify(L('err_not_ready'), 'error')
    end

    local ok, answer = Garage.request('kiosk:open', { garage = garageId })
    opening = false
    if not ok then return Garage.refused(answer) end

    local data, types = prepare(answer)
    local state = Kiosk.new(data)
    state.started = true
    -- With nothing here, the screen opens on every car instead of an empty page.
    local any = false
    for _, car in ipairs(data.cars) do if car.place == 'here' then any = true end end
    if not any then state.tab = 'all' end
    using = { garage = garageId, object = object, state = state, types = types, corners = cornersOf(object) }
    push(true)

    local from, look = cameraFor(using.corners, object)
    TaskTurnPedToFaceCoord(PlayerPedId(), look.x, look.y, look.z, 800)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', from.x, from.y, from.z, 0.0, 0.0, 0.0, FOV, false, 2)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)

    CreateThread(function()
        local checked, ticked = 0, 0
        local mine = using
        while using == mine do
            DisableAllControlActions(0)
            SetMouseCursorThisFrame()
            HideHudAndRadarThisFrame()

            -- Which part of the glass the pointer is over.
            local quad, whole = {}, true
            for n, corner in ipairs(mine.corners) do
                local onScreen, x, y = GetScreenCoordFromWorldCoord(corner.x, corner.y, corner.z)
                if not onScreen then whole = false end
                quad[n] = { x = x, y = y }
            end
            local target = nil
            if whole then
                local u, v = Kiosk.uvAt(quad, GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240))
                if u and u >= 0 and u <= 1 and v >= 0 and v <= 1 then
                    target = Kiosk.hit(mine.state, u * Kiosk.W, v * Kiosk.H)
                end
            end
            if target ~= mine.hover then
                mine.hover = target
                push(false)
            end

            local s = mine.state
            if IsDisabledControlJustPressed(0, KEY.click) and target then
                handle(Kiosk.press(s, target))
                push(false)
            elseif IsDisabledControlJustPressed(0, KEY.wheelUp) then
                Kiosk.wheel(s, -1)
                push(false)
            elseif IsDisabledControlJustPressed(0, KEY.wheelDown) then
                Kiosk.wheel(s, 1)
                push(false)
            elseif IsDisabledControlJustPressed(0, KEY.q) then
                Kiosk.key(s, 'q')
                push(false)
            elseif IsDisabledControlJustPressed(0, KEY.e) then
                Kiosk.key(s, 'e')
                push(false)
            elseif IsDisabledControlJustPressed(0, KEY.esc) or IsDisabledControlJustPressed(0, KEY.back)
                or IsDisabledControlJustPressed(0, KEY.rclick) then
                if Kiosk.key(s, 'back') == 'leave' and not s.busy then using = nil end
                push(false)
            end

            local now = GetGameTimer()
            if now - ticked > 150 then
                ticked = now
                if Kiosk.tick(s, now) then push(false) end
            end
            if now - checked > 250 then
                checked = now
                local me = PlayerPedId()
                if IsEntityDead(me) or not DoesEntityExist(object) or #(GetEntityCoords(me) - GetEntityCoords(object)) > 3.5 then
                    using = nil
                end
            end
            Wait(0)
        end

        RenderScriptCams(false, true, 500, true, true)
        SetTimeout(600, function() DestroyCam(cam, false) end)
    end)
end

-- ── painting ───────────────────────────────────────────────────────────

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local near = {}
        for id, entry in pairs(placed) do
            local object = entry.object
            local garage = util.garage(id)
            if garage and DoesEntityExist(object) and #(me - GetEntityCoords(object)) < PAINT_DISTANCE then
                near[#near + 1] = { object = object, corners = cornersOf(object), sheet = idleSheet(garage) }
                -- The player's own screen too, so it is ready by the time they use it.
                makeSheet('live', nil)
            end
        end
        if #near == 0 then
            Wait(500)
        else
            -- Repainted every frame for half a second, then the kiosks are
            -- looked up again.
            local untilAt = GetGameTimer() + 500
            while GetGameTimer() < untilAt do
                for _, k in ipairs(near) do
                    local sheet = (using and using.object == k.object and sheets.live) or k.sheet
                    if sheet.ready and DoesEntityExist(k.object) then paint(k.corners, sheet.name) end
                end
                Wait(0)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if using then
        using = nil
        RenderScriptCams(false, false, 0, true, true)
    end
    for id in pairs(placed) do clear(id) end
    for _, sheet in pairs(sheets) do
        if sheet.dui then DestroyDui(sheet.dui) end
    end
end)
