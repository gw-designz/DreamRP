
Inventory = Inventory or {};

CreateThread(function()
    if Config.Inventory ~= 'tgiann-inventory' then
        return
    end

    function Inventory:Init()
        while GetResourceState('tgiann-inventory') ~= 'started' do
            Wait(100)
        end
     
        if Config.Framework == 'esx' then
            ESX = ESX or exports['es_extended']:getSharedObject()

            for _,v in pairs(Main.usableItems) do
                ESX.RegisterUsableItem(v.name, function(src, name, item)
                    local itemName = item.name
    
                    v.use(src, itemName)
                end)
            end
        elseif Config.Framework == 'qbcore' then
            QBCore = QBCore or exports['qb-core']:GetCoreObject()
     
            for _,v in pairs(Main.usableItems) do
                QBCore.Functions.CreateUseableItem(v.name, function(src, item)
                    local itemName = item.name
    
                    v.use(src, itemName)
                end)
            end
        elseif Config.Framework == 'qbox' then
            for _,v in pairs(Main.usableItems) do
                exports.qbx_core:CreateUseableItem(v.name, function(src, item)
                    local itemName = item.name
    
                    v.use(src, itemName)
                end)
            end
        else
            Trace('Unsupported framework for tgiann-inventory')
        end
    end
     
    local items = nil

    -- tgiann item labels/descriptions can be multi-language objects such as
    -- { en = "Water", tr = "Su" }. The editor NUI expects plain strings, and
    -- passing the raw object crashes React ("objects are not valid as a React
    -- child"). Resolve to a string: configured locale -> en -> first string -> fallback.
    local function resolveLocalized(value, fallback)
        if type(value) == 'string' then return value end
        if type(value) == 'table' then
            local lang = (tostring(Config.Locale or 'en-US'):sub(1, 2)):lower()
            if type(value[lang]) == 'string' then return value[lang] end
            if type(value.en) == 'string' then return value.en end
            for _, entry in pairs(value) do
                if type(entry) == 'string' then return entry end
            end
        end
        return fallback
    end

    function Inventory:getItems()
        if not items then
            items = {}

            for k, v in pairs(exports['tgiann-inventory']:Items()) do
                table.insert(items, {
                    name = k,
                    label = resolveLocalized(v.label, k),
                    description = resolveLocalized(v.description, nil),
                    image = 'nui://inventory_images/images/' .. (v.image or (v.name and v.name .. '.png' or '')),
                    unique = v.stack == false or v.unique
                })
            end
        end

        return items
    end
     
    function Inventory:getPlayerInventory(src)
        local inventory = exports['tgiann-inventory']:GetPlayerItems(src)
     
        if not inventory then
            return false
        end
     
        local items = {}
     
        for _, v in pairs(inventory) do
            table.insert(items, {
                item = v.name,
                slot = v.slot,
                quantity = v.amount,
                metadata = v.metadata or {},
            })
        end
        return items
    end
     
    function Inventory:getPlayerItemsCount(src)
        local inventory = exports['tgiann-inventory']:GetPlayerItems(src)
     
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
                if exports['tgiann-inventory']:AddItem(src, item, 1, nil, metadata) == false then
                    return false
                end
            end
     
            return true
        end
     
        return exports['tgiann-inventory']:AddItem(src, item, amount, nil, metadata) ~= false
    end
     
    function Inventory:removePlayerItem(src, item, amount)
        return exports['tgiann-inventory']:RemoveItem(src, item, amount) ~= false
    end
     
    function Inventory:getSpecificPlayerItem(src, data)
        local item = exports['tgiann-inventory']:GetItemBySlot(src, data.slot)
     
        if not item then
            return false
        end
     
        return {
            item = item.name,
            metadata = item.metadata or {},
        }
    end
     
    function Inventory:removeSpecificPlayerItem(src, data, amount)
        return exports['tgiann-inventory']:RemoveItem(src, data.item, amount, data.slot)
    end
     
    function Inventory:setMetadata(src, data, metadata)
        local item = exports['tgiann-inventory']:GetItemBySlot(src, data.slot, metadata)
     
        if not item or item.name ~= data.item then
            return false
        end
     
        item.info = metadata
     
        return exports['tgiann-inventory']:SetItemData(src, item.name, data.slot, metadata)
    end
     
    function Inventory:canCarryItems(src, items)
        return exports["tgiann-inventory"]:CanCarryItems(src, items)
    end
end)
