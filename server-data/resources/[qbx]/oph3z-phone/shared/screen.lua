--[[
    Geometry for the desktop painted on a laptop's screen, done the way
    Renewed-Banking paints its ATMs. Nothing here touches the game.

    A screen is kept in the laptop model's own coordinates, front facing -Y
    (the side the player stands on), so +X is on their right:
        { x, y, z = the middle of the glass, width, height = metres,
          tilt = degrees the top leans back, away from the player }
]]

LaptopGeometry = {}

--- The page, in pixels.
LaptopGeometry.W, LaptopGeometry.H = Config.Display.Resolution.w, Config.Display.Resolution.h

--- The screen's corners in model coordinates: top left, top right, bottom
--- right, bottom left as the player sees them, a few millimetres in front
--- of the glass so the picture is never inside the lid.
function LaptopGeometry.corners(screen)
    local t = math.rad(screen.tilt or 0.0)
    local halfW, halfH = screen.width / 2, screen.height / 2
    local upY, upZ = math.sin(t) * halfH, math.cos(t) * halfH
    -- Towards the player, along the glass's normal.
    local liftY, liftZ = -math.cos(t) * 0.003, math.sin(t) * 0.003
    local x, y, z = screen.x, screen.y + liftY, screen.z + liftZ
    return {
        { x = x - halfW, y = y + upY, z = z + upZ },
        { x = x + halfW, y = y + upY, z = z + upZ },
        { x = x + halfW, y = y - upY, z = z - upZ },
        { x = x - halfW, y = y - upY, z = z - upZ },
    }
end

--- Where the camera looks from, in model coordinates: square on to the
--- glass, back far enough that the glass fills `fill` of the view's height.
function LaptopGeometry.camera(screen, fov, fill)
    local t = math.rad(screen.tilt or 0.0)
    local distance = (screen.height / fill / 2) / math.tan(math.rad(fov / 2))
    return { x = screen.x, y = screen.y - math.cos(t) * distance, z = screen.z + math.sin(t) * distance }
end

--- A first guess from the model's size (GetModelDimensions): the lid at
--- the back, most of the width, leaning back a little.
function LaptopGeometry.fit(min, max)
    local width, depth, height = max.x - min.x, max.y - min.y, max.z - min.z
    local screenWidth = width * 0.8
    return {
        x = (min.x + max.x) / 2, y = max.y - depth * 0.3, z = min.z + height * 0.58,
        width = screenWidth, height = math.min(screenWidth * 0.625, height * 0.7), tilt = 12.0,
    }
end

local function sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function cross(a, b) return { x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x } end

--- The direction through a point of the monitor (mx, my: 0 to 1 from the top
--- left) for a camera at rotation `rot` (degrees: pitch x, yaw z; no roll),
--- vertical field of view `fov` and width/height `aspect`.
function LaptopGeometry.rayFrom(rot, fov, aspect, mx, my)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    local forward = { x = -math.sin(yaw) * math.cos(pitch), y = math.cos(yaw) * math.cos(pitch), z = math.sin(pitch) }
    local right = { x = math.cos(yaw), y = math.sin(yaw), z = 0.0 }
    local up = cross(right, forward)
    local h = math.tan(math.rad(fov) / 2)
    local sx, sy = (mx * 2 - 1) * h * aspect, (1 - my * 2) * h
    return {
        x = forward.x + right.x * sx + up.x * sy,
        y = forward.y + right.y * sx + up.y * sy,
        z = forward.z + right.z * sx + up.z * sy,
    }
end

--- Where a ray meets the glass, as (u, v): 0 to 1 across and down it.
--- `corners` are its world corners.
function LaptopGeometry.uvFromRay(origin, direction, corners)
    local tl = corners[1]
    local across, down = sub(corners[2], tl), sub(corners[4], tl)
    local normal = cross(across, down)
    local facing = dot(direction, normal)
    if math.abs(facing) < 1e-9 then return nil end
    local t = dot(sub(tl, origin), normal) / facing
    if t <= 0 then return nil end
    local hit = { x = origin.x + direction.x * t, y = origin.y + direction.y * t, z = origin.z + direction.z * t }
    local rel = sub(hit, tl)
    return dot(rel, across) / dot(across, across), dot(rel, down) / dot(down, down)
end
