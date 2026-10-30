


if Config.Dispatch ~= "dispatch_name" then
    return
end

if IsDuplicityVersion() then
    -- Server side functions
    ---commented by noLag
    ---@param notifyData table { label: string, coords: vector3 }
    RegisterNetEvent('nolag_properties:server:property:breached', function(notifyData)
        -- Server side job check
        if not Framework.isPlayerAuthorizedToRaid() then return end
        -- Send the notification to the client
        TriggerClientEvent('nolag_properties:client:property:breached', -1, notifyData)
    end)
else
    -- Client side functions
    RegisterNetEvent('nolag_properties:client:property:breached', function(notifyData)
        -- Client side job check
        if not Framework.isPlayerAuthorizedToRaid() then return end
        -- Notify the player
        Framework.Notify({
            description = locale('property_breached', notifyData.label),
            type = 'error'
        })
    end)
end
