----
-- NOTICE: This inventory integration is provided as-is.
-- TeamsGG does not provide official support for this integration.
----

CreateThread(function()
    if Config.Item.Inventory ~= "codem-inventory" then return end

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
        local src = source
        local inventory = exports["codem-inventory"]:GetInventory(false, src)
        local items = {}

        for _, v in pairs(inventory) do
            if v.name == name then
                items[#items + 1] = v
            end
        end

        return items
    end

    --- Get a sim card item from a player's inventory by sim number
    ---@param playerId number The player's ID
    ---@param simNumber string The sim card's number
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

        exports['codem-inventory']:AddItem(source, Config.Sim.ItemName, 1, nil, {
            cardId = cardId,
            simNumber = simNumber,
        })

        return { success = true, message = "Sim card added to your inventory" }
    end

    --- Remove a sim card item from a player's inventory by card ID
    ---@param playerId number The player's ID
    ---@param simNumber string The card's unique ID
    ---@return boolean
    function RemoveSimCardItem(playerId, simNumber)
        if not playerId or not tonumber(playerId) then return false end

        local item = GetSimCardItem(playerId, simNumber)
        if not item then return false end

        exports['codem-inventory']:RemoveItem(playerId, Config.Sim.ItemName, 1, item.slot)

        return true
    end

    lib.callback.register('yseries:server:assign-item-metadata', function(source, item, metadata)
        exports['codem-inventory']:SetItemMetadata(source, item.slot, metadata)

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
        local player = Framework.GetPlayerFromId(source)
        if player then
            -- Genereate new imei. Set the imei to the phone item. Set the phone item to the player's inventory
            local newImei = GenerateUniqueIdentifier()

            local inventory = exports["codem-inventory"]:GetInventory(false, source)
            if inventory then
                local phone = inventory[tostring(phoneItem.slot)]
                if phone then
                    local info = phone.info
                    if not info then
                        info = {}
                    end
                    info.imei = newImei
                    exports['codem-inventory']:SetItemMetadata(source, phoneItem.slot, info)
                else
                    print('Phone item not found')
                end
            end

            return newImei
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
                framework.RegisterUsableItem(Config.UseableItems[i], function(source, _, item)
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
                framework.RegisterUsableItem(requiredItem, function(source, _, item)
                    TriggerClientEvent('yseries:useUSBCable', source, item)
                end)
            end
        end
    end
end)
