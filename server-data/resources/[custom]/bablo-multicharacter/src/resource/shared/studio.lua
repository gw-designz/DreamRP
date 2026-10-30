-- Builds a Config.Locations entry from Config.Studio: a straight lineup of
-- characters facing a camera, with a backdrop rendered client-side by
-- StudioBackdrop (client/studio.lua). Runs on both sides so the server's
-- premium-slot logic sees the same slot list as the client.

local studio = Config.Studio
if not (studio and studio.enabled and studio.origin) then return end

local o       = studio.origin
local slots   = studio.slots   or 5
local spacing = studio.spacing or 1.55
local camCfg  = studio.camera  or {}
local detail  = studio.detail  or {}

-- GTA heading h faces (-sin h, cos h); the ped's right-hand side is (cos h, sin h).
local h      = math.rad(o.w)
local fx, fy = -math.sin(h), math.cos(h)
local rx, ry = math.cos(h), math.sin(h)

local scenes = {}
for i = 1, slots do
    -- Slot 1 is on the ped's right, which is the left of the camera's frame.
    local lateral = ((slots + 1) / 2 - i) * spacing
    local px, py  = o.x + rx * lateral, o.y + ry * lateral

    scenes[i] = {
        coords    = vector4(px, py, o.z, o.w),
        freeze    = true,
        animation = studio.animation or false,
        locked    = studio.locked and studio.locked[i] or nil,
        camera    = {
            coords   = vector3(px, py, o.z),
            rotation = vector3(0.0, 0.0, o.w + 180.0),
            fov      = detail.fov or 45.0,
            distance = detail.distance or 2.2,
            aside    = detail.aside or 0.0,
            offsets  = vector3(0.0, 0.0, 0.35),
        },
    }
end

local camDist = camCfg.distance or 4.6
Config.Locations = {
    {
        defaultCamera = {
            coords   = vector3(o.x + fx * camDist, o.y + fy * camDist, o.z + (camCfg.height or 0.6)),
            rotation = vector3(camCfg.pitch or -2.0, 0.0, o.w + 180.0),
            fov      = camCfg.fov or 50.0,
        },
        scenes = scenes,
        studio = studio,
    },
}
