if Config.Framework ~= 'qbcore' then
    return
end

OnPlayerLoadedEvent = 'QBCore:Server:OnPlayerLoaded'   -- networked
OnPlayerUnloadedEvent = "QBCore:Server:OnPlayerUnload" -- non-networked

QBCore = exports['qb-core']:GetCoreObject()
Framework = {
    GetPlayers = QBCore.Functions.GetPlayers,

    GetPlayerFromId = function(source)
        local xPlayer = {}
        local qbPlayer = QBCore.Functions.GetPlayer(source)
        ---------
        if not qbPlayer then
            return nil
        end
        xPlayer.source = qbPlayer.PlayerData.source
        ---------
        xPlayer.identifier = qbPlayer.PlayerData.citizenid
        ---------
        local gradeName = 'none'
        local gradeLevel = -1

        if qbPlayer.PlayerData.job.grade then
            gradeName = qbPlayer.PlayerData.job.grade.name
            gradeLevel = qbPlayer.PlayerData.job.grade.level
        end

        xPlayer.job = {
            name = qbPlayer.PlayerData.job.name,
            label = qbPlayer.PlayerData.job.label,
            grade = gradeLevel,
            grade_name = gradeName,
            isboss = qbPlayer.PlayerData.job.isboss
        }
        ---------
        xPlayer.getName = function()
            if qbPlayer.PlayerData.charinfo and qbPlayer.PlayerData.charinfo.firstname and qbPlayer.PlayerData.charinfo.lastname then
                return qbPlayer.PlayerData.charinfo.firstname .. ' ' .. qbPlayer.PlayerData.charinfo.lastname
            else
                return qbPlayer.PlayerData.name
            end
        end
        ---------
        xPlayer.addAccountMoney = function(type, money)
            if type == 'money' then
                type = 'cash'
            end
            qbPlayer.Functions.AddMoney(type, money)
        end
        ---------
        xPlayer.getAccount = function(type)
            if type == 'money' then
                type = 'cash'
            end
            return {
                money = qbPlayer.Functions.GetMoney(type) or 0
            }
        end
        ---------
        xPlayer.removeAccountMoney = function(type, money, reason)
            if type == 'money' then
                type = 'cash'
            end
            return qbPlayer.Functions.RemoveMoney(type, money, reason)
        end
        ---------
        xPlayer.setMeta = function(key, val)
            return qbPlayer.Functions.SetMetaData(key, val)
        end
        ---------
        xPlayer.getMeta = function(key)
            return qbPlayer.Functions.GetMetaData(key)
        end
        ---------
        xPlayer.clearMeta = function(key)
            return qbPlayer.Functions.SetMetaData(key, nil)
        end
        return xPlayer
    end,
    GetPlayerFromIdentifier = function(citizenid)
        local qbPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
        if not qbPlayer then
            qbPlayer = QBCore.Player.GetOfflinePlayer(citizenid)

            if not qbPlayer then
                return nil
            end

            local gradeName = 'none'
            local gradeLevel = -1

            if qbPlayer.PlayerData.job.grade then
                gradeName = qbPlayer.PlayerData.job.grade.name
                gradeLevel = qbPlayer.PlayerData.job.grade.level
            end

            return {
                source = qbPlayer.PlayerData.source,
                ---------
                identifier = qbPlayer.PlayerData.citizenid,
                ---------
                job = {
                    name = qbPlayer.PlayerData.job.name,
                    label = qbPlayer.PlayerData.job.label,
                    grade = gradeLevel,
                    grade_name = gradeName,
                    isboss = qbPlayer.PlayerData.job.isboss
                },
                ---------
                getName = function()
                    if qbPlayer.PlayerData.charinfo and qbPlayer.PlayerData.charinfo.firstname and qbPlayer.PlayerData.charinfo.lastname then
                        return qbPlayer.PlayerData.charinfo.firstname .. ' ' .. qbPlayer.PlayerData.charinfo.lastname
                    else
                        return qbPlayer.PlayerData.name
                    end
                end,
                ---------
                addAccountMoney = function(type, money)
                    if type == 'money' then
                        type = 'cash'
                    end
                    qbPlayer.Functions.AddMoney(type, money)
                end,
                ---------
                getAccount = function(type)
                    if type == 'money' then
                        type = 'cash'
                    end
                    return {
                        money = qbPlayer.Functions.GetMoney(type) or 0
                    }
                end,
                ---------
                removeAccountMoney = function(type, money, reason)
                    if type == 'money' then
                        type = 'cash'
                    end
                    return qbPlayer.Functions.RemoveMoney(type, money, reason)
                end,
                ---------
                setMeta = function(key, val)
                    return qbPlayer.Functions.SetMetaData(key, val)
                end,
                ---------
                getMeta = function(key)
                    return qbPlayer.Functions.GetMetaData(key)
                end,
                ---------
                clearMeta = function(key)
                    return qbPlayer.Functions.SetMetaData(key, nil)
                end,
            }
        end
        return Framework.GetPlayerFromId(qbPlayer.PlayerData.source)
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
function UpdatePlayerCooords(identifier, coords)
    local playersTable = 'players'
    return MySQL.update.await([[
        UPDATE `]] .. playersTable .. [[`
        SET position = ?
        WHERE citizenid = ?
    ]], {
        json.encode(coords),
        identifier
    }) > 0
end

---@return OfflinePlayer[]
function GetAllOfflinePlayersWithNames()
    local result = MySQL.query.await([[
        SELECT 
            citizenid as identifier, 
            CONCAT(
                JSON_VALUE(charinfo, '$.firstname'), 
                ' ', 
                JSON_VALUE(charinfo, '$.lastname')
            ) AS name
        FROM `players`;
    ]])
    return result
end

---@param identifier string
---@return string
function GetOfflinePlayerName(identifier)
    local playersTable = 'players'
    local result = MySQL.query.await([[
          SELECT
              JSON_VALUE(charinfo, '$.firstname') AS firstname,
              JSON_VALUE(charinfo, '$.lastname') AS lastname
          FROM `]] .. playersTable .. [[`
          WHERE citizenid = ?
      ]], { identifier })
    return result[1] and result[1].firstname .. ' ' .. result[1].lastname or 'Unknown'
end

---@param identifier string
---@param type 'bank' | 'cash'
---@param money number
---@param reason? string
---@return boolean
function RemoveOfflinePlayerMoney(identifier, type, money, reason)
    local playersTable = 'players'
    local result = MySQL.single.await([[
        SELECT money
        FROM `]] .. playersTable .. [[`
        WHERE citizenid = ?
        LIMIT 1
    ]], { identifier })

    if not result then
        return false
    end

    local playerAccount = json.decode(result.money)
    playerAccount[type] = playerAccount[type] - money
    if playerAccount[type] < 0 then
        return false
    end

    return MySQL.update.await([[
        UPDATE `]] .. playersTable .. [[`
        SET money = ?
        WHERE citizenid = ?
    ]], {
        json.encode(playerAccount),
        identifier
    }) > 0
end

---@param identifier string
---@param type 'bank' | 'cash'
---@param money number
---@param reason? string
---@return boolean
function AddOfflinePlayerMoney(identifier, type, money, reason)
    local playersTable = 'players'
    local result = MySQL.single.await([[
        SELECT money
        FROM `]] .. playersTable .. [[`
        WHERE citizenid = ?
        LIMIT 1
    ]], { identifier })

    if not result then
        return false
    end

    local playerAccount = json.decode(result.money)
    playerAccount[type] = playerAccount[type] + money

    return MySQL.update.await([[
        UPDATE `]] .. playersTable .. [[`
        SET money = ?
        WHERE citizenid = ?
    ]], {
        json.encode(playerAccount),
        identifier
    }) > 0
end


function GetJobGrades(jobName)
    local grades = {}
    if not QBCore.Shared.Jobs[jobName] then
        return grades
    end
    for grade, data in pairs(QBCore.Shared.Jobs[jobName].grades) do
        grades[#grades+1] = {
            grade = grade,
            name = data.name,
            isBoss = data.isboss == true
        }
    end

    return grades
end

RegisterNetEvent('nolag_properties:server:LogoutLocation', function()
    local src = source
    if not src then return end

    local Player = QBCore.Functions.GetPlayer(src)
    local MyItems = Player.PlayerData.items
    MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?',
        { json.encode(MyItems), Player.PlayerData.citizenid })
    QBCore.Player.Logout(src)
    TriggerClientEvent('qb-multicharacter:client:chooseChar', src)
end)
