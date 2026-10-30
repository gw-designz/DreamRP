if Config.Framework ~= 'qbcore' then
    return
end

local qb_name = "qb-core"
OnPlayerLoadedEvent = "QBCore:Client:OnPlayerLoaded"
OnPlayerUnloadedEvent = "QBCore:Client:OnPlayerUnload"
OnJobUpdateEvent = "QBCore:Client:OnJobUpdate"

Framework = {}
local QBCore = exports[qb_name]:GetCoreObject()
local QBPlayerData = QBCore.Functions.GetPlayerData()

PlayerData = {
    insideBigZone = {},     -- don't change this
    insideYards = {}, -- don't change this
    insideMlos = {}, -- don't change this
    insideProperty = false, -- don't change this
    currentProperty = nil, -- don't change this
    identifier = QBPlayerData?.citizenid or nil,
    job = {
        name = QBPlayerData?.job?.name or nil,
        grade = QBPlayerData?.job?.grade?.level or nil,
        isboss = QBPlayerData?.job?.isboss or nil,
    },
}

Framework = {
    Notify = function(notifyData)
        lib.notify(notifyData)
    end,
    showTextUI = function(text, options)
        lib.showTextUI(text, options)
    end,
    hideTextUI = function()
        lib.hideTextUI()
    end,
    isPlayerAuthorized = function(jobList)
        local jobs = jobList or Config.RealEstateJobs
        for jobName, grade in pairs(jobs) do
            if jobName == PlayerData.job.name and PlayerData.job.grade >= grade then
                return true
            end
        end
        return false
    end,
    isPlayerAuthorizedToRaid = function()
        for jobName, grade in pairs(Config.PoliceRaid.Jobs) do
            if jobName == PlayerData.job.name and PlayerData.job.grade >= grade then
                return true
            end
        end
        return false
    end,
    isPlayerAuthorizedToLockdown = function()
        return Framework.isPlayerAuthorizedToRaid()
    end,
    isSocietyBoss = function(society)
        return PlayerData.job.name == society and PlayerData.job.isboss == true
    end,
}

RegisterNetEvent(OnPlayerLoadedEvent, function()
    QBPlayerData = QBCore.Functions.GetPlayerData()
    PlayerData.identifier = QBPlayerData.citizenid
    PlayerData.job = {
        name = QBPlayerData.job.name,
        grade = QBPlayerData.job.grade.level,
        isboss = QBPlayerData.job.isboss,
    }
end)

RegisterNetEvent(OnPlayerUnloadedEvent, function()
    PlayerData.identifier = nil
    PlayerData.job = nil
end)

RegisterNetEvent(OnJobUpdateEvent, function(PlayerJob)
    if GetInvokingResource() then return end

    PlayerData.job = {
        name = PlayerJob.name,
        grade = PlayerJob.grade.level,
        isboss = PlayerJob.isboss,
    }
end)