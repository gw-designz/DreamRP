local vfuel = {}

---@param source number
---@param vehicle number
---@param amount number
---@return boolean
function vfuel.set(source, vehicle, amount)
    if not vehicle or not DoesEntityExist(vehicle) then
        return false
    end

    exports['Renewed-Fuel']:SetFuel(vehicle, amount)
    return true
end

return vfuel
