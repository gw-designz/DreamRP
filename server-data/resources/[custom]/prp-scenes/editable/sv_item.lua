SprayCanItemName = "spray_can"

CreateThread(function()
    Wait(100)
    bridge.fw.registerItemUse(SprayCanItemName, function(src, item)
        TriggerClientEvent("prp-scenes:openGraffitiCreator", src, SprayCanItemName)
    end)
end)

--[[

    ['spray_can'] = {
        label = 'Spray Can',
        weight = 1,
        stack = false,
    },


    ['spray_remover'] = {
        label = 'Spray Remover',
        weight = 1,
        stack = false,
    },

]]