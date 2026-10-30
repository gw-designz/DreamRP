local medical = {}

---@param src number | string
---@param amount number
function medical.healPlayer(src, amount)
    exports.tk_ambulancejob:revive(src, true)
end

return medical