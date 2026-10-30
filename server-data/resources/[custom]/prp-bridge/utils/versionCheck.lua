local url = "https://raw.githubusercontent.com/ProdigyPRP/prp-bridge/main/versions/%s.json"
local checked = {}

local function checkVersion(resource)
    if not BridgeConfig or BridgeConfig.VersionCheck ~= true then return end
    if checked[resource] or type(resource) ~= "string" or resource == "" then return end
    checked[resource] = true

    local localVersion = GetResourceMetadata(resource, "version", 0)
    if type(localVersion) ~= "string" or localVersion == "" then
        return print(("^1[prp-bridge]: No version found in fxmanifest.lua for %s^7"):format(resource))
    end

    PerformHttpRequest(url:format(resource), function(status, body)
        if status ~= 200 then
            return print(("^1[prp-bridge]: Failed to fetch %s version (Code: %s)^7"):format(resource, status))
        end

        local ok, data = pcall(json.decode, body or "")
        if not ok or type(data) ~= "table" or type(data.version) ~= "string" then
            return print(("^1[prp-bridge]: Invalid version file for %s^7"):format(resource))
        end

        if data.version == localVersion then
            return
        end

        print(("^3[prp-bridge]: %s is out of date | Current: v%s | Latest: v%s^7 Please download the latest version from https://portal.cfx.re/"):
            format(resource, localVersion, data.version))

        if type(data.changes) == "table" and #data.changes > 0 then
            print("^5[prp-bridge]: \n Changes:")
            for _, change in ipairs(data.changes) do
                print(("^5  - %s^7"):format(change))
            end
        end

        if type(data.filesAffected) == "table" and #data.filesAffected > 0 then
            print("^5Files Affected:")
            for _, file in ipairs(data.filesAffected) do
                print(("^5  - %s^7"):format(file))
            end
        end
    end, "GET", "", { ["user-agent"] = "prp-bridge/1.0" })
end

exports("CheckVersion", checkVersion)