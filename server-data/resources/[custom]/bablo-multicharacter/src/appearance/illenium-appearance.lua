



local RESOURCE   = 'illenium-appearance'
local CONFIG_KEY = 'illenium-appearance'

local function activate()
    if Config.Appearance == CONFIG_KEY then return true end
    if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Appearance = CONFIG_KEY
    return true
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Appearance/illenium-appearance] registering SERVER methods')

        function Appearance:FetchSkin(characterId)
            Trace(('[Appearance/illenium-appearance] FetchSkin called id=%s framework=%s'):format(
                tostring(characterId), tostring(Config.Framework)
            ))

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

            if not rawSkin or rawSkin == '' then
                Trace(('[Appearance/illenium-appearance] FetchSkin — no skin row for id=%s'):format(tostring(characterId)))
                return nil
            end

            local ok, parsed = pcall(json.decode, rawSkin)
            if not ok or type(parsed) ~= 'table' then
                Trace(('[Appearance/illenium-appearance] FetchSkin — JSON decode failed: %s'):format(tostring(parsed)))
                return nil
            end

            parsed.__model = separateModel
                          or parsed.model
                          or (type(parsed.skin) == 'table' and parsed.skin.model)
                          or (parsed.sex == 1 and 'mp_f_freemode_01')
                          or (parsed.sex == 0 and 'mp_m_freemode_01')
                          or nil

            if not parsed.__model then
                local keys = {}
                for k in pairs(parsed) do keys[#keys + 1] = tostring(k) end
                Trace(('[Appearance/illenium-appearance] FetchSkin — id=%s parsed.model is nil, top-level keys: [%s]'):format(
                    tostring(characterId),
                    table.concat(keys, ', ')
                ))
            end

            Trace(('[Appearance/illenium-appearance] FetchSkin — skin returned, __model=%s'):format(tostring(parsed.__model)))
            return parsed
        end
        return
    end

    Trace('[Appearance/illenium-appearance] registering CLIENT methods')

    function Appearance:Apply(ped, skin)
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end
        if not skin then return end

        local payload = {}
        for k, v in pairs(skin) do
            if k ~= '__model' then payload[k] = v end
        end

        local ok, err = pcall(function()
            exports['illenium-appearance']:setPedAppearance(ped, payload)
        end)
        if not ok then
            Trace(('[Appearance/illenium-appearance] Apply — setPedAppearance export failed: %s'):format(tostring(err)))
        end
    end

    function Appearance:OpenEditor()
        if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
            TriggerEvent('qb-clothes:client:CreateFirstCharacter')
            return
        end
        if Config.Framework == 'esx' then
            TriggerEvent('esx_skin:openSaveableMenu', function() end, function() end)
            return
        end
        local ok, err = pcall(function()
            exports['illenium-appearance']:startPlayerCustomization(function(_) end)
        end)
        if not ok then
            Trace(('[Appearance/illenium-appearance] OpenEditor — startPlayerCustomization export failed: %s'):format(tostring(err)))
        end
    end

    function Appearance:GetCurrent(ped, cb)
        local skin
        local ok = pcall(function()
            skin = exports['illenium-appearance']:getPedAppearance(ped or PlayerPedId())
        end)
        if not ok then
            Trace('[Appearance/illenium-appearance] GetCurrent — getPedAppearance export unavailable')
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
    Trace('[Appearance/illenium-appearance] resource not started after 10s — giving up')
end)

