if Config.Framework ~= 'ox_core' then
    return
end

OnPlayerLoadedEvent = 'ox:playerLoaded'
OnPlayerUnloadedEvent = 'ox:playerLogout'
OnJobUpdateEvent = 'ox:setGroup'

local import = LoadResourceFile('ox_core', 'lib/init.lua')
local chunk = assert(load(import))
chunk()

Framework = {}
local oxPlayer = Ox.GetPlayer()
local playerGroup, playerGrade = oxPlayer.getGroupByType('job')

PlayerData = {
    insideBigZone = {},     -- don't change this
    insideYards = {},       -- don't change this
    insideMlos = {},        -- don't change this
    insideProperty = false, -- don't change this
    currentProperty = nil,  -- don't change this
    currentCameraProperty = nil, -- don't change this
    identifier = oxPlayer.stateId,
    job = {
        name = playerGroup,
        grade = playerGrade
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
        if not jobList then return true end
        for jobName, grade in pairs(jobList) do
            if jobName == PlayerData.job?.name and PlayerData.job?.grade >= grade then
                return true
            end
        end
        return false
    end,
    isPlayerAuthorizedToRaid = function()
        for jobName, grade in pairs(Config.PoliceRaid.Jobs) do
            if jobName == PlayerData.job?.name and PlayerData.job?.grade >= grade then
                return true
            end
        end
        return false
    end,
    isPlayerAuthorizedToLockdown = function()
        return Framework.isPlayerAuthorizedToRaid()
    end,
    isSocietyBoss = function(society)
        local jobGrade = oxPlayer.getGroup(society)

        if jobGrade then
            local jobState = GlobalState['group.' .. society]
            return (jobState.accountRoles[tostring(jobGrade)] ~= nil and jobState.accountRoles[tostring(jobGrade)] == 'owner')
        end

        return false
    end,
}

RegisterNetEvent(OnPlayerLoadedEvent, function(player)
    PlayerData.identifier = player.stateId

    oxPlayer = Ox.GetPlayer()
    playerGroup, playerGrade = oxPlayer.getGroupByType('job')
    PlayerData.job = {
        name = playerGroup,
        grade = playerGrade
    }
end)

RegisterNetEvent(OnPlayerUnloadedEvent, function()
    PlayerData.identifier = nil
    PlayerData.job = nil
end)

RegisterNetEvent(OnJobUpdateEvent, function(name, grade)
    PlayerData.job = nil
    if grade and grade > 0 then
        PlayerData.job = {
            name = name,
            grade = grade
        }
    end
end)
