



local RESOURCE   = 'tgiann-clothing'
local CONFIG_KEY = 'tgiann-clothing'

local function activate()
    if Config.Appearance == CONFIG_KEY then return true end
    if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Appearance = CONFIG_KEY
    return true
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Appearance/tgiann-clothing] registering SERVER methods')

        function Appearance:FetchSkin(characterId)
            if not characterId then return nil end

            local row = MySQL.single.await(
                'SELECT `model`, `skin` FROM `tgiann_skin` WHERE `citizenid` = ? LIMIT 1',
                { characterId }
            )

            if not row or not row.skin or row.skin == '' then return nil end

            local ok, parsed = pcall(json.decode, row.skin)
            if not ok or type(parsed) ~= 'table' then return nil end

            parsed.__model = row.model
                          or parsed.model
                          or (parsed.sex == 1 and 'mp_f_freemode_01')
                          or (parsed.sex == 0 and 'mp_m_freemode_01')
                          or nil
            return parsed
        end
        return
    end

    Trace('[Appearance/tgiann-clothing] registering CLIENT methods')

    function Appearance:Apply(ped, skin)
        if not skin then return end
        TriggerEvent('qb-clothing:client:loadPlayerClothing', skin, ped or PlayerPedId())
    end

    function Appearance:OpenEditor()
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end

    function Appearance:GetCurrent(_ped, cb)
        cb(nil)
    end
end

if activate() then
    register()
    return
end

if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return end

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
    Trace('[Appearance/tgiann-clothing] resource not started after 10s — giving up')
end)

