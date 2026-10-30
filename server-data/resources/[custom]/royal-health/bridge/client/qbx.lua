if Config.Framework == 'QBX' then
    Bridge = Bridge or {}

    function Bridge.GetJobName()
        local data = exports.qbx_core:GetPlayerData()
        return data and data.job and data.job.name
    end

    function Bridge.IsDead()
        if GetResourceState('qbx_medical') == 'started' then
            return exports.qbx_medical:IsDead() or exports.qbx_medical:IsLaststand()
        end
        return LocalPlayer.state.isDead == true or IsEntityDead(cache.ped)
    end

    function Bridge.IsLoaded()
        local data = exports.qbx_core:GetPlayerData()
        return data ~= nil and data.citizenid ~= nil
    end

    RegisterNetEvent('qbx_medical:client:playerRevived', function()
        TriggerEvent('royal-health:client:clearInjuries')
    end)

    AddEventHandler('hospital:client:Revive', function()
        TriggerEvent('royal-health:client:clearInjuries')
    end)
end
