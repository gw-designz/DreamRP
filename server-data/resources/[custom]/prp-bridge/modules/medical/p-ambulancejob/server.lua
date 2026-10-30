local medical = {}

---@param src number | string
---@param amount number
function medical.healPlayer(src, amount)
    local target = tonumber(src)
    if not target then return end

    TriggerClientEvent('p_ambulancejob/client/death/revive', target)
end

return medical
