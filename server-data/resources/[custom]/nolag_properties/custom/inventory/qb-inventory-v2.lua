--[[
    Provided below is the stash configuration, allowing you to make
    adjustments or create your own. If your inventory is not included,
    you have the option to request the creator to generate a file based
    on this example and include it.
]]

if Config.Inventory ~= "qb-inventory-v2" then
    return
end

if IsDuplicityVersion() then
    function RegisterStash(name, label, maxSlots, maxWeight, coords)
        exports['qb-inventory']:CreateInventory(name, {
            label = label,
            slots = maxSlots,
            weight = maxWeight,
        })
    end

    RegisterNetEvent('nolag_properties:server:openStorage-qb-inventory', function(id)
        exports['qb-inventory']:OpenInventory(source, id)
    end)

    function ClearStash(name)
        MySQL.query('DELETE FROM inventories WHERE identifier = ?', { name })
    end

    function RemoveItem(source, item, amount)
        exports['qb-inventory']:RemoveItem(source, item, amount)
    end

    function HasItem(source, item, amount)
        return exports['qb-inventory']:HasItem(source, item, amount)
    end
else
    function OpenStash(stash)
        TriggerServerEvent('nolag_properties:server:openStorage-qb-inventory', 'Housing_' .. stash.name)
    end
end

Config.Functions["OpenInventory"] = {
    type = "inside",    -- inside or outside
    maxPerProperty = 1, -- The maximum amount of inventory menu's per property
    radius = 1.0,       -- The radius of the interaction
    label = "Inventory",
    icon = "fas fa-box-open",
    breakable = true, -- Can be broken with lockpick
    onSelect = function(property, point)
        if property.metadata.lockdown and Config.PoliceLockdown.DisableInventory then
            Framework.Notify({
                description = locale("property_under_police_lockdown"),
                type = "error"
            })
            return
        end
        TriggerServerEvent('nolag_properties:server:openStorage-qb-inventory', 'Housing_' .. point.id)
    end,
}
