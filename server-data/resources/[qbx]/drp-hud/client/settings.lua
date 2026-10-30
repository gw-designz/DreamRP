local KVP_KEY = 'my-hud:settings'
local listeners = {}
local settingsOpen = false

local function round(v) return math.floor(v + 0.5) end

local function sanitizeLayout(input)
    local out = {}
    if type(input) ~= 'table' then return out end
    for _, name in ipairs(Config.Widgets) do
        local l = input[name]
        if type(l) == 'table' then
            local x = Hud.clamp(round(tonumber(l.x) or 0), -2000, 2000)
            local y = Hud.clamp(round(tonumber(l.y) or 0), -2000, 2000)
            local s = Hud.clamp(round((tonumber(l.s) or 1) * 100) / 100, 0.5, 1.5)
            if x ~= 0 or y ~= 0 or s ~= 1 then out[name] = { x = x, y = y, s = s } end
        end
    end
    return out
end

-- Bumped when a widget moves to a different anchor, so offsets saved for its old spot
-- (which would now push it somewhere odd) are dropped once.
-- 2: the key hints bar moved from bottom center to bottom right.
local LAYOUT_VERSION = 2

local SPEEDO_STYLES = {
    modern = true, analog = true, linear = true, ev = true, dual = true, watch = true,
}

local SPEED_UNITS = { mph = true, kmh = true }
local WATER_UNITS = { knots = true, mph = true, kmh = true }
local RADIUS = { slight = true, rounded = true, full = true }

-- Allowed values for every choice setting ('auto' follows hudStyle). Invalid values, like
-- the old speedometer and status choices, fall back to Config.Defaults.
local CHOICES = {
    statusStyle = { bars = true, hex = true, square = true, circle = true },
    mapStyle = { auto = true, brackets = true, clean = true, minimal = true, circle = true },
    locationStyle = { auto = true, bar = true, pills = true, compass = true, minimal = true },
    speedoStyle = SPEEDO_STYLES,
    speedoBicycle = SPEEDO_STYLES,
    speedoBoat = SPEEDO_STYLES,
    speedoAir = SPEEDO_STYLES,
    speedoTrain = SPEEDO_STYLES,
    performance = { performance = true, balanced = true, quality = true },
    distanceUnit = { feet = true, meters = true },
    limitStyle = { us = true, minimal = true },
    bikeUnit = SPEED_UNITS,
    trainUnit = SPEED_UNITS,
    boatUnit = WATER_UNITS,
    airUnit = WATER_UNITS,
    voiceAlign = { left = true, right = true },
    voiceRadius = RADIUS,
    infoRadius = RADIUS,
    weaponRadius = RADIUS,
    vcRadius = RADIUS,
}

-- Menu colours: '#rrggbb' strings under short keys ('health.progress', 'carRpm', ...).
local function sanitizeColors(input)
    local out, count = {}, 0
    if type(input) ~= 'table' then return out end
    for key, value in pairs(input) do
        if type(key) == 'string' and #key <= 40 and key:match('^[%w%.]+$')
            and type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') then
            out[key] = value:lower()
            count = count + 1
            if count >= 100 then break end
        end
    end
    return out
end

local function sanitizeHidden(input)
    local out = {}
    if type(input) ~= 'table' then return out end
    for _, name in ipairs(Config.Widgets) do
        if input[name] == true then out[name] = true end
    end
    return out
end

local function sanitize(input)
    local migrate = type(input) == 'table' and input.layoutVersion ~= LAYOUT_VERSION
    local out = {}
    for key, default in pairs(Config.Defaults) do
        local v = input and input[key]
        if type(v) ~= type(default) then v = default end
        out[key] = v
    end
    out.scale = Hud.clamp(round(out.scale * 100) / 100, 0.75, 1.25)
    if out.speedUnit ~= 'mph' and out.speedUnit ~= 'kmh' then out.speedUnit = Config.Defaults.speedUnit end
    if out.hudStyle ~= 'circuit' and out.hudStyle ~= 'classic' then out.hudStyle = Config.Defaults.hudStyle end
    for key, allowed in pairs(CHOICES) do
        if not allowed[out[key]] then out[key] = allowed[Config.Defaults[key]] and Config.Defaults[key] or 'auto' end
    end
    out.colors = sanitizeColors(out.colors)
    out.hidden = sanitizeHidden(out.hidden)
    out.mapOffsetX = Hud.clamp(round(out.mapOffsetX), -60, 60)
    out.mapOffsetY = Hud.clamp(round(out.mapOffsetY), -60, 60)
    out.mapZoom = Hud.clamp(round(out.mapZoom), 0, 1400)
    out.layout = sanitizeLayout(out.layout)
    if migrate then out.layout.controls = nil end
    out.layoutVersion = LAYOUT_VERSION
    return out
end

local function load()
    local raw = GetResourceKvpString(KVP_KEY)
    local ok, decoded = pcall(json.decode, raw or '')
    return sanitize(ok and type(decoded) == 'table' and decoded or nil)
end

local function save()
    SetResourceKvp(KVP_KEY, json.encode(Hud.settings))
end

function Hud.onSettings(cb)
    listeners[#listeners + 1] = cb
end

-- The NUI already shows what the player picked, so saves are not echoed back.
-- `push` is used for resets, where the NUI needs the new values.
function Hud.applySettings(new, push)
    local old = Hud.settings
    Hud.settings = sanitize(new)
    if push then Hud.send('settings', { settings = Hud.settings }) end
    for _, cb in ipairs(listeners) do cb(Hud.settings, old) end
end

-- Settings listeners compare layouts per widget.
function Hud.layoutOf(settings, name)
    local l = settings.layout[name]
    if l then return l.x, l.y, l.s end
    return 0, 0, 1
end

Hud.settings = load()

local blurred = false

local function setBlur(state)
    state = state and Config.MenuBlur
    if state == blurred then return end
    blurred = state
    if state then TriggerScreenblurFadeIn(250) else TriggerScreenblurFadeOut(250) end
end

local function closeSettings()
    if not settingsOpen then return end
    settingsOpen = false
    Hud.forceMap = false
    setBlur(false)
    SetNuiFocus(false, false)
    Hud.send('closeSettings')
end

-- NUI focus takes the keyboard and mouse, but a controller still reaches the game. While the
-- menu is open, game controls are disabled and the d-pad, shoulders and south / east buttons
-- are forwarded to the NUI as navigation (keyboard input is handled in the page itself).
local NAV = {
    { 172, 'up' }, { 173, 'down' }, { 174, 'left' }, { 175, 'right' },
    { 205, 'prevTab' }, { 206, 'nextTab' }, { 201, 'accept' }, { 202, 'back' },
}

local function gamepadLoop()
    while settingsOpen do
        DisableAllControlActions(0)
        if not IsUsingKeyboard(0) then
            for i = 1, #NAV do
                if IsDisabledControlJustPressed(0, NAV[i][1]) then
                    Hud.send('nav', { key = NAV[i][2] })
                end
            end
        end
        Wait(0)
    end
end

-- `page` opens the menu on that tab (e.g. 'dev' from the dev command).
function Hud.openSettings(page)
    if settingsOpen then
        if page then Hud.send('openSettings', { settings = Hud.settings, dev = Hud.devAccess, page = page }) end
        return
    end
    settingsOpen = true
    SetNuiFocus(true, true)
    setBlur(true)
    Hud.send('openSettings', { settings = Hud.settings, dev = Hud.devAccess, page = page })
    CreateThread(gamepadLoop)
end

RegisterCommand(Config.SettingsCommand, function()
    if settingsOpen then return closeSettings() end
    Hud.openSettings()
end, false)

RegisterNUICallback('saveSettings', function(data, cb)
    Hud.applySettings(data)
    save()
    cb(1)
end)

RegisterNUICallback('resetSettings', function(_, cb)
    Hud.applySettings(Config.Defaults)
    save()
    cb({ settings = Hud.settings })
end)

RegisterNUICallback('closeSettings', function(_, cb)
    closeSettings()
    cb(1)
end)

-- 'menu' blurs the game; 'editor' / 'calibrate' keep the radar on screen (even on foot with
-- "minimap on foot" disabled) so it can be lined up, and drop the blur so the HUD is visible.
RegisterNUICallback('menuMode', function(data, cb)
    local mode = settingsOpen and data and data.mode or 'hud'
    Hud.forceMap = mode == 'editor' or mode == 'calibrate'
    setBlur(mode == 'menu')
    cb(1)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not settingsOpen then return end
    SetNuiFocus(false, false)
    if blurred then TriggerScreenblurFadeOut(0) end
end)
