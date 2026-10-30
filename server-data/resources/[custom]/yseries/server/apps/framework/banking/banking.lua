lib.callback.register('yseries:server:banking:get-balance', function(source)
    local player = Framework.GetPlayerFromId(source)
    local playerJob = player?.job.name
    local balance = GetAccountMoney(playerJob)

    return balance or 0
end)

lib.callback.register('yseries:server:banking:deposit', function(source, amount)
    local player = Framework.GetPlayerFromId(source)
    if not player then return false, 'Player not found' end

    local isboss = player.job.isboss or player.getJob().grade_name == 'boss'
    local accountName = player.job.name
    if not isboss then return false, 'Only the boss can deposit money' end

    local currentAmountPlayer = player.getAccount('bank').money
    if currentAmountPlayer < amount then return false, 'Insufficient funds' end

    local currentBalance = GetAccountMoney(accountName)
    if not currentBalance then return false, 'Failed to retrieve current balance' end

    local depositSuccess = AddAccountMoney(accountName, amount)
    if not depositSuccess then return false, 'Deposit failed' end

    player.removeAccountMoney('bank', amount, 'app-phone')

    return true
end)

lib.callback.register('yseries:server:banking:withdraw', function(source, amount)
    local player = Framework.GetPlayerFromId(source)
    if not player then return false, 'Player not found' end

    local isboss = player.job.isboss or player.getJob().grade_name == 'boss'
    local accountName = player.job.name
    if not isboss then return false, 'Only the boss can withdraw money' end

    local currentBalance = GetAccountMoney(accountName)
    if not currentBalance then return false, 'Failed to retrieve current balance' end

    if currentBalance < amount then return false, 'Insufficient funds' end

    local withdrawSuccess = RemoveAccountMoney(accountName, amount)
    if not withdrawSuccess then return false, 'Withdrawal failed' end

    player.addAccountMoney('bank', amount, 'app-phone')

    return true
end)
