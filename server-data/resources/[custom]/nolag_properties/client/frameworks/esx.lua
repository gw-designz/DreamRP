if Config.Framework ~= 'esx' then
    return
end

local esx_name = "es_extended"
OnPlayerLoadedEvent = "esx:playerLoaded"
OnPlayerUnloadedEvent = "esx:onPlayerLogout"
OnJobUpdateEvent = "esx:setJob"

Framework = {}
local ESX = exports[esx_name]:getSharedObject()
local ESXPlayerData = ESX.GetPlayerData()

PlayerData = {
    insideBigZone = {},     -- don't change this
    insideYards = {}, -- don't change this
    insideMlos = {}, -- don't change this
    insideProperty = false, -- don't change this
    currentProperty = nil, -- don't change this
    identifier = ESXPlayerData?.identifier or nil,
    job = ESXPlayerData?.job or nil,
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
        return PlayerData.job.name == society and PlayerData.job.grade_name == "boss"
    end,
}

RegisterNetEvent(OnPlayerLoadedEvent, function(xPlayer)
    if GetInvokingResource() then return end

    ESXPlayerData = xPlayer
    PlayerData.identifier = ESXPlayerData.identifier
    PlayerData.job = ESXPlayerData.job
end)

RegisterNetEvent(OnPlayerUnloadedEvent, function()
    if GetInvokingResource() then return end

    PlayerData.identifier = nil
    PlayerData.job = nil
end)

RegisterNetEvent(OnJobUpdateEvent, function(PlayerJob)
    if GetInvokingResource() then return end

    PlayerData.job = PlayerJob
end)
