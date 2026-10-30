local vkeys = {}

-- https://docs.wasabiscripts.com/wasabi-scripts/advanced-series/wasabi_carlock/exports

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports.wasabi_carlock:GiveKey(src, plate)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports.wasabi_carlock:RemoveKey(src, plate)
end

return vkeys