-------------------------------------
-------------------------------------
--- IMPORTANT: READ FULLY -----------
------- IMPORTANT: READ FULLY -------
----------- IMPORTANT: READ FULLY ---
-------------------------------------
-------------------------------------
-- The API keys for the different upload methods. (Discord, Fivemanage, Custom).
-- For Fivemanage (V3 API) you can use a single workspace token for Image/Video/Audio/Logs,
-- or keep separate tokens per media type using the convars below. The phone uses the
-- per-type tokens when minting V3 presigned URLs (see server/utils/utils.lua).
-- !! How to generate a Fivemanage token: https://youtu.be/GL7HBlA9i4s !!


------------ RECOMMENDED ------------
-- If you want to keep your apiKeys in `server.cfg` you can set them like this:
-- set yseriesApiKeyImage "REPLACE_WITH_YOUR_API_KEY"
-- set yseriesApiKeyVideo "REPLACE_WITH_YOUR_API_KEY"
-- set yseriesApiKeyAudio "REPLACE_WITH_YOUR_API_KEY"
-------------------------------------
------- IMPORTANT: READ FULLY -------
-------------------------------------

-- READ IN OUR DOCUMENTATION HOW TO SET THE API KEYS IN SERVER.CFG - https://docs.teamsgg.dev/paid-scripts/phone/configure#camera

ApiKeys = {
    Image = GetConvar("yseriesApiKeyImage", "SET_YOUR_API_KEY_IN_SERVER.CFG"),
    Video = GetConvar("yseriesApiKeyVideo", "SET_YOUR_API_KEY_IN_SERVER.CFG"),
    Audio = GetConvar("yseriesApiKeyAudio", "SET_YOUR_API_KEY_IN_SERVER.CFG"),
    Logs = GetConvar("yseriesApiKeyLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG")
}

-- The Discord webhook that will be used to send the posts to the Discord channel.
LogsWebhooks = {                                                                                            -- https://docs.teamsgg.dev/paid-scripts/phone/configure#camera
    ['instashots_posts'] = GetConvar("yseriesInstashotsPostsLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),       -- Instashots Posts
    ['instashots_messages'] = GetConvar("yseriesInstashotsMessagesLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"), -- Instashots Messages
    ['y_posts'] = GetConvar("yseriesYPostsLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                         -- Y Posts
    ['y_messages'] = GetConvar("yseriesYMessagesLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                   -- Y Messages
    ['ypay'] = GetConvar("yseriesYPayLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                              -- Posts
    ['ybuy'] = GetConvar("yseriesYBuyLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                              -- Posts
    ['companies'] = GetConvar("yseriesCompaniesLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                    -- Duty On/Off
    ['phone'] = GetConvar("yseriesPhoneLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                            -- Calls
    ['messages'] = GetConvar("yseriesMessagesLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                      -- Messages
    ['darkchat'] = GetConvar("yseriesDarkChatLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                      -- Messages
    ['promoHub'] = GetConvar("yseriesPromoHubLogs", "SET_YOUR_API_KEY_IN_SERVER.CFG"),                      -- Promo Hub
}

-- How to setup Pexels API Key - https://docs.teamsgg.dev/paid-scripts/phone/configure/wallpapers-app
-- Get your FREE Pexels API key at: https://www.pexels.com/api/
WallpapersAppApiKey = GetConvar("yseriesPexelsApiKey", "SET_YOUR_PEXELS_API_KEY_IN_SERVER.CFG")

--[[
╔═══════════════════════════════════════════════════════════════════════════════════════════╗
║                         RTC RELAY CONFIGURATION                                           ║
╠═══════════════════════════════════════════════════════════════════════════════════════════╣
║  Dynamic RTC Relay allows you to generate TURN server credentials dynamically             ║
║  for each video call session, improving security and reliability.                         ║
║                                                                                           ║
║  Setup Instructions:                                                                      ║
║  1. Create a Cloudflare account at https://www.cloudflare.com/                            ║
║  2. Navigate to Realtime > TURN Server in the Cloudflare dashboard                        ║
║  3. Create a new TURN key and copy the Turn Token ID and API Token                        ║
║  4. Add these credentials to server/apiKeys.lua                                           ║
║  5. Set Config.RTCRelay.enabled = true                                                    ║
║                                                                                           ║
║  Phone documentation: https://docs.teamsgg.dev/paid-scripts/phone/configure/video-calls   ║
║  Documentation: https://developers.cloudflare.com/realtime/turn/                          ║
╚═══════════════════════════════════════════════════════════════════════════════════════════╝
--]]

RTCRelaySecrets = {
    token = GetConvar("yseriesRTCRelayToken", ""),  -- Turn Token ID from Cloudflare
    apiKey = GetConvar("yseriesRTCRelayApiKey", "") -- API Token from Cloudflare
}

-- Coturn TURN REST API shared secret (used when Config.RTCRelay.Provider == "coturn")
-- Set in server.cfg: set yseriesRTCRelayCoturnSecret "REPLACE_WITH_SHARED_SECRET"
RTCRelayCoturnSecrets = {
    sharedSecret = GetConvar("yseriesRTCRelayCoturnSecret", "")
}
