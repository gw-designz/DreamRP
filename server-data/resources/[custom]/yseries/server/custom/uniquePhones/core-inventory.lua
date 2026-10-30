----
-- NOTICE: This inventory integration is provided as-is.
-- TeamsGG does not provide official support for this integration.
----

CreateThread(function()
    if Config.Item.Inventory ~= "core_inventory" then return end

    local framework = nil
    if Config.Framework == "esx" then
        framework = exports['es_extended']:getSharedObject()
    elseif Config.Framework == "qb" then
        framework = exports["qb-core"]:GetCoreObject()
    end

    ---Function to get all items a player has with a specific name
    ---@param source number
    ---@param name string
    ---@return table items
    local function getItemsByName(source, name)
        local playerIdentifier = Framework.GetPlayerFromId(source)?.identifier
        if playerIdentifier then
            playerIdentifier = playerIdentifier:gsub(':', '')

            local inventoryIdentifier = 'content-' .. playerIdentifier
            local inventory = exports['core_inventory']:getInventory(inventoryIdentifier)

            local items = {}
            for _, v in pairs(inventory) do
                if v.name == name then
                    items[#items + 1] = v
                end
            end

            return items
        end

        return {}
    end

    --- Get a sim card item from a player's inventory by sim number
    ---@param playerId number The player's ID
    ---@param simNumber string The sim card's number
    ---@return { simNumber: string, cardId: number, slot: number, itemId?: string } | nil
    function GetSimCardItem(playerId, simNumber)
        local items = getItemsByName(playerId, Config.Sim.ItemName)

        for _, item in pairs(items) do
            if item.info.simNumber == simNumber then
                return {
                    cardId = item.metadata.cardId,
                    simNumber = item.metadata.simNumber,
                    itemId = item.info.id,
                }
            end
        end

        return nil
    end

    --- Give a sim card item to player's inventory.
    ---@param playerId number The player's ID
    ---@param cardId number The card's unique ID
    ---@param simNumber string The card number
    ---@return { success: boolean, message: string }
    function GiveSimCardItem(playerId, cardId, simNumber)
        if not playerId or not tonumber(playerId) then return { success = false, message = "Invalid player ID" } end

        local canCarry = exports.core_inventory:canCarry(playerId, Config.Sim.ItemName, 1, {
            cardId = cardId,
            simNumber = simNumber,
        })

        if not canCarry then return { success = false, message = "Cannot carry item" } end

        local success = exports.core_inventory:addItem(playerId, Config.Sim.ItemName, 1, {
            cardId = cardId,
            simNumber = simNumber,
        }, 'content')

        if not success then return { success = false, message = "Failed to add sim card to your inventory" } end

        return { success = true, message = "Sim card added to your inventory" }
    end

    --- Remove a sim card item from a player's inventory by card ID
    ---@param playerId number The player's ID
    ---@param simNumber string The card's unique ID
    ---@return boolean
    function RemoveSimCardItem(playerId, simNumber)
        if not playerId or not tonumber(playerId) then return false end

        local inventory = exports.core_inventory:getInventory(playerId)

        for _, item in pairs(inventory) do
            if item.name == Config.Sim.ItemName and item.info.simNumber == simNumber then
                return exports.core_inventory:removeItem(playerId, Config.Sim.ItemName, 1)
            end
        end

        return false
    end

    lib.callback.register('yseries:server:assign-item-metadata', function(source, item, metadata)
        exports.core_inventory:setMetadata(source, item.slot, metadata)

        return true
    end)

    -- If unique phones are not enabled or not required, do not execute the rest of the code.
    if not Config.Item.UniquePhones or not Config.Item.Require then return end

    ---Function to check if a player has a phone with a specific imei
    ---@param source any
    ---@param imei string
    ---@return boolean
    function HasImeiIdentifier(source, imei)
        debugPrint("Checking if " .. source .. " has a phone item with imei: " .. imei)

        -- Iterate over each item name in Config.UseableItems
        for _, itemName in ipairs(Config.UseableItems) do
            local phones = getItemsByName(source, itemName)

            for i = 1, #phones do
                local phone = phones[i]
                -- Assuming the IMEI is stored in the first element of the info array
                if phone?.metadata?.imei == imei then
                    debugPrint("Phone with imei " .. imei .. " found in " .. itemName)
                    return true
                end
            end
        end

        debugPrint("Phone with imei " .. imei .. " not found")
        return false
    end

    lib.callback.register('yseries:server:generate-phone-imei', function(source, phoneItem)
        local playerIdentifier = Framework.GetPlayerFromId(source)?.identifier
        if playerIdentifier then
            playerIdentifier = playerIdentifier:gsub(':', '')

            local inventoryIdentifier = 'content-' .. playerIdentifier
            local inventory = exports['core_inventory']:getInventory(inventoryIdentifier)
            for i = 1, #inventory do
                local item = inventory[i]
                if item?.name == phoneItem.name then
                    local newImei = GenerateUniqueIdentifier()

                    item.metadata.imei = newImei
                    exports['core_inventory']:updateMetadata(inventoryIdentifier, item.id, item.metadata)

                    return newImei
                end
            end
        end

        return false
    end)

    if framework then
        for i = 1, #Config.UseableItems do
            if Config.Framework == "qb" then
                framework.Functions.CreateUseableItem(Config.UseableItems[i], function(source, item)
                    if item then
                        debugPrint("Using phone item")

                        TriggerClientEvent("yseries:use-phone-item", source, item)
                    end
                end)
            elseif Config.Framework == "esx" then
                framework.RegisterUseableItem(Config.UseableItems[i], function(source, _, item)
                    if item then
                        debugPrint("Using phone item")

                        TriggerClientEvent("yseries:use-phone-item", source, item)
                    end
                end)
            end
        end
    end

    -- Vehicle Charging System Integration
    if Config.Battery?.Enabled then
        local requiredItem = Config.Battery.VehicleCharging?.RequiredItem or "usb_cable"

        if framework then
            if Config.Framework == "qb" then
                framework.Functions.CreateUseableItem(requiredItem, function(source, item)
                    TriggerClientEvent('yseries:useUSBCable', source, item)
                end)
            elseif Config.Framework == "esx" then
                framework.RegisterUseableItem(requiredItem, function(source, _, item)
                    TriggerClientEvent('yseries:useUSBCable', source, item)
                end)
            end
        end
    end
end)
