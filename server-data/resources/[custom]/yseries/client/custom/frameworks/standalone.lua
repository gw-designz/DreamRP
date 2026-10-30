CreateThread(function()
    if Config.Framework ~= "standalone" then
        return
    end

    while not NetworkIsSessionStarted() do
        Wait(500)
    end

    PlayerData = {}
    PlayerLicense = nil
    RegisterNetEvent('yseries:standalone:receive-player-ident')
    AddEventHandler('yseries:standalone:receive-player-ident', function(license)
        PlayerLicense = license
        debugPrint("Player License set to: " .. PlayerLicense)

        -- Now that PlayerLicense is set, you can use it
        PlayerData.identifier = PlayerLicense
        -- Perform any actions here that depend on PlayerData being set
    end)

    -- Function to request the player's identifier from the server
    local function requestPlayerIdentifier()
        TriggerServerEvent('yseries:standalone:request-player-ident')
    end

    -- Request the player's identifier
    requestPlayerIdentifier()

    function HasImeiIdentifier(phoneImei)
        return true
    end

    --- Returns whether the local player may use/open the phone (item gate).
    --- Generic checks live in `client/custom/uniquePhones/<inventory>.lua` as `HasAnyPhoneUseableItem` when using ox_inventory.
    ---@param phoneImei string|nil
    ---@return boolean
    function HasPhoneItem(phoneImei)
        if not Config.Item.Require then
            return true
        end

        if Config.Item.UniquePhones and phoneImei then
            return HasImeiIdentifier(phoneImei)
        end

        if HasAnyPhoneUseableItem then
            return HasAnyPhoneUseableItem()
        end

        return true
    end

    -- * Get company data based on the player's job and grade.
    function GetCompanyData(cb)
        cb {}
    end

    -- * Hire an employee.
    ---@param source number
    ---@return boolean
    function HireEmployee(source)
        return false
    end

    -- * Fire an employee.
    function FireEmployee(identifier)
        return false
    end

    -- * Promote/demote an employee.
    function SetGrade(identifier, newGrade)
        return false
    end

    -- * Toggle duty status.
    function ToggleDuty()
        return false
    end

    -- * Toggle duty status.
    function ToggleDuty()
        return false
    end

    -- * Send a notification to a player.
    function Notify(messageData)
        lib.notify(messageData)
    end
end)
