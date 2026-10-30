RenewedBanking = RenewedBanking or {}
local RB = RenewedBanking

-- Geometry for the ATM page painted on a machine's screen. Nothing here
-- touches the game, so tests/run.lua checks it outside it.
RB.AtmScreen = {}

-- The page, in pixels: 4:3 like the glass.
RB.AtmScreen.W, RB.AtmScreen.H = 1024, 768

--- The four corners of a screen in the model's own coordinates: top left,
--- top right, bottom right, bottom left, as seen by someone standing in
--- front of it (on -Y, looking at +Y, so +X is on their right).
function RB.AtmScreen.corners(screen)
    local tilt = math.rad(screen.tilt or 0.0)
    local halfW, halfH = screen.width / 2, screen.height / 2
    -- Up along the glass leans away from the viewer as the top tilts back.
    local upY, upZ = math.sin(tilt) * halfH, math.cos(tilt) * halfH
    local x, y, z = screen.x, screen.y, screen.z
    return {
        { x = x - halfW, y = y + upY, z = z + upZ },
        { x = x + halfW, y = y + upY, z = z + upZ },
        { x = x + halfW, y = y - upY, z = z - upZ },
        { x = x - halfW, y = y - upY, z = z - upZ }
    }
end

--- Where the camera looks from, in model coordinates: square on to the
--- glass and back far enough that it fills nine tenths of the view's height.
function RB.AtmScreen.camera(screen, fov)
    local tilt = math.rad(screen.tilt or 0.0)
    local distance = (screen.height / 0.9 / 2) / math.tan(math.rad(fov / 2))
    -- The glass faces -Y, tipped up by its tilt.
    return {
        x = screen.x,
        y = screen.y - math.cos(tilt) * distance,
        z = screen.z + math.sin(tilt) * distance
    }
end

--- Which of the machine's side buttons (u, v) is on, from a screen's `keys`:
--- 'left' or 'right' and the row (1 at the top), or nil.
function RB.AtmScreen.keyAt(keys, u, v)
    if not keys or not u or not v then return nil end
    local side
    if u >= keys.left[1] and u <= keys.left[2] then side = 'left'
    elseif u >= keys.right[1] and u <= keys.right[2] then side = 'right'
    else return nil end
    local half = keys.height / 2
    for row, centre in ipairs(keys.rows) do
        if v >= centre - half and v <= centre + half then return side, row end
    end
    return nil
end

--- A point on the glass's plane at (u, v), from its world corners.
function RB.AtmScreen.pointAt(corners, u, v)
    local tl, tr, bl = corners[1], corners[2], corners[4]
    return {
        x = tl.x + (tr.x - tl.x) * u + (bl.x - tl.x) * v,
        y = tl.y + (tr.y - tl.y) * u + (bl.y - tl.y) * v,
        z = tl.z + (tr.z - tl.z) * u + (bl.z - tl.z) * v
    }
end

local function sub(a, b) return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z } end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function cross(a, b) return { x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x } end

--- The direction through a point of the monitor (mx, my: 0 to 1 from the top
--- left) for a camera at rotation `rot` (degrees: pitch x, yaw z; no roll),
--- vertical field of view `fov` (degrees) and width/height `aspect`.
function RB.AtmScreen.rayFrom(rot, fov, aspect, mx, my)
    local pitch, yaw = math.rad(rot.x), math.rad(rot.z)
    local forward = { x = -math.sin(yaw) * math.cos(pitch), y = math.cos(yaw) * math.cos(pitch), z = math.sin(pitch) }
    local right = { x = math.cos(yaw), y = math.sin(yaw), z = 0.0 }
    local up = cross(right, forward)
    local h = math.tan(math.rad(fov) / 2)
    local sx, sy = (mx * 2 - 1) * h * aspect, (1 - my * 2) * h
    return {
        x = forward.x + right.x * sx + up.x * sy,
        y = forward.y + right.y * sx + up.y * sy,
        z = forward.z + right.z * sx + up.z * sy
    }
end

--- Where a ray meets the glass's plane, as (u, v): 0 to 1 across and down the
--- glass, and beyond it outside the glass. `corners` are its world corners.
function RB.AtmScreen.uvFromRay(origin, direction, corners)
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
