local PropertyMenuKeybind = lib.addKeybind({
    name = 'property_menu:open',
    description = locale('keybind_property_menu'),
    defaultKey = Config.Keybinds.PropertyMenu,
    onPressed = function(self)
        OpenPropertyMenu()
    end,
})

RegisterCommand(Config.CreatePropertyCommand, function(source, args, raw)
    OpenCreationMenu()
end, false)
TriggerEvent('chat:addSuggestion', "/" .. Config.CreatePropertyCommand, 'Open the creation menu')

RegisterCommand(Config.ToggleBlipsCommand, function()
    lib.registerMenu({
        id = 'toggle_blips',
        title = 'Blips Config',
        position = 'top-right',
        onCheck = function(selected, checked, args)
            if selected == 1 then
                Client.blipsVisibility.all = checked
            elseif selected == 2 then
                Client.blipsVisibility.owned = checked
            elseif selected == 3 then
                Client.blipsVisibility.forSale = checked
            elseif selected == 4 then
                Client.blipsVisibility.forRent = checked
            elseif selected == 5 then
                Client.blipsVisibility.renter = checked
            elseif selected == 6 then
                Client.blipsVisibility.keyholder = checked
            end
            SetResourceKvp('blips_visibility', json.encode(Client.blipsVisibility))
            PropertyManager:refreshBlips()
            BuildingManager:refreshBlips()

            Framework.Notify({
                description = locale('notify_blips_updated'),
                type = 'info',
                duration = 5000,
                icon = 'fas fa-map-marker'
            })
        end,
        options = {
            { label = 'All properties',      checked = Client.blipsVisibility.all },
            { label = 'Owned properties',    checked = Client.blipsVisibility.owned },
            { label = 'Properties for sale', checked = Client.blipsVisibility.forSale },
            { label = 'Properties for rent', checked = Client.blipsVisibility.forRent },
            { label = 'Renters',             checked = Client.blipsVisibility.renter },
            { label = 'Keyholders',          checked = Client.blipsVisibility.keyholder },
        }
    })

    lib.showMenu('toggle_blips')
end, false)
TriggerEvent('chat:addSuggestion', "/" .. Config.ToggleBlipsCommand, 'Toggle the blips')

AddEventHandler('nolag_properties:client:spawnAtProperty', function(propertyId)
    local property = GetPropertyById(tonumber(propertyId))
    if property then
        property:spawnInside()
    end
end)

AddEventHandler('qb-houses:client:enterOwnedHouse', function(propertyId)
    local property = GetPropertyById(tonumber(propertyId))
    if property then
        property:spawnInside()
    end
end)

RegisterNetEvent('qb-houses:client:LastLocationHouse', function(propertyId)
    local property = GetPropertyById(tonumber(propertyId))
    if property then
        property:spawnInside()
    end
end)

function AddBlipCategoryLabels()
    -- Legacy blip categories (keeping for compatibility)
    AddTextEntry('BLIP_PROPCAT', locale("property"))
    AddTextEntry('BLIP_APARTCAT', locale("owned_property"))

    -- New custom blip categories (50-55)
    AddTextEntry('BLIP_CAT_50', locale("owned_property"))    -- Category 50: Owned Property
    AddTextEntry('BLIP_CAT_51', locale("rented_property"))   -- Category 51: Rented Property
    AddTextEntry('BLIP_CAT_52', locale("property_for_sale")) -- Category 52: Property For Sale
    AddTextEntry('BLIP_CAT_53', locale("property_for_rent")) -- Category 53: Property For Rent
    AddTextEntry('BLIP_CAT_54', locale("property_with_key")) -- Category 54: Property with Key
    AddTextEntry('BLIP_CAT_55', locale("property"))          -- Category 55: Property
end

local function wrapIntoProperty(propertyId)
    local property = GetPropertyById(tonumber(propertyId))
    if not property then return false end
    if property.type == "mlo" then return false end
    property:spawnInside()

    local wrapped = lib.waitFor(function()
        if PlayerData.insideProperty and PlayerData.currentProperty?.id == propertyId then
            return true
        end
    end)

    if not wrapped then
        property:exit()
        return false
    end

    return true
end

lib.callback.register('nolag_properties:client:wrapIntoProperty', wrapIntoProperty)
exports('WrapIntoStarterApartment', wrapIntoProperty)
exports('WrapIntoProperty', wrapIntoProperty)
