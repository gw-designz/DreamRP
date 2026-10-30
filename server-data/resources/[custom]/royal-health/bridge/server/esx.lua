if Config.Framework == 'ESX' then
    Bridge = Bridge or {}

    local ESX = exports['es_extended']:getSharedObject()

    function Bridge.GetJobName(src)
        local player = ESX.GetPlayerFromId(src)
        return player and player.getJob and player.getJob().name
    end

    function Bridge.Revive(src)
        TriggerClientEvent('royal-health:client:revive', src)
        local xPlayer = ESX.GetPlayerFromId(src)
        xPlayer.setMeta('isDead', false)
        return true
    end
end
