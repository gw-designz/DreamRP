-- Wait for Config.BatteringRam to be available before proceeding
while true do
    if Config and Config.BatteringRam then
        break
    end
    Citizen.Wait(500)
end

if not Config.BatteringRam.enabled then
    return
end

-- Returns true if the given player source has an authorized job
function PlayerHasBatteringRamAccess(playerSource)
    local playerJob  = Bridge.Framework.getPlayerJob(playerSource)
    local allowedJobs = Config.BatteringRam.jobs or Config.Jobs

    if playerJob and allowedJobs then
        return nil ~= allowedJobs[playerJob.name]
    end

    return playerJob or allowedJobs
end

-- Sends a webhook log entry for a battering ram door-force event
function LogBatteringRamUse(playerSource)
    local webhooks = Config.Webhooks
    if webhooks and webhooks.interactions then
        Bridge.Logs.Send(
            playerSource,
            "Interactions",
            "Forced a door open with the battering ram",
            webhooks.interactions
        )
    end
end

-- Net event: forces a specific door open (by door ID) and logs the action
-- doorId is expected to be an ox_doorlock door identifier
RegisterNetEvent("p_policejob/server/batteringram/forceDoor", function(doorId)
    local playerSource = source

    if doorId == nil then
        return
    end

    if not PlayerHasBatteringRamAccess(playerSource) then
        return
    end

    if GetResourceState("ox_doorlock") == "started" then
        exports.ox_doorlock:setDoorState(doorId, 0)
    end

    LogBatteringRamUse(playerSource)

    Bridge.Debug(string.format("[BatteringRam] Player %s forced door %s", playerSource, tostring(doorId)))
end)

-- Net event: logs a door-force action without re-applying doorlock state
-- ⚠️ This event performs no job check and no doorlock change — it appears
--    to be a lightweight logging-only path (e.g. when the client handles
--    the door force locally). Clarify with original author if this is intentional.
RegisterNetEvent("p_policejob:batteringram:log", function()
    local playerSource = source

    LogBatteringRamUse(playerSource)

    Bridge.Debug(string.format("[BatteringRam] Player %s forced a door", playerSource))
end)
