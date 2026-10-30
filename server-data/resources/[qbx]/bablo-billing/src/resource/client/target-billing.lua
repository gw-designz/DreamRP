-- ============================================================
-- target-billing.lua  –  bablo-billing  (client)
-- ============================================================

CreateThread(function()
    -- Guard: only run when Target billing is enabled
    if not (Config.Target and Config.TargetBilling and Config.TargetBilling.enabled) then
        return
    end

    -- Wait for Framework to be ready
    while not Framework do Wait(500) end

    -- Wait for the target system to expose addGlobalPlayer
    while not (Target and Target.addGlobalPlayer) do Wait(500) end

    -- Returns true if the local player's job is in the allowed job grades list
    local function localPlayerHasValidJob()
        local playerData = Framework.GetPlayerData and Framework.GetPlayerData() or nil
        if not playerData or not playerData.job then return false end

        local jobName = playerData.job.name
        if not jobName then return false end

        return Config.JobAccount.jobGrades[jobName] ~= nil
    end

    -- Called by the target option – resolves the target ped's server ID then opens quick-bill NUI
    local function onSendBillAction(targetPed)
        if not targetPed then return end

        local networkIndex = NetworkGetPlayerIndexFromPed(targetPed)
        if not networkIndex or networkIndex == -1 then
            if Framework.Notify then Framework.Notify("Could not identify target player", "error") end
            return
        end

        local targetServerId = GetPlayerServerId(networkIndex)
        if not targetServerId or targetServerId == 0 then
            if Framework.Notify then Framework.Notify("Could not identify target player", "error") end
            return
        end

        local response = TriggerServerCallback({
            eventName = "bablo-billing:GET_PLAYER_BY_SOURCE",
            args      = { { playerSource = targetServerId } },
        })

        if not response or not response.success or not response.data then
            if Framework.Notify then Framework.Notify("Could not find player information", "error") end
            return
        end

        local targetData = response.data
        local playerData = Framework.GetPlayerData and Framework.GetPlayerData() or nil
        local senderJob  = playerData and playerData.job or nil

        setUser()
        SetNuiFocus(true, true)

        local jobPayload = nil
        if senderJob then
            jobPayload = {
                name  = senderJob.name,
                label = senderJob.label or senderJob.name,
            }
        end

        SendNUIMessage({
            event = "OPEN_QUICK_BILL",
            data  = {
                identifier    = targetData.identifier,
                characterName = targetData.characterName,
                source        = targetServerId,
                jobOnly       = Config.TargetBilling.jobOnly or false,
                allowPersonal = (false ~= Config.Invoice.allowPrivatePersonToSendInvoice),
                job           = jobPayload,
            }
        })
    end

    -- Register the global-player target option
    Target.addGlobalPlayer(Target, {
        label      = Config.TargetBilling.label    or "Send Bill",
        name       = "bablo_billing_send_bill",
        icon       = Config.TargetBilling.icon     or "fas fa-file-invoice-dollar",
        distance   = Config.TargetBilling.distance or 2.5,

        canInteract = function(targetPed)
            if not targetPed then return false end
            if targetPed == PlayerPedId() then return false end
            if not IsPedAPlayer(targetPed) then return false end
            return localPlayerHasValidJob()
        end,

        action = onSendBillAction,
    })
end)
