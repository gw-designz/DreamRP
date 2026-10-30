
Framework = Framework or {};

CreateThread(function()
    if Config.Framework ~= 'esx' then
        return
    end

    function Framework:getCore()
        return exports['es_extended']:getSharedObject();
    end

    local ESX = Framework:getCore();

    function Framework:fetchPlayer(source)
        return ESX.GetPlayerFromId(source)
    end

    function Framework:getPlayerJob(source)
        local player = ESX.GetPlayerFromId(source)
        if not player or not player.job then return nil end
        return player.job.name
    end

    function Framework:addMoney(source, amount)
        local player = ESX.GetPlayerFromId(source)
        if not player then return end

        player.addMoney(amount)
    end

    function Framework:getPlayers()
        if ESX.GetExtendedPlayers then
            return ESX.GetExtendedPlayers()
        else
            return ESX.GetPlayers()
        end
    end

    function Framework:getEmployees(jobName)
        local employees = {}
        local employeesCount = 0

        if ESX.GetExtendedPlayers then
            local players = ESX.GetExtendedPlayers("job", jobName)

            for _, player in pairs(players) do
                employeesCount += 1
                employees[employeesCount] = player.source
            end
        else
            Trace(
            "You are running an extremely old version of ESX. The script will still work, but you should consider updating. (you can remove this warning in frameworks/esx/server.lua)")
            local players = ESX.GetPlayers()

            for _, source in pairs(players) do
                if ESX.GetPlayerFromId(source).job.name == jobName then
                    employeesCount += 1
                    employees[employeesCount] = source
                end
            end
        end

        return employees
    end

    function Framework:vehicleChecks(netId, vehicleEntity)
        -- Make extra checks here if needed

        return false -- Should return false if the vehicle allowed to be used in smash n grab
    end

    function Framework:Notify(source, message)
        TriggerClientEvent('esx:showNotification', source, message)
    end

    function Framework:getPlayerName(source)
        source = tonumber(source)

        local player = self:fetchPlayer(source)

        if player.getName then
            return player.getName()
        end

        return "Unknown Player"
    end

    function Framework:isAdmin(source)
        source = tonumber(source)
        if not source then return false end

        local player = ESX.GetPlayerFromId(source)
        if player then
            local group = player.getGroup()
            if group == 'admin' or group == 'superadmin' then
                return true
            end
        end

        return IsPlayerAceAllowed(source, 'command')
    end
end)
