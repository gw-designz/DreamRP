
if not IsFrameworkValid() or Config.Framework:lower() ~= 'qbox' then
    return
end

local QBX = nil
local useNativeQBX = false

local success, result = pcall(function()
    return exports.qbx_core
end)

if success and result then
    useNativeQBX = true
    QBX = result
    print("^2[BILLING] Using native qbx_core exports^0")
else
    success, result = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if success and result then
        QBX = result
        print("^3[BILLING] Using qb-core compatibility layer for QBox^0")
    else
        print("^1[BILLING] Failed to get QBox/QBCore object^0")
        return
    end
end

local MySQL = rawget(_G, 'MySQL') or exports.oxmysql

local m = {}

local function localeDescription(key, fallback)
    local L = Locales and Config and Config.Locale and Locales[Config.Locale]
    if type(L) == 'table' and type(L.common) == 'table' and type(L.common.descriptions) == 'table' then
        local v = L.common.descriptions[key]
        if type(v) == 'string' and v ~= '' then return v end
    end
    return fallback
end

local function fetchPlayer(source)
    if not source then return nil end

    if useNativeQBX then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(source)
        end)
        if ok and player then
            return player
        end
        return nil
    end

    if QBX and type(QBX.Functions) == 'table' and QBX.Functions.GetPlayer then
        local ok, player = pcall(function()
            return QBX.Functions.GetPlayer(source)
        end)
        if ok and player then
            return player
        end
    end

    return nil
end

local function getPlayerSource(player)
    return player and player.PlayerData and player.PlayerData.source or nil
end

local function addMoneyCompat(player, identifier, moneyType, amount, reason)
    if useNativeQBX then
        local src = getPlayerSource(player)
        if src then
            local ok, res = pcall(function()
                return exports.qbx_core:AddMoney(src, moneyType, amount, reason or 'bablo-billing')
            end)
            if ok and res then return true end
        end
    end

    if player and player.Functions and player.Functions.AddMoney then
        return player.Functions.AddMoney(moneyType, amount, reason or 'bablo-billing')
    end

    return false
end

local function removeMoneyCompat(player, identifier, moneyType, amount, reason)
    if useNativeQBX then
        local src = getPlayerSource(player)
        if src then
            local ok, res = pcall(function()
                return exports.qbx_core:RemoveMoney(src, moneyType, amount, reason or 'bablo-billing')
            end)
            if ok and res then return true end
        end
    end

    if player and player.Functions and player.Functions.RemoveMoney then
        return player.Functions.RemoveMoney(moneyType, amount, reason or 'bablo-billing')
    end

    return false
end

local function fetchPlayerByIdentifier(identifier)
    if not identifier then return nil end

    if useNativeQBX then
        local success, player = pcall(function()
            return exports.qbx_core:GetPlayerByCitizenId(identifier)
        end)
        if success and player then
            return player
        end
    end

    local players = GetPlayers()
    for _, src in ipairs(players) do
        local player = fetchPlayer(tonumber(src))
        if player and player.PlayerData then
            local citizenid = player.PlayerData.citizenid or
                (player.PlayerData.charinfo and player.PlayerData.charinfo.citizenid)
            if citizenid == identifier then
                return player
            end
        end
    end
    return nil
end

function m.getIdentifier(source)
    local player = fetchPlayer(source)
    if not player then return nil end

    local playerData = player.PlayerData
    if not playerData then return nil end

    local citizenid = playerData.citizenid
    if not citizenid and playerData.charinfo then
        citizenid = playerData.charinfo.citizenid
    end

    return citizenid
end

function m.getCharacterName(source)
    local player = fetchPlayer(source)
    if not player then return nil end

    if not player.PlayerData then return "Unknown" end
    local info = player.PlayerData.charinfo
    if not info then return "Unknown" end

    local firstname = info.firstname or ''
    local lastname = info.lastname or ''
    local full = (firstname .. ' ' .. lastname):gsub('^%s+', ''):gsub('%s+$', '')
    return (#full > 0) and full or 'Unknown Player'
end

function m.getPlayerJob(source)
    local player = fetchPlayer(source)
    if not player then return nil end

    local job = player.PlayerData.job
    if not job then return nil end

    local gradeLevel = 0
    local gradeName = ''

    if job.grade then
        Debug:debug("[getPlayerJob/qbox] raw job.grade type:", type(job.grade), "value:", job.grade)
        if type(job.grade) == 'table' then
            local rawLevel = job.grade.level or job.grade.grade
            gradeLevel = tonumber(rawLevel) or 0
            gradeName = job.grade.name or ''
            Debug:debug("[getPlayerJob/qbox] grade is table | raw level type:", type(rawLevel), "value:", rawLevel,
                "| final gradeLevel:", gradeLevel)
        else
            gradeLevel = tonumber(job.grade) or 0
            Debug:debug("[getPlayerJob/qbox] grade is not table | final gradeLevel:", gradeLevel)
        end
    else
        Debug:debug("[getPlayerJob/qbox] job.grade is nil, defaulting to 0")
    end

    return {
        name = job.name or 'unemployed',
        label = job.label or job.name or 'Unemployed',
        grade = gradeLevel,
        grade_name = gradeName,
        grade_salary = job.payment or 0
    }
end

function m.getJobLabel(jobName)
    if not jobName then return nil end

    local sharedJobs = nil

    if useNativeQBX and exports.qbx_core.GetJobs then
        sharedJobs = exports.qbx_core:GetJobs()
    elseif not useNativeQBX and QBX and type(QBX.Shared) == 'table' and QBX.Shared.Jobs then
        sharedJobs = QBX.Shared.Jobs
    end

    if sharedJobs and sharedJobs[jobName] then
        return sharedJobs[jobName].label
    end

    return jobName
end

function m.getPlayerMoney(identifier)
    local player = fetchPlayerByIdentifier(identifier)
    if not player then return 0 end
    return player.PlayerData.money.cash or 0
end

function m.addPlayerMoney(identifier, amount)
    local player = fetchPlayerByIdentifier(identifier)
    if not player then return false end
    return addMoneyCompat(player, identifier, 'cash', amount, 'invoice')
end

function m.removePlayerMoney(identifier, amount)
    local player = fetchPlayerByIdentifier(identifier)
    if not player then return false end
    return removeMoneyCompat(player, identifier, 'cash', amount, 'invoice')
end

function m.getPlayerFromIdentifier(identifier)
    local player = fetchPlayerByIdentifier(identifier)
    if not player then return nil end
    return player.PlayerData.source
end

function m.isPlayerAdmin(source)
    return IsPlayerAceAllowed(source, 'command.billing') or IsPlayerAceAllowed(source, 'qbox.admin')
end

function m.isValidIdentifier(identifier)
    if not identifier or identifier == "" then return false, "Identifier required" end
    local result = MySQL.query.await('SELECT citizenid FROM players WHERE citizenid = ?', { identifier })
    if not result or #result == 0 then return false, "Player not found" end
    return true, nil
end

function m.getAllJobs(source)
    local jobs = {}
    local sharedJobs = nil

    if useNativeQBX and exports.qbx_core.GetJobs then
        sharedJobs = exports.qbx_core:GetJobs()
    elseif not useNativeQBX and QBX and type(QBX.Shared) == 'table' and QBX.Shared.Jobs then
        sharedJobs = QBX.Shared.Jobs
    end

    if sharedJobs then
        for jobName, jobData in pairs(sharedJobs) do
            if jobName ~= "unemployed" then
                table.insert(jobs, {
                    name = jobName,
                    label = jobData.label or jobName,
                    onlineCount = 0
                })
            end
        end
    end
    return jobs
end

function m.notifyPlayer(source, message, type)
    if useNativeQBX then
        exports.qbx_core:Notify(source, message, type or 'primary')
    else
        TriggerClientEvent('QBCore:Notify', source, message, type or 'primary')
    end
    return true
end

function m.getPlayerBankMoney(identifier)
    local player = fetchPlayerByIdentifier(identifier)
    if not player then return 0 end
    return player.PlayerData.money.bank or 0
end

function m.removePlayerBankMoney(identifier, amount)
    local player = fetchPlayerByIdentifier(identifier)
    if not player then return false end

    if removeMoneyCompat(player, identifier, 'bank', amount, 'invoice_paid') then
        if GetResourceState('bablo-banking') == 'started' and player.PlayerData and player.PlayerData.source then
            pcall(function()
                exports["bablo-banking"]:CreateDefaultTransaction(player.PlayerData.source, "withdraw",
                    localeDescription("invoice_paid", "Invoice Paid"), -amount)
            end)
        end
        return true
    end
    return false
end

function m.addPlayerBankMoney(identifier, amount)
    local player = fetchPlayerByIdentifier(identifier)
    if not player then return false end

    if addMoneyCompat(player, identifier, 'bank', amount, 'invoice_payment') then
        if GetResourceState('bablo-banking') == 'started' and player.PlayerData and player.PlayerData.source then
            pcall(function()
                exports["bablo-banking"]:CreateDefaultTransaction(player.PlayerData.source, "deposit",
                    localeDescription("invoice_payment", "Invoice Payment"), amount)
            end)
        end
        return true
    end
    return false
end

function m.getJobMoney(jobName)
    if Config.SocietyResource == "bablo-banking" then
        local success, result = pcall(function()
            return exports['bablo-banking']:GetSocietyBalance(jobName)
        end)
        if success and result then return result end
    end

    if GetResourceState('qbx_management') == 'started' then
        return exports.qbx_management:GetAccount(jobName)
    elseif GetResourceState('qb-management') == 'started' then
        return exports['qb-management']:GetAccount(jobName)
    end
    return 0
end

function m.removeJobMoney(jobName, amount)
    if Config.SocietyResource == "bablo-banking" then
        local success, result = pcall(function()
            local description = Locales[Config.Locale] and Locales[Config.Locale].common and
                Locales[Config.Locale].common.descriptions and Locales[Config.Locale].common.descriptions
                .invoice_payment or
                "Invoice Payment"
            local res = exports['bablo-banking']:RemoveSocietyMoney(jobName, amount, { description = description })
            if type(res) == 'table' then return res.success end
            return res
        end)
        if success and result then return result end
    end

    if GetResourceState('qbx_management') == 'started' then
        return exports.qbx_management:RemoveMoney(jobName, amount)
    elseif GetResourceState('qb-management') == 'started' then
        return exports['qb-management']:RemoveMoney(jobName, amount)
    end
    return false
end

function m.addJobMoney(jobName, amount)
    if Config.SocietyResource == "bablo-banking" then
        local success, result = pcall(function()
            local description = Locales[Config.Locale] and Locales[Config.Locale].common and
                Locales[Config.Locale].common.descriptions and Locales[Config.Locale].common.descriptions
                .invoice_payment or
                "Invoice Payment"
            local res = exports['bablo-banking']:AddSocietyMoney(jobName, amount, { description = description })
            if type(res) == 'table' then return res.success end
            return res
        end)
        if success and result then return result end
    end

    if GetResourceState('qbx_management') == 'started' then
        return exports.qbx_management:AddMoney(jobName, amount)
    elseif GetResourceState('qb-management') == 'started' then
        return exports['qb-management']:AddMoney(jobName, amount)
    end
    return false
end

function m.getOfflineMoney(identifier, moneyType)
    if not identifier then return 0 end
    moneyType = (moneyType == 'cash' or moneyType == 'wallet') and 'cash' or 'bank'
    local rows = MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { identifier })
    if not rows or not rows[1] or not rows[1].money then return 0 end
    local ok, moneyObj = pcall(json.decode, rows[1].money)
    if not ok or type(moneyObj) ~= 'table' then return 0 end
    return tonumber(moneyObj[moneyType] or 0) or 0
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
    moneyObj[moneyType] = (tonumber(moneyObj[moneyType]) or 0) + amount
    local newJson = json.encode(moneyObj)
    local affected = MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { newJson, identifier })
    return affected > 0
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
    local current = tonumber(moneyObj[moneyType] or 0)
    if current < amount then return false end
    moneyObj[moneyType] = current - amount
    local newJson = json.encode(moneyObj)
    local affected = MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { newJson, identifier })
    return affected > 0
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
