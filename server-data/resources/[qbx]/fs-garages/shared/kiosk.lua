--[[
    fs-garages / shared/kiosk.lua

    The garage screen on the kiosk: where everything is on it, and what
    each press does.

    The screen is a page the game paints onto the kiosk, so nobody clicks
    on the page itself -- the mouse moves over a picture of it in the world.
    The game works out which point of the screen the mouse is on and asks
    this file what is there. The page is only told what to draw and where:
    every box it draws comes from here, so what is seen and what is pressed
    can never drift apart.

    Nothing in here touches the game, so it is checked outside it.
]]

Kiosk = {}

--- The page, in pixels: 3:4 like the glass on the kiosk.
Kiosk.W, Kiosk.H = 768, 1024

local L = {
    search = { 24, 86, 720, 42 },
    keyQ = { 24, 140, 26, 32 },
    keyE = { 718, 140, 26, 32 },
    tabs = { { 58, 140, 212, 32 }, { 278, 140, 212, 32 }, { 498, 140, 212, 32 } },
    grid = { 24, 186, 720, 814 },
    cardW = 232, cardH = 224, gap = 12,
    -- the two buttons over a card the mouse is on, from the card's corner
    primary = { 14, 66, 204, 40 },
    info = { 14, 116, 204, 40 },
    panel = { 144, 322, 480, 380 },
    rowH = 34, rowGap = 2,
}
Kiosk.LAYOUT = L

--- here: parked in this garage; elsewhere: parked in another; all: every car.
Kiosk.TABS = { 'here', 'elsewhere', 'all' }

local ROW = L.cardH + L.gap
local VISIBLE_ROWS = math.floor((L.grid[4] + L.gap) / ROW)

local function inside(rect, x, y)
    return x >= rect[1] and y >= rect[2] and x <= rect[1] + rect[3] and y <= rect[2] + rect[4]
end
Kiosk.inside = inside

local function lower(text) return tostring(text or ''):lower() end

-- ── state ──────────────────────────────────────────────────────────────

--[[
    A screen for one visit to the kiosk. `data` is what the game made of the
    server's answer to kiosk:open:
      garage  { id, label, type, kind }
      cars    { { plate, label, model, image, place, at, fuel, engine, body,
                  recover, recoverFee } }
              place: 'here', 'elsewhere' (at = that garage's name), 'out'
              (in the city), 'lost' (left out, no longer there) or
              'impounded'; fuel, engine, body are 0-100. At an impound,
              `recover` marks the cars that can be got back there, and
              recoverFee is what that costs, already written as money
              ('' when free)
      fee     what bringing a car over costs, already written as money
]]
function Kiosk.new(data)
    return {
        data = data or { cars = {} },
        started = false,
        tab = 'here',
        q = '',
        scroll = 0,
        info = nil,          -- the plate of the car whose details are open
        busy = false,
        done = nil, doneUntil = 0,
        error = nil, errorUntil = 0,
    }
end

--- New figures from the server, keeping the tab, the search and the place.
function Kiosk.update(s, data)
    s.data = data or s.data
    if s.info and not Kiosk.carByPlate(s, s.info) then s.info = nil end
    Kiosk.clampScroll(s)
end

local function isDepot(s)
    return (s.data.garage or {}).kind == 'depot'
end

--- The cars on the open tab that match the search. At an impound, the
--- first tab holds the cars to collect.
function Kiosk.shown(s)
    local out, needle = {}, lower(s.q)
    local depot = isDepot(s)
    for _, car in ipairs(s.data.cars or {}) do
        local tabOk
        if s.tab == 'all' then
            tabOk = true
        elseif depot and s.tab == 'here' then
            tabOk = car.recover == true
        else
            tabOk = car.place == s.tab
        end
        local found = needle == '' or lower(car.label):find(needle, 1, true) or lower(car.plate):find(needle, 1, true)
        if tabOk and found then out[#out + 1] = car end
    end
    return out
end

function Kiosk.maxScroll(s)
    local rows = math.ceil(#Kiosk.shown(s) / 3)
    return math.max(0, rows - VISIBLE_ROWS)
end

function Kiosk.clampScroll(s)
    s.scroll = math.max(0, math.min(s.scroll, Kiosk.maxScroll(s)))
end

function Kiosk.carByPlate(s, plate)
    for _, car in ipairs(s.data.cars or {}) do
        if car.plate == plate then return car end
    end
end

-- ── where things are ───────────────────────────────────────────────────

--- Each car on screen with its box, in page pixels (scrolled).
function Kiosk.cards(s)
    local out = {}
    local g = L.grid
    for i, car in ipairs(Kiosk.shown(s)) do
        local row, col = (i - 1) // 3, (i - 1) % 3
        local y = g[2] + (row - s.scroll) * ROW
        out[#out + 1] = { car = car, rect = { g[1] + col * (L.cardW + L.gap), y, L.cardW, L.cardH } }
    end
    return out
end

local function offset(rect, local_)
    return { rect[1] + local_[1], rect[2] + local_[2], local_[3], local_[4] }
end

local function closeRect()
    local p = L.panel
    return { p[1] + 20, p[2] + p[4] - 68, p[3] - 40, 48 }
end

--- The button a car's card offers, by where the car is.
local function primaryOf(car)
    if car.recover then return 'recover' end
    if car.place == 'here' then return 'retrieve' end
    if car.place == 'elsewhere' then return 'transfer' end
    return 'none'
end

--- What is under a point of the page: a name the press logic knows, or nil.
---   start, search, tab:<name>, key:q, key:e, card:<plate>,
---   retrieve:<plate>, transfer:<plate>, recover:<plate>, none:<plate>, info:<plate>,
---   close, outside
function Kiosk.hit(s, x, y)
    if x < 0 or y < 0 or x > Kiosk.W or y > Kiosk.H then return nil end
    if not s.started then return 'start' end

    if s.info then
        if inside(closeRect(), x, y) then return 'close' end
        if not inside(L.panel, x, y) then return 'outside' end
        return nil
    end

    if inside(L.search, x, y) then return 'search' end
    if inside(L.keyQ, x, y) then return 'key:q' end
    if inside(L.keyE, x, y) then return 'key:e' end
    for i, rect in ipairs(L.tabs) do
        if inside(rect, x, y) then return 'tab:' .. Kiosk.TABS[i] end
    end
    if inside(L.grid, x, y) then
        for _, card in ipairs(Kiosk.cards(s)) do
            if inside(card.rect, x, y) then
                local plate = card.car.plate
                if inside(offset(card.rect, L.primary), x, y) then return primaryOf(card.car) .. ':' .. plate end
                if inside(offset(card.rect, L.info), x, y) then return 'info:' .. plate end
                return 'card:' .. plate
            end
        end
    end
    return nil
end

--- The plate a target is about (the card under the mouse, or one of its buttons).
local function cardOf(target)
    if not target then return nil end
    return target:match('^card:(.+)$') or target:match('^retrieve:(.+)$') or target:match('^transfer:(.+)$')
        or target:match('^recover:(.+)$') or target:match('^none:(.+)$') or target:match('^info:(.+)$')
end
Kiosk.cardOf = cardOf

-- ── pressing ───────────────────────────────────────────────────────────

local function switchTab(s, step)
    local at = 1
    for i, name in ipairs(Kiosk.TABS) do if name == s.tab then at = i end end
    s.tab = Kiosk.TABS[(at - 1 + step) % #Kiosk.TABS + 1]
    s.scroll = 0
end

--- A press on a target. Returns what the game must do, or nil:
---   { kind = 'search' } { kind = 'retrieve', plate } { kind = 'transfer', plate }
---   { kind = 'recover', plate }
function Kiosk.press(s, target)
    if not target or s.busy or s.done then return nil end
    if target == 'start' then s.started = true return nil end
    if target == 'search' then return { kind = 'search' } end
    if target == 'key:q' then switchTab(s, -1) return nil end
    if target == 'key:e' then switchTab(s, 1) return nil end
    local tab = target:match('^tab:(%a+)$')
    if tab then s.tab = tab s.scroll = 0 return nil end
    if target == 'close' or target == 'outside' then s.info = nil return nil end

    local plate = target:match('^info:(.+)$')
    if plate then s.info = plate return nil end
    plate = target:match('^recover:(.+)$')
    if plate then
        local car = Kiosk.carByPlate(s, plate)
        if not car or not car.recover then return nil end
        return { kind = 'recover', plate = plate }
    end
    plate = target:match('^retrieve:(.+)$')
    if plate then
        local car = Kiosk.carByPlate(s, plate)
        if not car or car.place ~= 'here' or car.recover then return nil end
        return { kind = 'retrieve', plate = plate }
    end
    plate = target:match('^transfer:(.+)$')
    if plate then
        local car = Kiosk.carByPlate(s, plate)
        if not car or car.place ~= 'elsewhere' then return nil end
        return { kind = 'transfer', plate = plate }
    end
    return nil
end

--- The mouse wheel scrolls the cars.
function Kiosk.wheel(s, step)
    if not s.started or s.info then return end
    s.scroll = s.scroll + step
    Kiosk.clampScroll(s)
end

--- A key: 'q', 'e', 'back' (Esc). Returns 'leave' when the visit is over.
function Kiosk.key(s, key)
    if key == 'back' then
        if s.info then s.info = nil return nil end
        return 'leave'
    end
    if not s.started or s.info then return nil end
    if key == 'q' then switchTab(s, -1) elseif key == 'e' then switchTab(s, 1) end
    return nil
end

function Kiosk.search(s, text)
    s.q = tostring(text or ''):sub(1, 24)
    s.scroll = 0
end

function Kiosk.showDone(s, text, now) s.done, s.doneUntil = text, now + 1600 end
function Kiosk.showError(s, text, now) s.error, s.errorUntil = text, now + 3200 end

--- Lets messages run out. Returns true when something changed.
function Kiosk.tick(s, now)
    local changed = false
    if s.done and now >= s.doneUntil then s.done = nil changed = true end
    if s.error and now >= s.errorUntil then s.error = nil changed = true end
    return changed
end

-- ── what the page draws ────────────────────────────────────────────────

local function percent(value)
    return tostring(math.floor((tonumber(value) or 0) + 0.5)) .. '%'
end

--- The card's place line: "In this garage", "At Legion Square", "Out in the city".
local function placeText(car, w)
    if car.place == 'elsewhere' then return (w.at or '%s'):format(car.at or '') end
    return w['place_' .. car.place] or car.place
end

--- Everything the page needs to draw the screen, with `hover` the target
--- under the mouse and `words` the text in the server's language.
function Kiosk.view(s, hover, words)
    local w = words or {}
    local garage = s.data.garage or {}
    local view = {
        w = Kiosk.W, h = Kiosk.H,
        title = w.title, label = garage.label or '',
        started = s.started, touch = w.touch,
        busy = s.busy, done = s.done, error = s.error,
    }
    if not s.started then return view end

    view.search = { rect = L.search, text = s.q, placeholder = w.search, hover = hover == 'search' }
    view.keys = { q = L.keyQ, e = L.keyE }
    view.tabs = {}
    local depot = isDepot(s)
    for i, name in ipairs(Kiosk.TABS) do
        local label = (depot and name == 'here') and w.tab_impound or w['tab_' .. name]
        view.tabs[i] = { rect = L.tabs[i], label = label, on = s.tab == name, hover = hover == 'tab:' .. name }
    end
    view.grid = L.grid
    local hovered = not s.info and cardOf(hover) or nil
    view.cards = {}
    for _, card in ipairs(Kiosk.cards(s)) do
        local r = card.rect
        -- only what can be seen inside the grid is sent
        if r[2] + r[4] > L.grid[2] and r[2] < L.grid[2] + L.grid[4] then
            local car = card.car
            local item = {
                id = car.plate, rect = r, label = car.label, plate = car.plate, model = car.model, image = car.image,
                place = car.place, placeLabel = placeText(car, w),
                fuel = percent(car.fuel), engine = percent(car.engine), body = percent(car.body),
                hover = hovered == car.plate,
            }
            if item.hover then
                local kind = primaryOf(car)
                local label
                if kind == 'recover' then
                    label = (car.recoverFee or '') ~= '' and (w.recover or '%s'):format(car.recoverFee) or w.recover_free
                elseif kind == 'retrieve' then
                    label = w.retrieve
                elseif kind == 'transfer' then
                    label = (w.transfer or '%s'):format(s.data.fee or '')
                else
                    label = w['place_' .. car.place]
                end
                item.primary = { rect = offset(r, L.primary), label = label, disabled = kind == 'none' or s.busy,
                    hover = hover == kind .. ':' .. car.plate }
                item.info = { rect = offset(r, L.info), label = w.info, hover = hover == 'info:' .. car.plate }
            end
            view.cards[#view.cards + 1] = item
        end
    end
    local emptyKey = (depot and s.tab == 'here') and 'empty_impound' or 'empty_' .. s.tab
    view.empty = #view.cards == 0 and (s.q ~= '' and w.nothing_found or w[emptyKey]) or nil

    local most = Kiosk.maxScroll(s)
    if most > 0 then
        local g = L.grid
        local share = VISIBLE_ROWS / (VISIBLE_ROWS + most)
        local height = math.floor(g[4] * share)
        view.scrollbar = { g[1] + g[3] + 6, g[2] + math.floor((g[4] - height) * s.scroll / most), 4, height }
    end

    local car = s.info and Kiosk.carByPlate(s, s.info)
    if car then
        view.info = {
            panel = L.panel, name = car.label,
            rows = {
                { w.plate, car.plate }, { w.model, car.model or '' }, { w.where, placeText(car, w) },
                { w.fuel, percent(car.fuel) }, { w.engine, percent(car.engine) }, { w.body, percent(car.body) },
            },
            rowsY = L.panel[2] + 60, rowH = L.rowH, rowGap = L.rowGap,
            close = { rect = closeRect(), label = w.close, hover = hover == 'close' },
        }
    end
    return view
end

--[[
    Where on the screen the mouse is.

    `quad` is the screen's four corners as they appear on the monitor --
    top left, top right, bottom right, bottom left, each { x, y } -- and
    (px, py) is the mouse. Returns how far across and down the screen that
    is, 0 to 1 each, allowing for the screen being seen at an angle.
]]
function Kiosk.uvAt(quad, px, py)
    local x0, y0 = quad[1].x, quad[1].y
    local x1, y1 = quad[2].x, quad[2].y
    local x2, y2 = quad[3].x, quad[3].y
    local x3, y3 = quad[4].x, quad[4].y

    local dx1, dy1 = x1 - x2, y1 - y2
    local dx2, dy2 = x3 - x2, y3 - y2
    local sx, sy = x0 - x1 + x2 - x3, y0 - y1 + y2 - y3

    local det = dx1 * dy2 - dy1 * dx2
    if math.abs(det) < 1e-12 then return nil end

    local g = (sx * dy2 - sy * dx2) / det
    local h = (dx1 * sy - dy1 * sx) / det

    -- The grid that carries (u, v) to the monitor...
    local a, b, c = x1 - x0 + g * x1, x3 - x0 + h * x3, x0
    local d, e, f = y1 - y0 + g * y1, y3 - y0 + h * y3, y0

    -- ...turned round, to carry the monitor back to (u, v).
    local A = e - f * h
    local B = c * h - b
    local C = b * f - c * e
    local D = f * g - d
    local E = a - c * g
    local F = c * d - a * f
    local G = d * h - e * g
    local H = b * g - a * h
    local I = a * e - b * d

    local w = G * px + H * py + I
    if math.abs(w) < 1e-12 then return nil end
    return (A * px + B * py + C) / w, (D * px + E * py + F) / w
end
