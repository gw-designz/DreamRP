if Config.Companies.Banking ~= 'renewed-banking' then return end

function GetAccountMoney(accountName)
    return exports['Renewed-Banking']:getAccountMoney(accountName)
end

function AddAccountMoney(accountName, amount)
    return exports['Renewed-Banking']:addAccountMoney(accountName, amount)
end

function RemoveAccountMoney(accountName, amount)
    return exports['Renewed-Banking']:removeAccountMoney(accountName, amount)
end

function AddTransaction(sender, recipient, amount, description)
end
