



local RESOURCE   = 'crm-appearance'
local CONFIG_KEY = 'crm-appearance'

local function activate()
    if Config.Appearance == CONFIG_KEY then return true end
    if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Appearance = CONFIG_KEY
    return true
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Appearance/crm-appearance] registering SERVER methods')

        function Appearance:FetchSkin(characterId)
            if not characterId then return nil end

            local rawSkin, separateModel

            if Config.Framework == 'esx' then
                rawSkin = MySQL.scalar.await(
                    'SELECT `skin` FROM `users` WHERE `identifier` = ?',
                    { characterId }
                )
            else
                local rows = MySQL.query.await(
                    'SELECT `model`, `skin` FROM `playerskins` WHERE `citizenid` = ? AND `active` = 1',
                    { characterId }
                )
                if rows and rows[1] then
                    rawSkin       = rows[1].skin
                    separateModel = rows[1].model
                end
            end

            if not rawSkin or rawSkin == '' then return nil end

            local ok, parsed = pcall(json.decode, rawSkin)
            if not ok or type(parsed) ~= 'table' then return nil end

            parsed.__model = separateModel
                          or parsed.model
                          or (parsed.sex == 1 and 'mp_f_freemode_01')
                          or (parsed.sex == 0 and 'mp_m_freemode_01')
                          or nil
            return parsed
        end
        return
    end

    Trace('[Appearance/crm-appearance] registering CLIENT methods')

    function Appearance:Apply(ped, skin)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end
        if not skin then return end

        local payload = {}
        for k, v in pairs(skin) do
            if k ~= '__model' then payload[k] = v end
        end

        local ok, err = pcall(function()
            exports['crm-appearance']:crm_set_ped_appearance(ped, payload)
        end)
        if not ok then
            Trace(('[Appearance/crm-appearance] Apply — crm_set_ped_appearance export failed: %s'):format(tostring(err)))
        end
    end

    function Appearance:OpenEditor()
        local ok, err = pcall(function()
            TriggerEvent('crm-appearance:show-creator-menu')
        end)
        if not ok then
            Trace(('[Appearance/crm-appearance] OpenEditor — show-creator-menu event failed: %s'):format(tostring(err)))
        end
    end

    function Appearance:GetCurrent(ped, cb)
        local skin
        local ok = pcall(function()
            skin = exports['crm-appearance']:crm_get_ped_appearance(ped or PlayerPedId())
        end)
        if not ok then
            Trace('[Appearance/crm-appearance] GetCurrent — crm_get_ped_appearance export unavailable')
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
    Trace('[Appearance/crm-appearance] resource not started after 10s — giving up')
end)

