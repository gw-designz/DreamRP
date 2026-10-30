while true do
    if Config and Config.SmallItems then break end
    Citizen.Wait(500)
end

if not Config.SmallItems.Enabled then return end

-- Server side is intentionally minimal — item registration is handled by
-- Bridge.Framework.registerItem in each sub-module's config or by the client
-- net events. This file exists to satisfy the fxmanifest server_script entry.
