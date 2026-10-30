function RegisterCommands()
    bridge.fw.registerCommand("scene", locale("CREATE_SCENE"), {
        { name = "text", help = locale("CREATE_SCENE_HELP") },
    }, nil, function (src, args, rawCommand)
        local message = rawCommand:gsub("scene ", "")
        TriggerClientEvent("prp-scenes:openCreator", src, false, message)
    end)

    bridge.fw.registerCommand("hidescenes", locale("TOGGLE_SCENE_VISIBILITY"), {}, nil, function(src, args)
        TriggerClientEvent("prp-scenes:hideScenes", src, args)
    end)

    bridge.fw.registerCommand("scenestaff", locale("CREATE_SCENE_STAFF"), {
        { name = "text", help = locale("CREATE_SCENE_HELP") },
    }, "admin", function (src, args, rawCommand)
        local message = rawCommand:gsub("scenestaff ", "")
        TriggerClientEvent("prp-scenes:openCreator", src, true, message)
    end)

    bridge.fw.registerCommand("scenedelete", locale("DELETE_SCENE_HELP"), {}, nil, function(src, args)
        TriggerClientEvent("prp-scenes:tryDeleteScene", src, args)
    end)
end

CreateThread(function()
    Wait(200)
    RegisterCommands()
end)