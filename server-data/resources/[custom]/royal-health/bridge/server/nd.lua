if Config.Framework == 'ND' then
    Bridge = Bridge or {}

    function Bridge.GetJobName(src)
        local player = exports.ND_Core:getPlayer(src)
        return player and player.job
    end

    function Bridge.Revive(src)
        TriggerClientEvent('royal-health:client:revive', src)
        local player = exports.ND_Core:getPlayer(src)
        player.revive()
        return true
    end
end
