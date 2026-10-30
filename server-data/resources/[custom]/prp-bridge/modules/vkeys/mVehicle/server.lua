local vkeys = {}

-- https://mono-94.github.io/mDocuments/mVehicle/functions/server#addtemporalvehicle

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["mVehicle"].AddTemporalVehicle(src, vehicle)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    error("mVehicle does not support removing keys")
end

return vkeys