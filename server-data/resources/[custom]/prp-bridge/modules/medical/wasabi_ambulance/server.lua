local medical = {}

---@param src number | string
---@param amount number
function medical.healPlayer(src, amount)
    local target = tonumber(src)
    if not target then return end

    if GetResourceState('wasabi_ambulance') == 'started' then
        exports['wasabi_ambulance']:RevivePlayer(target)
        return
    end

    if GetResourceState('wasabi_ambulance_v2') == 'started' then
        exports['wasabi_ambulance_v2']:RevivePlayer(target)
    end
end

return medical
