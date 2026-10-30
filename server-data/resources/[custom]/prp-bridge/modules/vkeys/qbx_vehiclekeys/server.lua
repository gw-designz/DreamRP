local vkeys = {}

-- https://github.com/Qbox-project/qbx_vehiclekeys/

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    exports["qbx_vehiclekeys"]:GiveKeys(src, vehicle)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    exports["qbx_vehiclekeys"]:RemoveKeys(src, vehicle)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("qbx_vehiclekeys:prp-bridge:giveKey", function(vehicle)
        local src = source
        exports["qbx_vehiclekeys"]:GiveKeys(src, vehicle)
    end)

    RegisterNetEvent("qbx_vehiclekeys:prp-bridge:removeKey", function(vehicle)
        local src = source
        exports["qbx_vehiclekeys"]:RemoveKeys(src, vehicle)
    end)
end

return vkeys