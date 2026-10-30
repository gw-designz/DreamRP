RenewedBanking = RenewedBanking or {}
local RB = RenewedBanking
local Screen = RB.AtmScreen

--[[
    The ATM screen painted on the machines themselves.

    web/dist/atm.html is opened off screen as a DUI and its picture is drawn
    onto each nearby machine's glass with DrawTexturedPoly. Everyone sees the
    idle page; the player using a machine sees their own live page on it.
    While in use the camera faces the glass, the mouse is mapped from the
    monitor onto the page and passed in with SendDuiMouseMove/Down/Up, and the
    page calls back through the ordinary NUI callbacks.
]]

RB.Client.atm = {}

local resource = GetCurrentResourceName()
local URL = ('nui://%s/web/dist/atm.html?resource=%s'):format(resource, resource)
local TXD = 'renewed_banking_atm'
local KEY = { click = 24, rclick = 25, wheelUp = 241, wheelDown = 242, q = 44, e = 38, esc = 200, back = 202 }

-- model hash -> { name, screen, corners (model coordinates) }
local screens = {}
local function loadScreens()
    screens = {}
    for name, screen in pairs(Config.atm.screens or {}) do
        screens[joaat(name)] = { name = name, screen = screen, corners = Screen.corners(screen) }
    end
end
loadScreens()

-- ── the pages ───────────────────────────────────────────────────────────

local txd = nil
local sheets = {} -- name -> { dui, ready }

local function send(sheet, message)
    if sheet and sheet.ready then SendDuiMessage(sheet.dui, json.encode(message)) end
end

local function makeSheet(name, firstMessage)
    if sheets[name] then return sheets[name] end
    local sheet = { name = name, ready = false }
    sheets[name] = sheet
    sheet.dui = CreateDui(URL, Screen.W, Screen.H)
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

local function idleMessage() return { type = 'idle', brand = Config.branding } end

--- Paint a sheet on four world corners (top left, top right, bottom right,
--- bottom left). Both ways round, because the game only paints one face.
local function paint(c, name)
    local a, b, d, e = c[1], c[2], c[3], c[4]
    DrawTexturedPoly(a.x, a.y, a.z, b.x, b.y, b.z, d.x, d.y, d.z, 255, 255, 255, 255, TXD, name, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
    DrawTexturedPoly(a.x, a.y, a.z, d.x, d.y, d.z, e.x, e.y, e.z, 255, 255, 255, 255, TXD, name, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
    DrawTexturedPoly(d.x, d.y, d.z, b.x, b.y, b.z, a.x, a.y, a.z, 255, 255, 255, 255, TXD, name, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0)
    DrawTexturedPoly(e.x, e.y, e.z, d.x, d.y, d.z, a.x, a.y, a.z, 255, 255, 255, 255, TXD, name, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 1.0)
end

local function worldCorners(entity, info)
    local out = {}
    for i, c in ipairs(info.corners) do out[i] = GetOffsetFromEntityInWorldCoords(entity, c.x, c.y, c.z) end
    return out
end

--- The side buttons' hit boxes, in green and numbered. They lie on the glass's
--- plane, which sits behind the machine's bezel, so they are drawn over the
--- picture instead of in the world, where the bezel would hide them.
local keyFocus = nil -- while lining the buttons up: { row = n or nil, side = 'both' | 'left' | 'right' }

local function drawKeyBoxes(corners, keys)
    local half = keys.height / 2
    for row, centre in ipairs(keys.rows) do
        for side, span in pairs({ left = keys.left, right = keys.right }) do
            -- The row and side being moved show in yellow.
            local picked = keyFocus and (keyFocus.row == nil or keyFocus.row == row)
                and (keyFocus.side == 'both' or keyFocus.side == side) and (keyFocus.row or keyFocus.side ~= 'both')
            local r, g, b = 40, 255, 90
            if picked then r, g, b = 255, 210, 40 end
            local minX, minY, maxX, maxY, visible = 1, 1, 0, 0, true
            for _, point in ipairs({ { span[1], centre - half }, { span[2], centre - half }, { span[2], centre + half }, { span[1], centre + half } }) do
                local world = Screen.pointAt(corners, point[1], point[2])
                local onScreen, x, y = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)
                if not onScreen then visible = false break end
                minX, maxX = math.min(minX, x), math.max(maxX, x)
                minY, maxY = math.min(minY, y), math.max(maxY, y)
            end
            if visible then
                local w, h = maxX - minX, maxY - minY
                local cx, cy = minX + w / 2, minY + h / 2
                local edge = 0.0015
                DrawRect(cx, cy, w, h, r, g, b, 70)
                DrawRect(cx, minY, w, edge * 1.8, r, g, b, 255)
                DrawRect(cx, maxY, w, edge * 1.8, r, g, b, 255)
                DrawRect(minX, cy, edge, h, r, g, b, 255)
                DrawRect(maxX, cy, edge, h, r, g, b, 255)
                SetTextFont(4)
                SetTextScale(0.0, 0.32)
                SetTextColour(255, 255, 255, 255)
                SetTextOutline()
                SetTextCentre(true)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(tostring(row))
                EndTextCommandDisplayText(cx, cy - 0.012)
            end
        end
    end
end

-- ── the machines nearby ─────────────────────────────────────────────────

local nearby = {} -- { { entity, info, corners } }
local active = nil -- the machine in use: { entity, info, corners, cam, typing }
local opening = false
local outlines = false
local editing = nil -- the machine whose screen is on the gizmo: { entity, corners }

CreateThread(function()
    while true do
        if Config.atm.screen and next(screens) then
            local me = GetEntityCoords(cache.ped)
            local found = {}
            for _, object in ipairs(GetGamePool('CObject')) do
                local info = screens[GetEntityModel(object)]
                if info and #(me - GetEntityCoords(object)) < Config.atm.paintDistance then
                    found[#found + 1] = { entity = object, info = info, corners = worldCorners(object, info) }
                end
            end
            nearby = found
            -- The interact point sits on each one's screen.
            RB.Client.interactions.syncAtms(found)
            if #found > 0 then
                makeSheet('idle', idleMessage())
                -- The player's own page too, so it is ready by the time they use one.
                makeSheet('live', nil)
            end
            Wait(1500)
        else
            nearby = {}
            Wait(5000)
        end
    end
end)

CreateThread(function()
    while true do
        if #nearby == 0 and not active then
            Wait(500)
        else
            local idle, live = sheets.idle, sheets.live
            for _, machine in ipairs(nearby) do
                if DoesEntityExist(machine.entity) then
                    local mine = active and active.entity == machine.entity
                    local sheet = mine and live or idle
                    local edited = editing and editing.entity == machine.entity
                    local c = edited and editing.corners or machine.corners
                    if sheet and sheet.ready then paint(c, sheet.name) end
                    if outlines or edited then
                        for i = 1, 4 do
                            local from, to = c[i], c[i % 4 + 1]
                            DrawLine(from.x, from.y, from.z, to.x, to.y, to.z, 255, 40, 40, 255)
                        end
                        if machine.info.screen.keys then drawKeyBoxes(c, machine.info.screen.keys) end
                    end
                end
            end
            Wait(0)
        end
    end
end)

-- ── using one ───────────────────────────────────────────────────────────

function RB.Client.atm.canUse(entity)
    return Config.atm.screen == true and entity ~= nil and entity ~= 0 and DoesEntityExist(entity)
        and screens[GetEntityModel(entity)] ~= nil
end

function RB.Client.atm.isActive() return active ~= nil end

function RB.Client.atm.stop()
    if not active then return end
    active = nil
end

local function insertCard(ped)
    TaskStartScenarioInPlace(ped, 'PROP_HUMAN_ATM', 0, true)
    local progress = Config.interaction.progress
    local fn = progress.style == 'circle' and lib.progressCircle or lib.progressBar
    return fn({
        label = locale('open_atm'),
        duration = math.random(progress.durationMin, progress.durationMax),
        position = 'bottom',
        canCancel = true,
        useWhileDead = false,
        allowCuffed = false,
        disable = { car = true, move = true, combat = true }
    })
end

--- Lends the keyboard to the bank's own page (hidden) while a field on the
--- ATM's screen is being typed into; it passes each key on (atmKey). The
--- game keeps its input, so the mouse still moves over the screen.
local function setTyping(mine, value)
    if mine.typing == value then return end
    mine.typing = value
    SetNuiFocus(value, false)
    SetNuiFocusKeepInput(value)
    SendNUIMessage({ type = 'renewedBanking:atmTyping', active = value })
end

local function run(mine)
    local dui = sheets.live.dui
    local keys = mine.info.screen.keys
    local checked = 0
    local lastX, lastY = -1, -1
    local hoverKey = nil -- 'left:1' … the side button under the pointer
    -- Q / E already sit on the screen next to the tabs, so only the mouse keys go to the HUD.
    RB.Client.hudPrompts({
        { control = 24, key = 'LMB', label = 'Select' },
        { key = 'WHEELDOWN', label = 'Scroll' },
        { control = 25, key = 'RMB', label = 'Back' },
    })
    while active == mine do
        do
            DisableAllControlActions(0)
            SetMouseCursorThisFrame()
            HideHudAndRadarThisFrame()

            -- Where the pointer's ray meets the glass's plane: on the glass it
            -- moves the page's mouse, beside it it may be over a side button.
            local origin = GetCamCoord(mine.cam)
            local ray = Screen.rayFrom(GetCamRot(mine.cam, 2), GetCamFov(mine.cam), GetAspectRatio(false),
                GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240))
            local u, v = Screen.uvFromRay(origin, ray, mine.corners)
            if u and u >= 0 and u <= 1 and v >= 0 and v <= 1 then
                local px, py = math.floor(u * Screen.W), math.floor(v * Screen.H)
                if px ~= lastX or py ~= lastY then
                    lastX, lastY = px, py
                    SendDuiMouseMove(dui, px, py)
                end
            end
            local side, row = Screen.keyAt(keys, u, v)
            local key = side and (side .. ':' .. row) or nil
            if key ~= hoverKey then
                hoverKey = key
                -- Rows are 1-based here, 0-based on the page.
                send(sheets.live, { type = 'softkeyHover', side = side, index = row and row - 1 })
            end

            if IsDisabledControlJustPressed(0, KEY.click) then
                if side then
                    PlaySoundFrontend(-1, 'PIN_BUTTON', 'ATM_SOUNDS', true)
                    send(sheets.live, { type = 'softkey', side = side, index = row - 1 })
                else
                    SendDuiMouseDown(dui, 'left')
                end
            end
            if IsDisabledControlJustReleased(0, KEY.click) then SendDuiMouseUp(dui, 'left') end
            if IsDisabledControlJustPressed(0, KEY.wheelUp) then SendDuiMouseWheel(dui, 120, 0) end
            if IsDisabledControlJustPressed(0, KEY.wheelDown) then SendDuiMouseWheel(dui, -120, 0) end
            -- While a field is being typed into, the keys are the text's, not shortcuts.
            if not mine.typing then
                if IsDisabledControlJustPressed(0, KEY.q) then send(sheets.live, { type = 'key', key = 'q' }) end
                if IsDisabledControlJustPressed(0, KEY.e) then send(sheets.live, { type = 'key', key = 'e' }) end
                if IsDisabledControlJustPressed(0, KEY.esc) or IsDisabledControlJustPressed(0, KEY.back)
                    or IsDisabledControlJustPressed(0, KEY.rclick) then
                    send(sheets.live, { type = 'key', key = 'back' })
                end
            end
        end

        local now = GetGameTimer()
        if now - checked > 250 then
            checked = now
            local ped = cache.ped
            if IsEntityDead(ped) or not DoesEntityExist(mine.entity)
                or #(GetEntityCoords(ped) - GetEntityCoords(mine.entity)) > Config.atm.leaveDistance then
                active = nil
            end
        end
        Wait(0)
    end

    setTyping(mine, false)
    RB.Client.hudPrompts(nil)
    RenderScriptCams(false, true, 500, true, true)
    SetTimeout(600, function() DestroyCam(mine.cam, false) end)
    ClearPedTasks(cache.ped)
    RB.Client.state.atm = false
    send(sheets.live, idleMessage())
end

--- The side buttons' rows as page heights, for the page to line things up with.
local function softkeyRows(screen)
    if not screen.keys then return nil end
    local rows = {}
    for i, centre in ipairs(screen.keys.rows) do rows[i] = math.floor(centre * Screen.H) end
    return { rows = rows }
end

function RB.Client.atm.use(entity, context)
    if active or opening or RB.Client.state.open or not RB.Client.atm.canUse(entity) then return end
    opening = true
    local live = makeSheet('live', nil)
    local ped = cache.ped
    TaskTurnPedToFaceEntity(ped, entity, 600)
    Wait(600)
    if not insertCard(ped) then
        ClearPedTasks(ped)
        opening = false
        return
    end

    local deadline = GetGameTimer() + 8000
    while not live.ready and GetGameTimer() < deadline do Wait(100) end
    local session = live.ready and lib.callback.await('Renewed-Banking:server:v3:getSession', false, {})
    opening = false
    if not session or not session.ok then
        ClearPedTasks(ped)
        lib.notify({ title = locale('bank_name'), description = locale('loading_failed'), type = 'error' })
        return
    end

    local info = screens[GetEntityModel(entity)]
    local mine = { entity = entity, info = info, corners = worldCorners(entity, info), typing = false }
    active = mine
    RB.Client.state.atm = true
    send(live, {
        type = 'open',
        payload = {
            session = session.data,
            context = context,
            brand = Config.branding,
            quickAmounts = Config.atm.quickAmounts,
            pageSize = Config.atm.historyPageSize,
            softkeys = softkeyRows(info.screen)
        }
    })

    local from = Screen.camera(info.screen, Config.atm.fov)
    local camPos = GetOffsetFromEntityInWorldCoords(entity, from.x, from.y, from.z)
    local look = GetOffsetFromEntityInWorldCoords(entity, info.screen.x, info.screen.y, info.screen.z)
    mine.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, Config.atm.fov, false, 2)
    PointCamAtCoord(mine.cam, look.x, look.y, look.z)
    SetCamActive(mine.cam, true)
    RenderScriptCams(true, true, 500, true, true)

    CreateThread(function() run(mine) end)
end

-- ── what the page asks for ──────────────────────────────────────────────

-- A field on the ATM's screen gained or lost the caret.
RegisterNUICallback('atmFocus', function(data, cb)
    if active then setTyping(active, data.active == true) end
    cb({ ok = true })
end)

-- A key (or pasted text) from the bank's page, for the field being typed into.
RegisterNUICallback('atmKey', function(data, cb)
    if active and active.typing then
        send(sheets.live, {
            type = 'type',
            key = type(data.key) == 'string' and data.key:sub(1, 16) or nil,
            text = type(data.text) == 'string' and data.text:sub(1, 160) or nil,
            shift = data.shift == true
        })
    end
    cb({ ok = true })
end)

RegisterNUICallback('atmFinish', function(_, cb)
    active = nil
    cb({ ok = true })
end)

-- ── lining the screens up ───────────────────────────────────────────────

--[[
    Each ATM model has its own screen. Admins line one up at any machine of
    that model; the server saves it (atm_screens.json, over the defaults in
    Config.atm.screens) and every player gets it straight away.

    /atmscreen                 move and resize the screen with the gizmo
    /atmscreen keys            line up the machine's side buttons
    /atmscreen reset           back to the default in config.lua
    /atmscreen outline         outline every nearby screen (anyone can)
    /atmscreen x y z width height tilt
                               set the screen by hand
]]

local HELPER = joaat('prop_cs_tablet')
local SIZE_STEP = 0.0015 -- metres a frame while an arrow key is held
local KEY_SIZE = { left = 174, right = 175, up = 172, down = 173, fast = 21, wheelUp = 241, wheelDown = 242 }
local WHEEL_STEP = 0.01 -- a wheel notch grows or shrinks the screen by this share

-- The gizmo's cursor mode leaves some keys reading as disabled, so ask both ways.
local function held(control) return IsControlPressed(0, control) or IsDisabledControlPressed(0, control) end
local function tapped(control) return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control) end

local function drawSize(size)
    SetTextFont(4)
    SetTextScale(0.0, 0.42)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('Screen %.3f x %.3f m  ~c~Wheel: resize   Arrows: width / height   Shift: faster'):format(size.width, size.height))
    EndTextCommandDisplayText(0.5, 0.92)
end
local KEYS_STEP = 0.002 -- fraction of the screen a frame while a key is held
local KEY_EDIT = { up = 172, down = 173, left = 174, right = 175, shift = 21, taller = 10, shorter = 11, save = 191, cancel = 194, remove = 178 }
local DEFAULT_KEYS = { rows = { 0.2, 0.4, 0.6, 0.8 }, height = 0.1, left = { -0.15, -0.02 }, right = { 1.02, 1.15 } }

-- The screens as config.lua has them, for /atmscreen reset.
local defaults = lib.table.deepclone(Config.atm.screens or {})

local function notify(text, kind)
    lib.notify({ title = 'ATM screens', description = text, type = kind })
end

local function closestMachine()
    local me = GetEntityCoords(cache.ped)
    local closest, distance = nil, 4.0
    for _, machine in ipairs(nearby) do
        local far = #(me - GetEntityCoords(machine.entity))
        if far < distance then closest, distance = machine, far end
    end
    return closest
end

--- Puts a model's screen to use here (nil: back to the default).
local function useScreen(name, screen)
    Config.atm.screens[name] = screen or lib.table.deepclone(defaults[name])
    loadScreens()
    for _, machine in ipairs(nearby) do
        machine.info = screens[GetEntityModel(machine.entity)]
        if machine.info then machine.corners = worldCorners(machine.entity, machine.info) end
    end
end

local function configLine(name, screen)
    local keys = ''
    if screen.keys then
        local k = screen.keys
        local rows = {}
        for i, centre in ipairs(k.rows) do rows[i] = ('%.3f'):format(centre) end
        keys = (' keys = { rows = { %s }, height = %.3f, left = { %.3f, %.3f }, right = { %.3f, %.3f } },'):format(
            table.concat(rows, ', '), k.height, k.left[1], k.left[2], k.right[1], k.right[2])
    end
    return ('%s = { x = %.3f, y = %.3f, z = %.3f, width = %.3f, height = %.3f, tilt = %.1f,%s },'):format(
        name, screen.x, screen.y, screen.z, screen.width, screen.height, screen.tilt, keys)
end

--- Saves a model's screen on the server, which sends it to everyone.
local function saveScreen(name, screen)
    local result = lib.callback.await('Renewed-Banking:server:saveAtmScreen', false, name, screen)
    if not result or not result.ok then
        return notify(('Could not save %s: %s'):format(name, result and result.error and result.error.code or 'no answer'), 'error')
    end
    -- Also as a config.lua line, to make it the default.
    local line = configLine(name, result.data)
    print(line)
    lib.setClipboard(line)
    notify(('%s saved for every %s. Its config.lua line is in F8 and on your clipboard.'):format(name, name), 'success')
end

RegisterNetEvent('Renewed-Banking:client:atmScreen', function(name, screen)
    if type(name) ~= 'string' then return end
    useScreen(name, screen or nil)
end)

-- The saved screens, over config.lua's.
CreateThread(function()
    local saved = lib.callback.await('Renewed-Banking:server:atmScreens', false)
    for name, screen in pairs(saved or {}) do useScreen(name, screen) end
end)

local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

--- The screen's frame in the world: the machine's own axes with the glass
--- tipped back by its tilt. Its forward points into the machine.
local function screenFrame(entity, screen)
    local forward, right, up = GetEntityMatrix(entity)
    local t = math.rad(screen.tilt or 0.0)
    return {
        right = right,
        up = forward * math.sin(t) + up * math.cos(t),
        forward = forward * math.cos(t) - up * math.sin(t),
        position = GetOffsetFromEntityInWorldCoords(entity, screen.x, screen.y, screen.z)
    }
end

local function cornersFromHelper(helper, width, height)
    local _, right, up, position = GetEntityMatrix(helper)
    local r, u = right * (width / 2), up * (height / 2)
    return { position - r + u, position + r + u, position + r - u, position - r - u }
end

local function editWithGizmo(machine)
    if GetResourceState('object_gizmo') ~= 'started' then
        return notify('object_gizmo is not running', 'error')
    end
    local entity, name = machine.entity, machine.info.name
    local screen = machine.info.screen
    local size = { width = screen.width, height = screen.height }

    lib.requestModel(HELPER, 5000)
    local frame = screenFrame(entity, screen)
    local helper = CreateObjectNoOffset(HELPER, frame.position.x, frame.position.y, frame.position.z, false, false, false)
    SetModelAsNoLongerNeeded(HELPER)
    SetEntityCollision(helper, false, false)
    FreezeEntityPosition(helper, true)
    SetEntityAlpha(helper, 0, false)
    local f, r, u, p = frame.forward, frame.right, frame.up, frame.position
    SetEntityMatrix(helper, f.x, f.y, f.z, r.x, r.y, r.z, u.x, u.y, u.z, p.x, p.y, p.z)

    editing = { entity = entity, corners = cornersFromHelper(helper, size.width, size.height) }
    notify('Drag the gizmo: W move, R rotate, Q local/world, G cursor. Mouse wheel or arrow keys resize. ENTER saves.')

    -- The screen follows the helper and is resized by the wheel and arrows, until ENTER.
    CreateThread(function()
        while editing and DoesEntityExist(helper) do
            local fast = held(KEY_SIZE.fast)
            local step = fast and SIZE_STEP * 4 or SIZE_STEP
            if held(KEY_SIZE.right) then size.width = size.width + step end
            if held(KEY_SIZE.left) then size.width = math.max(0.05, size.width - step) end
            if held(KEY_SIZE.up) then size.height = size.height + step end
            if held(KEY_SIZE.down) then size.height = math.max(0.05, size.height - step) end
            -- The wheel keeps the shape and changes the size.
            local notch = (tapped(KEY_SIZE.wheelUp) and 1 or 0) - (tapped(KEY_SIZE.wheelDown) and 1 or 0)
            if notch ~= 0 then
                local scale = 1 + notch * WHEEL_STEP * (fast and 4 or 1)
                if size.width * scale >= 0.05 and size.height * scale >= 0.05 then
                    size.width, size.height = size.width * scale, size.height * scale
                end
            end
            editing.corners = cornersFromHelper(helper, size.width, size.height)
            drawSize(size)
            Wait(0)
        end
    end)

    exports.object_gizmo:useGizmo(helper)

    -- Back from the world into the machine's own coordinates.
    local _, _, up, position = GetEntityMatrix(helper)
    local forward, _, atmUp = GetEntityMatrix(entity)
    local offset = GetOffsetFromEntityGivenWorldCoords(entity, position.x, position.y, position.z)
    local tilt = math.deg(math.atan(dot(up, forward), dot(up, atmUp)))
    editing = nil
    DeleteEntity(helper)

    -- The side buttons stay where they are on the glass.
    saveScreen(name, {
        x = offset.x, y = offset.y, z = offset.z,
        width = size.width, height = size.height, tilt = tilt,
        keys = screen.keys
    })
end

local KEYS_HELP = table.concat({
    '**ATM side buttons**',
    '[1-4] pick a row (again: all)   [TAB] side: both / left / right',
    '[↑ ↓] move   [Shift ↑ ↓] spread all rows',
    '[← →] move columns   [Shift ← →] narrower / wider',
    '[PgUp PgDn] taller / shorter',
    '[ENTER] save   [BACKSPACE] cancel   [DEL] no buttons'
}, '  \n')

local ROW_KEYS = { 157, 158, 160, 164 } -- 1 to 4 on the top row of the keyboard
local SIDE_KEY = 37 -- TAB
local SIDES = { 'both', 'left', 'right' }

local function drawKeysReadout(keys)
    local gaps = {}
    for i = 2, #keys.rows do gaps[#gaps + 1] = ('%.3f'):format(keys.rows[i] - keys.rows[i - 1]) end
    local text = ('Row: %s   Side: %s   Gaps: %s   Height: %.3f   Left %.3f-%.3f   Right %.3f-%.3f'):format(
        keyFocus.row and tostring(keyFocus.row) or 'all', keyFocus.side, table.concat(gaps, ' / '),
        keys.height, keys.left[1], keys.left[2], keys.right[1], keys.right[2])
    SetTextFont(4)
    SetTextScale(0.0, 0.4)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.93)
end

--- Lines up the green boxes over the machine's own side buttons, on every
--- machine of the model at once. A picked row or side (yellow) moves alone.
local function editKeys(machine)
    local name, screen = machine.info.name, machine.info.screen
    local original = screen.keys
    local keys = lib.table.deepclone(original or DEFAULT_KEYS)
    screen.keys = keys
    local hadOutlines = outlines
    outlines = true
    editing = { entity = machine.entity, corners = machine.corners, keysOnly = true }
    keyFocus = { row = nil, side = 'both' }
    lib.showTextUI(KEYS_HELP)

    local outcome
    while not outcome do
        for _, control in pairs(KEY_EDIT) do DisableControlAction(0, control, true) end
        for _, control in ipairs(ROW_KEYS) do DisableControlAction(0, control, true) end
        DisableControlAction(0, SIDE_KEY, true)
        local held = function(control) return IsDisabledControlPressed(0, control) end
        local shift, s = held(KEY_EDIT.shift), KEYS_STEP

        for row, control in ipairs(ROW_KEYS) do
            if IsDisabledControlJustPressed(0, control) and keys.rows[row] then
                keyFocus.row = keyFocus.row ~= row and row or nil
            end
        end
        if IsDisabledControlJustPressed(0, SIDE_KEY) then
            for i, side in ipairs(SIDES) do
                if side == keyFocus.side then keyFocus.side = SIDES[i % #SIDES + 1] break end
            end
        end

        if held(KEY_EDIT.up) or held(KEY_EDIT.down) then
            local sign = held(KEY_EDIT.down) and 1 or -1
            if shift then
                -- Every row further apart or closer together, around their middle.
                local mean = 0
                for _, centre in ipairs(keys.rows) do mean = mean + centre end
                mean = mean / #keys.rows
                for i, centre in ipairs(keys.rows) do keys.rows[i] = mean + (centre - mean) * (1 + sign * s * 2) end
            elseif keyFocus.row then
                keys.rows[keyFocus.row] = keys.rows[keyFocus.row] + sign * s
            else
                for i, centre in ipairs(keys.rows) do keys.rows[i] = centre + sign * s end
            end
        end

        if held(KEY_EDIT.left) or held(KEY_EDIT.right) then
            local sign = held(KEY_EDIT.right) and 1 or -1
            local side = keyFocus.side
            if shift then
                -- Wider or narrower, from the outer edge.
                if side ~= 'right' then keys.left[1] = math.min(keys.left[1] - sign * s, keys.left[2] - 0.02) end
                if side ~= 'left' then keys.right[2] = math.max(keys.right[2] + sign * s, keys.right[1] + 0.02) end
            elseif side == 'both' then
                -- Both columns out from the glass or in towards it.
                keys.left[1], keys.left[2] = keys.left[1] - sign * s, keys.left[2] - sign * s
                keys.right[1], keys.right[2] = keys.right[1] + sign * s, keys.right[2] + sign * s
            else
                -- One column on its own, the way the arrow points.
                local span = keys[side]
                span[1], span[2] = span[1] + sign * s, span[2] + sign * s
            end
        end
        if held(KEY_EDIT.taller) then keys.height = keys.height + s end
        if held(KEY_EDIT.shorter) then keys.height = math.max(0.02, keys.height - s) end

        drawKeysReadout(keys)

        if IsDisabledControlJustPressed(0, KEY_EDIT.save) then outcome = 'save'
        elseif IsDisabledControlJustPressed(0, KEY_EDIT.remove) then outcome = 'remove'
        elseif IsDisabledControlJustPressed(0, KEY_EDIT.cancel) then outcome = 'cancel' end
        Wait(0)
    end

    lib.hideTextUI()
    outlines = hadOutlines
    editing = nil
    keyFocus = nil
    screen.keys = original
    if outcome == 'cancel' then return notify('Side buttons unchanged') end
    -- Saved top to bottom, whatever order the rows were moved into.
    table.sort(keys.rows)
    local saved = lib.table.deepclone(screen)
    saved.keys = outcome == 'save' and keys or nil
    saveScreen(name, saved)
end

RegisterCommand('atmscreen', function(_, args)
    if args[1] == 'outline' then
        outlines = not outlines
        return notify(outlines and 'Outlines on' or 'Outlines off')
    end
    if editing then return notify('Already editing a screen: finish that first', 'error') end
    local machine = closestMachine()
    if not machine then return notify('Stand at an ATM first', 'error') end

    CreateThread(function()
        if not lib.callback.await('Renewed-Banking:server:canEditAtmScreens', false) then
            return notify('Only admins can change ATM screens', 'error')
        end
        local name = machine.info.name
        if #args == 0 then return editWithGizmo(machine) end
        if args[1] == 'keys' then return editKeys(machine) end
        if args[1] == 'reset' then
            local result = lib.callback.await('Renewed-Banking:server:resetAtmScreen', false, name)
            return notify(result and result.ok and (name .. ' is back to its config.lua default') or 'Could not reset', result and result.ok and 'success' or 'error')
        end

        local values = {}
        for i = 1, 6 do
            values[i] = tonumber(args[i])
            if not values[i] then return notify('Usage: /atmscreen [keys | reset | outline | x y z width height tilt]', 'error') end
        end
        saveScreen(name, {
            x = values[1], y = values[2], z = values[3], width = values[4], height = values[5], tilt = values[6],
            keys = machine.info.screen.keys
        })
    end)
end, false)

AddEventHandler('onResourceStop', function(name)
    if name ~= resource then return end
    if active then
        RenderScriptCams(false, false, 0, true, true)
        active = nil
    end
    for _, sheet in pairs(sheets) do
        if sheet.dui then DestroyDui(sheet.dui) end
    end
end)
