if Config.Banking ~= 'LGMods_Banking' then return end

---@param society string The society that the money will be added to
---@param price number The amount of money that will be added
---@param playerIdentifier string The identifier of the player that executes the action
function AddMoneyToSociety(society, price, playerIdentifier)
    local player = Framework.GetPlayerFromIdentifier(playerIdentifier)
    if not player then return false end

    return exports['LGMods_Banking']:AddMoney(player.source, price, "business", society)
end

---@param society string The society that the money will be removed from
---@param price number The amount of money that will be removed
---@param playerIdentifier string The identifier of the player that executes the action
function RemoveMoneyFromSociety(society, price, playerIdentifier)
    local player = Framework.GetPlayerFromIdentifier(playerIdentifier)
    if not player then return false end

    local success = false

    exports['LGMods_Banking']:GetAccountDetails(player.source, "business", society, function(data)
        if data.success and data.account.balance >= price then
            success = exports['LGMods_Banking']:RemoveMoney(player.source, price, "business", society)
        end
    end)

    return success
end
