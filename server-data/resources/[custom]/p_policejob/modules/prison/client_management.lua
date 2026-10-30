if not (Config and Config.Prison and Config.Prison.Enabled) then return end

-- ─── Open Management ─────────────────────────────────────────────────────────

function Prison:openManagement()
    if not self:hasJobAccess() then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    local prisoners = lib.callback.await("p_policejob/server/prison/getAllPrisoners", false) or {}

    SendNUIMessage({ action = "setVisiblePrisonManagement", data = true })
    SendNUIMessage({
        action = "setPrisonManagementData",
        data   = {
            prisoners       = prisoners,
            cells           = (Prison.Map and Prison.Map.cells) or {},
            solitaryEnabled = Config.Prison.Solitary.enabled,
            solitaryMaxTime = Config.Prison.Solitary.maxTime,
            officerTasks    = (Config.Prison.OfficerTasks and Config.Prison.OfficerTasks.enabled
                                and Prison.getOfficerTasksForUI and Prison:getOfficerTasksForUI()) or {},
            activeOfficerTaskId = (Prison.getActiveOfficerTaskId and Prison:getActiveOfficerTaskId()) or nil,
        },
    })

    SetNuiFocus(true, true)
end

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("prison/management/close", function(_, cb)
    SendNUIMessage({ action = "setVisiblePrisonManagement", data = false })
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback("prison/management/release", function(payload, cb)
    if not (payload and payload.identifier) then
        return cb({ success = false })
    end
    TriggerServerEvent("p_policejob/server/prison/management/release", {
        identifier = payload.identifier,
    })
    cb({ success = true })
end)

RegisterNUICallback("prison/management/reduceSentence", function(payload, cb)
    if not (payload and payload.identifier and payload.minutes) then
        return cb({ success = false })
    end
    TriggerServerEvent("p_policejob/server/prison/management/reduceSentence", {
        identifier = payload.identifier,
        minutes    = tonumber(payload.minutes) or 0,
    })
    cb({ success = true })
end)

RegisterNUICallback("prison/management/increaseSentence", function(payload, cb)
    if not (payload and payload.identifier and payload.minutes) then
        return cb({ success = false })
    end
    TriggerServerEvent("p_policejob/server/prison/management/increaseSentence", {
        identifier = payload.identifier,
        minutes    = tonumber(payload.minutes) or 0,
    })
    cb({ success = true })
end)

RegisterNUICallback("prison/management/sendToSolitary", function(payload, cb)
    if not (payload and payload.identifier) then
        return cb({ success = false })
    end
    TriggerServerEvent("p_policejob/server/prison/management/solitary", {
        identifier = payload.identifier,
        minutes    = tonumber(payload.minutes) or 15,
        release    = false,
    })
    cb({ success = true })
end)

RegisterNUICallback("prison/management/releaseFromSolitary", function(payload, cb)
    if not (payload and payload.identifier) then
        return cb({ success = false })
    end
    TriggerServerEvent("p_policejob/server/prison/management/solitary", {
        identifier = payload.identifier,
        release    = true,
    })
    cb({ success = true })
end)

RegisterNUICallback("prison/management/moveToCell", function(payload, cb)
    if not (payload and payload.identifier and payload.cellId) then
        return cb({ success = false })
    end
    TriggerServerEvent("p_policejob/server/prison/management/moveToCell", {
        identifier = payload.identifier,
        cellId     = tonumber(payload.cellId),
    })
    cb({ success = true })
end)

RegisterNUICallback("prison/management/refreshPrisoners", function(_, cb)
    local prisoners = lib.callback.await("p_policejob/server/prison/getAllPrisoners", false) or {}
    cb({ prisoners = prisoners })
end)

RegisterNUICallback("prison/management/releaseAllExpired", function(_, cb)
    TriggerServerEvent("p_policejob/server/prison/management/releaseAllExpired")
    cb({ success = true })
end)

RegisterNUICallback("prison/management/startOfficerTask", function(payload, cb)
    if not (payload and payload.taskId) then
        return cb({ success = false })
    end

    SendNUIMessage({ action = "setVisiblePrisonManagement", data = false })
    SetNuiFocus(false, false)

    local success = Prison.startOfficerTaskById
        and Prison:startOfficerTaskById(tostring(payload.taskId))
        or false

    cb({ success = success })
end)

RegisterNUICallback("prison/management/cancelOfficerTask", function(_, cb)
    if Prison.cancelOfficerTask then
        Prison:cancelOfficerTask()
    end
    cb({ success = true })
end)

-- ─── Net Event / Exports / Command ───────────────────────────────────────────

RegisterNetEvent("p_policejob/client/prison/openManagement", function()
    Prison:openManagement()
end)

exports("openPrisonManagement", function()
    Prison:openManagement()
end)

exports("openJailMenu", function()
    Prison:openManagement()
end)

RegisterCommand("prisonmanagement", function()
    Prison:openManagement()
end, false)
