
if Config.Framework:lower() ~= 'esx' then
    return
end

local ESX = nil
local MySQL = nil
local m = {}
local isReady = false

local function WaitForESX()
    if isReady then return true end
    
    local timeout = 0
    while not isReady and timeout < 30000 do
        Citizen.Wait(100)
        timeout = timeout + 100
    end
    
    return isReady
end

Citizen.CreateThread(function()
    while GetResourceState('es_extended') ~= 'started' do
        Citizen.Wait(100)
    end
    
    Citizen.Wait(500)
    
    local success, esxObj = pcall(function()
        return exports['es_extended']:getSharedObject()
    end)

    if not success then
        Debug:error("Failed to get ESX object:", esxObj)
        return
    end
    
    ESX = esxObj
    MySQL = rawget(_G, 'MySQL') or exports.oxmysql
    isReady = true
    
    Debug:info("ESX Framework initialized successfully")
end)

Core = m

function m.getIdentifier(source)
    if not WaitForESX() then
        Debug:error("ESX not ready")
        return nil
    end
    
    if not source or source <= 0 then
        Debug:error("Invalid source provided for getIdentifier")
        return nil
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        Debug:error("Player not found for source:", source)
        return nil
    end

    local identifier = xPlayer.identifier
    if not identifier then
        Debug:error("No identifier found for player with source:", source)
        return nil
    end

    Debug:info("Identifier for source", source, "is", identifier)
    return identifier
end

function m.getCharacterName(source)
    if not WaitForESX() then return nil end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        Debug:error("Player not found for source:", source)
        return nil
    end

    local characterName = xPlayer.getName()
    if not characterName then
        Debug:error("No character name found for player with source:", source)
        return nil
    end

    Debug:info("Character name for source", source, "is", characterName)
    return characterName
end

function m.getPlayerJob(source)
    if not WaitForESX() then return nil end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        Debug:error("Player not found for source:", source)
        return nil
    end

    local job = xPlayer.job

    if not job or not job.name then
        Debug:error("No job found for player with source:", source)
        return nil
    end

    local gradeLabel = job.grade_label
    if not gradeLabel and ESX.Jobs and ESX.Jobs[job.name] and ESX.Jobs[job.name].grades then
        for _, g in pairs(ESX.Jobs[job.name].grades) do
            if g.grade == job.grade then
                gradeLabel = g.label
                break
            end
        end
    end
    gradeLabel = gradeLabel or job.grade_name

    local gradeNum = tonumber(job.grade) or 0
    Debug:debug("[getPlayerJob/esx] raw job.grade type:", type(job.grade), "value:", job.grade,
        "| final grade (tonumber):", gradeNum)

    local jobData = {
        name = job.name,
        label = job.label,
        grade = gradeNum,
        grade_name = gradeLabel,
        grade_salary = job.grade_salary or 0
    }

    Debug:info("Job for source", source, "is", jobData)
    return jobData
end

function m.getJobLabel(jobName)
    if not WaitForESX() then return jobName end
    if not jobName then return nil end

    if ESX.Jobs and ESX.Jobs[jobName] then
        return ESX.Jobs[jobName].label
    end

    return jobName
end

function m.getPlayerMoney(identifier)
    if not WaitForESX() then return 0 end
    
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        Debug:error("Player not found for identifier:", identifier)
        return 0
    end

    local money = xPlayer.getMoney()
    Debug:info("Money for identifier", identifier, "is", money)
    return money
end

function m.addPlayerMoney(identifier, amount)
    if not WaitForESX() then return false end
    
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        Debug:error("Player not found for identifier:", identifier)
        return false
    end

    xPlayer.addMoney(amount)
    Debug:info("Added", amount, "money to identifier", identifier)
    return true
end

function m.removePlayerMoney(identifier, amount)
    if not WaitForESX() then return false end
    
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        Debug:error("Player not found for identifier:", identifier)
        return false
    end

    local currentMoney = xPlayer.getMoney()
    if currentMoney < amount then
        Debug:error("Player", identifier, "does not have enough money. Has:", currentMoney, "Needs:", amount)
        return false
    end

    xPlayer.removeMoney(amount)
    Debug:info("Removed", amount, "money from identifier", identifier)
    return true
end

function m.getPlayerFromIdentifier(identifier)
    if not WaitForESX() then return nil end
    
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        return nil
    end

    return xPlayer.source
end

function m.isPlayerAdmin(source)
    if not WaitForESX() then return false end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return false
    end

    local playerGroup = xPlayer.getGroup()
    if playerGroup == 'admin' or playerGroup == 'superadmin' or playerGroup == 'owner' then
        return true
    end

    return IsPlayerAceAllowed(source, 'command.billing')
end

function m.isValidIdentifier(identifier)
    if not WaitForESX() then return false, "Framework not ready" end
    
    if not identifier or identifier == "" then
        Debug:error("Invalid identifier provided: identifier is nil or empty")
        return false, "Identifier is required"
    end

    local result = MySQL.query.await('SELECT identifier FROM users WHERE identifier = ?', { identifier })

    if not result or #result == 0 then
        Debug:error("Identifier not found in database:", identifier)
        return false, "Player with this identifier does not exist"
    end

    Debug:info("Identifier", identifier, "is valid")
    return true, nil
end

function m.getAllJobs(source)
    if not WaitForESX() then return {} end
    
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        Debug:error("Player not found for source:", source)
        return {}
    end

    local playerJob = xPlayer.job.name
    local jobs = {}

    if ESX.Jobs then
        Debug:info("Getting jobs from ESX.Jobs")
        for jobName, jobData in pairs(ESX.Jobs) do
            if jobName ~= playerJob and jobName ~= "unemployed" then
                table.insert(jobs, {
                    name = jobName,
                    label = jobData.label or jobName,
                    onlineCount = 0
                })
            end
        end
    else
        Debug:warn("ESX.Jobs not available, trying exports")
        local success, esxJobs = pcall(function()
            return exports['es_extended']:getSharedObject().Jobs
        end)

        if success and esxJobs then
            for jobName, jobData in pairs(esxJobs) do
                if jobName ~= playerJob then
                    table.insert(jobs, {
                        name = jobName,
                        label = jobData.label or jobName,
                        onlineCount = 0
                    })
                end
            end
        else
            Debug:warn("No job data available, using fallback jobs")
            local defaultJobs = {
                { name = "police",    label = "Police Department" },
                { name = "ambulance", label = "EMS" },
                { name = "mechanic",  label = "Mechanic" },
                { name = "taxi",      label = "Taxi Company" },
                { name = "cardealer", label = "Car Dealer" },
                { name = "realtor",   label = "Real Estate" },
                { name = "lawyer",    label = "Lawyer" },
                { name = "reporter",  label = "Reporter" },
                { name = "weazel",    label = "Weazel News" },
                { name = "sheriff",   label = "Sheriff Department" }
            }

            for _, jobData in ipairs(defaultJobs) do
                if jobData.name ~= playerJob then
                    table.insert(jobs, {
                        name = jobData.name,
                        label = jobData.label,
                        onlineCount = 0
                    })
                end
            end
        end
    end

    Debug:info("Found", #jobs, "jobs for player", source)
    return jobs
end

function m.notifyPlayer(source, message, type)
    if not WaitForESX() then return false end
    
    if not source or source <= 0 then
        Debug:error("Invalid source provided for notification")
        return false
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        Debug:error("Player not found for source:", source)
        return false
    end

    xPlayer.showNotification(message, type or 'info')
    Debug:info("Notification sent to player", source, ":", message)
    return true
end

function m.getPlayerBankMoney(identifier)
    if not WaitForESX() then return 0 end
    
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        Debug:error("Player not found for identifier:", identifier)
        return 0
    end

    local bankMoney = xPlayer.getAccount('bank').money or 0
    Debug:info("Bank money for identifier", identifier, "is", bankMoney)
    return bankMoney
end

function m.removePlayerBankMoney(identifier, amount)
    if not WaitForESX() then return false end
    
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        Debug:error("Player not found for identifier:", identifier)
        return false
    end

    local currentBankMoney = xPlayer.getAccount('bank').money or 0
    if currentBankMoney < amount then
        Debug:error("Player", identifier, "does not have enough bank money. Has:", currentBankMoney, "Needs:", amount)
        return false
    end

    xPlayer.removeAccountMoney('bank', amount)
    Debug:info("Removed", amount, "bank money from identifier", identifier)

    if GetResourceState('bablo-banking') == 'started' then
        local desc = "Invoice Paid"
        if Locales and Locales[Config.Locale] and Locales[Config.Locale].common and Locales[Config.Locale].common.descriptions then
            desc = Locales[Config.Locale].common.descriptions.invoice_paid or desc
        end
        exports["bablo-banking"]:CreateDefaultTransaction(xPlayer.source, "withdraw", desc, -amount)
    end

    return true
end

function m.addPlayerBankMoney(identifier, amount)
    if not WaitForESX() then return false end
    
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        Debug:error("Player not found for identifier:", identifier)
        return false
    end

    xPlayer.addAccountMoney('bank', amount)
    Debug:info("Added", amount, "bank money to identifier", identifier)

    if GetResourceState('bablo-banking') == 'started' then
        local desc = "Invoice Payment"
        if Locales and Locales[Config.Locale] and Locales[Config.Locale].common and Locales[Config.Locale].common.descriptions then
            desc = Locales[Config.Locale].common.descriptions.invoice_payment or desc
        end
        exports["bablo-banking"]:CreateDefaultTransaction(xPlayer.source, "deposit", desc, amount)
    end

    return true
end

function m.getJobMoney(jobName)
    if not WaitForESX() then return 0 end
    
    if Config.SocietyResource == "auto" or Config.SocietyResource == "esx_society" or Config.SocietyResource == "esx_addonaccount" then
        local promise = promise.new()

        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. jobName, function(account)
            if account then
                promise:resolve(account.money or 0)
            else
                Debug:warn("Society account not found for job:", jobName)
                promise:resolve(0)
            end
        end)

        local money = Citizen.Await(promise)
        Debug:info("Job money for", jobName, "is", money)
        return money
    elseif Config.SocietyResource == "bablo-banking" then
        local success, result = pcall(function()
            return exports['bablo-banking']:GetSocietyBalance(jobName)
        end)

        if success and result then
            Debug:info("Bablo Banking job money for", jobName, "is", result)
            return result
        end
    end
end

function m.removeJobMoney(jobName, amount)
    if not WaitForESX() then return false end
    
    if Config.SocietyResource == "auto" or Config.SocietyResource == "esx_society" or Config.SocietyResource == "esx_addonaccount" then
        local promise = promise.new()

        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. jobName, function(account)
            if account then
                if account.money >= amount then
                    account.removeMoney(amount)
                    promise:resolve(true)
                else
                    Debug:error("Job", jobName, "does not have enough money. Has:", account.money, "Needs:", amount)
                    promise:resolve(false)
                end
            else
                Debug:warn("Society account not found for job:", jobName)
                promise:resolve(false)
            end
        end)

        local success = Citizen.Await(promise)
        Debug:info("Removed", amount, "from job", jobName, "success:", success)
        return success
    elseif Config.SocietyResource == "bablo-banking" then
        local success, result = pcall(function()
            local description = Locales[Config.Locale] and Locales[Config.Locale].common and
                Locales[Config.Locale].common.descriptions and Locales[Config.Locale].common.descriptions
                .invoice_payment or
                "Invoice Payment"
            local res = exports['bablo-banking']:RemoveSocietyMoney(jobName, amount, { description = description })

            if type(res) == 'table' then
                return res.success
            end
            return res
        end)

        if success and result then
            Debug:info("Bablo Banking removed", amount, "from job", jobName, "success:", result)
            return result
        end
    end
end

function m.addJobMoney(jobName, amount)
    if not WaitForESX() then return false end
    
    if Config.SocietyResource == "auto" or Config.SocietyResource == "esx_society" or Config.SocietyResource == "esx_addonaccount" then
        local promise = promise.new()

        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. jobName, function(account)
            if account then
                account.addMoney(amount)
                promise:resolve(true)
            else
                Debug:warn("Society account not found for job:", jobName)
                promise:resolve(false)
            end
        end)

        local success = Citizen.Await(promise)
        Debug:info("Added", amount, "to job", jobName, "success:", success)
        return success
    elseif Config.SocietyResource == "bablo-banking" then
        local success, result = pcall(function()
            local description = Locales[Config.Locale] and Locales[Config.Locale].common and
                Locales[Config.Locale].common.descriptions and Locales[Config.Locale].common.descriptions
                .invoice_payment or
                "Invoice Payment"
            local res = exports['bablo-banking']:AddSocietyMoney(jobName, amount, { description = description })

            if type(res) == 'table' then
                return res.success
            end
            return res
        end)
        if success and result then
            Debug:info("Bablo Banking added", amount, "to job", jobName, "success:", result)
            return result
        end
    end
end

function m.getOfflineMoney(identifier, moneyType)
    if not WaitForESX() then return 0 end
    if not identifier then return 0 end
    local rows = MySQL.query.await('SELECT accounts FROM users WHERE identifier = ? LIMIT 1', { identifier })
    if not rows or not rows[1] then return 0 end
    local ok, acc = pcall(json.decode, rows[1].accounts or '{}')
    if not ok or type(acc) ~= 'table' then acc = {} end
    local key = (moneyType == 'cash' or moneyType == 'wallet') and 'money' or 'bank'
    return tonumber(acc[key] or 0) or 0
end

function m.addOfflineMoney(identifier, moneyType, amount)
    if not WaitForESX() then return false end
    amount = tonumber(amount) or 0
    if not identifier or amount <= 0 then return false end
    local rows = MySQL.query.await('SELECT accounts FROM users WHERE identifier = ? LIMIT 1', { identifier })
    if not rows or not rows[1] then return false end
    local ok, acc = pcall(json.decode, rows[1].accounts or '{}')
    if not ok or type(acc) ~= 'table' then acc = {} end
    local key = (moneyType == 'cash' or moneyType == 'wallet') and 'money' or 'bank'
    local current = tonumber(acc[key] or 0) or 0
    acc[key] = current + amount
    local newJson = json.encode(acc)
    local affected = (MySQL.update and MySQL.update.await and MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', { newJson, identifier }))
        or MySQL.query.await('UPDATE users SET accounts = ? WHERE identifier = ?', { newJson, identifier })
    if type(affected) == 'number' then return affected > 0 end
    return affected and true or false
end

function m.removeOfflineMoney(identifier, moneyType, amount)
    if not WaitForESX() then return false end
    amount = tonumber(amount) or 0
    if not identifier or amount <= 0 then return false end
    local rows = MySQL.query.await('SELECT accounts FROM users WHERE identifier = ? LIMIT 1', { identifier })
    if not rows or not rows[1] then return false end
    local ok, acc = pcall(json.decode, rows[1].accounts or '{}')
    if not ok or type(acc) ~= 'table' then acc = {} end
    local key = (moneyType == 'cash' or moneyType == 'wallet') and 'money' or 'bank'
    local current = tonumber(acc[key] or 0) or 0
    if current < amount then return false end
    acc[key] = current - amount
    local newJson = json.encode(acc)
    local affected = (MySQL.update and MySQL.update.await and MySQL.update.await('UPDATE users SET accounts = ? WHERE identifier = ?', { newJson, identifier }))
        or MySQL.query.await('UPDATE users SET accounts = ? WHERE identifier = ?', { newJson, identifier })
    if type(affected) == 'number' then return affected > 0 end
    return affected and true or false
end

function m.searchCitizens(searchTerm, limit)
    if not WaitForESX() then return {} end
    limit = limit or 20
    local searchPattern = "%" .. searchTerm .. "%"
    local results = {}
    
    local dbResults = MySQL.query.await([[
        SELECT identifier, firstname, lastname FROM users 
        WHERE identifier LIKE ? 
           OR firstname LIKE ?
           OR lastname LIKE ?
           OR CONCAT(firstname, ' ', lastname) LIKE ?
        LIMIT ?
    ]], { searchPattern, searchPattern, searchPattern, searchPattern, limit })
    
    if dbResults then
        for _, row in ipairs(dbResults) do
            local fullName = "Unknown"
            if row.firstname and row.lastname then
                fullName = row.firstname .. " " .. row.lastname
            elseif row.firstname then
                fullName = row.firstname
            end
            
            table.insert(results, {
                identifier = row.identifier,
                name = fullName
            })
        end
    end
    
    return results
end

function m.getCitizenName(identifier)
    if not WaitForESX() then return nil end
    if not identifier then return nil end
    
    local result = MySQL.query.await([[
        SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1
    ]], { identifier })
    
    if result and result[1] then
        if result[1].firstname and result[1].lastname then
            return result[1].firstname .. " " .. result[1].lastname
        elseif result[1].firstname then
            return result[1].firstname
        end
    end
    
    return nil
end
