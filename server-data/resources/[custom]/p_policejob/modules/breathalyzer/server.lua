-- Wait for Config to be available
while true do
    if Config and Config.Breathalyzer then break end
    Citizen.Wait(500)
end

if not Config.Breathalyzer.Enabled then return end

Breathalyzer = {}
Breathalyzer.activeTests = {}

-- ============================================================
--  Drunk level fetch (from target client)
-- ============================================================

function Breathalyzer.getTargetDrunkLevel(self, targetSource)
    local drunkLevel = lib.callback.await("p_policejob/client/breathalyzer/getDrunkLevel", targetSource)
    Bridge.Debug(("[Breathalyzer] Target %s drunk level: %s"):format(targetSource, drunkLevel))
    return drunkLevel or 0
end

-- ============================================================
--  Test execution
-- ============================================================

function Breathalyzer.startTest(self, officerSource, targetSource)
    local targetPed = targetSource and GetPlayerPed(targetSource)
    if not targetPed then
        return Bridge.Notify.showNotify(officerSource, locale("no_player_nearby"), "error")
    end

    Config.Breathalyzer.onTestStart_Server(officerSource, targetSource)

    local result = self:getTargetDrunkLevel(targetSource)

    Bridge.Debug(("[Breathalyzer] Player %s tested player %s, result: %s"):format(officerSource, targetSource, result))

    Config.Breathalyzer.onTestComplete_Server(officerSource, targetSource, result)

    return result
end

-- ============================================================
--  Use (server-side: validate job, handle consent, trigger client)
-- ============================================================

function Breathalyzer.use(self, officerSource, targetSource)
    local officerJob = Bridge.Framework.getPlayerJob(officerSource)
    if not Config.Jobs[officerJob.name] then
        return Bridge.Notify.showNotify(officerSource, locale("no_access_breathalyzer"), "error")
    end

    -- Resolve and validate target
    local targetNumeric = tonumber(targetSource)
    if targetNumeric and targetNumeric ~= officerSource and Config.Breathalyzer.requireConsent then
        local officerName = Bridge.Framework.getPlayerName(officerSource)
            or ("ID " .. tostring(officerSource))

        Bridge.Notify.showNotify(targetNumeric, locale("test_request_sent"), "inform")

        local consented = lib.callback.await("p_policejob/client/breathalyzer/requestConsent", targetNumeric, officerName)
        if not consented then
            return Bridge.Notify.showNotify(officerSource, locale("breathalyzer_declined"), "error")
        end
    end

    TriggerClientEvent("p_policejob/client/breathalyzer/open", officerSource, targetSource)
end

-- ============================================================
--  Exports
-- ============================================================

exports("useBreathalyzerItem", function(officerSource, targetSource)
    Breathalyzer:use(officerSource, targetSource)
end)

-- ⚠️ Generic item-use export — the "breathalyzer" export receives action, source, itemData, targetSource, extra
-- Only "usingItem" action is handled; expand if other actions are needed.
exports("breathalyzer", function(action, officerSource, itemData, targetSource, extra)
    if action == "usingItem" then
        Breathalyzer:use(itemData.id)
    end
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/server/breathalyzer/use", function(targetSource)
    Breathalyzer:use(source, targetSource)
end)

-- ============================================================
--  lib callbacks
-- ============================================================

lib.callback.register("p_policejob/server/breathalyzer/startBreathalyzer", function(officerSource, targetSource)
    return Breathalyzer:startTest(officerSource, targetSource)
end)
