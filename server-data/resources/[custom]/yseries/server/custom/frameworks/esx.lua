CreateThread(function()
    if Config.Framework ~= 'esx' then return end

    local export, ESX = pcall(function() return exports.es_extended:getSharedObject() end)

    if not export then
        while not ESX do
            TriggerEvent("esx:getSharedObject", function(obj)
                ESX = obj
            end)

            Wait(500)
        end
    end

    Framework = ESX

    Framework.IsPlayerAdmin = function(source)
        return IsPlayerAceAllowed(source, 'admin')
    end

    function GetOfflineCharacterName(identifier)
        local playersTable = 'users'

        local result = MySQL.query.await([[
        SELECT firstname, lastname
        FROM `]] .. playersTable .. [[`
        WHERE identifier = ?
    ]], { identifier })
        return result[1] and result[1].firstname .. ' ' .. result[1].lastname or "Unknown"
    end

    -- * Get an array of all players with a certain job.
    function GetEmployees(job)
        local employees = {}
        if Framework.GetExtendedPlayers then
            local xPlayers = Framework.GetExtendedPlayers("job", job)
            for _, xPlayer in pairs(xPlayers) do
                employees[#employees + 1] = xPlayer.source
            end
        else
            local xPlayers = Framework.GetPlayers()
            for _, source in pairs(xPlayers) do
                if Framework.GetPlayerFromId(source).job.name == job then
                    employees[#employees + 1] = source
                end
            end
        end
        return employees
    end

    -- * Send a notification to a player.
    function Notify(source, messageData)
        lib.notify(source, messageData)
    end

    -- * Get the job of a player.
    function GetJob(source)
        local xPlayer = Framework.GetPlayerFromId(source)
        return xPlayer.job?.name
    end

    -- * Refresh the online status of all companies.
    function RefreshCompanies()
        local openJobs = {}
        if Framework.GetExtendedPlayers then
            local xPlayers = Framework.GetExtendedPlayers()
            for _, xPlayer in pairs(xPlayers) do
                local job = xPlayer.job.name
                openJobs[job] = true
            end
        else
            local xPlayers = Framework.GetPlayers()
            for _, source in pairs(xPlayers) do
                local job = Framework.GetPlayerFromId(source).job.name
                openJobs[job] = true
            end
        end

        for i = 1, #Config.Companies.Services do
            local jobData = Config.Companies.Services[i]

            local isPoliceJob = false
            for _, jobName in ipairs(Config.Companies.AppearAsAlwaysAvailable) do
                if jobData.job == jobName then
                    isPoliceJob = true
                    break
                end
            end

            if isPoliceJob and Config.Companies.PoliceAlwaysAvailable then
                Config.Companies.Services[i].open = true -- Always appear as online.
            else
                Config.Companies.Services[i].open = openJobs[jobData.job] or false
            end
        end
    end

    lib.callback.register('yseries:server:companies:get-employees-ids', function(_, job)
        local employeesData = {}

        local employeesPromise = promise.new()
        TriggerEvent("esx_society:getEmployees", function(employees)
            employeesData = employees
            for i = 1, #employees do
                local employee = employees[i]

                employees[i] = {
                    name = employee.name,
                    id = employee.identifier,

                    gradeLabel = employee.job.grade_label,
                    grade = employee.job.grade,

                    canInteract = employee.job.grade_name ~= "boss"
                }
            end
            employeesPromise:resolve()
        end, job)

        Citizen.Await(employeesPromise)

        return employeesData
    end)
end)
