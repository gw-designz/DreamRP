
Framework = Framework or {};

CreateThread(function()
    if Config.Framework ~= 'qbcore' then
        return
    end

    function Framework:getCore()
        return exports['qb-core']:GetCoreObject();
    end

    local QBCore = Framework:getCore();

    function Framework:fetchPlayer(source)
        return QBCore.Functions.GetPlayer(source)
    end

    function Framework:getPlayerJob(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player or not player.PlayerData or not player.PlayerData.job then return nil end
        return player.PlayerData.job.name
    end

    function Framework:addMoney(source, amount)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return end

        player.Functions.AddMoney('cash', amount)
    end

    function Framework:getPlayers()
        local players = QBCore.Functions.GetQBPlayers()
        local cleanPlayers = {}

        for _, player in pairs(players) do
            if player and player.PlayerData and player.PlayerData.source then
                player.source = player.PlayerData.source
                table.insert(cleanPlayers, player)
            end
        end

        return cleanPlayers
    end

    function Framework:getEmployees(jobName)
        local employees = {}
        local players = QBCore.Functions.GetQBPlayers()

        for _, v in pairs(players) do
            if v and v.PlayerData and v.PlayerData.job
                and v.PlayerData.job.name == jobName
                and v.PlayerData.job.onduty then
                employees[#employees + 1] = v.PlayerData.source
            end
        end

        return employees
    end

    function Framework:vehicleChecks(netId, vehicleEntity)
        -- Make extra checks here if needed

        return false -- Should return false if the vehicle allowed to be used in smash n grab
    end

    function Framework:Notify(source, message)
        TriggerClientEvent('QBCore:Notify', source, message)
    end

    function Framework:getPlayerName(source)
        source = tonumber(source)

        local player = self:fetchPlayer(source)

        if player.Functions.GetName then
            return player.Functions.GetName()
        end

        return "Unknown Player"
    end

    function Framework:isAdmin(source)
        source = tonumber(source)
        if not source then return false end

        if QBCore.Functions.HasPermission(source, 'god') then return true end
        if QBCore.Functions.HasPermission(source, 'admin') then return true end

        return IsPlayerAceAllowed(source, 'command')
    end
end)
