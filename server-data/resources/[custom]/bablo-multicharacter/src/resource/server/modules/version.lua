Citizen.CreateThread(function()
    local resourceName   = GetCurrentResourceName()
    local currentVersion = GetResourceMetadata(resourceName, "version", 0)

    -- Helper: strip dots and convert to integer for numeric comparison.
    local function versionToInt(v)
        return tonumber((v:gsub("%.", "")))
    end

    Citizen.Wait(5000)
    print(("^2[%s] - Checking for updates...^0"):format(resourceName))

    local url = ("https://raw.githubusercontent.com/TheRealBablo/version/master/%s.json"):format(resourceName)

    PerformHttpRequest(url, function(statusCode, body, headers)
        if not body then
            print("^1Unable to check version.^0")
            return
        end

        -- The endpoint returns JSON followed by a trailing newline; trim it.
        local data = json.decode(body:sub(1, -2))
        if not data or not data.version then
            print("^1Invalid version data received.^0")
            return
        end

        local remoteInt  = versionToInt(data.version)
        local currentInt = versionToInt(currentVersion)

        if remoteInt > currentInt then
            -- Build a decorative separator whose width matches the header line.
            local separatorColor = ("^%d"):format(math.random(1, 9))
            local separator      = separatorColor .. ("="):rep(26 + #resourceName) .. "^0"

            local patchNotes = table.concat(data.descriptions, "\n")

            print(separator)
            print(([[
^2[%s] - New update available!^0
Current Version: ^5%s^0.
New Version: ^5%s^0.
Patch Notes:
^5%s^0

^5Download it now on your portal.cfx.re/assets/granted-assets^0.]]):format(
                resourceName, currentVersion, data.version, patchNotes))
            print(separator)
        else
            print(("^2[%s] - You are using the latest version.^0"):format(resourceName))
        end
    end, "GET")
end)
