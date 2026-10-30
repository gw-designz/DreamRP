if not Config.Item.UniquePhones and Config.Item.Useable and Config.Item.Require then
    if Config.Framework == 'qb' or Config.Framework == 'qbox' then
        local framework = exports["qb-core"]:GetCoreObject()

        if
            Config.Item.Inventory == "qb-inventory" or
            Config.Item.Inventory == "lj-inventory" or
            Config.Item.Inventory == "ps-inventory" or
            Config.Item.Inventory == 'qs-inventory' or
            Config.Item.Inventory == "codem-inventory" or
            Config.Item.Inventory == "core_inventory" or
            Config.Item.Inventory == 'tgiann-inventory'
        then
            for i = 1, #Config.UseableItems do
                framework.Functions.CreateUseableItem(Config.UseableItems[i], function(source, item)
                    if item then
                        debugPrint("Using phone item(usable item)")

                        TriggerClientEvent("yseries:use-phone-with-item", source, item)
                    end
                end)
            end
        end
    elseif Config.Framework == 'esx' then
        local framework = exports['es_extended']:getSharedObject()

        for i = 1, #Config.UseableItems do
            if Config.Item.Inventory == 'qs-inventory' then
                exports['qs-inventory']:CreateUseableItem(Config.UseableItems[i], function(source, item)
                    if item then
                        debugPrint("Using phone item")

                        TriggerClientEvent("yseries:use-phone-with-item", source, item)
                    end
                end)
            elseif
                Config.Item.Inventory == 'codem-inventory' or
                Config.Item.Inventory == 'chezza-inventory' or
                Config.Item.Inventory == "core_inventory" or
                Config.Item.Inventory == "tgiann-inventory"
            then
                framework.RegisterUsableItem(Config.UseableItems[i], function(source, _, item)
                    if item then
                        debugPrint("Using phone item")

                        TriggerClientEvent("yseries:use-phone-with-item", source, item)
                    end
                end)
            end
        end
    end
end
