if Config.Framework ~= 'esx' then
    return
end

OnPlayerLoadedEvent = 'esx:playerLoaded'    -- networked
OnPlayerUnloadedEvent = 'esx:playerDropped' -- non-networked

ESX = exports.es_extended:getSharedObject()
Framework = ESX

Framework.IsSocietyBoss = function(player, society)
    return player.job.name == society and player.job.grade_name == 'boss'
end
Framework.isPlayerAuthorized = function(player, forJob)
    for jobName, jobs in pairs(Config.RealEstateJobs) do
        if jobName == player.job.name and player.job.grade >= jobs[forJob] then
            return true, nil
        end
    end
    return false, locale('not_authorized_' .. forJob)
end
Framework.isPlayerAuthorizedToRaid = function(player)
    for jobName, grade in pairs(Config.PoliceRaid.Jobs) do
        if jobName == player.job.name and player.job.grade >= grade then
            return true
        end
    end
    return false
end
Framework.isPlayerAuthorizedToLockdown = function(player)
    return Framework.isPlayerAuthorizedToRaid(player)
end

---@param identifier string
---@param coords vector3
---@return boolean
function UpdatePlayerCooords(identifier, coords)
    return MySQL.update.await([[
        UPDATE `users`
        SET position = ?
        WHERE identifier = ?
    ]], {
        json.encode(coords),
        identifier
    }) > 0
end

---@return OfflinePlayer[]
function GetAllOfflinePlayersWithNames()
    local result = MySQL.query.await([[
        SELECT 
            identifier, 
            CONCAT(COALESCE(firstname, ''), ' ', COALESCE(lastname, '')) AS name
        FROM `users`;
    ]])
    return result
end

---@param identifier string
---@return string
function GetOfflinePlayerName(identifier)
    local result = MySQL.query.await([[
        SELECT CONCAT(COALESCE(firstname, ''), ' ', COALESCE(lastname, '')) AS name
        FROM `users`
        WHERE identifier = ?
    ]], { identifier })

    return result[1] and result[1].name or 'Unknown'
end

---@param identifier string
---@param type 'bank' | 'cash'
---@param money number
---@return boolean
function RemoveOfflinePlayerMoney(identifier, type, money)
    local result = MySQL.query.await([[
        SELECT accounts
        FROM `users`
        WHERE identifier = ?
    ]], { identifier })

    local accounts = json.decode(result[1].accounts)
    accounts[type] = accounts[type] - money
    if accounts[type] < 0 then return false end

    return MySQL.update.await([[
        UPDATE `users`
        SET accounts = ?
        WHERE identifier = ?
    ]], {
        json.encode(accounts),
        identifier
    }) > 0
end

---@param identifier string
---@param type 'bank' | 'cash'
---@param money number
---@return boolean
function AddOfflinePlayerMoney(identifier, type, money)
    local result = MySQL.query.await([[
        SELECT accounts
        FROM `users`
        WHERE identifier = ?
    ]], { identifier })
    local accounts = json.decode(result[1].accounts)
    accounts[type] = accounts[type] + money

    return MySQL.update.await([[
        UPDATE `users`
        SET accounts = ?
        WHERE identifier = ?
    ]], {
        json.encode(accounts),
        identifier
    }) > 0
end

function GetJobGrades(jobName)
    local jobs = ESX.GetJobs()
    local grades = {}

    for _, data in pairs(jobs[jobName].grades) do
        grades[#grades+1] = {
            grade = data.grade,
            name = data.label,
            isBoss = data.grade_name == 'boss'
        }
    end
    return grades
end