



local RESOURCE   = 'bl_appearance'
local CONFIG_KEY = 'bl_appearance'

local function activate()
    if Config.Appearance == CONFIG_KEY then return true end
    if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Appearance = CONFIG_KEY
    return true
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Appearance/bl_appearance] registering SERVER methods')

        function Appearance:FetchSkin(characterId)
            if not characterId then return nil end

            local skin
            local ok, err = pcall(function()
                skin = exports.bl_appearance:GetPlayerAppearance(characterId)
            end)
            if not ok then
                Trace(('[Appearance/bl_appearance] FetchSkin — GetPlayerAppearance export failed: %s'):format(tostring(err)))
                return nil
            end

            if not skin or (type(skin) == 'table' and next(skin) == nil) then
                return nil
            end

            if type(skin) ~= 'table' then
                local okJson, decoded = pcall(json.decode, tostring(skin))
                if not okJson or type(decoded) ~= 'table' then return nil end
                skin = decoded
            end

            skin.__model = skin.model
                        or (type(skin.skin) == 'table' and skin.skin.model)
                        or nil

            if type(skin.__model) == 'number' then
                skin.__model = skin.__model
            end
            return skin
        end
        return
    end

    Trace('[Appearance/bl_appearance] registering CLIENT methods')

    function Appearance:Apply(ped, skin)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end
        if not skin then return end

        local payload = {}
        for k, v in pairs(skin) do
            if k ~= '__model' then payload[k] = v end
        end

        local ok, err = pcall(function()
            exports.bl_appearance:SetPedAppearance(ped, payload)
        end)
        if not ok then
            Trace(('[Appearance/bl_appearance] Apply — SetPedAppearance export failed: %s'):format(tostring(err)))
        end
    end

    function Appearance:OpenEditor()
        local ok, err = pcall(function()
            exports.bl_appearance:InitialCreation(function() end)
        end)
        if not ok then
            Trace(('[Appearance/bl_appearance] OpenEditor — InitialCreation export failed: %s'):format(tostring(err)))
        end
    end

    function Appearance:GetCurrent(ped, cb)
        local skin
        local ok = pcall(function()
            skin = exports.bl_appearance:GetPedAppearance(ped or PlayerPedId())
        end)
        if not ok then
            Trace('[Appearance/bl_appearance] GetCurrent — GetPedAppearance export unavailable')
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
    Trace('[Appearance/bl_appearance] resource not started after 10s — giving up')
end)

