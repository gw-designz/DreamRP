Config = Config or {}

--[[
╔═══════════════════════════════════════════════════════════════════════════════════════════╗
║                         RTC RELAY CONFIGURATION                                           ║
╠═══════════════════════════════════════════════════════════════════════════════════════════╣
║  Dynamic RTC Relay allows you to generate TURN server credentials dynamically             ║
║  for each video call session, improving security and reliability.                         ║
║                                                                                           ║
║  Providers:                                                                               ║
║   - Cloudflare (managed TURN, API-generated ICE servers)                                  ║
║   - Coturn (self-hosted TURN, TURN REST shared-secret credentials)                        ║
║                                                                                           ║
║  Cloudflare Setup Instructions:                                                           ║
║  1. Create a Cloudflare account at https://www.cloudflare.com/                            ║
║  2. Navigate to Realtime > TURN Server in the Cloudflare dashboard                        ║
║  3. Create a new TURN key and copy the Turn Token ID and API Token                        ║
║  4. Add these credentials to server/apiKeys.lua                                           ║
║  5. Set Config.RTCRelay.Enabled = true                                                    ║
║  6. Keep Config.RTCRelay.Provider = "cloudflare"                                          ║
║                                                                                           ║
║  Phone documentation: https://docs.teamsgg.dev/paid-scripts/phone/configure/video-calls   ║
║  Documentation: https://developers.cloudflare.com/realtime/turn/                          ║
╚═══════════════════════════════════════════════════════════════════════════════════════════╝
--]]

--[[
╔═══════════════════════════════════════════════════════════════════════════════════════════╗
║                         COTURN RTC RELAY SETUP                                             ║
╠═══════════════════════════════════════════════════════════════════════════════════════════╣
║  Coturn uses TURN REST shared-secret credentials so each player gets time-limited TURN     ║
║  login details. The shared secret NEVER goes to the client/UI.                             ║
║                                                                                           ║
║  1. Install + configure coturn with: lt-cred-mech + use-auth-secret + static-auth-secret  ║
║  2. Set Config.RTCRelay.Provider = "coturn"                                                ║
║  3. Set Config.RTCRelay.Coturn.Urls = { "turn:...", "turns:..." }                          ║
║  4. Set Config.RTCRelay.Enabled = true                                                     ║
║  5. Set the shared secret in server.cfg (NOT in this config):                              ║
║     set yseriesRTCRelayCoturnSecret "REPLACE_WITH_SHARED_SECRET"                           ║
║                                                                                           ║
║  Coturn project: https://github.com/coturn/coturn                                          ║
║  Example setup guide: https://community.hetzner.com/tutorials/install-turn-stun-server-on- ║
║                       debian-ubuntu-with-coturn/                                           ║
╚═══════════════════════════════════════════════════════════════════════════════════════════╝
--]]

Config.RTCRelay = {}
Config.RTCRelay.Enabled = false         -- Enable dynamic RTC relay? (requires provider configuration)
Config.RTCRelay.Provider = "cloudflare" -- Options: "cloudflare", "coturn"
Config.RTCRelay.StripStun = false       -- Remove STUN servers when using dynamic relay? (not recommended)
Config.RTCRelay.CredentialTTL = 86400   -- Time-to-live for credentials in seconds (default: 24 hours, max: 86400)

-- Coturn (self-hosted) TURN REST API settings (no secrets here; secret is server-side in convars)
-- Use with a coturn server configured with: lt-cred-mech + use-auth-secret + static-auth-secret.
Config.RTCRelay.Coturn = {
    -- One or more TURN/TURNS URLs. Example:
    --  - turn:turn.example.com:3478?transport=udp
    --  - turn:turn.example.com:3478?transport=tcp
    --  - turns:turn.example.com:5349?transport=tcp
    Urls = {},
}

--[[
╔══════════════════════════════════════════════════════════════════╗
║                        UPLOAD CONFIGURATION                      ║
╠══════════════════════════════════════════════════════════════════╣
║     For detailed documentation and setup instructions, visit:    ║
║   https://docs.teamsgg.dev/paid-scripts/phone/configure/camera   ║
╚══════════════════════════════════════════════════════════════════╝
--]]

-- Whether the player will be able to upload files from external sources(links) as media.
Config.AllowExternalUpload = {
    Y = true,
    YBuy = true,
    Messages = true,
    Settings = true, -- Includes changing background.
    Instashots = true,
    PromoHub = true,
    Lovr = true,
    News = true,
    Contacts = true,
}

-- The maximum alowed video to capture with the phone camera. In seconds. *default - 20
Config.MaxVideoDuration = 25

Config.Upload = {}
-- Your upload method. (Discord, Fivemanage, Custom).
-- We higly advise you to not use Discord as permanent storage as the url will expire after a while.
-- Fivemanage has a free tier storage that allows you to upload images, videos and audio files. *docs - https://docs.fivemanage.com/
-- This integration uses Fivemanage's V3 API (presigned-URL flow) - your token never leaves the server.
-- Quick installation guide of Fivemanage - https://youtu.be/GL7HBlA9i4s
-- Custom is a custom upload method that you can use to upload files to your own server. If you're not sure how to use it, use *Fivemanage*.
Config.Upload.Method = { -- Options: (Discord, Fivemanage, Custom).
    Image = "Fivemanage",
    Video = "Fivemanage",
    Audio = "Fivemanage"
}

Config.Upload.Quality = 0.85 -- The quality of the uploaded image. *default - 0.95. *range - 0.0 - 1.0

-- !!! IMPORTANT !!!
-- !!! IMPORTANT !!!
--------------------
-- Set your API KEYS in `server\apiKeys.lua`
--------------------
-- !!! IMPORTANT !!!
-- !!! IMPORTANT !!!

Config.Upload.Methods = {
    Fivemanage = {
        -- V3 API: presigned URL is minted server-side per-upload (server/utils/utils.lua)
        -- and the response shape is { status, data: { id, url } } - hence successPath "data.url".
        Image = {
            url = "AUTO_POPULATED_DO_NOT_TOUCH",
            field = "file",
            successPath = "data.url"
        },
        Video = {
            url = "AUTO_POPULATED_DO_NOT_TOUCH",
            field = "file",
            successPath = "data.url"
        },
        Audio = {
            url = "AUTO_POPULATED_DO_NOT_TOUCH",
            field = "file",
            successPath = "data.url"
        }
    },
    Discord = {
        Image = {
            url = 'https://discord.com/api/webhooks/',
            field = "files[]",
            successPath = "attachments.0.url"
        },
        Video = {
            url = 'https://discord.com/api/webhooks/',
            field = "files[]",
            successPath = "attachments.0.url"
        },
        Audio = {
            url = 'https://discord.com/api/webhooks/',
            field = "files[]",
            successPath = "attachments.0.url"
        }
    },
    Custom = {
        Video = {
            url = "https://upload-url.com/",
            field = "file",
            headers = {
                ["Authorization"] = "API_KEY"
            },
            successPath = "url"
        },
        Image = {
            url = "https://upload-url.com/",
            field = "file",
            headers = {
                ["Authorization"] = "API_KEY"
            },
            successPath = "url"
        },
        Audio = {
            url = "https://upload-url.com/",
            field = "file",
            headers = {
                ["Authorization"] = "API_KEY"
            },
            successPath = "url"
        },
    }
}
