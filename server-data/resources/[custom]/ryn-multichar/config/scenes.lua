Config.ActiveScene = 'yacht'

--[[
    Scene presets — switch with Config.ActiveScene.
    Tune in-game with admin commands:
      /ryn_scene_pos  — copy ped vector4 to clipboard
      /ryn_scene_cam  — copy camera block to clipboard

    Presets: apartment | yacht
    idleAnim is the default look per slot when the character has no saved pose.

    group (optional, used when Config.UI.cardsOverPeds is on): where each slot's ped
    stands when they are all shown together, and the one camera that sees them all.
      group = { peds = { [1] = vector4(...), ... }, camera = { pos, rot, fov } }
    Without it, the slots' own ped spots are used and a camera is worked out to fit them.
]]

Config.ScenePresets = {
    apartment = {
        type = 'apartment',
        coords = vector3(-787.3, 315.79, 217.64),
        ipl = 'apa_v_mp_h_01_a',
        slots = {
            [1] = {
                ped = vector4(-786.49, 315.79, 217.64, 270.0),
                camera = {
                    pos = vector3(-782.35, 315.79, 218.35),
                    rot = vector3(-4.0, 0.0, 90.0),
                    fov = 44.0,
                },
                idleAnim = {
                    dict = 'anim@amb@casino@hangout@ped_male@stand@02b@idles',
                    name = 'idle_a',
                    flag = 1,
                },
            },
            [2] = {
                ped = vector4(-785.33, 329.19, 217.04, 99.42),
                -- ~4.14m in front of ped (same framing as slot 1)
                camera = {
                    pos = vector3(-781.25, 328.51, 217.75),
                    rot = vector3(-4.0, 0.0, 279.42),
                    fov = 44.0,
                },
                idleAnim = {
                    dict = 'amb@world_human_hang_out_street@male_c@idle_a',
                    name = 'idle_a',
                    flag = 1,
                },
            },
            [3] = {
                ped = vector4(-796.08, 327.22, 217.04, 140.80),
                -- ~4.14m in front of ped (same framing as slot 1)
                camera = {
                    pos = vector3(-793.47, 324.00, 217.75),
                    rot = vector3(-4.0, 0.0, 320.80),
                    fov = 44.0,
                },
                idleAnim = {
                    dict = 'amb@world_human_leaning@male@wall@back@foot_up@idle_a',
                    name = 'idle_a',
                    flag = 1,
                },
            },
        },
        lighting = true,
        weather = 'CLEAR',
        time = { hour = 14, minute = 0 },
    },

    yacht = {
        type = 'yacht',
        coords = vector3(-2058.27, -1024.50, 9.95),
        ipl = nil,
        slots = {
            [1] = {
                ped = vector4(-2045.73, -1023.99, 11.91, 140.26),
                camera = {
                    pos = vector3(-2047.98, -1026.67, 12.56),
                    rot = vector3(-4.0, 0.0, 320.26),
                    fov = 44.0,
                },
                idleAnim = {
                    dict = 'anim@amb@casino@hangout@ped_male@stand@02b@idles',
                    name = 'idle_a',
                    flag = 1,
                },
            },
            [2] = {
                ped = vector4(-2092.80, -1015.54, 8.98, 250.55),
                camera = {
                    pos = vector3(-2089.22, -1016.81, 9.69),
                    rot = vector3(-4.0, 0.0, 70.55),
                    fov = 44.0,
                },
                idleAnim = {
                    dict = 'amb@world_human_leaning@male@wall@back@foot_up@idle_a',
                    name = 'idle_a',
                    flag = 1,
                },
            },
            [3] = {
                ped = vector4(-2036.27, -1033.98, 8.97, 68.33),
                camera = {
                    pos = vector3(-2039.80, -1032.58, 9.68),
                    rot = vector3(-4.0, 0.0, 248.33),
                    fov = 44.0,
                },
                idleAnim = {
                    dict = 'amb@world_human_stand_guard@male@base',
                    name = 'base',
                    flag = 1,
                },
            },
        },
        -- A starting point worked out from slot 1's spot; tune with /ryn_scene_pos and /ryn_scene_cam.
        group = {
            peds = {
                [1] = vector4(-2046.96, -1022.97, 11.91, 140.26),
                [2] = vector4(-2045.73, -1023.99, 11.91, 140.26),
                [3] = vector4(-2044.50, -1025.01, 11.91, 140.26),
            },
            camera = {
                pos = vector3(-2049.31, -1028.30, 12.75),
                rot = vector3(-6.0, 0.0, 320.26),
                fov = 50.0,
            },
        },
        lighting = false,
        weather = 'CLEAR',
        time = { hour = 14, minute = 0 },
    },
}

-- A camera that fits every slot's ped: back from their middle, along the way they face on average.
local function fitGroupCamera(peds)
    local cx, cy, cz, fx, fy, n = 0.0, 0.0, 0.0, 0.0, 0.0, 0
    for _, p in pairs(peds) do
        cx, cy, cz, n = cx + p.x, cy + p.y, cz + p.z, n + 1
        local h = math.rad(p.w or 0.0)
        fx, fy = fx - math.sin(h), fy + math.cos(h)
    end
    if n == 0 then return nil end
    cx, cy, cz = cx / n, cy / n, cz / n

    local len = math.sqrt(fx * fx + fy * fy)
    if len < 0.1 then fx, fy, len = 0.0, 1.0, 1.0 end
    fx, fy = fx / len, fy / len

    local spread = 0.0
    for _, p in pairs(peds) do
        spread = math.max(spread, math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2))
    end

    local fov = 50.0
    local dist = math.max(3.5, (spread + 1.0) / math.tan(math.rad(fov / 2)) * 1.15)
    local pos = vector3(cx + fx * dist, cy + fy * dist, cz + 0.85)
    local yaw = math.deg(math.atan(-(cx - pos.x), cy - pos.y))
    return { pos = pos, rot = vector3(-6.0, 0.0, yaw), fov = fov }
end

--- With Config.UI.cardsOverPeds, a copy of the scene whose slots stand at their group spots
--- and all share the group camera; otherwise the scene as it is.
function ApplySceneGroupLayout(scene)
    if not scene or not (Config.UI and Config.UI.cardsOverPeds) or scene._grouped then return scene end

    local group = scene.group or {}
    local peds = {}
    for slotIndex, slot in pairs(scene.slots or {}) do
        peds[slotIndex] = (group.peds and group.peds[slotIndex]) or slot.ped
    end
    local camera = group.camera or fitGroupCamera(peds)

    local copy = {}
    for k, v in pairs(scene) do copy[k] = v end
    copy.slots = {}
    for slotIndex, slot in pairs(scene.slots or {}) do
        local s = {}
        for k, v in pairs(slot) do s[k] = v end
        s.ped = peds[slotIndex]
        s.camera = camera or slot.camera
        copy.slots[slotIndex] = s
    end
    copy._grouped = true
    return copy
end

Config.Scene = ApplySceneGroupLayout(Config.ScenePresets[Config.ActiveScene] or Config.ScenePresets.apartment)
