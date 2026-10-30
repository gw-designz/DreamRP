DoorHud = { enabled = false }

local cfg = Config.HUD
if not cfg or not cfg.enabled then return end

-- Sprites are rendered from tools/hud/render.html (node tools/hud/build.mjs) to match my-hud
local TXD = 'ox_doorlock_hud'
local txd = CreateRuntimeTxd(TXD)

for name in pairs(HudAssets) do
    CreateRuntimeTextureFromImage(txd, name, ('assets/hud/%s.png'):format(name))
end

CreateRuntimeTextureFromImage(txd, 'crosshair', 'assets/hud/crosshair.png')

local DrawSprite = DrawSprite
local SetDrawOrigin = SetDrawOrigin
local ClearDrawOrigin = ClearDrawOrigin
local GetAspectRatio = GetAspectRatio

-- Draws a sprite centred on the door, sized from its 1080p pixel size
local function drawAtDoor(door, name, scale, alpha)
    local size = HudAssets[name]
    if not size then return end

    local coords = door.drawCoords or door.coords
    local h = size[2] / 1080 * scale

    SetDrawOrigin(coords.x, coords.y, coords.z + (cfg.zOffset or 0.0), 0)
    DrawSprite(TXD, name, 0.0, 0.0, h * size[1] / size[2] / GetAspectRatio(true), h, 0.0, 255, 255, 255, alpha or 255)
    ClearDrawOrigin()
end

function DoorHud.drawPrompt(door)
    drawAtDoor(door, ('prompt_%d'):format(door.state), cfg.promptScale)
end

function DoorHud.drawRing(door)
    drawAtDoor(door, ('ring_%d'):format(door.state), cfg.ringScale, cfg.ringAlpha)
end

function DoorHud.drawCenter()
    local size = cfg.centerSize
    DrawSprite(TXD, 'crosshair', 0.5, 0.5, size, size * GetAspectRatio(true), 0.0, 255, 255, 255, 255)
end

DoorHud.enabled = true
