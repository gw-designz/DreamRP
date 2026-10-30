-- Wait for Config to be available
while not Config do Citizen.Wait(50) end

local BELL_DEFAULT_COOLDOWN = 30  -- seconds
local bellNextUseTime       = 0   -- unix timestamp; shared across all bells

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Notifies all online players whose job is in the given jobs table
function NotifyJobPlayers(bellConfig, senderSource)
    for _, rawId in ipairs(GetPlayers()) do
        local numericId = tonumber(rawId) or rawId
        local playerJob = numericId and Bridge.Framework.getPlayerJob(numericId)

        if playerJob then
            local allowedJobs = bellConfig.jobs or Config.Jobs
            if allowedJobs[playerJob.name] then
                Bridge.Notify.showNotify(numericId, locale("bell_alert"), "inform")
            end
        end
    end
end

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Client → server: a player pressed the bell interaction
RegisterNetEvent("p_policejob/server/departments/useBell", function(bellIndex)
    local playerSource = source
    local bellData     = Config.DepartmentData.bells[tonumber(bellIndex) or 0]
    if not bellData then return end

    -- Validate player ped exists
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return end

    -- Distance check
    local playerPos = GetEntityCoords(ped)
    local bellPos   = vec3(bellData.coords.x, bellData.coords.y, bellData.coords.z)
    if #(playerPos - bellPos) > 5.0 then return end

    -- Cooldown check
    local now = os.time()
    if now < bellNextUseTime then
        local remaining = bellNextUseTime - now
        return Bridge.Notify.showNotify(playerSource, locale("bell_cooldown", remaining), "error")
    end

    bellNextUseTime = now + (bellData.cooldown or BELL_DEFAULT_COOLDOWN)

    -- Build the allowed jobs list for dispatch
    local allowedJobsList = {}
    for jobName in pairs(bellData.jobs or Config.Jobs) do
        allowedJobsList[#allowedJobsList + 1] = jobName
    end

    -- Send dispatch alert or fall back to direct notification
    if Bridge.Dispatch and Bridge.Dispatch.SendAlert then
        Bridge.Dispatch.SendAlert(playerSource, {
            title    = locale("bell_alert"),
            code     = locale("bell"),
            icon     = "fa-solid fa-bell",
            priority = "low",
            blip     = { sprite = 409, scale = 0.8, color = 1 },
            job      = allowedJobsList,
        })
    else
        NotifyJobPlayers(bellData, playerSource)
    end

    Bridge.Notify.showNotify(playerSource, locale("bell_rang"), "success")
    Bridge.Debug(string.format("[Departments] Player %s rang bell #%s", playerSource, bellIndex))
end)
