if Config.Framework == 'OX' then
    Bridge = Bridge or {}

    function Bridge.GetJobName()
        local player = Ox and Ox.GetPlayer and Ox.GetPlayer()
        if not player then return end
        return player.get and player.get('activeGroup')
    end

    function Bridge.IsDead()
        return IsEntityDead(cache.ped)
    end

    function Bridge.IsLoaded()
        return Ox and Ox.GetPlayer and Ox.GetPlayer() ~= nil
    end
end
