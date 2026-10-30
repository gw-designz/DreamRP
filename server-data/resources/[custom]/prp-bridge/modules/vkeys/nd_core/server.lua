NDCore = {}

lib.load('@ND_Core.init')
local vkeys = {}

-- https://github.com/Qbox-project/qbx_vehiclekeys/

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.give(src, vehicle, plate)
    print('giving keys?', src, vehicle)
    NDCore.giveVehicleAccess(src, vehicle, true)
end

---@param src number | string Player server id
---@param vehicle number Vehicle entity
---@param plate? string Vehicle plate
function vkeys.remove(src, vehicle, plate)
    NDCore.giveVehicleAccess(src, vehicle, false)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("nd_core:prp-bridge:giveKey", function(vehicle)
        local src = source
        NDCore.giveVehicleAccess(src, vehicle, true)
    end)

    RegisterNetEvent("nd_core:prp-bridge:removeKey", function(vehicle)
        local src = source
        NDCore.giveVehicleAccess(src, vehicle, false)
    end)
end

return vkeys