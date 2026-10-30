if Config.Framework ~= 'ox_core' then
    return
end

local import = LoadResourceFile('ox_core', 'lib/init.lua')
local chunk = assert(load(import))
chunk()

OnPlayerLoadedEvent = 'ox:playerLoaded'
OnPlayerUnloadedEvent = 'ox:playerLogout'

Framework = {
    GetPlayers = function()
        local sources = {}
        local players = Ox.GetPlayers()
        for k in pairs(players) do
            sources[#sources + 1] = players[k].source
        end

        return sources
    end,

    GetPlayerFromId = function(source)
        local xPlayer = {}
        local oxPlayer = Ox.GetPlayer(source)
        ---------
        if not oxPlayer then
            return nil
        end
        xPlayer.source = oxPlayer.source
        ---------
        xPlayer.identifier = oxPlayer.stateId
        ---------
        xPlayer.license = oxPlayer.identifier
        ---------
        local group, grade = oxPlayer.getGroupByType('job')

        local jobState = group and GlobalState['group.' .. group] or nil
        local gradeName = jobState and jobState.grades[grade] or 'none'
        local gradeLevel = grade or -1

        xPlayer.job = {
            name = group,
            label = jobState and jobState.label or 'none',
            grade = gradeLevel,
            grade_name = gradeName,
            isboss = jobState and (jobState.accountRoles[tostring(grade)] == 'owner') or false
        }
        ---------
        xPlayer.getName = function()
            return string.format('%s %s', oxPlayer.get('firstName') or 'Unknown', oxPlayer.get('lastName') or 'Player')
        end
        ---------
        xPlayer.addAccountMoney = function(type, money)
            if type == 'money' or type == 'cash' then
                return exports.ox_inventory:AddItem(oxPlayer.source, 'money', money)
            end
            local account = oxPlayer.getAccount()
            if not account then return false end

            return account.addBalance({ amount = money, message = '' }).success
        end
        ---------
        xPlayer.getAccount = function(type)
            local money = 0
            if type == 'money' or type == 'cash' then
                money = exports.ox_inventory:GetItemCount(oxPlayer.source, 'money') or 0
            else
                local account = oxPlayer.getAccount()
                money = account and account.get('balance') or 0
            end
            return { money = money }
        end
        ---------
        xPlayer.removeAccountMoney = function(type, money, reason)
            if type == 'cash' or type == 'money' then
                return exports.ox_inventory:RemoveItem(oxPlayer.source, 'money', money)
            end
            local account = oxPlayer.getAccount()
            return account and account.removeBalance({ amount = money, message = reason }).success
        end
        ---------
        xPlayer.setMeta = function(key, val)
            return oxPlayer.set(key, val)
        end
        ---------
        xPlayer.getMeta = function(key)
            return oxPlayer.get(key)
        end
        ---------
        xPlayer.clearMeta = function(key)
            return oxPlayer.set(key, nil)
        end
        return xPlayer
    end,
    GetPlayerFromIdentifier = function(citizenid)
        local oxPlayer = Ox.GetPlayerFromFilter({ stateId = citizenid })
        return oxPlayer and Framework.GetPlayerFromId(oxPlayer.source) or nil
    end,
    isPlayerAuthorized = function(player, forJob)
        for jobName, jobs in pairs(Config.RealEstateJobs) do
            if jobName == player.job.name and player.job.grade >= jobs[forJob] then
                return true, nil
            end
        end
        return false, locale('not_authorized_' .. forJob)
    end,
    isPlayerAuthorizedToRaid = function(player)
        for jobName, grade in pairs(Config.PoliceRaid.Jobs) do
            if jobName == player.job.name and player.job.grade >= grade then
                return true
            end
        end
        return false
    end,
    isPlayerAuthorizedToLockdown = function(player)
        return Framework.isPlayerAuthorizedToRaid(player)
    end,
    IsSocietyBoss = function(player, society)
        return player.job.name == society and player.job.isboss == true
    end
}

---@param identifier string
---@param coords vector3
---@return boolean
function UpdatePlayerCoords(identifier, coords)
    return MySQL.update.await('UPDATE characters SET x = ?, y = ?, z = ? WHERE stateId = ?', { coords.x, coords.y, coords.z, identifier }) > 0
end

---@return OfflinePlayer[]
function GetAllOfflinePlayersWithNames()
    local result = MySQL.query.await([[
        SELECT
            stateId as identifier,
            fullName as name
        FROM `characters`;
    ]])
    return result
end

---@param identifier string
---@return string
function GetOfflinePlayerName(identifier)
    local result = MySQL.single.await('SELECT fullName FROM characters WHERE stateId = ?', { identifier })
    return result?.fullName or 'Unknown'
end

function ModifyOfflinePlayerMoney(identifier, type, money, operation)
    if type == 'cash' or type == 'money' then
        local result = MySQL.single.await('SELECT inventory FROM character_inventory WHERE stateId = ? LIMIT 1', { identifier })
        if not result then return false end

        local items = json.decode(result.inventory)
        local moneyItem = nil
        for _, item in ipairs(items) do
            if item.name == 'money' then
                moneyItem = item
                break
            end
        end

        if not moneyItem then return false end
        if operation == 'remove' and moneyItem.count < money then return false end

        moneyItem.count = operation == 'add' and moneyItem.count + money or moneyItem.count - money

        return MySQL.update.await('UPDATE character_inventory SET inventory = ? WHERE stateId = ?', { json.encode(items), identifier }) > 0
    end

    local result = MySQL.single.await('SELECT balance FROM accounts WHERE stateId = ? LIMIT 1', { identifier })
    if not result then return false end
    if operation == 'remove' and result.balance < money then return false end

    result.balance = operation == 'add' and result.balance + money or result.balance - money

    return MySQL.update.await('UPDATE accounts SET balance = ? WHERE stateId = ?', { result.balance, identifier }) > 0
end

function RemoveOfflinePlayerMoney(identifier, type, money)
    return ModifyOfflinePlayerMoney(identifier, type, money, 'remove')
end

function AddOfflinePlayerMoney(identifier, type, money)
    return ModifyOfflinePlayerMoney(identifier, type, money, 'add')
end

function GetJobGrades(jobName)
    local job = exports.ox_core:GetJob(jobName)
    local grades = {}
    local accountRoles = job and job.accountRoles or {}
    for grade, data in pairs(job.grades) do
        grades[#grades+1] = {
            grade = grade,
            name = data.label,
            isBoss = (accountRoles and accountRoles[tostring(grade)] == 'owner') or data.isBoss == true or data.isboss == true
        }
    end
    return grades
end