
Framework = Framework or {}

CreateThread(function()
    if Config.Framework ~= 'qbox' then
        return
    end

    function Framework:getCore()
        return exports['qb-core']:GetCoreObject();
    end

    local QBX = Framework:getCore()

    function Framework:fetchPlayer(source)
        return QBX.Functions.GetPlayer(source)
    end

    function Framework:getPlayerJob(source)
        local player = QBX.Functions.GetPlayer(source)
        if not player or not player.PlayerData or not player.PlayerData.job then return nil end
        return player.PlayerData.job.name
    end

    function Framework:addMoney(source, amount)
        local player = QBX.Functions.GetPlayer(source)
        if not player then return end

        player.Functions.AddMoney('cash', amount)
    end

    function Framework:getPlayers()
        local players = QBX.Functions.GetPlayers()
        local result = {}

        for _, src in pairs(players) do
            local player = QBX.Functions.GetPlayer(src)
            if player then
                result[#result + 1] = player
                player.source = src
            end
        end

        return result
    end

    -- Job aliases: when a job is requested, any job name listed here is treated
    -- as the same job. This lets LSSD count as police for every PoliceRequired
    -- check without touching the module logic. Add more law-enforcement jobs
    -- (e.g. 'bcso', 'sheriff') to the police group as needed.
    local JOB_GROUPS = {
        police = { police = true, lssd = true },
    }

    local function jobMatches(requested, actual)
        if actual == requested then return true end
        local group = JOB_GROUPS[requested]
        return group ~= nil and group[actual] == true
    end

    function Framework:getEmployees(jobName)
        local employees = {}

        -- Use GetQBPlayers if available (returns all player objects without individual lookups)
        -- This avoids calling GetPlayer(src) for each player which is extremely expensive on 100+ player servers
        if QBX.Functions.GetQBPlayers then
            local players = QBX.Functions.GetQBPlayers()
            for _, player in pairs(players) do
                if player and player.PlayerData and player.PlayerData.job
                    and jobMatches(jobName, player.PlayerData.job.name)
                    and player.PlayerData.job.onduty then
                    employees[#employees + 1] = player.PlayerData.source
                end
            end
        else
            local players = QBX.Functions.GetPlayers()
            for _, src in pairs(players) do
                local player = QBX.Functions.GetPlayer(src)
                if player and jobMatches(jobName, player.PlayerData.job.name) and player.PlayerData.job.onduty then
                    employees[#employees + 1] = src
                end
            end
        end

        return employees
    end

    function Framework:vehicleChecks(netId, vehicleEntity)
        -- Make extra checks here if needed

        return false -- Should return false if the vehicle is allowed to be used in smash n grab
    end

    function Framework:Notify(source, message)
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Notification',
            description = message,
            type = 'inform'
        })
    end

    function Framework:getPlayerName(source)
        source = tonumber(source)
        if not source then
            return "Unknown Player"
        end

        local player = self:fetchPlayer(source)
        if not player then
            return "Unknown Player"
        end

        if not player.PlayerData or not player.PlayerData.charinfo then
            return "Unknown Player"
        end

        local firstName = player.PlayerData.charinfo.firstname
        local lastName = player.PlayerData.charinfo.lastname

        if firstName and lastName and firstName ~= '' and lastName ~= '' then
            return firstName .. ' ' .. lastName
        elseif firstName and firstName ~= '' then
            return firstName
        elseif lastName and lastName ~= '' then
            return lastName
        end

        return "Unknown Player"
    end

    function Framework:isAdmin(source)
        source = tonumber(source)
        if not source then return false end

        if QBX.Functions.HasPermission then
            if QBX.Functions.HasPermission(source, 'god') then return true end
            if QBX.Functions.HasPermission(source, 'admin') then return true end
        end

        return IsPlayerAceAllowed(source, 'command')
    end
end)
