if Config.Banking ~= 'esx_addonaccount' then return end


---@param society string The society that the money will be added to
---@param price number The amount of money that will be added
---@param playerIdentifier string The identifier of the player that executes the action
function AddMoneyToSociety(society, price, playerIdentifier)
    local success = false
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. society, function(account)
        if account then
            account.addMoney(price)
            success = true
        else
            lib.print.error(('Couldn\'t find account named %s in esx_addonaccount'):format('society_' .. society))
        end
    end)

    Wait(1000)

    return success
end

---@param society string The society that the money will be removed from
---@param price number The amount of money that will be removed
---@param playerIdentifier string The identifier of the player that executes the action
function RemoveMoneyFromSociety(society, price, playerIdentifier)
    local success = false
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. society, function(account)
        if account then
            if account.money >= price then
                account.removeMoney(price)
                success = true
            end
        else
            lib.print.error(('Couldn\'t find account named %s in esx_addonaccount'):format('society_' .. society))
        end
    end)

    Wait(1000)

    return success
end
