local vfuel = {}

---@param source number
---@param vehicle number
---@param amount number
---@return boolean
function vfuel.set(source, vehicle, amount)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId <= 0 then
        return false
    end

    TriggerClientEvent("prp-bridge:client:setFuel", source, netId, amount)
    return true
end

return vfuel