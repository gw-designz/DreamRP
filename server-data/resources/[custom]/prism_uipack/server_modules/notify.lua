---@param playerId number
---@param data table
exports('Notify', function(playerId, data)
    TriggerClientEvent('prism:notify', playerId, data)
end)
