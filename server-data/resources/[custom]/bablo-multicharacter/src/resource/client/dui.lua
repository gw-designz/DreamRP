-- DUI texture dimensions for ped name-label sprites.
local DUI_WIDTH        = 512
local DUI_SLOT_HEIGHT  = 128
local DUI_ASPECT_RATIO = DUI_WIDTH / DUI_SLOT_HEIGHT   -- = 4.0
local MAX_SLOTS        = 10

-- Sprite sizing constants (world-space units).
local SPRITE_SCALE_DIST  = 0.2   -- distance-to-scale coefficient
local SPRITE_MIN_SCALE   = 0.05  -- minimum sprite half-width
local SPRITE_HEIGHT_BIAS = 0.55  -- upward Z offset applied to the head-bone position

-- Shared singleton DUI handle and the slot count it was created for.
-- Stored at file scope so all PedLabelsDui instances share one texture.
local sharedDuiHandle    = nil
local sharedDuiSlotCount = nil

-- Returns the current camera rotation (handles both gameplay cam and scripted cams).
local function getCamRot()
    if IsGameplayCamRendering() then
        return GetGameplayCamRot(2)
    end
    local cam = GetRenderingCam()
    if cam ~= 0 and cam ~= -1 then
        return GetCamRot(cam, 2)
    end
    return GetGameplayCamRot(2)
end

-- Returns the current camera position (handles both gameplay cam and scripted cams).
local function getCamCoord()
    if IsGameplayCamRendering() then
        return GetGameplayCamCoord()
    end
    local cam = GetRenderingCam()
    if cam ~= 0 and cam ~= -1 then
        return GetCamCoord(cam)
    end
    return GetGameplayCamCoord()
end

-- Returns the 6-component camera basis (right.x, right.y, zero, rightUp.x, rightUp.y, pitchCos)
-- needed by DrawSlot3D to orient name-label quads toward the camera.
-- ⚠️ This decomposition is tightly coupled to DrawSlot3D — verify both if you change either.
local function getCamBasis()
    local rot    = getCamRot()
    local pitchR = math.rad(rot.x)
    local yawR   = math.rad(rot.z)
    local sinPitch = math.sin(pitchR)
    local cosPitch = math.cos(pitchR)
    local sinYaw   = math.sin(yawR)
    local cosYaw   = math.cos(yawR)
    -- Returns: rightX, rightY, 0, sinYaw*sinPitch, -cosYaw*sinPitch, cosPitch
    return cosYaw, sinYaw, 0.0, sinYaw * sinPitch, -cosYaw * sinPitch, cosPitch
end

-- Returns the world position just above a ped's head (bone 31086 = SKEL_Head).
-- Falls back to entity coords + 1.0 if the bone is unavailable or at origin.
local function getPedHeadPosition(pedHandle)
    local boneIndex = GetPedBoneIndex(pedHandle, 31086)
    if boneIndex and boneIndex ~= -1 then
        local bonePos = GetWorldPositionOfEntityBone(pedHandle, boneIndex)
        if bonePos and not (bonePos.x == 0.0 and bonePos.y == 0.0 and bonePos.z == 0.0) then
            return bonePos.x, bonePos.y, bonePos.z + SPRITE_HEIGHT_BIAS
        end
    end
    local pos = GetEntityCoords(pedHandle)
    return pos.x, pos.y, pos.z + 1.0
end


PedLabelsDui = lib.class("PedLabelsDui")

function PedLabelsDui:constructor()
    self.running        = false
    self.handle         = nil
    self.slots          = {}
    self.slotCount      = MAX_SLOTS
    self.lastSerialized = ""
    self.theme          = "dark"
    self.referenceFov   = 57.0
end

-- Override the reference FOV used for scaling name-label sprites.
function PedLabelsDui:SetReferenceFov(fov)
    if type(fov) == "number" and fov > 0 then
        self.referenceFov = fov
    end
end

-- Returns a scale factor (≤ 1.0) based on the ratio of current cam FOV to referenceFov.
-- Wider FOV → smaller factor → smaller sprites (counteracts perspective zoom).
function PedLabelsDui:GetFovScale()
    local cam = GetRenderingCam()
    local currentFov
    if cam ~= 0 and cam ~= -1 then
        currentFov = GetCamFov(cam)
    else
        currentFov = GetGameplayCamFov()
    end
    local ref = self.referenceFov or 57.0
    if not currentFov or currentFov <= 0 or ref <= 0 then return 1.0 end
    return math.min(1.0, currentFov / ref)
end

-- Initialise (or re-use) the shared DUI texture and start the render thread.
-- slotCount controls how many ped name slots are packed into the texture vertically.
function PedLabelsDui:Init(slotCount)
    if self.running then return end

    slotCount = tonumber(slotCount) or MAX_SLOTS
    slotCount = math.max(1, math.min(slotCount, MAX_SLOTS))
    self.slotCount = slotCount

    -- If the shared DUI exists but was built for a different slot count, destroy and recreate.
    if sharedDuiHandle then
        if sharedDuiSlotCount ~= slotCount then
            local ok = pcall(function() sharedDuiHandle:remove() end)
            Trace(("PedLabelsDui:Init slot count changed %s -> %d, recreated DUI (remove ok=%s)"):format(
                tostring(sharedDuiSlotCount), slotCount, tostring(ok)))
            sharedDuiHandle = nil
        end
    end

    if not sharedDuiHandle then
        sharedDuiHandle = lib.dui:new({
            url    = ("nui://%s/dui.html"):format(GetCurrentResourceName()),
            width  = DUI_WIDTH,
            height = slotCount * DUI_SLOT_HEIGHT,
            debug  = false,
        })
        sharedDuiSlotCount = slotCount
        Trace(("PedLabelsDui:Init created shared DUI handle (%d slots, %dx%d)"):format(
            slotCount, DUI_WIDTH, slotCount * DUI_SLOT_HEIGHT))
    else
        Trace("PedLabelsDui:Init reusing existing shared DUI handle")
    end

    self.handle  = sharedDuiHandle
    self.running = true
    self:StartRenderThread()

    -- Force a full message push for the first ~3 s so the texture is primed
    -- before the first character-select frame.
    Citizen.CreateThread(function()
        local deadline = GetGameTimer() + 3000
        while self.running and GetGameTimer() < deadline do
            self.lastSerialized = ""
            self:PushMessage()
            Wait(150)
        end
    end)
end

-- Populate this instance's slot table from an array of slot descriptors.
-- Each descriptor: { pedHandle, name, empty, locked, hovered, duiScale }.
-- Slots beyond the array or whose ped no longer exists are marked invisible.
function PedLabelsDui:SetSlots(slotDescriptors)
    self.slots = {}
    for i = 1, self.slotCount do
        local desc = slotDescriptors[i]
        if desc and desc.pedHandle and DoesEntityExist(desc.pedHandle) then
            self.slots[i] = {
                pedHandle = desc.pedHandle,
                name      = desc.name      or "",
                empty     = desc.empty     == true,
                locked    = desc.locked    == true,
                hovered   = desc.hovered   == true,
                duiScale  = desc.duiScale  or 1.0,
                visible   = true,
            }
        else
            self.slots[i] = { visible = false }
        end
    end
    self:PushMessage()
end

-- Update the theme ("dark" or "light") and immediately push to the DUI.
function PedLabelsDui:SetTheme(theme)
    if theme ~= "dark" and theme ~= "light" then return end
    if self.theme == theme then return end
    self.theme = theme
    self:PushMessage()
end

-- Mark the hovered slot by matching pedHandle, then push to the DUI.
function PedLabelsDui:SetHovered(pedHandle)
    for i = 1, self.slotCount do
        local slot = self.slots[i]
        if slot and slot.pedHandle then
            local isHovered = slot.pedHandle == pedHandle
            if slot.hovered ~= isHovered then
                slot.hovered = isHovered
            end
        end
    end
    self:PushMessage()
end

-- Serialise the current slot state and send it to the DUI via sendMessage.
-- Skips the send if the serialised payload is identical to the last one (dirty-check).
function PedLabelsDui:PushMessage()
    if not self.handle then return end

    local accentColor = (Config.Theme and Config.Theme.accent) or "#7aadff"
    local payload = {
        slots      = {},
        theme      = self.theme,
        accent     = accentColor,
        slotCount  = self.slotCount,
    }

    for i = 1, self.slotCount do
        local slot = self.slots[i]
        if slot and slot.visible then
            table.insert(payload.slots, {
                visible = true,
                name    = slot.name,
                empty   = slot.empty,
                locked  = slot.locked,
                hovered = slot.hovered,
            })
        else
            table.insert(payload.slots, { visible = false })
        end
    end

    local serialised = json.encode(payload)
    if serialised == self.lastSerialized then return end
    self.lastSerialized = serialised
    if not self.handle.sendMessage then return end
    self.handle:sendMessage({ action = "bablo-multicharacter:peds", data = payload })
end

-- Draw a single DUI-textured billboard quad (split into two triangles) in world space
-- at the ped's head position for slot index slotIndex (0-based).
-- camRight/camUp are the two basis vectors from getCamBasis(); dictName/txtName are the
-- texture coordinates on the shared DUI atlas.
function PedLabelsDui:DrawSlot3D(slotIndex, headX, headY, headZ,
                                  camCoord,
                                  basisRX, basisRY, basisRZ,
                                  basisUX, basisUY, basisUZ,
                                  dictName, txtName, duiScale)
    local distToHead = #(vector3(headX, headY, headZ) - camCoord)
    local nameScale  = Config.NameplateScale or 1.0
    local slotScale  = (duiScale or 1.0) * self:GetFovScale() * nameScale

    local halfW = math.max(SPRITE_MIN_SCALE, distToHead * SPRITE_SCALE_DIST) * slotScale
    local halfH = halfW / DUI_ASPECT_RATIO * 0.5
    local hW    = halfW * 0.5
    local hH    = halfH * 0.5

    -- Four quad corners (world space).
    local x1 = headX - basisRX * hW + basisUX * hH
    local y1 = headY - basisRY * hW + basisUY * hH
    local z1 = headZ - basisRZ * hW + basisUZ * hH

    local x2 = headX + basisRX * hW + basisUX * hH
    local y2 = headY + basisRY * hW + basisUY * hH
    local z2 = headZ + basisRZ * hW + basisUZ * hH

    local x3 = headX - basisRX * hW - basisUX * hH
    local y3 = headY - basisRY * hW - basisUY * hH
    local z3 = headZ - basisRZ * hW - basisUZ * hH

    local x4 = headX + basisRX * hW - basisUX * hH
    local y4 = headY + basisRY * hW - basisUY * hH
    local z4 = headZ + basisRZ * hW - basisUZ * hH

    -- UV band for this slot within the shared atlas texture.
    local uvRowHeight = 1.0 / self.slotCount
    local uvTop       = slotIndex * uvRowHeight
    local uvBottom    = uvTop + uvRowHeight

    -- One (u, v, w) per vertex. Corners: 1 = top-left, 2 = top-right,
    -- 3 = bottom-left, 4 = bottom-right; both windings so either side shows.
    DrawSpritePoly(x1, y1, z1,  x3, y3, z3,  x2, y2, z2,
        255, 255, 255, 255, dictName, txtName,
        0.0, uvTop, 1.0,  0.0, uvBottom, 1.0,  1.0, uvTop, 1.0)

    DrawSpritePoly(x2, y2, z2,  x3, y3, z3,  x4, y4, z4,
        255, 255, 255, 255, dictName, txtName,
        1.0, uvTop, 1.0,  0.0, uvBottom, 1.0,  1.0, uvBottom, 1.0)

    DrawSpritePoly(x2, y2, z2,  x3, y3, z3,  x1, y1, z1,
        255, 255, 255, 255, dictName, txtName,
        1.0, uvTop, 1.0,  0.0, uvBottom, 1.0,  0.0, uvTop, 1.0)

    DrawSpritePoly(x4, y4, z4,  x3, y3, z3,  x2, y2, z2,
        255, 255, 255, 255, dictName, txtName,
        1.0, uvBottom, 1.0,  0.0, uvBottom, 1.0,  1.0, uvTop, 1.0)
end

-- Start the per-frame render thread that projects each visible ped label into world space.
function PedLabelsDui:StartRenderThread()
    CreateThread(function()
        local textureReady = false
        while self.running do
            Wait(0)
            if not self.handle then goto continue end

            local dictName = self.handle.dictName
            local txtName  = self.handle.txtName
            local hasTexture = dictName and txtName

            if hasTexture and not textureReady then
                textureReady = true
                self.lastSerialized = ""
                self:PushMessage()
            elseif not hasTexture and textureReady then
                textureReady = false
            end

            if not hasTexture then goto continue end

            local camPos                          = getCamCoord()
            local r1, r2, r3, u1, u2, u3         = getCamBasis()

            for slotIdx = 1, self.slotCount do
                local slot = self.slots[slotIdx]
                if slot and slot.visible and slot.pedHandle and DoesEntityExist(slot.pedHandle) then
                    local hx, hy, hz = getPedHeadPosition(slot.pedHandle)
                    self:DrawSlot3D(
                        slotIdx - 1,
                        hx, hy, hz,
                        camPos,
                        r1, r2, r3,
                        u1, u2, u3,
                        dictName, txtName,
                        slot.duiScale
                    )
                end
            end

            ::continue::
        end
    end)
end

-- Stop rendering and send an empty slot list to the DUI, then clear state.
function PedLabelsDui:Destroy()
    if not self.running then return end
    self.running = false
    if self.handle and self.handle.sendMessage then
        self.handle:sendMessage({
            action = "bablo-multicharacter:peds",
            data   = { slots = {}, slotCount = self.slotCount },
        })
    end
    self.handle         = nil
    self.slots          = {}
    self.lastSerialized = ""
end


-- LogoDui: renders a DUI-textured billboard at a fixed world position (e.g. a server logo).
local LOGO_DUI_SIZE = 1024

LogoDui = lib.class("LogoDui")

function LogoDui:constructor()
    self.running = false
    self.handle  = nil
    self.config  = nil
end

-- Initialise the logo DUI from a config table:
--   { coords = vector3, heading = number, width = number, height = number,
--     image = string, debug = bool }
function LogoDui:Init(config)
    if self.running then return end
    if not config or not config.coords then
        Trace("[LogoDui] Init — missing config or coords, bailing")
        return
    end

    self.config = config

    local c = config.coords
    Trace(("[LogoDui] Init — coords=(%.4f, %.4f, %.4f) heading=%.4f size=%.2fx%.2f image=%s debug=%s"):format(
        c.x, c.y, c.z,
        config.heading or 0.0,
        config.width   or 1.5,
        config.height  or 1.5,
        tostring(config.image),
        tostring(config.debug)
    ))

    self.handle = lib.dui:new({
        url    = ("nui://%s/logo.html"):format(GetCurrentResourceName()),
        width  = LOGO_DUI_SIZE,
        height = LOGO_DUI_SIZE,
        debug  = false,
    })
    self.running = true
    self:StartRenderThread()

    -- Push the logo image to the DUI for up to 3 s, logging once the texture is ready.
    Citizen.CreateThread(function()
        local textureReady = false
        local deadline     = GetGameTimer() + 3000
        while self.running and GetGameTimer() < deadline do
            if self.handle and self.handle.sendMessage then
                self.handle:sendMessage({
                    action = "bablo-multicharacter:logo",
                    data   = { image = config.image or "logo_example.png" },
                })
                if not textureReady and self.handle.dictName and self.handle.txtName then
                    textureReady = true
                    Trace(("[LogoDui] DUI texture ready — dict=%s tex=%s"):format(
                        tostring(self.handle.dictName),
                        tostring(self.handle.txtName)
                    ))
                end
            end
            Wait(150)
        end
        if self.running and not textureReady then
            Trace("[LogoDui] DUI texture never became ready within 3s — " ..
                  "image path may be wrong or logo.html not served (check fxmanifest files{} + that the PNG exists)")
        end
    end)
end

-- Draw five debug markers: one large red sphere at the centre and four small green/cyan
-- spheres at the quad corners. Also draws a text label via SetDrawOrigin.
function LogoDui:DrawDebug(cx, cy, cz, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, heading)
    local function drawSphere(x, y, z, r, g, b, size)
        DrawMarker(28, x, y, z, 0,0,0, 0,0,0, size, size, size, r, g, b, 200, false, false, 2, false, nil, nil, false)
    end
    drawSphere(cx, cy, cz, 255, 50,  50,  0.2)
    drawSphere(x1, y1, z1, 50,  255, 50,  0.08)
    drawSphere(x2, y2, z2, 50,  255, 50,  0.08)
    drawSphere(x3, y3, z3, 50,  200, 255, 0.08)
    drawSphere(x4, y4, z4, 50,  200, 255, 0.08)

    SetDrawOrigin(cx, cy, cz + 0.45, 0)
    SetTextScale(0.4, 0.4)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentSubstringPlayerName(
        ("LOGO @ %.2f, %.2f, %.2f  h=%.1f"):format(cx, cy, cz, heading))
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Per-frame render thread: draws the logo quad at the configured world position each frame.
function LogoDui:StartRenderThread()
    CreateThread(function()
        while self.running do
            Wait(0)
            local cfg = self.config
            if not cfg or not cfg.coords then goto continue end

            local heading = cfg.heading or 0.0
            local hRad    = math.rad(heading)
            local cosH    = math.cos(hRad)
            local sinH    = math.sin(hRad)

            local cx  = cfg.coords.x
            local cy  = cfg.coords.y
            local cz  = cfg.coords.z
            local hw  = (cfg.width  or 1.5) * 0.5
            local hht = (cfg.height or 1.5) * 0.5

            -- Quad corners: cos/sin of heading give the horizontal facing axis.
            local offX = cosH * hw
            local offY = sinH * hw

            local x1 = cx - offX;  local y1 = cy - offY;  local z1 = cz + hht
            local x2 = cx + offX;  local y2 = cy + offY;  local z2 = cz + hht
            local x3 = cx - offX;  local y3 = cy - offY;  local z3 = cz - hht
            local x4 = cx + offX;  local y4 = cy + offY;  local z4 = cz - hht

            if cfg.debug then
                self:DrawDebug(cx, cy, cz, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, heading)
            end

            if not self.handle then goto continue end
            local dictName = self.handle.dictName
            local txtName  = self.handle.txtName
            if not dictName or not txtName then goto continue end

            local opacity = cfg.opacity or 0.8
            opacity = math.max(0.0, math.min(1.0, opacity))
            local alpha = math.floor(opacity * 255)

            -- Two-triangle quad (four DrawSpritePoly calls to cover the full rectangle).
            -- One (u, v, w) per vertex; x1 top-left, x2 top-right,
            -- x3 bottom-left, x4 bottom-right. Both windings are drawn.
            DrawSpritePoly(x1, y1, z1,  x3, y3, z3,  x2, y2, z2,
                255, 255, 255, alpha, dictName, txtName,
                0.0, 0.0, 1.0,  0.0, 1.0, 1.0,  1.0, 0.0, 1.0)
            DrawSpritePoly(x2, y2, z2,  x3, y3, z3,  x4, y4, z4,
                255, 255, 255, alpha, dictName, txtName,
                1.0, 0.0, 1.0,  0.0, 1.0, 1.0,  1.0, 1.0, 1.0)
            DrawSpritePoly(x2, y2, z2,  x3, y3, z3,  x1, y1, z1,
                255, 255, 255, alpha, dictName, txtName,
                1.0, 0.0, 1.0,  0.0, 1.0, 1.0,  0.0, 0.0, 1.0)
            DrawSpritePoly(x4, y4, z4,  x3, y3, z3,  x2, y2, z2,
                255, 255, 255, alpha, dictName, txtName,
                1.0, 1.0, 1.0,  0.0, 1.0, 1.0,  1.0, 0.0, 1.0)

            ::continue::
        end
    end)
end

-- Stop rendering and release the DUI handle.
function LogoDui:Destroy()
    if not self.running then return end
    self.running = false
    if self.handle and self.handle.remove then
        pcall(function() self.handle:remove() end)
    end
    self.handle = nil
    self.config = nil
end
