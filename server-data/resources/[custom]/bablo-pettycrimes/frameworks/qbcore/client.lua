
Framework = Framework or {};

CreateThread(function()
    local charLoaded = false

    if Config.Framework ~= 'qbcore' then
        return
    end

    function Framework:getCore()
        return exports['qb-core']:GetCoreObject();
    end

    local QBCore = Framework:getCore();

    function Framework:isCharacterLoaded()
        return charLoaded
    end

    function Framework:Notify(message)
        QBCore.Functions.Notify(message)
    end

    function Framework:skillCheck()
        local success = lib.skillCheck({ 'easy', 'easy', { areaSize = 60, speedMultiplier = 2 }, 'medium' }, { 'e' })

        while lib.skillCheckActive() do
            Wait(0)
        end

        return success
    end

    function Framework:doProgress(progress, cb)
        if lib.progressBar({
                duration = progress.time,
                label = progress.text,
                useWhileDead = false,
                canCancel = true,
            }) then
            cb(true)
        else
            cb(false)
        end
    end

    function Framework:getPlayerJob()
        return QBCore.Functions.GetPlayerData().job.name
    end

    function Framework:canDoAction(action)
        if not Config.Modules[action] then return false end
        if Main and type(Main.isJobBlacklisted) == 'function' and Main:isJobBlacklisted(action) then
            return false
        end

        if action == 'MAILBOX_ROBBERY' then
            return true
        elseif action == 'PARKING_METER_ROBBERY' then
            return true
        elseif action == 'PARCEL_THEFT' then
            return true
        elseif action == 'PICKPOCKETING' then
            return true
        elseif action == 'SMASH_N_GRAB' then
            return true
        elseif action == 'MUGGING' then
            return true
        elseif action == 'ATM_ROBBERY' then
            return true
        elseif action == 'VENDING_MACHINE' then
            return true
        elseif action == 'TIRE_SLASH' then
            return true
        elseif action == 'PEDAL_BRICK' then
            return true
        elseif action == 'CASH_REGISTER_ROBBERY' then
            return true
        elseif action == 'STORE_SHELVES' then
            return true
        end

        return false
    end

    function Framework:onFinished(action)
        -- Override this per-module if you need custom logic when a crime finishes
    end

    Citizen.Wait(1000)

    TriggerEvent(eventName .. 'client:characterLoaded')

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        Citizen.Wait(1000)

        TriggerEvent(eventName .. 'client:characterLoaded')

        charLoaded = true
    end)
end)
