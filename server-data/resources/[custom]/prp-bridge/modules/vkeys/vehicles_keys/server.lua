local vkeys = {}

-- https://documentation.jaksam-scripts.com/vehicles-keys/server/give-keys-to-player-id

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["vehicles_keys"]:giveVehicleKeysToPlayerId(src, plate, "temporary")
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    if not plate then
        plate = GetVehicleNumberPlateText(vehicle)
    end

    exports["vehicles_keys"]:removeKeysFromPlayerId(src, plate)
end

return vkeys