----
-- NOTICE: This inventory integration is provided as-is.
-- TeamsGG does not provide official support for this integration.
----

CreateThread(function()
    if Config.Item.Inventory ~= "qs-inventory" then return end

    local framework = nil
    if Config.Framework == "qb" then
        framework = exports["qb-core"]:GetCoreObject()
    elseif Config.Framework == "esx" then
        framework = exports["es_extended"]:getSharedObject()
    end

    ---Function to get all items a player has with a specific name
    ---@param source number
    ---@param name string
    ---@return table items
    local function getItemsByName(source, name)
        local inventory = exports['qs-inventory']:GetInventory(source)

        local items = {}
        debugPrint("Getting items with name: ", name)
        for _, v in pairs(inventory) do
            if v.name == name then
                items[#items + 1] = v
            end
        end

        return items
    end

    --- Get a sim card item from a player's inventory by sim number
    ---@param playerId number The player's ID
    ---@param simNumber number The sim card's number
    ---@return { simNumber: string, cardId: number, slot: number } | nil
    function GetSimCardItem(playerId, simNumber)
        local items = getItemsByName(playerId, Config.Sim.ItemName)

        for _, item in pairs(items) do
            if item.info.simNumber == simNumber then
                return {
                    cardId = item.info.cardId,
                    simNumber = item.info.simNumber,
                    slot = item.slot,
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

        local expExists, canAdd = pcall(function() return exports['qs-inventory']:CanCarryItem(playerId, Config.Sim.ItemName, 1) end)

        if (expExists and canAdd) or not expExists then
            local success = exports['qs-inventory']:AddItem(playerId, Config.Sim.ItemName, 1, nil, {
                cardId = cardId,
                simNumber = simNumber,
            })

            if success then
                return { success = true, message = "Sim card added to your inventory" }
            else
                return { success = false, message = "Failed to add sim card to your inventory" }
            end
        end

        return { success = false, message = "Cannot carry item" }
    end

    --- Remove a sim card item from a player's inventory by card ID
    ---@param playerId number The player's ID
    ---@param simNumber number The card's unique ID
    ---@return boolean
    function RemoveSimCardItem(playerId, simNumber)
        if not playerId or not tonumber(playerId) then return false end

        local inventory = exports['qs-inventory']:GetInventory(playerId)

        for _, item in pairs(inventory) do
            if item.name == Config.Sim.ItemName and item.info.simNumber == simNumber then
                return exports['qs-inventory']:RemoveItem(playerId, Config.Sim.ItemName, 1, item.slot)
            end
        end

        return false
    end

    lib.callback.register('yseries:server:assign-item-metadata', function(source, item, metadata)
        exports['qs-inventory']:SetItemMetadata(source, item.slot, metadata)

        return true
    end)

    -- If unique phones are not enabled or not required, do not execute the rest of the code.
    if not Config.Item.UniquePhones or not Config.Item.Require then return end

    ---Function to check if a player has a phone with a specific imei
    ---@param source any
    ---@param imei string
    ---@return boolean
    function HasImeiIdentifier(source, imei)
        -- Iterate over each item name in Config.UseableItems
        for _, itemName in ipairs(Config.UseableItems) do
            local phones = getItemsByName(source, itemName)

            for i = 1, #phones do
                local phone = phones[i]
                -- Assuming the IMEI is stored in the first element of the info array
                if phone and phone.info and phone.info.imei == imei then
                    return true
                end
            end
        end

        debugPrint("Phone with imei " .. imei .. " not found")
        return false
    end

    lib.callback.register('yseries:server:generate-phone-imei', function(source, phoneItem)
        local player = nil
        if not framework then return false end

        if Config.Framework == "qb" then
            player = framework.Functions.GetPlayer(source)
        elseif Config.Framework == "esx" then
            player = framework.GetPlayerFromId(source)
        end

        if player then
            local newImei = GenerateUniqueIdentifier()

            local inventory = exports["qs-inventory"]:GetInventory(source)
            if inventory then
                local phone = inventory[phoneItem.slot]
                if phone then
                    local info = phone.info
                    if not info then
                        info = {}
                    end
                    info.imei = newImei

                    exports['qs-inventory']:SetItemMetadata(source, phoneItem.slot, info)
                else
                    debugPrint('Phone item not found')
                end
            end

            return newImei
        end
        return false
    end)

    for i = 1, #Config.UseableItems do
        debugPrint("Creating usable item: ", Config.UseableItems[i])
        exports['qs-inventory']:CreateUsableItem(Config.UseableItems[i], function(source, item)
            if item then
                debugPrint("Using phone item")

                TriggerClientEvent("yseries:use-phone-item", source, item)
            end
        end)
    end

    if Config.Battery?.Enabled then
        local requiredItem = Config.Battery.VehicleCharging?.RequiredItem or "usb_cable"
        exports['qs-inventory']:CreateUsableItem(requiredItem, function(source, item)
            TriggerClientEvent('yseries:useUSBCable', source, item)
        end)
    end
end)
