local vkeys = {}

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["wasabi_carlock"]:GiveKey(plate)
end

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(vehicle, plate)
    exports["wasabi_carlock"]:RemoveKey(plate)
end

return vkeys