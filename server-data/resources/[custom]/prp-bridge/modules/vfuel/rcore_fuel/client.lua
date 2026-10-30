local vfuel = {}

---@param netId number
---@param amount number
local function setFuel(netId, amount)
    local localVehicle = NetworkGetEntityFromNetworkId(netId)
    if not localVehicle or localVehicle == 0 or not DoesEntityExist(localVehicle) then return end

    amount = tonumber(amount)
    if not amount then return end

    exports["rcore_fuel"]:SetVehicleFuel(localVehicle, amount)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:client:setFuel", setFuel)
end

return vfuel
