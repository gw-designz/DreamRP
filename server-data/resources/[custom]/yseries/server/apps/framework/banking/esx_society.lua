if Config.Companies.Banking ~= 'esx_society' then return end

function GetAccountMoney(accountName)
    local balance = 0

    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. accountName, function(account)
        if account then
            balance = account.money
        end
    end)

    return balance
end

function AddAccountMoney(accountName, amount)
    local success = false
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. accountName, function(account)
        if account then
            account.addMoney(amount)
            success = true
        else
            debugPrint(('Couldn\'t find account named %s in esx_addonaccount'):format('society_' .. accountName))
        end
    end)

    Wait(1000)

    return success
end

function RemoveAccountMoney(accountName, amount)
    local success = false
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. accountName, function(account)
        if account then
            if account.money >= amount then
                account.removeMoney(amount)
                success = true
            end
        else
            debugPrint(('Couldn\'t find account named %s in esx_addonaccount'):format('society_' .. accountName))
        end
    end)

    Wait(1000)

    return success
end

function AddTransaction(sender, recipient, amount, description)
end
