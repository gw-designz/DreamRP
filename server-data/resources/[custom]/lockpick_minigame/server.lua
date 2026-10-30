local function hasTierItem(source, tier)
    local settings = Config.Tiers[tier]
    if not settings then return false end
    return (exports.ox_inventory:Search(source, 'count', settings.item) or 0) > 0, settings
end

-- A lockpick was used from the inventory (client.lua useItem). Same hand-off
-- qbx_consumables used to do: qbx_vehiclekeys listens on the client side, house
-- robbery on the server side. isAdvanced keeps the old resources working as they
-- did; tier is extra for the ones updated to use this minigame.
RegisterNetEvent('lockpick_minigame:server:used', function(tier)
    local src = source
    if not hasTierItem(src, tier) then return end

    local isAdvanced = tier ~= 'regular'
    TriggerClientEvent('lockpicks:UseLockpick', src, isAdvanced, tier)
    TriggerEvent('lockpicks:UseLockpick', src, isAdvanced, tier)
end)

-- The client rolled Config.Tiers[tier].breakChance on a failed pick and lost.
-- Only ever removes the player's own pick of that tier.
RegisterNetEvent('lockpick_minigame:server:break', function(tier)
    local src = source
    local owned, settings = hasTierItem(src, tier)
    if not owned then return end
    exports.ox_inventory:RemoveItem(src, settings.item, 1)
end)
