DoorHud = { enabled = false }

local cfg = Config.HUD
if not cfg or not cfg.enabled then return end

local TXD = 'ox_doorlock_hud'
local glyphs = HudFont.glyphs
local txd = CreateRuntimeTxd(TXD)

for _, name in ipairs({ 'key_e', 'font', 'dot', 'crosshair' }) do
    CreateRuntimeTextureFromImage(txd, name, ('assets/hud/%s.png'):format(name))
end

local DrawSprite = DrawSprite
local DrawSpriteUv = DrawSpriteUv
local SetDrawOrigin = SetDrawOrigin
local ClearDrawOrigin = ClearDrawOrigin
local GetAspectRatio = GetAspectRatio

local k = cfg.textSize / HudFont.lineHeight

local function measure(str)
    local w = 0.0
    for i = 1, #str do
        local ch = str:sub(i, i)
        if ch == ' ' then
            w = w + cfg.spaceWidth
        else
            local g = glyphs[ch]
            if g then w = w + (g[5] - cfg.tracking) end
        end
    end
    return w + cfg.tracking
end

local function drawText(str, x, y, ratio, c)
    local baseline = y + (HudFont.lineHeight * 0.5) * k * ratio

    for i = 1, #str do
        local ch = str:sub(i, i)

        if ch == ' ' then
            x = x + cfg.spaceWidth * k
        else
            local g = glyphs[ch]

            if g then
                local w, h = g[5] * k, g[6] * k * ratio
                local cy = baseline + (g[7] - g[6] * 0.5) * k * ratio

                DrawSpriteUv(TXD, 'font', x + w * 0.5, cy, w, h, g[1], g[2], g[3], g[4], 0.0, c[1], c[2], c[3], c[4])
                x = x + (g[5] - cfg.tracking) * k
            end
        end
    end
end

function DoorHud.drawPrompt(door)
    local ratio = GetAspectRatio(true)
    local label = cfg.labels[door.state] or ''
    local color = cfg.colors[door.state] or { 255, 255, 255, 255 }
    local keySize = cfg.keySize
    local keyColor = cfg.keyColor

    SetDrawOrigin(door.coords.x, door.coords.y, door.coords.z + (cfg.zOffset or 0.0), 0)

    DrawSprite(TXD, 'key_e', 0.0, 0.0, keySize, keySize * ratio, 0.0, keyColor[1], keyColor[2], keyColor[3], keyColor[4])

    drawText(label, keySize * 0.5 + cfg.textGap, 0.0, ratio, color)

    ClearDrawOrigin()
end

function DoorHud.drawRing(door)
    local ratio = GetAspectRatio(true)
    local size = cfg.ringSize

    SetDrawOrigin(door.coords.x, door.coords.y, door.coords.z + (cfg.zOffset or 0.0), 0)
    local a = cfg.ringAlpha or 255
    DrawSprite(TXD, 'dot', 0.0, 0.0, size, size * ratio, 0.0, 255, 255, 255, a)
    ClearDrawOrigin()
end

function DoorHud.drawCenter()
    local size = cfg.centerSize
    DrawSprite(TXD, 'crosshair', 0.5, 0.5, size, size * GetAspectRatio(true), 0.0, 255, 255, 255, 255)
end

DoorHud.enabled = true
