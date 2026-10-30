
Inventory = Inventory or {};

CreateThread(function()
    if Config.Inventory ~= 'origen_inventory' then
        return
    end

    function Inventory:Init()
        while GetResourceState('origen_inventory') ~= 'started' do
            Wait(100)
        end

        for _,v in pairs(Main.usableItems) do
            exports['origen_inventory']:CreateUsableItem(v.name, function(src, item)
                local itemName = item.name
     
                v.use(src, itemName)
            end)
        end
    end
     
    local items = nil
     
    function Inventory:getItems()
        if not items then
            items = {}
     
            for k, v in pairs(exports['origen_inventory']:Items()) do
                table.insert(items, {
                    name = k,
                    label = v.label or k,
                    description = v.description or '',
                    image = 'nui://origen_inventory/html/images/' .. (v.image or k .. '.png'),
                    unique = v.stack == false or v.unique
                })
            end
        end
     
        return items
    end
     
    function Inventory:getPlayerItemsCount(src)
        local inventoryData = exports['origen_inventory']:getInventory(src)
     
        if not inventoryData then
            return false
        end
     
        local items = {}
     
        for _, v in pairs(inventoryData.inventory) do
            if not items[v.name] then
                items[v.name] = v.amount
            else
                items[v.name] = items[v.name] + v.amount
            end
        end
     
        return items
    end
     
    function Inventory:getPlayerInventory(src)
        local inventoryData = exports['origen_inventory']:getInventory(src)
     
        if not inventoryData then
            return false
        end
     
        local items = {}
     
        for _, v in pairs(inventoryData.inventory) do
            table.insert(items, {
                item = v.name,
                slot = v.slot,
                quantity = v.amount,
                metadata = v.metadata,
            })
        end
     
        return items
    end
     
    function Inventory:addPlayerItem(src, item, amount, metadata, options)
        if options then
            metadata = metadata or {}
     
            if options.description then
                metadata.description = options.description
            end
     
            if options.label then
                metadata.label = options.label
            end
        end
     
        if amount > 1 and items and items[item]?.unique then
            -- Give multiple unique items one by one to prevent duplicated metadata
     
            for i = 1, amount do
                if not exports['origen_inventory']:addItem(src, item, 1, metadata) then
                    return false
                end
            end
     
            return true
        end
     
        return exports['origen_inventory']:addItem(src, item, amount, metadata)
    end
     
    function Inventory:removePlayerItem(src, item, amount)
        return exports['origen_inventory']:removeItem(src, item, amount)
    end
     
    function Inventory:getSpecificPlayerItem(src, data)
        local inventoryData = exports['origen_inventory']:getInventory(src)
     
        if not inventoryData then
            return false
        end
     
        for _, item in pairs(inventoryData.inventory) do
            if item.name == data.item and item.slot == data.slot then
                return {
                    item = item.name,
                    metadata = item.metadata,
                }
            end
        end
     
        return false
    end
     
    function Inventory:removeSpecificPlayerItem(src, data, amount)
        return exports['origen_inventory']:removeItem(src, data.item, amount, false, data.slot)
    end
     
    function Inventory:setMetadata(src, data, metadata)
        exports['origen_inventory']:AddItemMetadata(src, data.item, data.slot, metadata)
     
        return true
    end
     
    function Inventory:canCarryItem(src, item, amount)
        return exports['origen_inventory']:CanCarryItem(src, item, amount)
    end    
end)
