-- StudioBackdrop: draws the lineup set from Config.Studio — rock wall, tiled
-- floor and a contact shadow under each slot — as DUI-textured quads, adds
-- key/rim lights, and keeps ambient traffic out while the selector is open.

local DUI_SIZE = 2048

-- Atlas regions inside studio.html as { u0, v0, u1, v1 }.
local UV_WALL   = { 0.0, 0.0,   1.0,   0.5   }
local UV_FLOOR  = { 0.0, 0.5,   1.0,   0.875 }
local UV_SHADOW = { 0.0, 0.875, 0.125, 1.0   }
local UV_GLOW   = { 0.125, 0.875, 0.25, 1.0   }
local UV_FULL   = { 0.0, 0.0, 1.0, 1.0 }

StudioBackdrop = { running = false }

-- DRAW_SPRITE_POLY takes one (u, v, w) texture coordinate per vertex; w = 1.0.
local function tri(a, b, c, ua, va, ub, vb, uc, vc, dict, tex)
    DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z,
        255, 255, 255, 255, dict, tex,
        ua, va, 1.0, ub, vb, 1.0, uc, vc, 1.0)
end

-- Textured quad from its corners as laid out in the texture (top-left,
-- top-right, bottom-left, bottom-right). Both windings are drawn so the quad
-- shows regardless of which side faces the camera.
local function quad(q, uv, dict, tex)
    local u0, v0, u1, v1 = uv[1], uv[2], uv[3], uv[4]
    tri(q.tl, q.bl, q.tr, u0, v0, u0, v1, u1, v0, dict, tex)
    tri(q.tr, q.bl, q.br, u1, v0, u0, v1, u1, v1, dict, tex)
    tri(q.tl, q.tr, q.bl, u0, v0, u1, v0, u0, v1, dict, tex)
    tri(q.tr, q.br, q.bl, u1, v0, u1, v1, u0, v1, dict, tex)
end

local function hexToRgb(hex)
    local r, g, b = tostring(hex or ""):match("^#(%x%x)(%x%x)(%x%x)$")
    if not r then return 47, 211, 232 end
    return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
end

-- Precompute every quad and light position for the scene.
local function buildGeometry(scene)
    local s  = scene.studio
    local b  = s.backdrop or {}
    local o  = s.origin
    local h  = math.rad(o.w)
    local f  = vector3(-math.sin(h), math.cos(h), 0.0) -- toward the camera
    local r  = vector3(math.cos(h), math.sin(h), 0.0)  -- ped's right = left of frame
    local up = vector3(0.0, 0.0, 1.0)

    local floorZ   = o.z + (b.floorOffset or -1.0)
    local centre   = vector3(o.x, o.y, floorZ)
    local halfW    = (b.width or 22.0) / 2
    local wallBase = centre - f * (b.wallDistance or 2.4)
    local front    = wallBase + f * (b.floorDepth or 9.0)
    local wallTop  = wallBase + up * (b.height or 9.0)
    local sink     = up * 0.05 -- tuck the wall under the floor so no seam shows

    local geo = {
        wall = {
            tl = wallTop + r * halfW,         tr = wallTop - r * halfW,
            bl = wallBase + r * halfW - sink, br = wallBase - r * halfW - sink,
        },
        floor = {
            tl = wallBase + r * halfW, tr = wallBase - r * halfW,
            bl = front + r * halfW,    br = front - r * halfW,
        },
        shadows  = {},
        slotPos  = {},
        silhouettes = {},
        keyLight = centre + f * 3.5 + up * 3.2,
        wallBase = wallBase,
        floorZ   = floorZ,
        f = f, r = r, up = up,
    }

    for _, sc in ipairs(scene.scenes) do
        local p = vector3(sc.coords.x, sc.coords.y, floorZ + 0.01)
        geo.slotPos[#geo.slotPos + 1] = p
        geo.shadows[#geo.shadows + 1] = {
            tl = p - f * 0.45 + r * 0.5, tr = p - f * 0.45 - r * 0.5,
            bl = p + f * 0.45 + r * 0.5, br = p + f * 0.45 - r * 0.5,
        }
        -- Upright cut-out standing on the floor, facing the camera
        -- (+r is the left of frame, matching the texture's left edge).
        local base = p + f * 0.02
        geo.silhouettes[#geo.silhouettes + 1] = {
            tl = base + up * 1.92 + r * 0.48, tr = base + up * 1.92 - r * 0.48,
            bl = base + r * 0.48,             br = base - r * 0.48,
        }
    end

    return geo
end

-- Spotlight quads for a slot position p: a tall glow on the wall behind it
-- and a softer spill on the floor between the slot and the wall.
local function glowQuads(geo, p)
    local f, r, up = geo.f, geo.r, geo.up
    -- Project p onto the wall plane, nudged forward so it sits over the rock.
    local onWall = p - f * (f.x * (p.x - geo.wallBase.x) + f.y * (p.y - geo.wallBase.y)) + f * 0.03
    local wallMid = vector3(onWall.x, onWall.y, geo.floorZ + 2.8)
    local floorMid = vector3(p.x, p.y, geo.floorZ + 0.006) - f * 1.0
    return {
        tl = wallMid + up * 3.6 + r * 2.6, tr = wallMid + up * 3.6 - r * 2.6,
        bl = wallMid - up * 3.6 + r * 2.6, br = wallMid - up * 3.6 - r * 2.6,
    }, {
        tl = floorMid - f * 1.6 + r * 2.4, tr = floorMid - f * 1.6 - r * 2.4,
        bl = floorMid + f * 1.6 + r * 2.4, br = floorMid + f * 1.6 - r * 2.4,
    }
end

function StudioBackdrop:Start(scene)
    if self.running or not (scene and scene.studio) then return end
    self.running = true

    local s   = scene.studio
    local b   = s.backdrop or {}
    local geo = buildGeometry(scene)
    local gr, gg, gb = hexToRgb(b.glow)

    local url = ("nui://%s/studio.html?glow=%s&w=%s&d=%s"):format(
        GetCurrentResourceName(),
        (b.glow or "#2fd3e8"):gsub("#", "%%23"),
        tostring(b.width or 22.0),
        tostring(b.floorDepth or 9.0))
    -- backdrop.enabled = false: the lineup stands in a real room (MLO), so only
    -- the lights and traffic suppression run; nothing is drawn over the world.
    if b.enabled ~= false then
        -- ox_lib classes are instantiated with a colon: lib.dui:new(data).
        self.dui = lib.dui:new({ url = url, width = DUI_SIZE, height = DUI_SIZE, debug = false })
    end

    -- Empty slots show a dark silhouette instead of a bare freemode ped.
    if s.silhouettes ~= false then
        self.silDui = lib.dui:new({
            url    = ("nui://%s/silhouette.html"):format(GetCurrentResourceName()),
            width  = 512,
            height = 1024,
            debug  = false,
        })
    end
    local pedShown = {} -- ped handle -> last visibility we set

    -- The spotlight eases toward whichever slot is focused (mouse or arrows).
    local glowPos = geo.slotPos[math.ceil(#geo.slotPos / 2)] or geo.wallBase

    CreateThread(function()
        while self.running do
            local target = geo.slotPos[(Main and Main.focusedSlot) or 0] or glowPos
            glowPos = glowPos + (target - glowPos) * math.min(1.0, GetFrameTime() * 6.0)

            -- Nothing from the live world should wander into the shot.
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
            HideHudAndRadarThisFrame()

            if s.lights ~= false then
                local k  = geo.keyLight
                local rl = glowPos - geo.f * 0.9 + geo.up * 2.4
                DrawLightWithRange(k.x, k.y, k.z, 255, 250, 245, 10.0, 1.6)
                DrawLightWithRange(rl.x, rl.y, rl.z, gr, gg, gb, 4.5, 3.0)
            end

            local dict = self.dui and self.dui.dictName
            local tex  = self.dui and self.dui.txtName
            if dict and tex then
                quad(geo.wall, UV_WALL, dict, tex)
                quad(geo.floor, UV_FLOOR, dict, tex)
                local wallGlow, floorGlow = glowQuads(geo, glowPos)
                quad(wallGlow, UV_GLOW, dict, tex)
                quad(floorGlow, UV_GLOW, dict, tex)
                for _, q in ipairs(geo.shadows) do
                    quad(q, UV_SHADOW, dict, tex)
                end
            end

            -- Hide the ped of every empty slot and draw its silhouette, except
            -- the slot being created into (body selection needs the real ped).
            local silDict = self.silDui and self.silDui.dictName
            local silTex  = self.silDui and self.silDui.txtName
            for i, char in ipairs((Main and Main.characters) or {}) do
                local empty = not char.identifier and Main.creatingSlot ~= i
                local ped   = char.pedHandle
                local show  = not (empty and silDict)
                if ped and DoesEntityExist(ped) and pedShown[ped] ~= show then
                    SetEntityVisible(ped, show, false)
                    pedShown[ped] = show
                end
                if empty and silDict and geo.silhouettes[i] then
                    quad(geo.silhouettes[i], UV_FULL, silDict, silTex)
                end
            end

            Wait(0)
        end
    end)
end

-- /studiodebug: print what the lineup renderer sees (F8 console).
RegisterCommand("studiodebug", function()
    print(("[studio] running=%s backdrop=%s/%s silhouette=%s/%s creatingSlot=%s"):format(
        tostring(StudioBackdrop.running),
        tostring(StudioBackdrop.dui and StudioBackdrop.dui.dictName), tostring(StudioBackdrop.dui and StudioBackdrop.dui.txtName),
        tostring(StudioBackdrop.silDui and StudioBackdrop.silDui.dictName), tostring(StudioBackdrop.silDui and StudioBackdrop.silDui.txtName),
        tostring(Main and Main.creatingSlot)))
    for i, char in ipairs((Main and Main.characters) or {}) do
        local ped = char.pedHandle
        print(("[studio] slot %d id=%s locked=%s ped=%s exists=%s visible=%s"):format(
            i, tostring(char.identifier), tostring(char._locked == true), tostring(ped),
            tostring(ped and DoesEntityExist(ped)), tostring(ped and IsEntityVisible(ped))))
    end
end, false)

function StudioBackdrop:Stop()
    if not self.running then return end
    self.running = false
    for _, handle in ipairs({ self.dui, self.silDui }) do
        if handle and handle.remove then
            pcall(function() handle:remove() end)
        end
    end
    self.dui    = nil
    self.silDui = nil
end
