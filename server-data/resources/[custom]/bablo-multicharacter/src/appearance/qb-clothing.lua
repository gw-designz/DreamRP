



local RESOURCE   = 'qb-clothing'
local CONFIG_KEY = 'qb-clothing'

local function activate()
    if Config.Appearance == CONFIG_KEY then return true end
    if Config.Appearance ~= 'auto' and Config.Appearance ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Appearance = CONFIG_KEY
    return true
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Appearance/qb-clothing] registering SERVER methods')

        function Appearance:FetchSkin(citizenid)
            if not citizenid then return nil end

            local rows = MySQL.query.await(
                'SELECT `model`, `skin` FROM `playerskins` WHERE `citizenid` = ? AND `active` = 1',
                { citizenid }
            )

            if not rows or not rows[1] then return nil end

            local ok, parsed = pcall(json.decode, rows[1].skin or '')
            if not ok or type(parsed) ~= 'table' then
                Trace(('[Appearance/qb-clothing] FetchSkin — JSON decode failed: %s'):format(tostring(parsed)))
                return nil
            end

            parsed.__model = rows[1].model
            return parsed
        end
        return
    end

    Trace('[Appearance/qb-clothing] registering CLIENT methods')

    function Appearance:Apply(ped, skin)
        if not skin then return end
        TriggerEvent('qb-clothing:client:loadPlayerClothing', skin, ped or PlayerPedId())
    end

    function Appearance:OpenEditor()
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end

    function Appearance:GetCurrent(ped, cb)
        local result
        TriggerEvent('qb-clothing:client:getPlayerClothing', function(data)
            result = data
        end, ped)

        local deadline = GetGameTimer() + 1000
        while not result and GetGameTimer() < deadline do
            Wait(0)
        end

        cb(result)
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
    Trace('[Appearance/qb-clothing] resource not started after 10s — giving up')
end)

