--[[
╔════════════════════════════════════════════════════════════════════════════════╗
║                         RTC RELAY SERVER MODULE                                ║
╠════════════════════════════════════════════════════════════════════════════════╣
║  Handles dynamic TURN server credential generation for video calls.            ║
║  Supports:                                                                     ║
║   - Cloudflare TURN (dynamic ICE servers via API)                              ║
║   - Coturn TURN (TURN REST shared-secret, time-limited credentials)            ║
╚════════════════════════════════════════════════════════════════════════════════╝
--]]

---@type table<number, string> Store active Cloudflare usernames per player (source -> username)
local activeCredentials = {}

---@type boolean
local didCoturnSelfTest = false

---@type RTCRelayLocked|nil
local rtcRelayLocked = nil

---@return string|nil
local function getRTCRelayProvider()
    if not Config or not Config.RTCRelay or not Config.RTCRelay.Provider then
        return nil
    end

    return string.lower(tostring(Config.RTCRelay.Provider))
end

---@return number
local function getCredentialTTL()
    local ttl = 86400
    if Config and Config.RTCRelay and tonumber(Config.RTCRelay.CredentialTTL) then
        ttl = tonumber(Config.RTCRelay.CredentialTTL) --[[@as number]]
    end

    if ttl > 86400 then ttl = 86400 end -- keep consistent with Cloudflare limit + config docs
    if ttl < 60 then ttl = 60 end       -- avoid extremely short-lived credentials

    return ttl
end

---Loads the escrowed coturn helper module (outside server/custom).
---This prevents end-users from accidentally breaking the TURN REST crypto logic.
---@return table|nil
local function getRTCRelayLocked()
    if rtcRelayLocked then
        return rtcRelayLocked
    end

    local ok, result = pcall(lib.require, 'server.functions.rtcRelayInternal')

    if not ok then
        lib.print.error(("Failed to load RTC relay module (server/functions/rtcRelayInternal.lua): %s"):format(tostring(result)))
        return nil
    end

    if type(result) ~= 'table' then
        lib.print.error(("RTC relay module returned %s (expected table)."):format(type(result)))
        return nil
    end

    rtcRelayLocked = result
    return rtcRelayLocked
end

--[[
    Revoke Cloudflare TURN credentials for a player
    @param source number Player source ID
--]]
local function revokeCloudflareCredentials(source)
    local username = activeCredentials[source]

    if not username then
        return
    end

    local url = string.format("https://rtc.live.cloudflare.com/v1/turn/keys/%s/credentials/%s/revoke",
        RTCRelaySecrets.token, username)

    PerformHttpRequest(url, function(status, body, headers, errorData)
        if status >= 200 and status < 300 then
            lib.print.debug(string.format("Successfully revoked RTC relay credentials for player %d (%s).", source, username))
        else
            lib.print.warn(string.format("Failed to revoke RTC relay credentials for player %d (%s). Status: %d", source, username, status))
            if Config.DebugPrint then
                print("Response body:", body)
                print("Error data:", json.encode(errorData))
            end
        end
    end, "POST", "", {
        ["Authorization"] = "Bearer " .. RTCRelaySecrets.apiKey,
        ["Content-Type"] = "application/json"
    })

    activeCredentials[source] = nil
end

--[[
    Generate Cloudflare TURN credentials for a player
    @param source number Player source ID
    @return table|nil ICE servers configuration or nil on failure
--]]
local function getCloudflareCredentials(source)
    -- Revoke any existing credentials first
    revokeCloudflareCredentials(source)

    local url = string.format("https://rtc.live.cloudflare.com/v1/turn/keys/%s/credentials/generate-ice-servers",
        RTCRelaySecrets.token)

    local credentialsPromise = promise.new()

    local ttl = Config.RTCRelay.CredentialTTL or 86400
    if ttl > 86400 then
        ttl = 86400 -- Max 24 hours
    end

    PerformHttpRequest(url, function(status, body, headers, errorData)
        if status ~= 201 then
            lib.print.error(string.format("Failed to get RTC relay credentials from Cloudflare. Status: %d", status))
            if Config.DebugPrint then
                print("Response body:", body)
                print("Headers:", json.encode(headers))
                print("Error data:", json.encode(errorData))
            end

            credentialsPromise:resolve(nil)
            return
        end

        local success, credentials = pcall(json.decode, body)

        if not success or not credentials or not credentials.iceServers then
            lib.print.error("Failed to parse RTC relay credentials from Cloudflare. Invalid response.")
            if Config.DebugPrint then
                print("Response body:", body)
            end

            credentialsPromise:resolve(nil)
            return
        end

        -- Extract username from credentials for revocation tracking
        local username = nil
        for i = 1, #credentials.iceServers do
            if credentials.iceServers[i].username then
                username = credentials.iceServers[i].username
                break
            end
        end

        if username then
            activeCredentials[source] = username
        end

        credentialsPromise:resolve(credentials.iceServers)
    end, "POST", json.encode({
        ttl = ttl
    }), {
        ["Authorization"] = "Bearer " .. RTCRelaySecrets.apiKey,
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json"
    })

    return Citizen.Await(credentialsPromise)
end

--[[
    Generate coturn TURN REST API ICE server credentials for a player.

    Expects coturn config to enable:
      - lt-cred-mech
      - use-auth-secret
      - static-auth-secret=<sharedSecret>

    @param source number Player source ID
    @return table|nil ICE servers configuration or nil on failure
--]]
local function getCoturnCredentials(source)
    if not Config or not Config.RTCRelay or not Config.RTCRelay.Coturn or type(Config.RTCRelay.Coturn) ~= "table" then
        lib.print.error("RTC Relay (coturn) is enabled but Config.RTCRelay.Coturn is missing.")
        return nil
    end

    local urls = Config.RTCRelay.Coturn.Urls
    if not urls or type(urls) ~= "table" or #urls == 0 then
        lib.print.error("RTC Relay (coturn) is enabled but Config.RTCRelay.Coturn.Urls is empty.")
        return nil
    end

    if not RTCRelayCoturnSecrets
        or type(RTCRelayCoturnSecrets) ~= "table"
        or not RTCRelayCoturnSecrets.sharedSecret
        or RTCRelayCoturnSecrets.sharedSecret == "" then
        lib.print.error("RTC Relay (coturn) is enabled but shared secret is missing. Please set yseriesRTCRelayCoturnSecret in server.cfg.")
        return nil
    end

    if Config and Config.DebugPrint then
        local locked = getRTCRelayLocked()
        if locked and not didCoturnSelfTest and type(locked.CoturnCryptoSelfTest) == "function" then
            didCoturnSelfTest = true
            local ok, err = locked.CoturnCryptoSelfTest()
            if not ok then
                lib.print.error(("Coturn TURN REST crypto self-test failed: %s"):format(tostring(err)))
            else
                lib.print.debug("Coturn TURN REST crypto self-test OK.")
            end
        end
    end

    local ttl = getCredentialTTL()
    local locked = getRTCRelayLocked()
    if not locked or type(locked.BuildCoturnIceServers) ~= "function" then
        lib.print.error("RTC Relay (coturn) is enabled but locked module is not available.")
        return nil
    end

    return locked.BuildCoturnIceServers({
        urls = urls,
        sharedSecret = RTCRelayCoturnSecrets.sharedSecret,
        source = source,
        ttl = ttl,
    })
end

--[[
    Server callback to get RTC relay credentials
    @param source number Player source ID
    @return table|nil ICE servers configuration or nil on failure
--]]
lib.callback.register('yseries:server:rtc:get-relay-credentials', function(source)
    if not Config or not Config.RTCRelay or not Config.RTCRelay.Enabled then
        return nil
    end

    local provider = getRTCRelayProvider()

    if provider == "cloudflare" then
        if not RTCRelaySecrets
            or type(RTCRelaySecrets) ~= "table"
            or not RTCRelaySecrets.token or RTCRelaySecrets.token == ""
            or not RTCRelaySecrets.apiKey or RTCRelaySecrets.apiKey == "" then
            lib.print.error("RTC Relay (cloudflare) is enabled but credentials are missing. Please set them in server/apiKeys.lua (or server.cfg convars).")
            return nil
        end
        return getCloudflareCredentials(source)
    elseif provider == "coturn" then
        return getCoturnCredentials(source)
    end

    lib.print.error(("RTC Relay is enabled but no valid provider was configured. Provider=%s"):format(tostring(provider)))
    return nil
end)

-- Cleanup credentials when player disconnects
AddEventHandler("playerDropped", function()
    local src = source

    if getRTCRelayProvider() == "cloudflare" then
        revokeCloudflareCredentials(src)
    end
end)

-- Cleanup all credentials when resource stops
local function revokeAllCredentials()
    for source in pairs(activeCredentials) do
        if getRTCRelayProvider() == "cloudflare" then
            revokeCloudflareCredentials(source)
        end
    end
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        revokeAllCredentials()
    end
end)

AddEventHandler("txAdmin:events:serverShuttingDown", function()
    revokeAllCredentials()
end)
