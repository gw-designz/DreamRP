return {
    ---@return number
    getHealth = function()
        return GetEntityHealth(cache.ped)
    end,

    ---@return number
    getMaxHealth = function()
        return GetEntityMaxHealth(cache.ped)
    end,

    ---@return number
    getArmor = function()
        return GetPedArmour(cache.ped)
    end,

    ---@return number
    getMaxArmor = function()
        return GetPlayerMaxArmour(cache.playerId)
    end,
}
