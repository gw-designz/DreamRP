local vkeys = {}

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports.MrNewbVehicleKeys:GiveKeysByPlate(src, plate)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports.MrNewbVehicleKeys:RemoveKeysByPlate(src, plate)
end

return vkeys