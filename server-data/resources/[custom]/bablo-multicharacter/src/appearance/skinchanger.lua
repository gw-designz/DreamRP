



local RESOURCE   = 'skinchanger'
local CONFIG_KEY = 'skinchanger'

local function activate()
    if Config.Appearance == CONFIG_KEY then return true end
    if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Appearance = CONFIG_KEY
    return true
end

local function normalise(weight, divisor)
    return ((tonumber(weight) or 0) / divisor) + 0.0
end

local function pick(skin, key, fallback)
    local v = skin[key]
    if v == nil then return fallback end
    return v
end

local function applyHead(ped, skin)
    local face_weight  = normalise(pick(skin, 'face_md_weight', 0), 100)
    local skin_weight  = normalise(pick(skin, 'skin_md_weight', 0), 100)
    local third_weight = normalise(pick(skin, 'face_g_weight',  0), 100)
    local mom          = pick(skin, 'mom', 0)
    local dad          = pick(skin, 'dad', 0)
    local grand        = pick(skin, 'grandparents', 0)

    SetPedHeadBlendData(
        ped,
        mom, dad, grand,
        mom, dad, grand,
        face_weight, skin_weight, third_weight,
        false
    )
end

local function applyFace(ped, skin)
    local features = {
        'nose_1', 'nose_2', 'nose_3', 'nose_4', 'nose_5', 'nose_6',
        'eyebrows_5', 'eyebrows_6',
        'cheeks_1', 'cheeks_2', 'cheeks_3',
        'eye_squint',
        'lip_thickness',
        'jaw_1', 'jaw_2',
        'chin_1', 'chin_2', 'chin_3', 'chin_4',
        'neck_thickness',
    }
    for i = 1, #features do
        SetPedFaceFeature(ped, i - 1, normalise(pick(skin, features[i], 0), 10))
    end
    SetPedEyeColor(ped, pick(skin, 'eye_color', 0))
end

local function applyHeadOverlay(ped, skin)
    local features = {
        { 'blemishes_1',  'blemishes_2' },
        { 'beard_1',      'beard_2' },
        { 'eyebrows_1',   'eyebrows_2' },
        { 'age_1',        'age_2' },
        { 'makeup_1',     'makeup_2' },
        { 'blush_1',      'blush_2' },
        { 'complexion_1', 'complexion_2' },
        { 'sun_1',        'sun_2' },
        { 'lipstick_1',   'lipstick_2' },
        { 'moles_1',      'moles_2' },
        { 'chest_1',      'chest_2' },
    }
    for i = 1, #features do
        local f = features[i]
        SetPedHeadOverlay(ped, i - 1, pick(skin, f[1], 0), normalise(pick(skin, f[2], 0), 10))
    end
end

local function applyHeadOverlayColour(ped, skin)
    local features = {
        [1]  = { 'beard_3',     'beard_4'    },
        [2]  = { 'eyebrows_3',  'eyebrows_4' },
        [4]  = { 'makeup_3',    'makeup_4'   },
        [5]  = { 'blush_3',     0            },
        [8]  = { 'lipstick_3',  'lipstick_4' },
        [10] = { 'chest_3',     0            },
    }
    for idx, f in pairs(features) do
        local secondary = type(f[2]) == 'number' and f[2] or pick(skin, f[2], 0)
        SetPedHeadOverlayColor(ped, idx, 1, pick(skin, f[1], 0), secondary)
    end

    local bb1 = pick(skin, 'bodyb_1', -1)
    SetPedHeadOverlay(ped, 11, bb1 == -1 and 255 or bb1, normalise(pick(skin, 'bodyb_2', 0), 10))
    local bb3 = pick(skin, 'bodyb_3', -1)
    SetPedHeadOverlay(ped, 12, bb3 == -1 and 255 or bb3, normalise(pick(skin, 'bodyb_4', 0), 10))
end

local function applyHair(ped, skin)
    SetPedComponentVariation(ped, 2, pick(skin, 'hair_1', 0), pick(skin, 'hair_2', 0), 2)
    SetPedHairColor(ped, pick(skin, 'hair_color_1', 0), pick(skin, 'hair_color_2', 0))
end

local function applyComponents(ped, skin)
    local components = {
        { 'tshirt_1',  'tshirt_2',  8  },
        { 'torso_1',   'torso_2',   11 },
        { 'decals_1',  'decals_2',  10 },
        { 'arms',      'arms_2',    3  },
        { 'pants_1',   'pants_2',   4  },
        { 'shoes_1',   'shoes_2',   6  },
        { 'mask_1',    'mask_2',    1  },
        { 'bproof_1',  'bproof_2',  9  },
        { 'chain_1',   'chain_2',   7  },
        { 'bags_1',    'bags_2',    5  },
    }
    for i = 1, #components do
        local c = components[i]
        SetPedComponentVariation(ped, c[3], pick(skin, c[1], 0), pick(skin, c[2], 0), 2)
    end
end

local function applyProps(ped, skin)
    local props = {
        { 'helmet_1',    'helmet_2',    0 },
        { 'glasses_1',   'glasses_2',   1 },
        { 'ears_1',      'ears_2',      2 },
        { 'watches_1',   'watches_2',   6 },
        { 'bracelets_1', 'bracelets_2', 7 },
    }
    for i = 1, #props do
        local p = props[i]
        local drawable = pick(skin, p[1], -1)
        if drawable == -1 then
            ClearPedProp(ped, p[3])
        else
            SetPedPropIndex(ped, p[3], drawable, pick(skin, p[2], 0), true)
        end
    end
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Appearance/skinchanger] registering SERVER methods')

        function Appearance:FetchSkin(identifier)
            if not identifier then return nil end

            local rows = MySQL.query.await(
                'SELECT `skin` FROM `users` WHERE `identifier` = ?',
                { identifier }
            )

            if not rows or not rows[1] or not rows[1].skin then return nil end

            local ok, parsed = pcall(json.decode, rows[1].skin or '')
            if not ok or type(parsed) ~= 'table' then
                Trace(('[Appearance/skinchanger] FetchSkin — JSON decode failed: %s'):format(tostring(parsed)))
                return nil
            end

            return parsed
        end
        return
    end

    Trace('[Appearance/skinchanger] registering CLIENT methods')

    function Appearance:Apply(ped, skin)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end
        if not skin then return end

        if ped == PlayerPedId() then
            TriggerEvent('skinchanger:loadSkin', skin)
            return
        end

        applyHead(ped, skin)
        applyHair(ped, skin)
        applyFace(ped, skin)
        applyHeadOverlay(ped, skin)
        applyHeadOverlayColour(ped, skin)
        applyComponents(ped, skin)
        applyProps(ped, skin)
    end

    function Appearance:OpenEditor()
        TriggerEvent('esx_skin:openSaveableMenu', function() end)
    end

    function Appearance:GetCurrent(ped, cb)
        local skin
        local ok = pcall(function()
            skin = exports.skinchanger:GetSkin()
        end)
        if not ok then
            Trace('[Appearance/skinchanger] GetCurrent — skinchanger export unavailable')
        end
        cb(skin)
    end
end

if activate() then
    register()
    return
end

if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then
    return
end

CreateThread(function()
    local deadline = GetGameTimer() + 10000
    while GetGameTimer() < deadline do
        Wait(100)
        if activate() then
            register()
            return
        end
        if Config.Appearance ~= 'auto' and Config.Appearance ~= nil
           and Config.Appearance ~= CONFIG_KEY then
            return
        end
    end
    Trace('[Appearance/skinchanger] resource not started after 10s — giving up')
end)

