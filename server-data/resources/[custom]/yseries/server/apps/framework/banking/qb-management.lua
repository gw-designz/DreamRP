if Config.Companies.Banking ~= 'qb-management' then return end

function GetAccountMoney(accountName)
    return exports['qb-management']:GetAccount(accountName)
end

function AddAccountMoney(accountName, amount)
    return exports['qb-management']:AddMoney(accountName, amount)
end

function RemoveAccountMoney(accountName, amount)
    return exports['qb-management']:RemoveMoney(accountName, amount)
end

function AddTransaction(sender, recipient, amount, description)
end
