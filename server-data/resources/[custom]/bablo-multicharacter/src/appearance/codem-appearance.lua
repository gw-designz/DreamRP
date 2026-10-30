



local RESOURCE   = 'codem-appearance'
local CONFIG_KEY = 'codem-appearance'

local function activate()
    if Config.Appearance == CONFIG_KEY then return true end
    if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Appearance = CONFIG_KEY
    return true
end

local function register()
    if IsDuplicityVersion() then
        -- codem-appearance (mAppearance) stores the saved skin per-framework,
        -- exactly like the resources it replaces:
        --   ESX          -> `users`.skin        (raw skinchanger / flat format)
        --   QBCore/Qbox  -> `playerskins`.skin  (qb-clothing format) + `model` col
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
            if not ok or type(parsed) ~= 'table' then
                return nil
            end

            -- codem writes the QB `model` column as a ped hash (GetEntityModel);
            -- spawnPedForSlot accepts either a hash number or a name string. On
            -- ESX the flat skin carries `sex`, so fall back to the freemode ped.
            parsed.__model = separateModel
                          or parsed.model
                          or (parsed.sex == 1 and 'mp_f_freemode_01')
                          or (parsed.sex == 0 and 'mp_m_freemode_01')
                          or nil
            return parsed
        end
        return
    end

    -- Apply a saved skin to any ped — the selection-scene preview peds or the
    -- player. codem is skinchanger-based and honours a target ped argument:
    --   QB  -> `qb-clothing:client:loadPlayerClothing` converts the qb-format
    --          skin and calls skinchanger:loadSkin(..., ped)
    --   ESX -> the stored skin is already flat, so drive skinchanger directly
    function Appearance:Apply(ped, skin)
        if not skin then return end
        ped = ped or PlayerPedId()
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end

        if Config.Framework == 'esx' then
            local payload = {}
            for k, v in pairs(skin) do
                if k ~= '__model' then payload[k] = v end
            end
            TriggerEvent('skinchanger:loadSkin', payload, nil, ped)
            return
        end

        TriggerEvent('qb-clothing:client:loadPlayerClothing', skin, ped)
    end

    function Appearance:OpenEditor()
        if Config.Framework == 'esx' then
            TriggerEvent('esx_skin:openSaveableMenu', function() end, function() end)
            return
        end
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end

    -- codem exposes no synchronous "read current ped appearance" export and the
    -- multichar never consumes this value, so it's a no-op (as tgiann-clothing).
    function Appearance:GetCurrent(_ped, cb)
        cb(nil)
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
end)

