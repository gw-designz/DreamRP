RegisterNetEvent("prp-boosting:useObdModule", function(class)
    lib.registerMenu({
        id = "boosting_obd_menu",
        title = locale("OBD_MENU_TITLE"),
        position = "top-right",
        options = {
        {
            icon = "fas fa-car",
            label = locale("OBD_MENU_FLASH"),
            close = true,
            args = {
                command = "ecu_flash"
            }
        },
        {
            icon = "fas fa-car",
            label = locale("OBD_MENU_IMMO"),
            close = true,
            args = {
                command = "ecu_immo"
            }
        },
        {
            icon = "fas fa-car",
            label = locale("OBD_MENU_REGISTER"),
            close = true,
            args = {
                command = "key_register"
            }
        },
        {
            icon = "fas fa-car",
            label = locale("OBD_MENU_SAVE"),
            close = true,
            args = {
                command = "key_save"
            }
        }
        }
    }, function(selected, scrollIndex, args)
        TriggerServerEvent("prp-boosting:runOBDCommand", class, args.command)
    end)
    lib.showMenu("boosting_obd_menu")
end)

CreateThread(function()
    Wait(100)
    local itemUrlTemplate = bridge.inv.getItemImageUrl("{item}")
    SendAppAction("boosting", "setInventoryImgTemplate", itemUrlTemplate)
end)