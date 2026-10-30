if Config.Framework ~= 'standalone' then
    return
end



local framework_name = "custom-framework"
OnPlayerLoadedEvent = "esx:playerLoaded"
OnPlayerUnloadedEvent = "esx:onPlayerLogout"
OnJobUpdateEvent = "esx:setJob"

Framework = {}
local CustomFramework = exports[framework_name]:GetCoreObject()
local CustomPlayerData = CustomFramework.Functions.GetPlayerData()

PlayerData = {
    insideBigZone = {},     -- don't change this
    insideYards = {}, -- don't change this
    insideMlos = {}, -- don't change this
    insideProperty = false, -- don't change this
    currentProperty = nil, -- don't change this
    identifier = CustomPlayerData?.citizenid or nil,
    job = {
        name = CustomPlayerData?.job?.name or nil,
        grade = CustomPlayerData?.job?.grade?.level or nil,
        isboss = CustomPlayerData?.job?.isboss or nil,
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
    isSocietyBoss = function()
        return PlayerData.job.grade_name == "boss"
    end,
}

RegisterNetEvent(OnPlayerLoadedEvent, function()
    CustomPlayerData = CustomFramework.Functions.GetPlayerData()
    PlayerData.identifier = CustomPlayerData.citizenid
    PlayerData.job = {
        name = CustomPlayerData.job.name,
        grade = CustomPlayerData.job.grade.level,
        isboss = CustomPlayerData.job.isboss,
    }
end)

RegisterNetEvent(OnPlayerUnloadedEvent, function()
    PlayerData.identifier = nil
    PlayerData.job = nil
end)

RegisterNetEvent(OnJobUpdateEvent, function()
    CustomPlayerData = CustomFramework.Functions.GetPlayerData()
    PlayerData.job = {
        name = CustomPlayerData.job.name,
        grade = CustomPlayerData.job.grade.level,
        isboss = CustomPlayerData.job.isboss,
    }
end)