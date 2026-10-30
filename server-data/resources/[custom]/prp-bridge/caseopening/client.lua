RegisterNetEvent("prp-bridge:client:openCase", function(caseId)
    local caseInfo = lib.callback.await("prp-bridge:case:getCaseInfo", false, caseId)
    if not caseInfo then
        return
    end

    SendNUIMessage({
        event = "sendAppEvent",
        app = "caseOpening",
        action = "open",
        payload = caseInfo
    })
    SetNuiFocus(true, true)
end)

RegisterNuiCallback("case:tryOpenCase", function(caseId, callback)
    local canOpen, itemIndex, itemCount = lib.callback.await("prp-bridge:case:canOpenCase", 500, caseId)

    if not canOpen then
        if not itemIndex then
            bridge.fw.notify("error", locale("CASE_OPENING_SPAM_ERROR"))
        else
            bridge.fw.notify("error", locale("CASE_OPENING_ITEM_ERROR", itemIndex))
        end

        return callback({
            success = false,
            error = itemIndex
        })
    end

    return callback({
        success = true,
        itemIndex = itemIndex,
        itemCount = itemCount
    })
end)

RegisterNuiCallback("case:caseOpened", function(_, callback)
    local caseOpened, errorMsg = lib.callback.await("prp-bridge:case:caseOpened", 500)

    if not caseOpened then
        bridge.fw.notify("error", errorMsg)
    end

    callback(caseOpened)
end)

RegisterNuiCallback("case:close", function(_, callback)
    SetNuiFocus(false, false)
    callback(true)
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= cache.resource then return end
    SetNuiFocus(false, false)
end)