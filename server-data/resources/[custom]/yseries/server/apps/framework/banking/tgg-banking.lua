if Config.Companies.Banking ~= 'tgg-banking' then return end

function GetAccountMoney(accountName)
    return exports['tgg-banking']:GetSocietyAccountMoney(accountName)
end

function AddAccountMoney(accountName, amount)
    return exports['tgg-banking']:AddSocietyMoney(accountName, amount)
end

function RemoveAccountMoney(accountName, amount)
    return exports['tgg-banking']:RemoveSocietyMoney(accountName, amount)
end

function AddTransaction(sender, recipient, amount, description, transactionType)
    local toIban = exports['tgg-banking']:GetPersonalAccountByPlayerId(recipient).iban
    local fromIban = exports['tgg-banking']:GetPersonalAccountByPlayerId(sender).iban

    return exports['tgg-banking']:AddTransaction(toIban, fromIban, transactionType, amount, description, sender)
end
