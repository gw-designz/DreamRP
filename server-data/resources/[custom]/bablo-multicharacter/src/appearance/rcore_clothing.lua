



local RESOURCE   = 'rcore_clothing'
local CONFIG_KEY = 'rcore_clothing'

local function activate()
    if Config.Appearance == CONFIG_KEY then return true end
    if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Appearance = CONFIG_KEY
    return true
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Appearance/rcore_clothing] registering SERVER methods')

        function Appearance:FetchSkin(characterId)
            if not characterId then return nil end

            local skin
            local ok, err = pcall(function()
                skin = exports['rcore_clothing']:getSkinByIdentifier(characterId)
            end)
            if not ok then
                Trace(('[Appearance/rcore_clothing] FetchSkin — getSkinByIdentifier export failed: %s'):format(tostring(err)))
                return nil
            end

            if not skin or (type(skin) == 'table' and next(skin) == nil) then
                return nil
            end

            if type(skin) ~= 'table' then
                local okJson, decoded = pcall(json.decode, tostring(skin))
                if not okJson or type(decoded) ~= 'table' then
                    return nil
                end
                skin = decoded
            end

            local innerSex = type(skin.skin) == 'table' and skin.skin.sex
            skin.__model = skin.ped_model
                        or skin.model
                        or (type(skin.skin) == 'table' and skin.skin.ped_model)
                        or (type(skin.skin) == 'table' and skin.skin.model)
                        or (innerSex == 1 and 'mp_f_freemode_01')
                        or (innerSex == 0 and 'mp_m_freemode_01')
                        or (skin.sex == 1 and 'mp_f_freemode_01')
                        or (skin.sex == 0 and 'mp_m_freemode_01')
                        or nil
            return skin
        end
        return
    end

    Trace('[Appearance/rcore_clothing] registering CLIENT methods')

    function Appearance:Apply(ped, skin)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end
        if not skin then return end

        local payload = {}
        for k, v in pairs(skin) do
            if k ~= '__model' then payload[k] = v end
        end

        local ok, err = pcall(function()
            exports['rcore_clothing']:setPedSkin(ped, payload)
        end)
        if not ok then
            Trace(('[Appearance/rcore_clothing] Apply — setPedSkin export failed: %s'):format(tostring(err)))
        end
    end

    function Appearance:OpenEditor()
        local ok, err = pcall(function()
            TriggerEvent('rcore_clothing:openCharCreator')
        end)
        if not ok then
            Trace(('[Appearance/rcore_clothing] OpenEditor — openCharCreator event failed: %s'):format(tostring(err)))
        end
    end

    function Appearance:GetCurrent(ped, cb)
        local skin
        local ok = pcall(function()
            skin = exports['rcore_clothing']:getPlayerSkin(true)
        end)
        if not ok then
            Trace('[Appearance/rcore_clothing] GetCurrent — getPlayerSkin export unavailable')
        end
        cb(skin)
    end

    local function toHash(m)
        if type(m) == 'number' then return m end
        if type(m) == 'string' and m ~= '' then
            return tonumber(m) or GetHashKey(m)
        end
        return nil
    end

    local function skinBody(skin)
        if type(skin) ~= 'table' then return nil end
        if type(skin.skin) == 'table' then return skin.skin end
        return skin
    end

    -- The exact ped model the character was saved with. rcore stores this in the
    -- skin itself (`model` — a name string OR a hash number, e.g. mp_f_freemode_01
    -- = 225514697) and the multichar merges the QB `playerskins.model` column into
    -- __model. When it's present + valid we apply it verbatim: this is the
    -- authoritative source and covers male, female AND custom peds in one shot.
    local function resolveModel(skin)
        local body = skinBody(skin)
        local raw = (body and (body.model or body.ped_model))
            or (type(skin) == 'table' and (skin.__model or skin.model or skin.ped_model))
        local h = toHash(raw)
        if h and IsModelInCdimage(h) and IsModelValid(h) then
            return h
        end
        return nil
    end

    -- Fallback when the skin carries no usable model: pick the matching freemode
    -- ped from the gender. Prefer the skin's own `sex` (0 = male, 1 = female —
    -- present on ESX/rcore skins), then the framework's charinfo.gender (QB/Qbox),
    -- polled briefly in case it lags on relog.
    local function resolveFemale(skin)
        local body = skinBody(skin)
        if body then
            local sex = body.sex
            if sex == 1 or sex == '1' or sex == 'f' or sex == 'F' then return true end
            if sex == 0 or sex == '0' or sex == 'm' or sex == 'M' then return false end
        end

        local pd
        local deadline = GetGameTimer() + 4000
        while GetGameTimer() < deadline do
            if GetResourceState('qbx_core') == 'started' then
                pcall(function() pd = exports.qbx_core:GetPlayerData() end)
            elseif GetResourceState('qb-core') == 'started' then
                pcall(function() pd = exports['qb-core']:GetCoreObject().Functions.GetPlayerData() end)
            end
            if pd and pd.charinfo and pd.charinfo.gender ~= nil then break end
            Wait(100)
        end

        local g = pd and pd.charinfo and pd.charinfo.gender
        Trace(('[Appearance/rcore_clothing] resolveFemale charinfo.gender raw=%s (%s)'):format(tostring(g), type(g)))
        return (g == 1 or g == '1' or g == 1.0
            or g == 'f' or g == 'F' or g == 'female' or g == 'Female' or g == 'FEMALE')
    end

    local function ensureFreemodePlayer()
        local skin
        pcall(function() skin = exports['rcore_clothing']:getPlayerSkin(true) end)

        local target  = resolveModel(skin)
        local viaModel = target ~= nil
        if not target then
            target = resolveFemale(skin) and `mp_f_freemode_01` or `mp_m_freemode_01`
        end

        if GetEntityModel(PlayerPedId()) == target then return end

        RequestModel(target)
        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(target) and GetGameTimer() < deadline do Wait(0) end
        if not HasModelLoaded(target) then
            Trace('[Appearance/rcore_clothing] ensureFreemodePlayer — model failed to load')
            return
        end

        SetPlayerModel(PlayerId(), target)
        SetModelAsNoLongerNeeded(target)
        SetPedDefaultComponentVariation(PlayerPedId())

        if type(skin) ~= 'table' then
            pcall(function() skin = exports['rcore_clothing']:getPlayerSkin(true) end)
        end
        if type(skin) == 'table' then
            pcall(function() exports['rcore_clothing']:setPedSkin(PlayerPedId(), skin) end)
        end
        Trace(('[Appearance/rcore_clothing] applied %s ped after spawn (model=%s)')
            :format(viaModel and 'saved-model' or 'gender-freemode', tostring(target)))
    end

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        CreateThread(function() Wait(750) ensureFreemodePlayer() end)
    end)
    RegisterNetEvent('esx:playerLoaded', function()
        CreateThread(function() Wait(750) ensureFreemodePlayer() end)
    end)
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
    Trace('[Appearance/rcore_clothing] resource not started after 10s — giving up')
end)

