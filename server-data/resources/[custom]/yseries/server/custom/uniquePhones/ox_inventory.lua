CreateThread(function()
    if Config.Item.Inventory ~= "ox_inventory" then return end

    --- Get a sim card item from a player's inventory by sim number
    ---@param playerId number The player's ID
    ---@param simNumber number The sim card's number
    ---@return { simNumber: string, cardId: number, slot: number } | nil
    function GetSimCardItem(playerId, simNumber)
        local simCardItems = exports.ox_inventory:Search(playerId, "slots", Config.Sim.ItemName)
        for i = 1, #simCardItems do
            local card = simCardItems[i]
            if card.metadata.simNumber == simNumber then
                return {
                    simNumber = card.metadata.simNumber,
                    cardId = card.metadata.cardId,
                    slot = card.slot,
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

        if exports.ox_inventory:CanCarryItem(playerId, Config.Sim.ItemName, 1) then
            local success, _ = exports.ox_inventory:AddItem(playerId, Config.Sim.ItemName, 1, {
                cardId = cardId,
                simNumber = simNumber,
            })

            if success then
                return { success = true, message = "Sim card added to your inventory" }
            else
                return { success = false, message = "Failed to add sim card to your inventory" }
            end
        else
            return { success = false, message = "You do not have enough space in your inventory" }
        end
    end

    --- Remove a sim card item from a player's inventory by card ID
    ---@param playerId number The player's ID
    ---@param simNumber number The card's unique ID
    ---@return boolean
    function RemoveSimCardItem(playerId, simNumber)
        local cards = exports.ox_inventory:Search(playerId, "slots", Config.Sim.ItemName)
        for i = 1, #cards do
            local card = cards[i]

            if card.metadata.simNumber == simNumber then
                return exports.ox_inventory:RemoveItem(playerId, Config.Sim.ItemName, 1, nil, card.slot)
            end
        end

        return false
    end

    lib.callback.register('yseries:server:assign-item-metadata', function(source, item, metadata)
        exports.ox_inventory:SetMetadata(source, item.slot, metadata)

        return true
    end)

    --- If unique phones are not enabled or not required, do not execute the rest of the code.
    if not Config.Item.UniquePhones or not Config.Item.Require then return end

    ---Function to get all phone items a player has in their inventory
    ---@param source number
    ---@return table items
    local function GetPhoneItems(source)
        local items = {}
        for _, itemName in ipairs(Config.UseableItems) do
            local foundItems = exports.ox_inventory:Search(source, "slots", itemName)
            for i = 1, #foundItems do
                if foundItems[i] then
                    items[#items + 1] = foundItems[i]
                end
            end
        end
        return items
    end

    ---Function to check if a player has a phone with a specific number
    ---@param source any
    ---@param imei string
    ---@return boolean
    function HasImeiIdentifier(source, imei)
        debugPrint("Checking if " .. source .. " has a phone item with imei: ", imei)

        local phones = GetPhoneItems(source) -- Retrieve all phone items

        for i = 1, #phones do
            local phone = phones[i]
            if phone and phone.metadata and phone.metadata.imei == imei then
                debugPrint("Phone with imei " .. imei .. " found")
                return true
            end
        end

        debugPrint("Phone with imei " .. imei .. " not found")
        return false
    end

    lib.callback.register('yseries:server:generate-phone-imei', function(source, phoneItem)
        local item = exports.ox_inventory:GetSlot(source, phoneItem.slot)

        local newImei = GenerateUniqueIdentifier()
        item.metadata.imei = newImei

        exports.ox_inventory:SetMetadata(source, item.slot, item.metadata)

        return newImei
    end)
end)
