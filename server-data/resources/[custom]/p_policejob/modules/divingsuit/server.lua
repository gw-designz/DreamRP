while true do
    if Config and Config.DivingSuit then break end
    Citizen.Wait(500)
end

if not Config.DivingSuit.enabled then return end

-- ============================================================
--  Access check callback
-- ============================================================

lib.callback.register("p_policejob/server/divingsuit/canUseSuit", function(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job or not Config.Jobs[job.name] then return false end

    local count = Bridge.Inventory.getItemCount(playerSource, "diving_suit")
    return count >= 1
end)

-- ============================================================
--  Activate
-- ============================================================

RegisterNetEvent("p_policejob/server/divingsuit/activate", function()
    local playerSource = source
    local job          = Bridge.Framework.getPlayerJob(playerSource)

    if not job or not Config.Jobs[job.name] then
        Bridge.Debug(("[DivingSuit] Activation denied for player %s (job not allowed)"):format(playerSource))
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    local count = Bridge.Inventory.getItemCount(playerSource, "diving_suit")
    if count < 1 then
        return Bridge.Notify.showNotify(playerSource, locale("no_diving_suit_item"), "error")
    end

    Bridge.Debug(("[DivingSuit] Player %s activated diving suit"):format(playerSource))

    if Config.Webhooks and Config.Webhooks.divingsuit then
        Bridge.Logs.Send(playerSource, "DivingSuit", "Player activated diving suit", Config.Webhooks.divingsuit)
    end
end)

-- ============================================================
--  Deactivate
-- ============================================================

RegisterNetEvent("p_policejob/server/divingsuit/deactivate", function()
    local playerSource = source

    if Config.Webhooks and Config.Webhooks.divingsuit then
        Bridge.Logs.Send(playerSource, "DivingSuit", "Player removed diving suit", Config.Webhooks.divingsuit)
    end
end)
