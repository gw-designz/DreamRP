local vkeys = {}

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(vehicle, plate)
    TriggerServerEvent("qbx_vehiclekeys:prp-bridge:giveKey", NetworkGetNetworkIdFromEntity(vehicle))
end

---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(vehicle, plate)
    TriggerServerEvent("qbx_vehiclekeys:prp-bridge:removeKey", NetworkGetNetworkIdFromEntity(vehicle))
end

return vkeys