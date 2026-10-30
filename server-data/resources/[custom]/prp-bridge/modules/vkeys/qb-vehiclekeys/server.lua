local vkeys = {}

-- https://github.com/qbcore-framework/qb-vehiclekeys/blob/main/server/main.lua

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["qb-vehiclekeys"]:GiveKeys(src, plate)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["qb-vehiclekeys"]:RemoveKeys(src, plate)
end

return vkeys