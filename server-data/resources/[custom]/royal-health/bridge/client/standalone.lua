if Config.Framework == 'STANDALONE' then
    Bridge = Bridge or {}

    function Bridge.GetJobName()
        return nil
    end

    function Bridge.IsDead()
        return IsEntityDead(cache.ped)
    end

    function Bridge.IsLoaded()
        return true
    end
end
