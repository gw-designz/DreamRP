local vfuel = {}

---@param netId number
---@param amount number
local function setFuel(netId, amount)
    local localVehicle = NetworkGetEntityFromNetworkId(netId)
    if not localVehicle then return end

    exports['Renewed-Fuel']:SetFuel(localVehicle, amount)
end

---@param vehicle number
---@return number
function vfuel.get(vehicle)
    if not vehicle or not DoesEntityExist(vehicle) then
        return 0
    end

    local fuel = exports['Renewed-Fuel']:GetFuel(vehicle)
    return fuel or 0
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:client:setFuel", setFuel)
end

return vfuel
