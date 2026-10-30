CreateThread(function()
    if Config.Item.Inventory ~= "qb-inventory" and Config.Item.Inventory ~= "lj-inventory" and Config.Item.Inventory ~= "ps-inventory" then return end

    local framework = exports["qb-core"]:GetCoreObject()

    ---Function to get all items a player has with a specific name
    ---@param source number
    ---@param name string
    ---@return table items
    local function getItemsByName(source, name)
        local inventory = framework.Functions.GetPlayer(source).PlayerData.items

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

        local expExists, canAdd = pcall(function()
            return exports['qb-inventory']:CanAddItem(playerId, Config.Sim.ItemName, 1)
        end)

        if (expExists and canAdd) or not expExists then
            local success = exports['qb-inventory']:AddItem(playerId, Config.Sim.ItemName, 1, false, {
                cardId = cardId,
                simNumber = simNumber,
            }, '')

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

        local inventory = framework.Functions.GetPlayer(playerId).PlayerData.items

        for _, item in pairs(inventory) do
            if item.name == Config.Sim.ItemName and item.info.simNumber == simNumber then
                return exports['qb-inventory']:RemoveItem(playerId, Config.Sim.ItemName, 1, item.slot, 'remove')
            end
        end

        return false
    end

    lib.callback.register('yseries:server:assign-item-metadata', function(source, item, metadata)
        local player = framework.Functions.GetPlayer(source)
        if player?.PlayerData?.items[item.slot] then
            player.PlayerData.items[item.slot].info = metadata
            player.Functions.SetInventory(player.PlayerData.items)

            player.Functions.Save()

            return true
        else
            return false
        end
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
                if phone and phone.info and phone.info.imei == imei then
                    debugPrint("Phone with imei " .. imei .. " found in " .. itemName)
                    return true
                end
            end
        end

        debugPrint("Phone with imei " .. imei .. " not found")
        return false
    end

    lib.callback.register('yseries:server:generate-phone-imei', function(source, phoneItem)
        local player = framework.Functions.GetPlayer(source)

        if player then
            -- Genereate new imei. Set the imei to the phone item. Set the phone item to the player's inventory
            local newImei = GenerateUniqueIdentifier()
            player.PlayerData.items[phoneItem.slot].info.imei = newImei
            player.Functions.SetInventory(player.PlayerData.items)

            player.Functions.Save()

            return newImei
        else
            return false
        end
    end)

    for i = 1, #Config.UseableItems do
        framework.Functions.CreateUseableItem(Config.UseableItems[i], function(source, item)
            if item then
                debugPrint("Using phone item")

                TriggerClientEvent("yseries:use-phone-item", source, item)
            end
        end)
    end

    if Config.Battery?.Enabled then
        local requiredItem = Config.Battery.VehicleCharging?.RequiredItem or "usb_cable"
        framework.Functions.CreateUseableItem(requiredItem, function(source, item)
            local Player = framework.Functions.GetPlayer(source)
            if not Player then return end

            TriggerClientEvent('yseries:useUSBCable', source, item)
        end)
    end
end)
