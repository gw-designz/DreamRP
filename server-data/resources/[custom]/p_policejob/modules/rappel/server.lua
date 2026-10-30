while true do
    if Config and Config.Rappel then break end
    Citizen.Wait(500)
end

if not Config.Rappel.enabled then return end

-- [playerSource] = os.time() when item was consumed (for refund window)
local consumedAt = {}

-- ============================================================
--  Authorize callback (validates job + item, optionally consumes)
-- ============================================================

lib.callback.register("p_policejob/server/rappel/authorize", function(playerSource)
    local RappelCfg = Config.Rappel

    -- Job check
    if RappelCfg.requireJob then
        local job = Bridge.Framework.getPlayerJob(playerSource)
        if not job or not Config.Jobs[job.name] then
            Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
            return false
        end
    end

    -- Item check
    if Bridge.Inventory.getItemCount(playerSource, RappelCfg.item) < 1 then
        Bridge.Notify.showNotify(playerSource, locale("rappel_no_kit"), "error")
        return false
    end

    -- Consume item if configured
    if RappelCfg.consumeItem then
        Bridge.Inventory.removeItem(playerSource, RappelCfg.item, 1)
        consumedAt[playerSource] = os.time()
    end

    return true
end)

-- ============================================================
--  Refund event (if rappel failed to start within ~10s)
-- ============================================================

RegisterNetEvent("p_policejob/server/rappel/refund", function()
    local playerSource = source
    local timestamp    = consumedAt[playerSource]
    consumedAt[playerSource] = nil

    if timestamp and (os.time() - timestamp) <= 10 then
        Bridge.Inventory.addItem(playerSource, Config.Rappel.item, 1)
    end
end)

-- ============================================================
--  Item registration (triggers rappel when item is used)
-- ============================================================

Bridge.Framework.registerItem(Config.Rappel.item, function(playerSource)
    TriggerClientEvent("p_policejob/client/rappel/use", playerSource)
end)
