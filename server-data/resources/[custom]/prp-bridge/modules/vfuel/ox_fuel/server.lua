local vfuel = {}

---@param source number
---@param vehicle number
---@param amount number
---@return boolean
function vfuel.set(source, vehicle, amount)
    local state = Entity(vehicle).state
    if not state then return false end
    
    state.fuel = amount
    return true
end

return vfuel