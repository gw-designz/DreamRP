if Config.Banking ~= 'okokBanking' then return end

---@param society string The society that the money will be added to
---@param price number The amount of money that will be added
---@param playerIdentifier string The identifier of the player that executes the action
function AddMoneyToSociety(society, price, playerIdentifier)
    return exports.okokBanking:AddMoney(society, price, 'Test') -- if this export doesn't exist, please look at the documentation
end

---@param society string The society that the money will be removed from
---@param price number The amount of money that will be removed
---@param playerIdentifier string The identifier of the player that executes the action
function RemoveMoneyFromSociety(society, price, playerIdentifier)
    local money = exports.okokBanking:GetAccount(society)
    if money < price then return false end

    local removed = exports.okokBanking:RemoveMoney(society, price, 'Test')
    return removed
end
