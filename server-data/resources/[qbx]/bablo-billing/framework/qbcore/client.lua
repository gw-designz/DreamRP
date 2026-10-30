
if not IsFrameworkValid() or Config.Framework:lower() ~= 'qbcore' then
    return
end

local QBCore = exports['qb-core']:GetCoreObject()
local m = {}

m.Notify = function(message, type)
    if not message or type == nil then
        Debug:error("Invalid parameters for notify")
        return
    end

    QBCore.Functions.Notify(message, type)
end

m.GetPlayerData = function()
    local player = QBCore.Functions.GetPlayerData()
    return player
end

Framework = m
