local vkeys = {}

-- https://docs.okokscripts.io/scripts/okokgarage#server

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    TriggerEvent("okokGarage:GiveKeys", plate)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    TriggerEvent("okokGarage:RemoveKeys", plate, src)
end

return vkeys