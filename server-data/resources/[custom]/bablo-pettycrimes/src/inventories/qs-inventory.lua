
Inventory = Inventory or {};

CreateThread(function()
    if Config.Inventory ~= 'qs-inventory' then
        return
    end

    function Inventory:Init()
        while GetResourceState('qs-inventory') ~= 'started' do
            Wait(100)
        end

        for _,v in pairs(Main.usableItems) do
            exports['qs-inventory']:CreateUsableItem(v.name, function(src, item)
                local itemName = item.name
     
                v.use(src, itemName)
            end)
        end
    end
     
    local items = nil
     
    function Inventory:getItems()
        if not items then
            items = {}
     
            for k, v in pairs(exports['qs-inventory']:GetItemList()) do
                if v and type(v) == 'table' then
                    table.insert(items, {
                        name = k,
                        label = v.label or k,
                        description = v.description or '',
                        image = 'nui://qs-inventory/html/images/' .. (v.image or k .. '.png'),
                        unique = v.stack == false or v.unique
                    })
                end
            end
        end
     
        return items
    end
     
    function Inventory:getPlayerItemsCount(src)
        local inventory = exports['qs-inventory']:GetInventory(src)
     
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
        local inventory = exports['qs-inventory']:GetInventory(src)
     
        if not inventory then
            return false
        end
     
        local items = {}
     
        for _, v in pairs(inventory) do
            table.insert(items, {
                item = v.name,
                slot = v.slot,
                quantity = v.amount,
                metadata = v.info,
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
                if not exports['qs-inventory']:AddItem(src, item, 1, nil, metadata) then
                    return false
                end
            end
     
            return true
        end
     
        return exports['qs-inventory']:AddItem(src, item, amount, nil, metadata)
    end
     
    function Inventory:removePlayerItem(src, item, amount)
        return exports['qs-inventory']:RemoveItem(src, item, amount)
    end
     
    function Inventory:getSpecificPlayerItem(src, data)
        local inventory = exports['qs-inventory']:GetInventory(src)
     
        if not inventory then
            return false
        end
     
        for _, item in pairs(inventory) do
            if item.name == data.item and item.slot == data.slot then
                return {
                    item = item.name,
                    metadata = item.info,
                }
            end
        end
     
        return false
    end
     
    function Inventory:removeSpecificPlayerItem(src, data, amount)
        return exports['qs-inventory']:RemoveItem(src, data.item, amount, data.slot)
    end
     
    function Inventory:setMetadata(src, data, metadata)
        exports['qs-inventory']:SetItemMetadata(src, data.slot, metadata)
     
        return true
    end
     
    function Inventory:canCarryItem(src, item, amount)
        return exports['qs-inventory']:CanCarryItem(src, item, amount)
    end
end)
