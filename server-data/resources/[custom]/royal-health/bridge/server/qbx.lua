if Config.Framework == 'QBX' then
    Bridge = Bridge or {}

    function Bridge.GetJobName(src)
        local player = exports.qbx_core:GetPlayer(src)
        return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
    end

    function Bridge.Revive(src)
        TriggerClientEvent('royal-health:client:revive', src)
        exports.qbx_medical:Revive(src)
        exports.qbx_core:SetMetadata(src, 'isDead', false)
        return true
    end
end
