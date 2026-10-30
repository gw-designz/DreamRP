while true do
    if Config then break end
    Citizen.Wait(50)
end

local COMPAT_RESOURCES = {
    "qb-policejob",
    "qbx_police",
    "esx_policejob",
    "wasabi_police",
}

-- Registers an export AND intercepts __cfx_export_* from all compat resources
local function registerCompatExport(exportName, handler)
    for _, resourceName in ipairs(COMPAT_RESOURCES) do
        AddEventHandler(("__cfx_export_%s_%s"):format(resourceName, exportName), function(setCb)
            setCb(handler)
        end)
    end
    exports(exportName, handler)
end

-- Returns a list of server IDs for all currently online police officers
local function getCopList()
    local cops = {}
    for _, playerSource in ipairs(GetPlayers()) do
        local src = tonumber(playerSource)
        if src then
            local job = Bridge.Framework.getPlayerJob(src)
            if job and Config.Jobs[job.name] then
                cops[#cops + 1] = src
            end
        end
    end
    return cops
end

local function getCopCount()
    return #getCopList()
end

-- Returns true if the player (by server ID) has a police job
local function isCop(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return false end
    local job = Bridge.Framework.getPlayerJob(playerSource)
    return job ~= nil
end

-- Returns true if at least `minCount` cops are online (defaults to 1)
local function isPoliceForcePresent(minCount)
    return getCopCount() >= (tonumber(minCount) or 1)
end

registerCompatExport("GetCops",               getCopCount)
registerCompatExport("GetCopCount",            getCopCount)
registerCompatExport("GetCopList",             getCopList)
registerCompatExport("IsPoliceForcePresent",   isPoliceForcePresent)
registerCompatExport("IsCop",                  isCop)
registerCompatExport("IsPolice",               isCop)

-- ============================================================
--  Compat: legacy police alert net event
-- ============================================================

RegisterNetEvent("police:server:policeAlert", function(title)
    if not Bridge.Dispatch or not Bridge.Dispatch.SendAlert then return end

    -- Build job list from Config.Jobs keys
    local jobList = {}
    for jobName in pairs(Config.Jobs) do
        jobList[#jobList + 1] = jobName
    end

    Bridge.Dispatch.SendAlert(source, {
        title    = tostring(title or "Police alert"),
        code     = "10-31",
        icon     = "fa-solid fa-bell",
        priority = "medium",
        blip     = { sprite = 161, scale = 1.0, color = 1 },
        job      = jobList,
    })
end)
