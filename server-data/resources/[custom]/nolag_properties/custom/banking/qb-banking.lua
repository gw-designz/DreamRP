if Config.Banking ~= 'qb-banking' then return end

---@param society string The society that the money will be added to
---@param price number The amount of money that will be added
---@param playerIdentifier string The identifier of the player that executes the action
function AddMoneyToSociety(society, price, playerIdentifier)
    return exports['qb-banking']:AddMoney(society, price, 'Test')
end

---@param society string The society that the money will be removed from
---@param price number The amount of money that will be removed
---@param playerIdentifier string The identifier of the player that executes the action
function RemoveMoneyFromSociety(society, price, playerIdentifier)
    -- RemoveMoney should check if the society has enough money but we will check it here too
    local money = exports['qb-banking']:GetAccountBalance(society)
    if money < price then return false end

    local removed = exports['qb-banking']:RemoveMoney(society, price, 'Test')
    return removed
end
