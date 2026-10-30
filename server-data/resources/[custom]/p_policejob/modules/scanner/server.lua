while true do
    if Config and Config.Scanner then break end
    Citizen.Wait(50)
end

if not Config.Scanner.enabled then return end

-- ============================================================
--  Mugshot lookup helper
-- ============================================================

-- Returns the most recent mugshot URL for a suspect name, or nil.
local function findMugshotUrl(fullName)
    if not Config.Scanner.showMugshot then return nil end
    if not (Mugshot and Mugshot.records) then return nil end

    local nameLower = fullName:lower()
    for _, record in ipairs(Mugshot.records) do
        if record.suspect and record.suspect:lower() == nameLower then
            return record.url
        end
    end
    return nil
end

-- ============================================================
--  Identify callback
-- ============================================================

lib.callback.register("p_policejob/scanner/identify", function(officerSource, targetSource)
    targetSource = tonumber(targetSource)
    if not targetSource or targetSource == 0 then return false end

    -- Job access check
    local officerJob = Bridge.Framework.getPlayerJob(officerSource)
    if not officerJob or not Config.Jobs[officerJob.name] then return false end

    -- Target must be online
    local targetPed = GetPlayerPed(targetSource)
    if not targetPed or targetPed == 0 then return false end

    -- Distance check
    local dist = #(GetEntityCoords(GetPlayerPed(officerSource)) - GetEntityCoords(targetPed))
    if dist > Config.Scanner.maxDistance then return false end

    -- Get first + last name from framework (returns firstName, lastName)
    local firstName, lastName = Bridge.Framework.getPlayerName(targetSource, true)
    if not firstName then return false end
    if not lastName then lastName = "" end

    local fullName = ("%s %s"):format(firstName, lastName):gsub("%s+$", "")

    -- Webhook
    local webhook = (Config.Webhooks and (Config.Webhooks.scanner or Config.Webhooks.objects)) or ""
    Bridge.Logs.Send(officerSource, "Scanner",
        locale("scanner_log_identified", fullName), webhook)

    return {
        firstName = firstName,
        lastName  = lastName,
        mugshot   = findMugshotUrl(fullName),
    }
end)

-- ============================================================
--  getPlayerIdentity export
-- ============================================================

exports("getPlayerIdentity", function(targetSource)
    targetSource = tonumber(targetSource)
    if not targetSource or targetSource == 0 then return nil end

    local firstName, lastName = Bridge.Framework.getPlayerName(targetSource, true)
    if not firstName then return nil end
    if not lastName then lastName = "" end

    local fullName = ("%s %s"):format(firstName, lastName):gsub("%s+$", "")

    return {
        firstName = firstName,
        lastName  = lastName,
        mugshot   = findMugshotUrl(fullName),
    }
end)
