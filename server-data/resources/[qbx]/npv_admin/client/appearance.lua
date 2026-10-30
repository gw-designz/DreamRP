-- Appearance for freemode peds (mp_m_freemode_01 / mp_f_freemode_01): heritage, face, hair, eyes,
-- head overlays, clothing components and props. Slot ids follow the RAGE wiki "Clothes" page:
--   components 0 Head, 1 Masks, 2 Hair, 3 Torsos, 4 Legs, 5 Bags, 6 Shoes, 7 Accessories,
--              8 Undershirts, 9 Body armor, 10 Decals, 11 Tops
--   props      0 Hats, 1 Glasses, 2 Ears, 6 Watches, 7 Bracelets
--
-- Shape of an appearance table (all keys optional; missing values use defaults):
--   blend    = { s1, s2, k1, k2, sm, km }       shape/skin parents 0-45, mix 0.0-1.0
--   face     = { 20 numbers -1.0 .. 1.0 }       in the order of FACE_FEATURES below
--   overlays = { ["0".."11"] = { i = style (255 = none), o = opacity, c = colour, c2 = second colour } }
--   hair     = { s = style, t = texture, c = colour, h = highlight }
--   eye      = 0-31
--   comps    = { ["1"|"3".."11"] = { d = drawable, t = texture } }
--   props    = { ["0"|"1"|"2"|"6"|"7"] = { d = drawable (-1 = none), t = texture } }
--   autoTorso = true to let the game pick the torso (arms) that matches the top / undershirt

Appearance = {}

local MALE, FEMALE = joaat('mp_m_freemode_01'), joaat('mp_f_freemode_01')

-- overlay id -> colour type for SetPedHeadOverlayColor (1 = hair colours, 2 = makeup colours)
local OVERLAY_COLOR_TYPE = { [1] = 1, [2] = 1, [10] = 1, [4] = 2, [5] = 2, [8] = 2 }
local COMPONENTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 } -- hair (2) is handled with the hair colour
local PROPS = { 0, 1, 2, 6, 7 }

function Appearance.IsFreemodeName(name)
    return name == 'mp_m_freemode_01' or name == 'mp_f_freemode_01'
end

function Appearance.IsFreemode(ped)
    local m = GetEntityModel(ped)
    return m == MALE or m == FEMALE
end

local function f(v, default) return ((tonumber(v) or default or 0) + 0.0) end
local function i(v, default) return math.floor(tonumber(v) or default or 0) end

---Ask the game which torso (arms) the current top / undershirt wants. Falls back to the bare torso (15).
function Appearance.FitTorso(ped)
    local torso
    for _, comp in ipairs({ 8, 11 }) do -- undershirt first, the top overrides it
        local d, t = GetPedDrawableVariation(ped, comp), GetPedTextureVariation(ped, comp)
        local hash = GetHashNameForComponent(ped, comp, d, t)
        if hash and hash ~= 0 then
            for n = 0, GetShopPedApparelForcedComponentCount(hash) - 1 do
                local _, enumValue, componentType = GetForcedComponent(hash, n)
                if componentType == 3 then torso = enumValue end
            end
        end
    end
    SetPedComponentVariation(ped, 3, torso or 15, 0, 0)
    return torso
end

---Apply an appearance to a freemode ped. Call it from a thread (it waits for the head blend).
function Appearance.Apply(ped, a)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not Appearance.IsFreemode(ped) then return end
    a = type(a) == 'table' and a or {}

    SetPedDefaultComponentVariation(ped)
    local b = a.blend or {}
    SetPedHeadBlendData(ped, i(b.s1), i(b.s2), 0, i(b.k1), i(b.k2), 0, f(b.sm, 0.5), f(b.km, 0.5), 0.0, false)
    local waited = 0
    while not HasPedHeadBlendFinished(ped) and waited < 1500 do Wait(0) waited = waited + 16 end

    local face = a.face or {}
    for n = 1, 20 do SetPedFaceFeature(ped, n - 1, f(face[n], 0.0)) end

    for id = 0, 11 do
        local o = a.overlays and a.overlays[tostring(id)]
        if o then
            SetPedHeadOverlay(ped, id, i(o.i, 255), f(o.o, 1.0))
            local colorType = OVERLAY_COLOR_TYPE[id]
            if colorType then SetPedHeadOverlayColor(ped, id, colorType, i(o.c), i(o.c2)) end
        else
            SetPedHeadOverlay(ped, id, 255, 0.0)
        end
    end

    local h = a.hair or {}
    SetPedComponentVariation(ped, 2, i(h.s), i(h.t), 0)
    SetPedHairColor(ped, i(h.c), i(h.h))
    SetPedEyeColor(ped, i(a.eye))

    for _, comp in ipairs(COMPONENTS) do
        local v = a.comps and a.comps[tostring(comp)]
        if v then SetPedComponentVariation(ped, comp, i(v.d), i(v.t), 0) end
    end
    if a.autoTorso ~= false then Appearance.FitTorso(ped) end

    for _, prop in ipairs(PROPS) do
        local v = a.props and a.props[tostring(prop)]
        if v and i(v.d, -1) >= 0 then SetPedPropIndex(ped, prop, i(v.d), i(v.t), true)
        else ClearPedProp(ped, prop) end
    end
end

---Read the current look of a freemode ped into the appearance format.
function Appearance.Read(ped)
    if not Appearance.IsFreemode(ped) then return nil end
    local s1, s2, _, k1, k2, _, sm, km = Citizen.InvokeNative(0x2746BD9D88C5C5D0, ped,
        Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
        Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
        Citizen.PointerValueFloatInitialized(0), Citizen.PointerValueFloatInitialized(0), Citizen.PointerValueFloatInitialized(0))
    local app = {
        blend = { s1 = s1 or 0, s2 = s2 or 0, k1 = k1 or 0, k2 = k2 or 0, sm = math.min(1.0, math.floor((sm or 0.5) * 100) / 100), km = math.min(1.0, math.floor((km or 0.5) * 100) / 100) },
        face = {}, overlays = {}, comps = {}, props = {}, autoTorso = false,
    }
    for n = 0, 19 do app.face[n + 1] = math.floor(GetPedFaceFeature(ped, n) * 100) / 100 end
    for id = 0, 11 do
        local _, value, _, c1, c2, opacity = GetPedHeadOverlayData(ped, id)
        app.overlays[tostring(id)] = { i = value or 255, o = math.floor((opacity or 1.0) * 100) / 100, c = c1 or 0, c2 = c2 or 0 }
    end
    app.hair = { s = GetPedDrawableVariation(ped, 2), t = GetPedTextureVariation(ped, 2), c = GetPedHairColor(ped), h = GetPedHairHighlightColor(ped) }
    app.eye = GetPedEyeColor(ped)
    for _, comp in ipairs(COMPONENTS) do
        app.comps[tostring(comp)] = { d = GetPedDrawableVariation(ped, comp), t = GetPedTextureVariation(ped, comp) }
    end
    for _, prop in ipairs(PROPS) do
        app.props[tostring(prop)] = { d = GetPedPropIndex(ped, prop), t = math.max(0, GetPedPropTextureIndex(ped, prop)) }
    end
    return app
end

-- ---- helpers for the DM tool UI -----------------------------------------------------------------
-- A hidden, frozen ped per model is used to read counts (drawables, textures, overlays) and to ask the
-- game which torso fits a top. They are removed when the menu closes.
local tempPeds = {}

local function tempPed(model)
    local existing = tempPeds[model]
    if existing and DoesEntityExist(existing) then return existing end
    if type(model) ~= 'string' or not Appearance.IsFreemodeName(model) then return nil end
    local hash = joaat(model)
    if not lib.requestModel(hash, 5000) then return nil end
    local ped = CreatePed(4, hash, 0.0, 0.0, -100.0, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if ped == 0 then return nil end
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    tempPeds[model] = ped
    return ped
end

local function clearTemp()
    for model, ped in pairs(tempPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
        tempPeds[model] = nil
    end
end
AddEventHandler('npv_admin:client:closed', clearTemp)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then clearTemp() end end)

local Calls = Nui.ClientCalls

---Item counts for a model: how many drawables each slot has, overlay styles, colours.
Calls['appearance.info'] = function(p)
    local ped = tempPed(p.model)
    if not ped then return { error = 'not_freemode' } end
    local info = { drawables = {}, props = {}, overlays = {} }
    for comp = 0, 11 do info.drawables[tostring(comp)] = GetNumberOfPedDrawableVariations(ped, comp) end
    for _, prop in ipairs(PROPS) do info.props[tostring(prop)] = GetNumberOfPedPropDrawableVariations(ped, prop) end
    for id = 0, 11 do info.overlays[tostring(id)] = GetPedHeadOverlayNum(id) end
    info.hairColors = GetNumHairColors()
    info.makeupColors = GetNumMakeupColors()
    return info
end

---Texture count for one drawable of a component or prop.
Calls['appearance.textures'] = function(p)
    local ped = tempPed(p.model)
    if not ped then return 1 end
    local slot, drawable = i(p.slot), i(p.drawable)
    if p.kind == 'prop' then return math.max(1, GetNumberOfPedPropTextureVariations(ped, slot, drawable)) end
    return math.max(1, GetNumberOfPedTextureVariations(ped, slot, drawable))
end

---Which torso does the game want for this top / undershirt? Returns { torso = drawable | nil }.
Calls['appearance.forced'] = function(p)
    local ped = tempPed(p.model)
    if not ped then return {} end
    SetPedComponentVariation(ped, i(p.comp), i(p.drawable), i(p.texture), 0)
    local d, t = GetPedDrawableVariation(ped, i(p.comp)), GetPedTextureVariation(ped, i(p.comp))
    local hash = GetHashNameForComponent(ped, i(p.comp), d, t)
    local torso
    if hash and hash ~= 0 then
        for n = 0, GetShopPedApparelForcedComponentCount(hash) - 1 do
            local _, enumValue, componentType = GetForcedComponent(hash, n)
            if componentType == 3 then torso = enumValue end
        end
    end
    return { torso = torso }
end

Calls['appearance.mine'] = function()
    local app = Appearance.Read(PlayerPedId())
    if not app then return { error = 'not_freemode' } end
    return { appearance = app, model = GetEntityModel(PlayerPedId()) == MALE and 'mp_m_freemode_01' or 'mp_f_freemode_01' }
end

Calls['appearance.nearby'] = function()
    local me = PlayerPedId()
    local c = GetEntityCoords(me)
    local best, bestD
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= me and Appearance.IsFreemode(ped) then
            local d = #(GetEntityCoords(ped) - c)
            if d < 12.0 and (not bestD or d < bestD) then best, bestD = ped, d end
        end
    end
    if not best then return { error = 'none_nearby' } end
    return { appearance = Appearance.Read(best), model = GetEntityModel(best) == MALE and 'mp_m_freemode_01' or 'mp_f_freemode_01' }
end

-- ---- camera on the preview ped (drag to rotate, wheel to zoom) -----------------------------------------
local cam, camState
local FOCUS = { face = { dist = 0.9, z = 0.62 }, body = { dist = 2.7, z = 0.1 } }

local function destroyCam()
    if cam then
        RenderScriptCams(false, true, 300, true, false)
        DestroyCam(cam, false)
        cam = nil
    end
    camState = nil
end
AddEventHandler('npv_admin:client:closed', destroyCam)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then destroyCam() end end)

local function aimCam()
    local ped = camState and Editor.Preview(camState.id)
    if not ped or not DoesEntityExist(ped) then return end
    local c = GetEntityCoords(ped)
    local f = FOCUS[camState.focus] or FOCUS.body
    -- The ped faces its heading; the camera starts in front of it and orbits by camState.angle.
    local ang = math.rad(GetEntityHeading(ped) + camState.angle)
    local dist = f.dist * camState.zoom
    SetCamCoord(cam, c.x - math.sin(ang) * dist, c.y + math.cos(ang) * dist, c.z + f.z)
    PointCamAtCoord(cam, c.x, c.y, c.z + f.z - 0.05)
end

---{ on = false } closes it. Otherwise: id (the NPC's object id), focus ('face' | 'body'), dx (drag), zoom (+1 out / -1 in).
Calls['appearance.camera'] = function(p)
    if p.on == false then destroyCam() return true end
    if not cam then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        camState = { id = p.id, focus = p.focus or 'body', angle = 0.0, zoom = 1.0 }
        aimCam()
        SetCamActive(cam, true)
        RenderScriptCams(true, true, 400, true, false)
        CreateThread(function()
            while cam do
                aimCam()
                Wait(0)
            end
        end)
    end
    if not camState then return true end
    if p.id then camState.id = p.id end
    if p.focus then camState.focus = p.focus end
    if p.dx then camState.angle = (camState.angle + p.dx * 0.5) % 360.0 end
    if p.zoom then camState.zoom = math.max(0.5, math.min(2.0, camState.zoom * (1.0 + p.zoom * 0.1))) end
    return true
end
