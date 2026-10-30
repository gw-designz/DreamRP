----
-- NOTICE: This inventory integration is provided as-is.
-- TeamsGG does not provide official support for this integration.
----

CreateThread(function()
    if Config.Item.Inventory ~= "codem-inventory" then return end

    local framework = nil
    if Config.Framework == "qb" then
        framework = exports["qb-core"]:GetCoreObject()
    end

    local function getItemsByName(name)
        if Config.Framework == "esx" then
            local items = {}
            local inventory = exports['codem-inventory']:GetClientPlayerInventory()
            for _, item in pairs(inventory) do
                if item?.name == name then
                    items[#items + 1] = item
                end
            end
            return items
        elseif Config.Framework == "qb" and framework then
            local items = {}
            local inventory = framework.Functions.GetPlayerData().items
            for _, item in pairs(inventory) do
                if item?.name == name then
                    items[#items + 1] = item
                end
            end
            return items
        end
    end

    --- Returns true if the local player carries at least one entry from `Config.UseableItems`.
    ---@return boolean
    function HasAnyPhoneUseableItem()
        for _, itemName in ipairs(Config.UseableItems) do
            local phones = getItemsByName(itemName)
            if phones and #phones > 0 then
                return true
            end
        end

        return false
    end

    --- Get all sim card items from a player's inventory
    ---@return table
    function GetSimCardItems()
        local simCardItems = {}

        local cards = getItemsByName(Config.Sim.ItemName)
        for i = 1, #cards do
            local card = cards[i]
            if card and (not card.info?.cardId or not card.info?.simNumber) then
                local simCardDetails = lib.callback.await('yseries:server:generate-sim-card-details')
                if not simCardDetails then debugPrint('Failed to generate or seed sim card details') end

                lib.callback.await('yseries:server:assign-item-metadata', false, card, simCardDetails)

                card.info.cardId = simCardDetails.cardId
                card.info.simNumber = simCardDetails.simNumber
            end

            if card.info and card.info.cardId and card.info.simNumber then
                simCardItems[#simCardItems + 1] = {
                    id = card.info.cardId,
                    number = card.info.simNumber,
                }
            end
        end

        return simCardItems
    end

    -- If unique phones are not enabled or not required, do not execute the rest of the code.
    if Config.Item.UniquePhones and Config.Item.Require then
        function HasImeiIdentifier(imei)
            for _, itemName in ipairs(Config.UseableItems) do
                local phones = getItemsByName(itemName) -- Retrieve items by each name in the useable items list.
                for i = 1, #phones do
                    local phone = phones[i]
                    if phone and phone.info and phone.info.imei == imei then
                        return true -- Return true if any phone matches the IMEI.
                    end
                end
            end

            return false -- Return false if no matching IMEI is found.
        end

        function GetImeiFromItem(item)
            return item?.info?.imei
        end

        RegisterNetEvent("yseries:use-phone-item", function(phoneItem)
            local active = SetupPhone(phoneItem)

            if active then
                ToggleOpen(true)
            end
        end)

        RegisterNetEvent('codem-inventory:client:additem', function()
            debugPrint('Phone item added')
        end)

        RegisterNetEvent('codem-inventory:client:removeitemtoclientInventory', function()
            Wait(500)

            if Config.Item.UniquePhones and CurrentPhoneImei and not HasImeiIdentifier(CurrentPhoneImei) then
                PhoneDropped()

                RemovePrimaryPhone(PlayerData.identifier, CurrentPhoneImei)

                if not HasPrimaryPhone then
                    debugPrint('Removed primary phone item with imei: ' .. CurrentPhoneImei)
                else
                    debugPrint('Could not remove primary phone item with imei: ' .. CurrentPhoneImei)
                end
            end
        end)
    end

    -- Charging System Integration
    if Config.Battery?.Enabled and Config.Battery.VehicleCharging?.Enabled then
        -- Check if player has USB cable
        function HasUSBCable()
            local items = getItemsByName(Config.Battery.VehicleCharging?.RequiredItem or "usb_cable")
            return items and #items > 0
        end

        -- Register USB cable usage event for automatic vehicle charging
        RegisterNetEvent('yseries:useUSBCable', function(itemData)
            if exports['yseries'].StartVehicleCharging then
                local result = exports['yseries'].StartVehicleCharging()
                debugPrint("StartVehicleCharging result:", result)
            else
                debugPrint("ERROR: StartVehicleCharging export not found")
            end
        end)
    end
end)
