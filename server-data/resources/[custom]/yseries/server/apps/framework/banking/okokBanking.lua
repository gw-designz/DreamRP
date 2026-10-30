if Config.Companies.Banking ~= 'okokBanking' then return end

function GetAccountMoney(accountName)
    return exports['okokBanking']:GetAccount(accountName)
end

function AddAccountMoney(accountName, amount)
    return exports['okokBanking']:AddMoney(accountName, amount)
end

function RemoveAccountMoney(accountName, amount)
    return exports['okokBanking']:RemoveMoney(accountName, amount)
end

function AddTransaction(sender, recipient, amount, description)
end
