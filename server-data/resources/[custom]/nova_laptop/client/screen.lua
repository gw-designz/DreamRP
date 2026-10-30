--[[
    The desktop painted on placed laptops, the way Renewed-Banking paints its
    ATMs.

    web/dist/index.html?mode=dui is opened off screen as two DUIs: an idle
    page (the lock screen) that every placed laptop nearby shows, and a live
    page, the owner's desktop, shown on the laptop they are using. Each is
    drawn onto the laptop's glass with DrawTexturedPoly every frame.

    While a laptop is in use the camera faces the glass. The game keeps the
    mouse: the cursor's ray is met with the glass and passed in with
    SendDuiMouseMove/Down/Up. The keyboard goes to the NUI page only while a
    text field on the desktop has the caret, and that page passes each key on.

    Where the glass is: screens.json (staff line it up with /laptopscreen),
    then Config.Display.Screens, then a fit from the model's size.
]]

LaptopScreen = {}

local G = LaptopGeometry
local RESOURCE = GetCurrentResourceName()
local URL = ('nui://%s/web/dist/index.html?mode=dui&res=%s'):format(RESOURCE, RESOURCE)
local TXD = 'nova_laptop_dui'
local NAME = Config.Placement.Prop
local MODEL = GetHashKey(NAME)
local HINTS = { { 24, 'Select' }, { 200, 'Close laptop' } }
local KEY = { click = 24, rclick = 25, wheelUp = 241, wheelDown = 242, esc = 200, back = 202 }

local overrides = {} -- model name -> screen, from the server
local nearby = {}    -- { { entity, corners } } placed laptops close enough to paint
local active = nil   -- the laptop in use: { entity, corners, cam, typing, held }
local editing = nil  -- the laptop whose screen is on the gizmo: { entity, corners }
local outlines = false

-- ── where the glass is ─────────────────────────────────────────────────

local fitted = nil
local function screen()
    if overrides[NAME] then return overrides[NAME] end
    local configured = Config.Display.Screens and Config.Display.Screens[NAME]
    if type(configured) == 'table' then return configured end
    if not fitted then
        local min, max = GetModelDimensions(MODEL)
        fitted = G.fit(min, max)
    end
    return fitted
end

local function worldCorners(entity)
    local out = {}
    for i, c in ipairs(G.corners(screen())) do out[i] = GetOffsetFromEntityInWorldCoords(entity, c.x, c.y, c.z) end
    return out
end

local function refreshCorners()
    for _, laptop in ipairs(nearby) do laptop.corners = worldCorners(laptop.entity) end
    if active then active.corners = worldCorners(active.entity) end
end

RegisterNetEvent('nova_laptop:client:screens', function(all)
    overrides = type(all) == 'table' and all or {}
    refreshCorners()
end)

RegisterNetEvent('nova_laptop:client:screen', function(name, value)
    overrides[name] = value or nil
    refreshCorners()
end)

CreateThread(function() TriggerServerEvent('nova_laptop:server:screens') end)

-- ── the pages ──────────────────────────────────────────────────────────

local txd = nil
local sheets = {} -- name -> { dui, ready }

local function send(sheet, message)
    if sheet and sheet.ready then SendDuiMessage(sheet.dui, json.encode(message)) end
end

local function makeSheet(name, firstMessage)
    if sheets[name] then return sheets[name] end
    local sheet = { name = name, ready = false }
    sheets[name] = sheet
    sheet.dui = CreateDui(URL, G.W, G.H)
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
        if firstMessage then send(sheet, firstMessage) end
    end)
    return sheet
end

--- The desktop on the laptop in use.
function LaptopScreen.send(message) send(sheets.live, message) end

--- Waits for the live page, making it on first use.
function LaptopScreen.prepare()
    local live = makeSheet('live', nil)
    local deadline = GetGameTimer() + 9000
    while not live.ready and GetGameTimer() < deadline do Wait(100) end
    return live.ready
end

function LaptopScreen.markReady() end

--- Paint a page on four world corners. Both ways round, because the game
--- only paints one face of a triangle.
local function paint(c, name)
    local a, b, d, e = c[1], c[2], c[3], c[4]
    DrawTexturedPoly(a.x, a.y, a.z, b.x, b.y, b.z, d.x, d.y, d.z, 255, 255, 255, 255, TXD, name, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
    DrawTexturedPoly(a.x, a.y, a.z, d.x, d.y, d.z, e.x, e.y, e.z, 255, 255, 255, 255, TXD, name, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawTexturedPoly(d.x, d.y, d.z, b.x, b.y, b.z, a.x, a.y, a.z, 255, 255, 255, 255, TXD, name, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
    DrawTexturedPoly(e.x, e.y, e.z, d.x, d.y, d.z, a.x, a.y, a.z, 255, 255, 255, 255, TXD, name, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0)
end

-- ── the laptops nearby ─────────────────────────────────────────────────

local function placed(object)
    return GetEntityModel(object) == MODEL and NetworkGetEntityIsNetworked(object) and Entity(object).state.novaLaptop ~= nil
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local found = {}
        for _, object in ipairs(GetGamePool('CObject')) do
            if #(me - GetEntityCoords(object)) < Config.Display.PaintDistance and placed(object) then
                found[#found + 1] = { entity = object, corners = worldCorners(object) }
            end
        end
        nearby = found
        if #found > 0 then
            makeSheet('idle', { type = 'idle' })
            -- The player's own page too, so it is ready by the time they use one.
            makeSheet('live', nil)
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        if #nearby == 0 and not active then
            Wait(500)
        else
            local idle, live = sheets.idle, sheets.live
            for _, laptop in ipairs(nearby) do
                if DoesEntityExist(laptop.entity) then
                    local mine = active and active.entity == laptop.entity
                    local sheet = mine and live or idle
                    local edited = editing and editing.entity == laptop.entity
                    local c = edited and editing.corners or laptop.corners
                    if sheet and sheet.ready then paint(c, sheet.name) end
                    if outlines or edited then
                        for i = 1, 4 do
                            local from, to = c[i], c[i % 4 + 1]
                            DrawLine(from.x, from.y, from.z, to.x, to.y, to.z, 255, 40, 40, 255)
                        end
                    end
                end
            end
            Wait(0)
        end
    end
end)

-- ── using one ──────────────────────────────────────────────────────────

function LaptopScreen.active() return active ~= nil end

--- Lends the keyboard to the NUI page while a field on the desktop has the
--- caret; it passes each key on. The game keeps its input, so the mouse
--- still moves over the screen.
local function setTyping(mine, value)
    if mine.typing == value then return end
    mine.typing = value
    SetNuiFocus(value, false)
    SetNuiFocusKeepInput(value)
    SendNUIMessage({ type = 'relay', on = value })
end

function LaptopScreen.typing(value)
    if active then setTyping(active, value == true) end
end

local ESCAPE = { key = 'Escape', code = 'Escape', shift = false, ctrl = false, alt = false, meta = false, ['repeat'] = false }

local function run(mine)
    local dui = sheets.live.dui
    local lastX, lastY = -1, -1
    while active == mine do
        DisableAllControlActions(0)
        EnableControlAction(0, 249, true) -- push to talk
        SetMouseCursorThisFrame()
        HideHudAndRadarThisFrame()

        -- Where the pointer's ray meets the glass.
        local ray = G.rayFrom(GetCamRot(mine.cam, 2), GetCamFov(mine.cam), GetAspectRatio(false),
            GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240))
        local u, v = G.uvFromRay(GetCamCoord(mine.cam), ray, mine.corners)
        if u and u >= 0 and u <= 1 and v >= 0 and v <= 1 then
            local px, py = math.floor(u * G.W), math.floor(v * G.H)
            if px ~= lastX or py ~= lastY then
                lastX, lastY = px, py
                SendDuiMouseMove(dui, px, py)
            end
        end

        if IsDisabledControlJustPressed(0, KEY.click) then SendDuiMouseDown(dui, 'left') mine.held.left = true end
        if IsDisabledControlJustReleased(0, KEY.click) then SendDuiMouseUp(dui, 'left') mine.held.left = nil end
        if IsDisabledControlJustPressed(0, KEY.rclick) then SendDuiMouseDown(dui, 'right') mine.held.right = true end
        if IsDisabledControlJustReleased(0, KEY.rclick) then SendDuiMouseUp(dui, 'right') mine.held.right = nil end
        if IsDisabledControlJustPressed(0, KEY.wheelUp) then SendDuiMouseWheel(dui, 120, 0) end
        if IsDisabledControlJustPressed(0, KEY.wheelDown) then SendDuiMouseWheel(dui, -120, 0) end
        -- While a field is being typed into, Escape comes as a key from the NUI page.
        if not mine.typing and (IsDisabledControlJustPressed(0, KEY.esc) or IsDisabledControlJustPressed(0, KEY.back)) then
            send(sheets.live, { type = 'keys', keys = { ESCAPE } })
        end

        Hints.draw(HINTS)
        Wait(0)
    end

    for button in pairs(mine.held) do SendDuiMouseUp(dui, button) end
    setTyping(mine, false)
    -- A new visit may already have its own camera running.
    if not active then RenderScriptCams(false, true, 500, true, true) end
    SetTimeout(600, function() DestroyCam(mine.cam, false) end)
end

--- Moves the camera to the laptop's screen and runs it until stop().
function LaptopScreen.start(entity)
    if active or not sheets.live or not sheets.live.ready or not DoesEntityExist(entity) then return false end
    local s = screen()
    local mine = { entity = entity, corners = worldCorners(entity), typing = false, held = {} }
    local from = G.camera(s, Config.Display.Fov, Config.Display.Fill)
    local camPos = GetOffsetFromEntityInWorldCoords(entity, from.x, from.y, from.z)
    local look = GetOffsetFromEntityInWorldCoords(entity, s.x, s.y, s.z)
    mine.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, Config.Display.Fov + 0.0, false, 2)
    PointCamAtCoord(mine.cam, look.x, look.y, look.z)
    SetCamActive(mine.cam, true)
    RenderScriptCams(true, true, 500, true, true)
    active = mine
    CreateThread(function() run(mine) end)
    return true
end

function LaptopScreen.stop()
    if not active then return end
    active = nil
    send(sheets.live, { type = 'close' })
end

-- ── lining the screen up ───────────────────────────────────────────────

--[[
    Staff line the screen up at any placed laptop; the server saves it
    (screens.json) and every player gets it straight away.

    /laptopscreen                 move, turn and scale it with object_gizmo
    /laptopscreen reset           back to Config.Display.Screens or the fit
    /laptopscreen outline         outline every nearby screen
    /laptopscreen x y z width height tilt
]]

local HELPER = GetHashKey('prop_cs_tablet')

LaptopScreen.notify = function() end
local function notify(text) LaptopScreen.notify(text) end

local function drawSize(size)
    SetTextFont(4)
    SetTextScale(0.0, 0.42)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('Screen %.3f x %.3f m'):format(size.width, size.height))
    EndTextCommandDisplayText(0.5, 0.92)
end

local function configLine(s)
    return ('%s = { x = %.4f, y = %.4f, z = %.4f, width = %.4f, height = %.4f, tilt = %.2f },'):format(NAME, s.x, s.y, s.z, s.width, s.height, s.tilt)
end

-- A question for the server, answered by an event.
local waiting = {}
local function ask(event, answer, ...)
    local p = promise.new()
    waiting[answer] = p
    TriggerServerEvent(event, ...)
    SetTimeout(5000, function() if waiting[answer] == p then waiting[answer] = nil p:resolve(nil) end end)
    return Citizen.Await(p)
end
local function answered(answer)
    return function(...)
        local p = waiting[answer]
        waiting[answer] = nil
        if p then p:resolve({ ... }) end
    end
end
RegisterNetEvent('nova_laptop:client:canEditScreen', answered('canEdit'))
RegisterNetEvent('nova_laptop:client:screenSaved', answered('saved'))

local function saveScreen(value)
    local reply = ask('nova_laptop:server:saveScreen', 'saved', NAME, value)
    if not reply or not reply[1] then return notify(reply and reply[2] or 'The server did not answer.') end
    print(configLine(reply[2]))
    notify('Laptop screen saved for every laptop. Its config.lua line is in F8.')
end

local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

--- The screen's frame in the world: the laptop's own axes with the glass
--- tipped back by its tilt. Its forward points into the laptop.
local function screenFrame(entity, s)
    local forward, right, up = GetEntityMatrix(entity)
    local t = math.rad(s.tilt or 0.0)
    return {
        right = right,
        up = forward * math.sin(t) + up * math.cos(t),
        forward = forward * math.cos(t) - up * math.sin(t),
        position = GetOffsetFromEntityInWorldCoords(entity, s.x, s.y, s.z),
    }
end

--- The helper's axes stay a metre long until the gizmo's scale handle
--- stretches them: their lengths are how much the screen has grown.
local function sizeFromHelper(helper, base)
    local _, right, up = GetEntityMatrix(helper)
    return { width = base.width * #right, height = base.height * #up }
end

local function cornersFromHelper(helper, width, height)
    local _, right, up, position = GetEntityMatrix(helper)
    local r, u = norm(right) * (width / 2), norm(up) * (height / 2)
    return { position - r + u, position + r + u, position + r - u, position - r - u }
end

local function editWithGizmo(entity)
    if GetResourceState('object_gizmo') ~= 'started' then return notify('object_gizmo is not running.') end
    local s = screen()
    local base = { width = s.width, height = s.height }
    local size = base

    RequestModel(HELPER)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(HELPER) and GetGameTimer() < deadline do Wait(20) end
    local frame = screenFrame(entity, s)
    local helper = CreateObjectNoOffset(HELPER, frame.position.x, frame.position.y, frame.position.z, false, false, false)
    SetModelAsNoLongerNeeded(HELPER)
    SetEntityCollision(helper, false, false)
    FreezeEntityPosition(helper, true)
    SetEntityAlpha(helper, 0, false)
    local f, r, u, p = frame.forward, frame.right, frame.up, frame.position
    SetEntityMatrix(helper, f.x, f.y, f.z, r.x, r.y, r.z, u.x, u.y, u.z, p.x, p.y, p.z)

    editing = { entity = entity, corners = cornersFromHelper(helper, size.width, size.height) }
    notify('W move, R rotate, S scale the screen. Enter saves, Esc cancels.')

    -- The screen follows the helper as the gizmo moves, turns and scales it.
    CreateThread(function()
        while editing and DoesEntityExist(helper) do
            size = sizeFromHelper(helper, base)
            editing.corners = cornersFromHelper(helper, size.width, size.height)
            drawSize(size)
            Wait(0)
        end
    end)

    local result = exports.object_gizmo:useGizmo(helper, {
        space = 'local',     -- the handles run along the screen, not the world
        pivot = 'origin',    -- the helper's origin is the screen's middle
        enableScale = true,  -- [S] stretches the screen
        snapToGround = false,
        outline = false,
        freezeEntity = true,
    })

    local kept = result and not result.cancelled and result.confirmed ~= false and DoesEntityExist(helper)
    if not kept then
        editing = nil
        if DoesEntityExist(helper) then DeleteEntity(helper) end
        return notify('Laptop screen unchanged.')
    end
    -- Back from the world into the laptop's own coordinates.
    size = sizeFromHelper(helper, base)
    local _, _, up, position = GetEntityMatrix(helper)
    local forward, _, laptopUp = GetEntityMatrix(entity)
    local offset = GetOffsetFromEntityGivenWorldCoords(entity, position.x, position.y, position.z)
    local tilt = math.deg(math.atan(dot(up, forward), dot(up, laptopUp)))
    editing = nil
    DeleteEntity(helper)
    saveScreen({ x = offset.x, y = offset.y, z = offset.z, width = size.width, height = size.height, tilt = tilt })
end

local function closest()
    local me = GetEntityCoords(PlayerPedId())
    local found, distance = nil, 4.0
    for _, laptop in ipairs(nearby) do
        local far = #(me - GetEntityCoords(laptop.entity))
        if far < distance then found, distance = laptop, far end
    end
    return found
end

--- Set by main.lua: closes the laptop before its screen is lined up.
LaptopScreen.beforeEdit = function() end

RegisterCommand('laptopscreen', function(_, args)
    if args[1] == 'outline' then
        outlines = not outlines
        return notify(outlines and 'Laptop screen outlines on.' or 'Laptop screen outlines off.')
    end
    if editing then return notify('Already lining a screen up: press Enter to finish that first.') end
    local wasOpen = active ~= nil
    LaptopScreen.beforeEdit()
    CreateThread(function()
        -- The camera eases back to the player first.
        if wasOpen then Wait(700) end
        local laptop = closest()
        if not laptop then return notify('Stand at a placed laptop first.') end
        local allowed = ask('nova_laptop:server:canEditScreen', 'canEdit')
        if not allowed or not allowed[1] then return notify('Only staff can change laptop screens.') end
        if #args == 0 then return editWithGizmo(laptop.entity) end
        if args[1] == 'reset' then
            TriggerServerEvent('nova_laptop:server:resetScreen', NAME)
            return notify('Laptop screen back to its default.')
        end
        local values = {}
        for i = 1, 6 do
            values[i] = tonumber(args[i])
            if not values[i] then return notify('Usage: /laptopscreen [reset | outline | x y z width height tilt]') end
        end
        saveScreen({ x = values[1], y = values[2], z = values[3], width = values[4], height = values[5], tilt = values[6] })
    end)
end, false)

--- How far the camera sits back: /laptopzoom 0.72 (the share of the view's
--- height the screen fills). Prints the value for config.lua.
RegisterCommand('laptopzoom', function(_, args)
    local fill = tonumber(args[1])
    if fill then Config.Display.Fill = math.max(0.3, math.min(1.0, fill)) end
    print(('Fill = %.2f,'):format(Config.Display.Fill))
end, false)

AddEventHandler('onResourceStop', function(name)
    if name ~= RESOURCE then return end
    if active then
        RenderScriptCams(false, false, 0, true, true)
        active = nil
    end
    for _, sheet in pairs(sheets) do
        if sheet.dui then DestroyDui(sheet.dui) end
    end
end)
