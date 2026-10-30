if Config.Framework == 'OX' then
    Bridge = Bridge or {}

    function Bridge.GetJobName(src)
        local player = Ox and Ox.GetPlayer and Ox.GetPlayer(src)
        if not player then return end
        return player.get and player.get('activeGroup')
    end

    function Bridge.Revive(src)
        TriggerClientEvent('royal-health:client:revive', src)
        Player(src).state:set('isDead', false)
        return true
    end
end
