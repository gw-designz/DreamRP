--[[
    Provided below is the stash configuration, allowing you to make
    adjustments or create your own. If your inventory is not included,
    you have the option to request the creator to generate a file based
    on this example and include it.
]]

if Config.Inventory ~= "ox_inventory" then
    return
end


if IsDuplicityVersion() then
    function RegisterStash(name, label, maxSlots, maxWeight, coords)
        exports.ox_inventory:RegisterStash(name, label, maxSlots, maxWeight, nil, nil, coords)
    end
    function ClearStash(name)
        exports.ox_inventory:ClearInventory(name)
    end
    function ForceOpenInventory(source, name)
        exports.ox_inventory:forceOpenInventory(source, 'stash', name)
    end
    function IsInventoryEmpty(stash)
        local items = exports.ox_inventory:GetInventoryItems(stash)
        if type(items) ~= 'table' then return true end
        if type(items) == 'table' and table.type(items) == 'empty' then return true end
        return false
    end
    function RemoveItem(source, item, amount)
        exports.ox_inventory:RemoveItem(source, item, amount)
    end
    function HasItem(source, item, amount)
        return exports.ox_inventory:GetItemCount(source, item) >= amount
    end
else
    function OpenStash(stash)
        exports.ox_inventory:openInventory('stash', stash.name)
    end
    function IsInventoryEmpty(stashName)
        return lib.callback.await("nolag_properties:server:isInventoryEmpty", false, stashName)
    end
end

Config.Functions["OpenInventory"] = {
    type = "inside",    -- inside or outside
    maxPerProperty = 1, -- The maximum amount of inventory menu's per property
    radius = 1.0,       -- The radius of the interaction
    label = "Inventory",
    icon = "fas fa-box-open",
    requireKeys = true, -- Require keys to access inventory
    breakable = true, -- Can be broken with lockpick
    canMove = function (property, point)
        local isInventoryEmpty = IsInventoryEmpty("property_" .. point.id)
        return isInventoryEmpty, locale("property_inventory_not_empty")
    end,
    canDelete = function (property, point)
        local isInventoryEmpty = IsInventoryEmpty("property_" .. point.id)
        return isInventoryEmpty, locale("property_inventory_not_empty")
    end,
    onSelect = function(property, point)
        if property.metadata.lockdown and Config.PoliceLockdown.DisableInventory then
            Framework.Notify({
                description = locale("property_under_police_lockdown"),
                type = "error"
            })
            return
        end
        lib.print.debug("Opening inventory for property: " .. point.id)
        exports.ox_inventory:openInventory('stash', "property_" .. point.id)
    end,
}
