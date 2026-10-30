if Config.Framework == 'ESX' then
    Bridge = Bridge or {}

    local ESX = exports['es_extended']:getSharedObject()

    function Bridge.GetJobName()
        local data = ESX.GetPlayerData()
        return data and data.job and data.job.name
    end

    function Bridge.IsDead()
        local data = ESX.GetPlayerData()
        if data and data.dead ~= nil then
            return data.dead == true
        end
        return IsEntityDead(cache.ped)
    end

    function Bridge.IsLoaded()
        local data = ESX.GetPlayerData()
        return data ~= nil and data.job ~= nil
    end

    RegisterNetEvent('esx_ambulancejob:revive', function()
        TriggerEvent('royal-health:client:clearInjuries')
    end)
end
