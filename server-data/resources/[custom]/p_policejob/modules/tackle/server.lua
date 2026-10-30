while true do
    if Config and Config.Tackle then break end
    Wait(500)
end

if not Config.Tackle.Enabled then return end

-- ============================================================
--  Access check
-- ============================================================

local function hasJobAccess(playerSource)
    if not Config.Tackle.JobRestricted then return true end

    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job or not job.name then return false end

    local minGrade = Config.Jobs[job.name]
    if minGrade == nil then return false end

    return (job.grade or 0) >= minGrade
end

-- ============================================================
--  tacklePlayer event
-- ============================================================

RegisterNetEvent("p_policejob/server/tackle/tacklePlayer", function(targetSource)
    if type(targetSource) ~= "number" or targetSource < 1 then return end

    local officerSource = source
    if not hasJobAccess(officerSource) then return end

    local officerPed = GetPlayerPed(officerSource)
    local targetPed  = GetPlayerPed(targetSource)

    if not officerPed or officerPed == 0 then return end
    if not targetPed  or targetPed  == 0 then return end

    -- Distance check (max 4 metres)
    local dist = #(GetEntityCoords(officerPed) - GetEntityCoords(targetPed))
    if dist > 4.0 then return end

    -- Trigger tackle animation on both sides
    TriggerClientEvent("p_policejob/client/tackle/tacklePlayer", officerSource, {
        targetId  = targetSource,
        isTackler = true,
    })
    TriggerClientEvent("p_policejob/client/tackle/tacklePlayer", targetSource, {
        targetId  = officerSource,
        isTackler = false,
    })
end)
