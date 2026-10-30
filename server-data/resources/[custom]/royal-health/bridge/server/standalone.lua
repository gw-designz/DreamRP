if Config.Framework == 'STANDALONE' then
    Bridge = Bridge or {}

    function Bridge.GetJobName(src)
        return nil
    end

    function Bridge.Revive(src)
        TriggerClientEvent('royal-health:client:revive', src)
        return true
    end
end
