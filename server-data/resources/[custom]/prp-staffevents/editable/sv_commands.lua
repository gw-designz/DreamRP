CreateThread(function()
    bridge.fw.registerCommand("events", locale("EVENTS_COMMAND_HELP"), nil, nil, function(src, args, rawCommand)
        local stateId = bridge.fw.getIdentifier(src)
        if not stateId then return end
        if not EventPermission:HasAccess(stateId) then
            return bridge.fw.notify(src, 'error', locale("NO_ACCESS"))
        end

        ---@diagnostic disable-next-line: param-type-mismatch
        local isAdmin = bridge.fw.isAdmin(src)

        TriggerClientEvent("prp-staffevents:openMenu", src, isAdmin, EventPermission:GetPermissions(stateId))
    end)
end)