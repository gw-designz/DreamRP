---@param model string | number
---@return VehicleData | nil
local function getVehicleData(model)
    model = type(model) == 'string' and joaat(model) or model
    if not BridgeConfig.VehicleData[model] then
        return
    end

    return BridgeConfig.VehicleData[model]
end

exports("GetAllVehicleData", function()
    return BridgeConfig.VehicleData
end)
exports("GetVehicleData", getVehicleData)
