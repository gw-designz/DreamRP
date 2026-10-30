--[[ 
    Greetings, esteemed developer! If you're reading this, you're probably curious about the functioning of this
    automated insertion system. It's incredibly straightforward. Just follow the same syntax as the provided examples
    to populate your furniture and append the insertFurniture function at the conclusion of this document.
    This process will enable you to add individual items or groups to the Furnitures table.

    Furthermore, you have the option to enhance the visibility of your furniture by incorporating a distinct color!
]]

if GetResourceState('dc_housingshells') ~= 'started' then
    return
end

CreateThread(function()
    InsertFurnitureCategory("dc_housingshells", "DC Housing Shells", nil, "🆔")
    Wait(500)
end)

CreateThread(function()
    local DCCustomz = {
        { object = "dc_acvent", price = 50, label = "DC Acvent", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_acvent2", price = 50, label = "DC Acvent 2", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_doorcamera", price = 50, label = "DC Door Camera", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_firesprinkler", price = 50, label = "DC Fire Sprinkler", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_lightswitch1", price = 50, label = "DC Light Switch 1", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_lightswitch2", price = 50, label = "DC Light Switch 2", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_lightswitch3", price = 50, label = "DC Light Switch 3", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_lightswitch4", price = 50, label = "DC Light Switch 4", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_showerhead", price = 50, label = "DC Shower Head", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_showerhead2", price = 50, label = "DC Shower Head 2", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_showerhead3", price = 50, label = "DC Shower Head 3", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_smokedetector", price = 50, label = "DC Smoke Detector", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_thermostat", price = 50, label = "DC Thermostat", background = "rgba(162, 16, 230, 0.17)", },
        { object = "dc_thermostat2", price = 50, label = "DC Thermostat 2", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_toilet", price = 50, label = "DC Toilet", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_toilet2", price = 50, label = "DC Toilet 2", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_toilet3", price = 50, label = "DC Toilet 3", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_toolbox", price = 50, label = "DC Toolbox", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_toolbox2", price = 50, label = "DC Toolbox 2", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_walloutlet", price = 50, label = "DC Wall Outlet", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_walloutlet2", price = 50, label = "DC Wall Outlet 2", background = "rgba(162, 16, 230, 0.17)" },
        { object = "dc_walloutlet3", price = 50, label = "DC Wall Outlet 3", background = "rgba(162, 16, 230, 0.17)" }
    }

    local DCCustomzDoors = {
        { object = "dc_housesix_door", price = 0, label = "House 6 Door", type = "door" },
        { object = "dc_housesix_doorsmall", price = 0, label = "House 6 Small Bath Door" },
        { object = "dc_houseseven_door", price = 0, label = "House 7 Door", type = "door" },
        { object = "dc_houseeight_door", price = 0, label = "House 8 Door", type = "door" },
        { object = "dc_townhouseone_door", price = 0, label = "Town House 1 Door", type = "door" },
        { object = "dc_townhousetwo_door", price = 0, label = "Town House 2 Door", type = "door" },
        { object = "dc_apartmentfour_door", price = 0, label = "Apartment 4 Door", type = "door" },
        { object = "dc_apartmentone_door", price = 0, label = "Apartment 1 Door", type = "door" },
        { object = "dc_apartmentthree_door", price = 0, label = "Apartment 3 Door", type = "door" },
        { object = "dc_apartmenttwo_door", price = 0, label = "Apartment 2 Door", type = "door" },
        { object = "dc_housefive_door", price = 0, label = "House 5 Door", type = "door" },
        { object = "dc_housefour_door", price = 0, label = "House 4 Door", type = "door" },
        { object = "dc_houseone_door", price = 0, label = "House 1 Door", type = "door" },
        { object = "dc_housethree_door", price = 0, label = "House 3 Door", type = "door" },
        { object = "dc_housetwo_door", price = 0, label = "House 2 Door", type = "door" },
        { object = "dc_trapshellone_door", price = 0, label = "Trap Shell 1 Door", type = "door" },
        { object = "dc_trapshellthree_door", price = 0, label = "Trap Shell 3 Door", type = "door" },
        { object = "dc_trapshelltwo_door", price = 0, label = "Trap Shell 2 Door", type = "door" },
        { object = "dc_apartmentfive_door", price = 0, label = "Apartment 5 Door", type = "door" },
        { object = "dc_apartment6_door",    price = 0, label = "Apartment 6 Door", type = "door" },
        { object = "dc_h9door",             price = 0, label = "House 9 Door", type = "door" },
        { object = "dc_house10_door",       price = 0, label = "House 10 Door", type = "door" },
        { object = "dc_house11_door",       price = 0, label = "House 11 Door", type = "door" },
        { object = "dc_house12_door",       price = 0, label = "House 12 Door", type = "door" },
        { object = "dc_house13_door",       price = 0, label = "House 13 Door", type = "door" },
        { object = "dc_townhouse3_door",    price = 0, label = "Town House 3 Door", type = "door" },
        { object = "dc_townhouse4_door",    price = 0, label = "Town House 4 Door", type = "door" },
        { object = "dc_trap4_door",          price = 0, label = "Trap Shell 4 Door", type = "door" },
    }

    InsertFurniture(FurnitureConfig.Furniture.dc_housingshells, DCCustomz)
    InsertFurniture(FurnitureConfig.Furniture.doors, DCCustomzDoors)
end)