local vkeys = {}

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    return exports.MrNewbVehicleKeys:GiveKeysByPlate(plate)

end

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end
    exports.MrNewbVehicleKeys:RemoveKeysByPlate(plate)
end

return vkeys