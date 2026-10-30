if Config.Framework == 'ND' then
    Bridge = Bridge or {}

    function Bridge.GetJobName()
        local player = exports.ND_Core:getPlayer()
        return player and player.job
    end

    function Bridge.IsDead()
        local player = exports.ND_Core:getPlayer()
        if player and player.metadata and player.metadata.isDead ~= nil then
            return player.metadata.isDead == true
        end
        return IsEntityDead(cache.ped)
    end

    function Bridge.IsLoaded()
        local player = exports.ND_Core:getPlayer()
        return player ~= nil and player.id ~= nil
    end
end
