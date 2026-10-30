
Inventory = Inventory or {};

CreateThread(function()
    if Config.Inventory ~= 'core_inventory' then
        return
    end

    function Inventory:Init()
        while GetResourceState('core_inventory') ~= 'started' do
            Wait(100)
        end
     
        QBCore = QBCore or exports['qb-core']:GetCoreObject()
     
        for _,v in pairs(Main.usableItems) do
            QBCore.Functions.CreateUseableItem(v.name, function(src, item)
                local itemName = item.name

                v.use(src, itemName)
            end)
        end
    end
     
    local items = nil
     
    function Inventory:getItems()
        if not items then
            items = {}
     
            for _, v in pairs(exports['core_inventory']:getItemsList()) do
                table.insert(items, {
                    name = v.name,
                    label = v.label or v.name,
                    description = v.description or '',
                    image = 'nui://core_inventory/html/images/' .. (v.image or (v.name and v.name .. '.png' or '')),
                    unique = v.stack == false or v.unique
                })
            end
        end
     
        return items
    end
     
    function Inventory:getPlayerItemsCount(src)
        local inventory = exports['core_inventory']:getInventory(src)
     
        if not inventory then
            return false
        end
     
        local items = {}
     
        for _, v in pairs(inventory) do
            if not items[v.name] then
                items[v.name] = v.amount
            else
                items[v.name] = items[v.name] + v.amount
            end
        end
     
        return items
    end
     
    function Inventory:getPlayerInventory(src)
        local inventory = exports['core_inventory']:getInventory(src)
     
        if not inventory then
            return false
        end
     
        local items = {}
     
        for _, v in pairs(inventory) do
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
                if not exports['core_inventory']:addItem(src, item, 1, metadata) then
                    return false
                end
            end
     
            return true
        end
     
        return exports['core_inventory']:addItem(src, item, amount, metadata)
    end
     
    function Inventory:removePlayerItem(src, item, amount)
        return exports['core_inventory']:removeItem(src, item, amount)
    end
     
    function Inventory:getSpecificPlayerItem(src, data)
        local inventory = exports['core_inventory']:getInventory(src)
     
        if not inventory then
            return false
        end
     
        for _, item in pairs(inventory) do
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
        local inventory = exports['core_inventory']:getInventory(src)
     
        if not inventory then
            return false
        end
     
        local item
     
        for _, v in pairs(inventory) do
            if v.name == data.item and v.slot == data.slot then
                item = v
                break
            end
        end
     
        if not item then
            return false
        end
     
        return exports['core_inventory']:removeItemExact(src, item.id, amount)
    end
     
    function Inventory:setMetadata(src, data, metadata)
        exports['core_inventory']:setMetadata(src, data.slot, metadata)
     
        return true
    end
     
    function Inventory:canCarryItem(src, item, amount)
        return exports['core_inventory-inventory']:canCarry(src, item, amount)
    end
end)
