if not Config.Modules.TIRE_SLASH then
    return
end

while not eventName do
    Wait(0)
end

RegisterServerEvent(eventName .. "server:tireSlashSync")
AddEventHandler(eventName .. "server:tireSlashSync", function(targetNetId, tireIndex)
    if Main.isJobBlacklisted(Main, source, "TIRE_SLASH") then return end
    TriggerClientEvent(eventName .. "client:tireSlashSync", targetNetId, tireIndex)
end)

RegisterServerEvent(eventName .. "server:tireSlashDone")
AddEventHandler(eventName .. "server:tireSlashDone", function()
    if Main.isJobBlacklisted(Main, source, "TIRE_SLASH") then return end
    sendWebhook(source, "TIRE_SLASH", "Slashed a tire")
end)
