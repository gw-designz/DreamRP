while true do
    if Config then break end
    Citizen.Wait(50)
end

-- Police job resource names to shim exports/events for
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

local function isHandcuffed()
    return LocalPlayer.state.isCuffed == true
end

local function isPolice()
    local job = Bridge.Framework.fetchPlayerJob()
    return job ~= nil
end

registerCompatExport("IsHandcuffed",      isHandcuffed)
registerCompatExport("isHandcuffed",      isHandcuffed)
registerCompatExport("IsPlayerHandcuffed", isHandcuffed)
registerCompatExport("IsCop",   isPolice)
registerCompatExport("IsPolice", isPolice)
