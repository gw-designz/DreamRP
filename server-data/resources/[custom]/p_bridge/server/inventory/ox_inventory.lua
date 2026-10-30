if (Config.Inventory == 'auto' and not checkResource('ox_inventory')) or (Config.Inventory ~= 'auto' and Config.Inventory ~= 'ox_inventory') then
    return
end

while not Bridge do
    Citizen.Wait(0)
end

if Config.Debug then
    lib.print.info('[Inventory] Loaded: ox_inventory')
end

Bridge.Inventory = {}

--@param playerId: number [existing player id]
--@return items: table [{name: string, amount: number, metadata: table, slot: number}]
Bridge.Inventory.getPlayerItems = function(playerId)
    return exports['ox_inventory']:GetInventoryItems(playerId)
end

--@param itemName: string [item name]
--@return itemData: table|nil [{name: string, label: string, description: string, image: string}]
Bridge.Inventory.getItemData = function(itemName)
    local info = exports['ox_inventory']:Items(itemName)
    return info and {name = itemName, label = info.label, description = info.description, image = ('https://cfx-nui-ox_inventory/web/images/%s.png'):format(itemName)}
end

--@param stashId: string [unique stash id]
--@param label: string [stash label]
--@param slots: number [stash slots]
--@param maxWeight: number [stash max weight]
Bridge.Inventory.registerStash = function(stashId, label, slots, maxWeight)
    exports['ox_inventory']:RegisterStash(stashId, label, slots, maxWeight)
end

--@param inventoryId: string|number [stash id or player id]
--@return inventory: table|nil [{items: table, ...}]
Bridge.Inventory.getInventory = function(inventoryId)
    return exports['ox_inventory']:GetInventory(inventoryId, false)
end

--@param inventoryId: string|number [stash id or player id]
Bridge.Inventory.clearInventory = function(inventoryId)
    exports['ox_inventory']:ClearInventory(inventoryId)
end

--@param playerId: number [existing player id]
--@param slot: number [item slot]
--@param metadata: table [new metadata]
Bridge.Inventory.setMetadata = function(playerId, slot, metadata)
    exports['ox_inventory']:SetMetadata(playerId, slot, metadata)
end

--@param event: string [ox_inventory hook event]
--@param cb: function [hook callback]
--@param options: table|nil [hook options]
Bridge.Inventory.registerHook = function(event, cb, options)
    return exports['ox_inventory']:registerHook(event, cb, options)
end

--@param prefix: string [prefix for the drop]
--@param items: table [name: string, count: number, metadata: table]
--@param coords: vector3 [drop coordinates]
Bridge.Inventory.CustomDrop = function(prefix, items, coords)
    exports['ox_inventory']:CustomDrop(prefix, items, coords)
end

--@param playerId: number [existing player id]
--@param itemName: string [item name]
--@param itemCount: number [amount of items to add]
--@param itemMetadata: table [item metadata, optional]
--@param itemSlot: number [item slot, optional]
Bridge.Inventory.addItem = function(playerId, itemName, itemCount, itemMetadata, itemSlot)
    exports['ox_inventory']:AddItem(playerId, itemName, itemCount, itemMetadata, itemSlot)
end

--@param playerId: number [existing player id]
--@param itemName: string [item name]
--@param itemCount: number [amount of items to add]
--@param itemMetadata: table [item metadata, optional]
--@param itemSlot: number [item slot, optional]
Bridge.Inventory.removeItem = function(playerId, itemName, itemCount, itemMetadata, itemSlot)
    exports['ox_inventory']:RemoveItem(playerId, itemName, itemCount, itemMetadata, itemSlot)
end

--@param playerId: number [existing player id]
--@param itemName: string [item name]
--@param itemMetadata: table [item metadata, optional]
--@return count: number [amount of items in inventory]
Bridge.Inventory.getItemCount = function(playerId, itemName, itemMetadata)
    return exports['ox_inventory']:Search(playerId, 'count', itemName, itemMetadata)
end

Bridge.Inventory.getItemSlot = function(playerId, slot)
    return exports['ox_inventory']:GetSlot(playerId, slot)
end

Bridge.Inventory.createShop = function(shopName, data)
    while GetResourceState('ox_inventory') ~= 'started' do
        Citizen.Wait(100)
    end

    Citizen.Wait(100)
    exports['ox_inventory']:RegisterShop(shopName, data)
end