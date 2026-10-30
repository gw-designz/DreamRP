local vkeys = {}

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    TriggerClientEvent("cd_garage:AddKeys", src, plate)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    error("mVehicle does not support removing keys")
end

return vkeys