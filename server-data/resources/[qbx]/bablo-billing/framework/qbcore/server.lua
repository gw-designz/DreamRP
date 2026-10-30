
if not IsFrameworkValid() or Config.Framework:lower() ~= 'qbcore' then
    return
end

local success, QBCore = pcall(function()
    return exports['qb-core']:GetCoreObject()
end)

if not success then
    Debug:error("Failed to get QBCore object:", QBCore)
    return {}
end

local MySQL = rawget(_G, 'MySQL') or exports.oxmysql

local m = {}

function m.getIdentifier(source)
    if not source or source <= 0 then
        Debug:error("Invalid source provided for getIdentifier")
        return nil
    end

    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        Debug:error("Player not found for source:", source)
        return nil
    end

    local identifier = player.PlayerData.citizenid
    if not identifier then
        Debug:error("No identifier found for player with source:", source)
        return nil
    end

    Debug:info("Identifier for source", source, "is", identifier)
    return identifier
end

function m.getCharacterName(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        Debug:error("Player not found for source:", source)
        return nil
    end

    local characterName = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
    if not characterName then
        Debug:error("No character name found for player with source:", source)
        return nil
    end

    Debug:info("Character name for source", source, "is", characterName)
    return characterName
end

function m.getPlayerJob(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        Debug:error("Player not found for source:", source)
        return nil
    end

    local job = player.PlayerData.job
    if not job or not job.name then
        Debug:error("No job found for player with source:", source)
        return nil
    end

    local rawGrade = job.grade.level or job.grade
    local gradeNum = tonumber(rawGrade) or 0
    Debug:debug("[getPlayerJob/qbcore] raw job.grade type:", type(job.grade), "value:", job.grade,
        "| raw extracted grade type:", type(rawGrade), "value:", rawGrade,
        "| final grade (tonumber):", gradeNum)

    local jobData = {
        name = job.name,
        label = job.label,
        grade = gradeNum,
        grade_name = job.grade.name or "Unknown",
        grade_salary = job.payment or 0
    }

    Debug:info("Job for source", source, "is", jobData)
    return jobData
end

function m.getJobLabel(jobName)
    if not jobName then return nil end

    if QBCore.Shared and QBCore.Shared.Jobs and QBCore.Shared.Jobs[jobName] then
        return QBCore.Shared.Jobs[jobName].label
    end

    return jobName
end

function m.getPlayerMoney(identifier)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then
        Debug:error("Player not found for identifier:", identifier)
        return 0
    end

    local money = player.PlayerData.money.cash or 0
    Debug:info("Money for identifier", identifier, "is", money)
    return money
end

function m.addPlayerMoney(identifier, amount)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then
        Debug:error("Player not found for identifier:", identifier)
        return false
    end

    player.Functions.AddMoney('cash', amount)
    Debug:info("Added", amount, "money to identifier", identifier)
    return true
end

function m.removePlayerMoney(identifier, amount)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then
        Debug:error("Player not found for identifier:", identifier)
        return false
    end

    local currentMoney = player.PlayerData.money.cash or 0
    if currentMoney < amount then
        Debug:error("Player", identifier, "does not have enough money. Has:", currentMoney, "Needs:", amount)
        return false
    end

    player.Functions.RemoveMoney('cash', amount)
    Debug:info("Removed", amount, "money from identifier", identifier)
    return true
end

function m.getPlayerFromIdentifier(identifier)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then
        return nil
    end

    return player.PlayerData.source
end

function m.isPlayerAdmin(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return false
    end

    local permission = QBCore.Functions.GetPermission(source)
    if permission == 'admin' or permission == 'god' then
        return true
    end

    return IsPlayerAceAllowed(source, 'command.billing')
end

function m.isValidIdentifier(identifier)
    if not identifier or identifier == "" then
        Debug:error("Invalid identifier provided: identifier is nil or empty")
        return false, "Identifier is required"
    end

    local result = MySQL.query.await('SELECT citizenid FROM players WHERE citizenid = ?', { identifier })

    if not result or #result == 0 then
        Debug:error("Identifier not found in database:", identifier)
        return false, "Player with this identifier does not exist"
    end

    Debug:info("Identifier", identifier, "is valid")
    return true, nil
end

function m.getAllJobs(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        Debug:error("Player not found for source:", source)
        return {}
    end

    local jobs = {}

    if QBCore.Shared and QBCore.Shared.Jobs then
        for jobName, jobData in pairs(QBCore.Shared.Jobs) do
            if jobName ~= "unemployed" then
                table.insert(jobs, {
                    name = jobName,
                    label = jobData.label or jobName,
                    onlineCount = 0
                })
            end
        end
    end

    Debug:info("Found", #jobs, "jobs for player", source)
    return jobs
end

function m.notifyPlayer(source, message, type)
    if not source or source <= 0 then
        Debug:error("Invalid source provided for notification")
        return false
    end

    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        Debug:error("Player not found for source:", source)
        return false
    end

    TriggerClientEvent('QBCore:Notify', source, message, type or 'primary')
    Debug:info("Notification sent to player", source, ":", message)
    return true
end

function m.getPlayerBankMoney(identifier)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then
        Debug:error("Player not found for identifier:", identifier)
        return 0
    end

    local bankMoney = player.PlayerData.money.bank or 0
    Debug:info("Bank money for identifier", identifier, "is", bankMoney)
    return bankMoney
end

function m.removePlayerBankMoney(identifier, amount)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then
        Debug:error("Player not found for identifier:", identifier)
        return false
    end

    local currentBankMoney = player.PlayerData.money.bank or 0
    if currentBankMoney < amount then
        Debug:error("Player", identifier, "does not have enough bank money. Has:", currentBankMoney, "Needs:", amount)
        return false
    end

    player.Functions.RemoveMoney('bank', amount)
    Debug:info("Removed", amount, "bank money from identifier", identifier)

    if GetResourceState('bablo-banking') == 'started' then
        local desc = "Invoice Paid"
        if Locales and Locales[Config.Locale] and Locales[Config.Locale].common and Locales[Config.Locale].common.descriptions then
            desc = Locales[Config.Locale].common.descriptions.invoice_paid or desc
        end
        exports["bablo-banking"]:CreateDefaultTransaction(player.PlayerData.source, "withdraw", desc, -amount)
    end

    return true
end

function m.addPlayerBankMoney(identifier, amount)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then
        Debug:error("Player not found for identifier:", identifier)
        return false
    end

    player.Functions.AddMoney('bank', amount)
    Debug:info("Added", amount, "bank money to identifier", identifier)

    if GetResourceState('bablo-banking') == 'started' then
        local desc = "Invoice Payment"
        if Locales and Locales[Config.Locale] and Locales[Config.Locale].common and Locales[Config.Locale].common.descriptions then
            desc = Locales[Config.Locale].common.descriptions.invoice_payment or desc
        end
        exports["bablo-banking"]:CreateDefaultTransaction(player.PlayerData.source, "deposit", desc, amount)
    end

    return true
end

function m.getJobMoney(jobName)
    if Config.SocietyResource == "auto" then
        local success, result = pcall(function()
            return exports['qb-management']:GetAccount(jobName)
        end)

        if success and result then
            Debug:info("QB Management job money for", jobName, "is", result)
            return result
        else
            local success2, result2 = pcall(function()
                return exports['qb-bossmenu']:GetAccount(jobName)
            end)

            if success2 and result2 then
                Debug:info("QB Bossmenu job money for", jobName, "is", result2)
                return result2
            else
                Debug:warn("No job money system found for", jobName)
                return 0
            end
        end
    elseif Config.SocietyResource == "qb-management" then
        local success, result = pcall(function()
            return exports['qb-management']:GetAccount(jobName)
        end)

        if success and result then
            Debug:info("QB Management job money for", jobName, "is", result)
            return result
        end
    elseif Config.SocietyResource == "qb-bossmenu" then
        local success, result = pcall(function()
            return exports['qb-bossmenu']:GetAccount(jobName)
        end)

        if success and result then
            Debug:info("QB Bossmenu job money for", jobName, "is", result)
            return result
        end
    elseif Config.SocietyResource == "bablo-banking" then
        local success, result = pcall(function()
            return exports['bablo-banking']:GetSocietyBalance(jobName)
        end)

        if success and result then
            Debug:info("Bablo Banking job money for", jobName, "is", result)
            return result
        end
    else
        Debug:error("Invalid society resource provided:", Config.SocietyResource)
        return 0
    end
end

function m.removeJobMoney(jobName, amount)
    if Config.SocietyResource == "auto" then
        local success, result = pcall(function()
            local currentMoney = exports['qb-management']:GetAccount(jobName)
            if currentMoney and currentMoney >= amount then
                return exports['qb-management']:RemoveMoney(jobName, amount)
            end
            return false
        end)

        if success and result then
            Debug:info("QB Management removed", amount, "from job", jobName, "success:", result)
            return result
        else
            local success2, result2 = pcall(function()
                local currentMoney = exports['qb-bossmenu']:GetAccount(jobName)
                if currentMoney and currentMoney >= amount then
                    return exports['qb-bossmenu']:RemoveMoney(jobName, amount)
                end
                return false
            end)

            if success2 and result2 then
                Debug:info("QB Bossmenu removed", amount, "from job", jobName, "success:", result2)
                return result2
            else
                Debug:warn("Failed to remove job money for", jobName)
                return false
            end
        end
    elseif Config.SocietyResource == "qb-management" then
        local success, result = pcall(function()
            return exports['qb-management']:RemoveMoney(jobName, amount)
        end)

        if success and result then
            Debug:info("QB Management removed", amount, "from job", jobName, "success:", result)
            return result
        end
    elseif Config.SocietyResource == "qb-bossmenu" then
        local success, result = pcall(function()
            return exports['qb-bossmenu']:RemoveMoney(jobName, amount)
        end)

        if success and result then
            Debug:info("QB Bossmenu removed", amount, "from job", jobName, "success:", result)
            return result
        end
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
        else
            Debug:error("Bablo Banking failed to remove money or pcall failed", success, result)
            return false
        end
    else
        Debug:error("Invalid society resource provided:", Config.SocietyResource)
        return false
    end
end

function m.addJobMoney(jobName, amount)
    if Config.SocietyResource == "auto" then
        local success, result = pcall(function()
            return exports['qb-management']:AddMoney(jobName, amount)
        end)

        if success and result then
            Debug:info("QB Management added", amount, "to job", jobName, "success:", result)
            return result
        else
            local success2, result2 = pcall(function()
                return exports['qb-bossmenu']:AddMoney(jobName, amount)
            end)

            if success2 and result2 then
                Debug:info("QB Bossmenu added", amount, "to job", jobName, "success:", result2)
                return result2
            else
                Debug:warn("Failed to add job money for", jobName)
                return false
            end
        end
    elseif Config.SocietyResource == "qb-management" then
        local success, result = pcall(function()
            return exports['qb-management']:AddMoney(jobName, amount)
        end)

        if success and result then
            Debug:info("QB Management added", amount, "to job", jobName, "success:", result)
            return result
        end
    elseif Config.SocietyResource == "qb-bossmenu" then
        local success, result = pcall(function()
            return exports['qb-bossmenu']:AddMoney(jobName, amount)
        end)

        if success and result then
            Debug:info("QB Bossmenu added", amount, "to job", jobName, "success:", result)
            return result
        end
    elseif Config.SocietyResource == "bablo-banking" then
        local success, result = pcall(function()
            local description = Locales[Config.Locale] and Locales[Config.Locale].common and
                Locales[Config.Locale].common.descriptions and Locales[Config.Locale].common.descriptions
                .invoice_payment or
                "Invoice Payment"
            return exports['bablo-banking']:AddSocietyMoney(jobName, amount, { description = description })
        end)

        if success and result then
            Debug:info("Bablo Banking added", amount, "to job", jobName, "success:", result)
            return result
        end
    else
        Debug:error("Invalid society resource provided:", Config.SocietyResource)
        return false
    end
end

function m.getOfflineMoney(identifier, moneyType)
    if not identifier then return 0 end
    moneyType = (moneyType == 'cash' or moneyType == 'wallet') and 'cash' or 'bank'
    local rows = MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { identifier })
    if not rows or not rows[1] or not rows[1].money then return 0 end
    local ok, moneyObj = pcall(json.decode, rows[1].money)
    if not ok or type(moneyObj) ~= 'table' then return 0 end
    local val = tonumber(moneyObj[moneyType] or 0) or 0
    return val
end

function m.addOfflineMoney(identifier, moneyType, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    moneyType = (moneyType == 'cash' or moneyType == 'wallet') and 'cash' or 'bank'
    local rows = MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { identifier })
    if not rows or not rows[1] then return false end
    local moneyJson = rows[1].money
    local ok, moneyObj = pcall(json.decode, moneyJson or '{}')
    if not ok or type(moneyObj) ~= 'table' then moneyObj = {} end
    local current = tonumber(moneyObj[moneyType] or 0) or 0
    moneyObj[moneyType] = current + amount
    local newJson = json.encode(moneyObj)
    local affected = MySQL.update and MySQL.update.await and
        MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { newJson, identifier }) or
        MySQL.query.await('UPDATE players SET money = ? WHERE citizenid = ?', { newJson, identifier })
    if type(affected) == 'number' then
        return affected > 0
    end
    return affected and true or false
end

function m.removeOfflineMoney(identifier, moneyType, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return false end
    moneyType = (moneyType == 'cash' or moneyType == 'wallet') and 'cash' or 'bank'
    local rows = MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { identifier })
    if not rows or not rows[1] then return false end
    local moneyJson = rows[1].money
    local ok, moneyObj = pcall(json.decode, moneyJson or '{}')
    if not ok or type(moneyObj) ~= 'table' then moneyObj = {} end
    local current = tonumber(moneyObj[moneyType] or 0) or 0
    if current < amount then return false end
    moneyObj[moneyType] = current - amount
    local newJson = json.encode(moneyObj)
    local affected = MySQL.update and MySQL.update.await and
        MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { newJson, identifier }) or
        MySQL.query.await('UPDATE players SET money = ? WHERE citizenid = ?', { newJson, identifier })
    if type(affected) == 'number' then
        return affected > 0
    end
    return affected and true or false
end

function m.searchCitizens(searchTerm, limit)
    limit = limit or 20
    local searchPattern = "%" .. searchTerm .. "%"
    local results = {}
    
    local nameParts = {}
    for part in string.gmatch(searchTerm, "%S+") do
        table.insert(nameParts, part)
    end
    
    local query
    local params
    
    if #nameParts >= 2 then
        local firstName = nameParts[1]
        local lastName = nameParts[2]
        query = [[
            SELECT citizenid, charinfo FROM players 
            WHERE citizenid LIKE ? 
               OR (JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ? 
                   AND JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?)
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
            LIMIT ?
        ]]
        params = { searchPattern, "%" .. firstName .. "%", "%" .. lastName .. "%", searchPattern, searchPattern, limit }
    else
        query = [[
            SELECT citizenid, charinfo FROM players 
            WHERE citizenid LIKE ? 
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ?
               OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
            LIMIT ?
        ]]
        params = { searchPattern, searchPattern, searchPattern, limit }
    end
    
    local dbResults = MySQL.query.await(query, params)
    
    if dbResults then
        for _, row in ipairs(dbResults) do
            local charinfo = {}
            if row.charinfo then
                local ok, parsed = pcall(json.decode, row.charinfo)
                if ok and parsed then
                    charinfo = parsed
                end
            end
            
            local fullName = "Unknown"
            if charinfo.firstname and charinfo.lastname then
                fullName = charinfo.firstname .. " " .. charinfo.lastname
            elseif charinfo.firstname then
                fullName = charinfo.firstname
            end
            
            table.insert(results, {
                identifier = row.citizenid,
                name = fullName
            })
        end
    end
    
    return results
end

function m.getCitizenName(identifier)
    if not identifier then return nil end
    
    local result = MySQL.query.await([[
        SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1
    ]], { identifier })
    
    if result and result[1] and result[1].charinfo then
        local ok, charinfo = pcall(json.decode, result[1].charinfo)
        if ok and charinfo then
            if charinfo.firstname and charinfo.lastname then
                return charinfo.firstname .. " " .. charinfo.lastname
            elseif charinfo.firstname then
                return charinfo.firstname
            end
        end
    end
    
    return nil
end

Core = m
