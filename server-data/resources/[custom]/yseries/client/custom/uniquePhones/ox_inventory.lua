CreateThread(function()
    if Config.Item.Inventory ~= "ox_inventory" then return end

    --- Returns true if the local player carries at least one entry from `Config.UseableItems`.
    --- Used by `HasPhoneItem` in `client/custom/frameworks/qbox.lua` when no IMEI-specific check applies.
    ---@return boolean
    function HasAnyPhoneUseableItem()
        for _, itemName in ipairs(Config.UseableItems) do
            if (exports.ox_inventory:Search("count", itemName) or 0) > 0 then
                return true
            end
        end

        return false
    end

    exports.ox_inventory:displayMetadata({
        cardId = "Card ID",
        simNumber = "Sim Number",
        imei = "IMEI",
    })

    --- Get all sim card items from a player's inventory
    ---@return table
    function GetSimCardItems()
        local simCardItems = {}

        local cards = exports.ox_inventory:Search("slots", Config.Sim.ItemName)
        for i = 1, #cards do
            local card = cards[i]
            if card and (not card.metadata?.cardId or not card.metadata?.simNumber) then
                local simCardDetails = lib.callback.await('yseries:server:generate-sim-card-details')
                if not simCardDetails then debugPrint('Failed to generate or seed sim card details') end

                lib.callback.await('yseries:server:assign-item-metadata', false, card, simCardDetails)

                card.metadata.cardId = simCardDetails.cardId
                card.metadata.simNumber = simCardDetails.simNumber
            end

            if card.metadata and card.metadata.cardId and card.metadata.simNumber then
                simCardItems[#simCardItems + 1] = {
                    id = card.metadata.cardId,
                    number = card.metadata.simNumber,
                }
            end
        end

        return simCardItems
    end

    if Config.Item.UniquePhones and Config.Item.Require then
        function HasImeiIdentifier(imei)
            for _, itemName in ipairs(Config.UseableItems) do
                local phones = exports.ox_inventory:Search("slots", itemName)

                for i = 1, #phones do
                    local phone = phones[i]
                    if phone and phone.metadata and phone.metadata.imei == imei then
                        return true
                    end
                end
            end

            return false
        end

        function GetImeiFromItem(item)
            for _, itemName in ipairs(Config.UseableItems) do
                local phones = exports.ox_inventory:Search("slots", itemName)

                for i = 1, #phones do
                    local phone = phones[i]
                    if phone and phone.slot == item.slot then
                        return phone.metadata and phone.metadata.imei or nil
                    end
                end
            end

            return nil
        end

        RegisterNetEvent("yseries:use-phone-item", function(phoneItem)
            local active = SetupPhone(phoneItem)
            if active then
                ToggleOpen(true)
            end
        end)

        RegisterNetEvent('yseries:phone-item-added', function()
            debugPrint('Phone item added')
        end)

        RegisterNetEvent('yseries:phone-item-removed', function()
            Wait(500)

            if Config.Item.UniquePhones and CurrentPhoneImei and not HasImeiIdentifier(CurrentPhoneImei) then
                PhoneDropped()

                local _phoneImei = CurrentPhoneImei

                RemovePrimaryPhone(PlayerData.identifier, CurrentPhoneImei)

                if not HasPrimaryPhone then
                    debugPrint('Removed primary phone item with imei: ' .. _phoneImei)
                else
                    debugPrint('Could not remove primary phone item with imei: ' .. _phoneImei)
                end
            end
        end)
    end

    -- Charging System Integration
    if Config.Battery?.Enabled and Config.Battery.VehicleCharging?.Enabled then
        -- Check if player has USB cable
        function HasUSBCable()
            local items = exports.ox_inventory:Search("slots", Config.Battery.VehicleCharging?.RequiredItem or "usb_cable")
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
