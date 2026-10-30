if Config.Companies.Banking ~= 'qb-banking' then return end

function GetAccountMoney(accountName)
    return exports['qb-banking']:GetAccount(accountName)
end

function AddAccountMoney(accountName, amount)
    return exports['qb-banking']:AddMoney(accountName, amount)
end

function RemoveAccountMoney(accountName, amount)
    return exports['qb-banking']:RemoveMoney(accountName, amount)
end

function AddTransaction(sender, recipient, amount, description)
end
