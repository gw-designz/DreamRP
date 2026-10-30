function CancelEmote()

end

AddEventHandler("prp-bridge:client:died", function()
    StopMinigame()
end)

RegisterNUICallback("balance:updateAngle", function(data, cb)
    local angle = data.angle
    TriggerEvent("prp-minigames:balance:updateAngle", angle)
    cb("ok")
end)

RegisterNUICallback("buttonMash:sendProgress", function(data, cb)
    cb("ok")
    TriggerEvent("prp-minigames:buttonMash:sendProgress", data.progress)
end)

RegisterNUICallback("cocaineCut:updateProgress", function(data, cb)
    TriggerEvent("prp-minigames:cocaineCut:updateProgress", data.progress)
    cb({})
end)

RegisterNUICallback("containerShake:shakeStatus", function(data, cb)
    if data.status then
        TriggerEvent("prp-minigames:containerShake:started")
    else
        TriggerEvent("prp-minigames:containerShake:stopped")
    end

    cb({})
end)