-- Rectangular minimap in the bottom-left corner.
--
-- The rounded corners come from a runtime texture: a 256px white rounded rectangle is drawn
-- pixel by pixel and swapped in for the radar masks (radarmasksm for clip type 0,
-- radarmask1g for clip type 1). No binary .ytd is shipped.
--
-- Placement: radar components are sized in a 16:9 space whose width follows the screen
-- height (resY * 16 / 9), and 'L' / 'T' alignment offsets are measured from the left and
-- top safezone edges. The NUI frame receives the same rectangle (before the layout-editor
-- offset, which both sides apply with the same formula), so frame and radar move together.

local MASK_TXD = 'myhud_minimap'
local MASK_SIZE = 256
local maskReady = false
local maskShape
local placed

-- The player's map style with 'auto' resolved the same way as script.js (resolveStyles).
local function mapStyle()
    local s = Hud.settings
    if s.mapStyle ~= 'auto' then return s.mapStyle end
    return s.hudStyle == 'classic' and 'clean' or 'brackets'
end

-- Signed distance to a rounded square, so the corner edge is anti-aliased.
-- A radius of half the texture makes the circle for the round map.
local function buildMaskTexture(txd, name, rad)
    local tex = CreateRuntimeTexture(txd, name, MASK_SIZE, MASK_SIZE)
    local half = MASK_SIZE * 0.5
    for y = 0, MASK_SIZE - 1 do
        local qy = math.abs(y + 0.5 - half) - (half - rad)
        for x = 0, MASK_SIZE - 1 do
            local qx = math.abs(x + 0.5 - half) - (half - rad)
            local ox, oy = math.max(qx, 0.0), math.max(qy, 0.0)
            local dist = math.sqrt(ox * ox + oy * oy) + math.min(math.max(qx, qy), 0.0) - rad
            local c = math.floor(Hud.clamp(-dist, 0.0, 1.0) * 255)
            SetRuntimeTexturePixel(tex, x, y, c, c, c, c)
        end
        -- Spread the work over frames so the first spawn does not hitch.
        if y % 32 == 31 then Wait(0) end
    end
    CommitRuntimeTexture(tex)
end

local function buildMask()
    local txd = CreateRuntimeTxd(MASK_TXD)
    buildMaskTexture(txd, 'radarmasksm', Config.Minimap.cornerRadius)
    buildMaskTexture(txd, 'radarmaskround', MASK_SIZE * 0.5)
    maskReady = true
end

-- Points both radar masks at the rounded square or the circle.
local function applyMask(shape)
    if shape == maskShape then return end
    maskShape = shape
    local name = shape == 'circle' and 'radarmaskround' or 'radarmasksm'
    for _, target in ipairs({ 'radarmasksm', 'radarmask1g' }) do
        RemoveReplaceTexture('platform:/textures/graphics', target)
        AddReplaceTexture('platform:/textures/graphics', target, MASK_TXD, name)
    end
end

-- Map geometry for the player's styles: the base values with the HUD style's overrides,
-- or the square of the round map.
local function geometry()
    local cfg = Config.Minimap
    local style = cfg.styles and cfg.styles[Hud.settings.hudStyle] or {}
    if mapStyle() == 'circle' and cfg.circle then style = cfg.circle end
    return {
        width = style.width or cfg.width,
        height = style.height or cfg.height,
        marginLeft = style.marginLeft or cfg.marginLeft,
        marginBottom = style.marginBottom or cfg.marginBottom,
    }
end

-- Top-left corner and size of the map rectangle in pixels, before the layout-editor offset.
local function baseRect(m)
    local cfg = geometry()
    local w, h = cfg.width * m.k, cfg.height * m.k
    local x = m.marginX + cfg.marginLeft * m.k
    local y = m.resY - m.marginY - cfg.marginBottom * m.k - h
    return x, y, w, h
end

local function placeComponent(name, m, x, y, w, h)
    local cal = Config.Minimap.components[name]
    local cw, ch = w * cal.scale, h * cal.scale
    x = x + cal.x * m.k - (cw - w) * 0.5
    y = y + cal.y * m.k - (ch - h) * 0.5
    local vw = m.resY * 16 / 9
    SetMinimapComponentPosition(name, 'L', 'T', (x - m.safeX) / vw, (y - m.marginY) / m.resY, cw / vw, ch / m.resY)
end

function Hud.layoutMinimap()
    if not maskReady then return end
    local m = Hud.metrics()
    local s = Hud.settings
    local x, y, w, h = baseRect(m)

    -- Same formula as applyMinimap() in script.js: offset in 1080p px, size around the center.
    local kr = m.resY / 1080
    local ox, oy, scale = Hud.layoutOf(s, 'minimap')
    local mapW, mapH = w * scale, h * scale
    local mapX = x + ox * kr + s.mapOffsetX * m.k - (mapW - w) * 0.5
    local mapY = y + oy * kr + s.mapOffsetY * m.k - (mapH - h) * 0.5

    local key = ('%d:%d:%.2f:%.2f:%.2f:%.2f'):format(m.resX, m.resY, mapX, mapY, mapW, mapH)
    local round = mapStyle() == 'circle'
    key = key .. (round and ':round' or '')
    if key ~= placed then
        placed = key
        applyMask(round and 'circle' or 'square')
        -- clip type 1 also keeps edge blips on the circle
        SetMinimapClipType(round and 1 or Config.Minimap.clipType)
        placeComponent('minimap', m, mapX, mapY, mapW, mapH)
        placeComponent('minimap_mask', m, mapX, mapY, mapW, mapH)
        placeComponent('minimap_blur', m, mapX, mapY, mapW, mapH)
        -- The radar only re-reads component positions when the bigmap state flips.
        SetBigmapActive(true, false)
        Wait(0)
        SetBigmapActive(false, false)
        Bridge.debug(('minimap placed at %.0f,%.0f %.0fx%.0f'):format(mapX, mapY, mapW, mapH))
    end

    -- The frame is laid out in design pixels (width / height) and scaled in the NUI by
    -- kh * innerHeight, so it matches even if the CEF viewport differs from resY.
    local g = geometry()
    Hud.send('minimap', {
        cx = (x + w * 0.5) / m.resX,
        cy = (y + h * 0.5) / m.resY,
        kh = m.k / m.resY,
        width = g.width,
        height = g.height,
    })
end

local function applyZoom(level)
    SetRadarZoom(level or 0)
end

-- The game resets the radar zoom when the player changes vehicle state, so the zoom is
-- re-applied from the visibility loop while an override is set.
function Hud.tickMinimapZoom()
    local zoom = Hud.settings.mapZoom
    if zoom > 0 then applyZoom(zoom) end
end

CreateThread(function()
    buildMask()
    if Config.Minimap.hideNorthBlip then SetBlipAlpha(GetNorthRadarBlip(), 0) end
    applyZoom(Hud.settings.mapZoom)
    Hud.layoutMinimap()
end)

Hud.onSettings(function(new, old)
    local ox, oy, os = Hud.layoutOf(new, 'minimap')
    local px, py, ps = Hud.layoutOf(old, 'minimap')
    if new.scale ~= old.scale or new.hudStyle ~= old.hudStyle or new.mapStyle ~= old.mapStyle or new.mapOffsetX ~= old.mapOffsetX or new.mapOffsetY ~= old.mapOffsetY
        or ox ~= px or oy ~= py or os ~= ps then
        CreateThread(Hud.layoutMinimap)
    end
    if new.mapZoom ~= old.mapZoom then applyZoom(new.mapZoom) end
end)
