Config = Config or {}

--[[
╔════════════════════════════════════════════════════════════════════════╗
║                          LOGS CONFIGURATION                            ║
╠════════════════════════════════════════════════════════════════════════╣
║       For detailed documentation and setup instructions, visit:        ║
║       https://docs.teamsgg.dev/paid-scripts/phone/configure/logs       ║
╚════════════════════════════════════════════════════════════════════════╝
--]]

Config.Logs = {}                 -- The webhook that will be used to send the posts to the discord channel.
Config.Logs.Provider = 'discord' -- Options: 'discord', 'fivemanage'
Config.Logs.Timeout = 30         -- The amount of time in seconds that the logs will be queued before being sent to the discord channel.
Config.Logs.Webhooks = {
    -- Logs webhooks are moved in - `server\apiKeys.lua`
}

Config.Logs.Avatars = { -- The avatar for the bot that will be used to send the posts to the discord channel.
    ['instashots'] = '',
    ['instashots_posts'] = '',
    ['instashots_messages'] = '',
    ['y'] = '',
    ['y_posts'] = '',
    ['y_messages'] = '',
    ['ypay'] = '',
    ['ybuy'] = '',
    ['companies'] = '',
    ['phone'] = '',
    ['messages'] = '',
    ['darkchat'] = '',
    ['special'] = '',
    ['promoHub'] = '',
}

Config.Logs.Colors = { -- https://www.spycolor.com/
    ['instashots'] = 15884387,
    ['instashots_posts'] = 15884387,
    ['instashots_messages'] = 15884387,
    ['companies'] = 1940464,
    ['default'] = 14423100,
    ['ybuy'] = 15020857,
    ['ypay'] = 431319,
    ['y'] = 1940464,
    ['y_posts'] = 1940464,
    ['y_messages'] = 1940464,
    ['phone'] = 009966,
    ['messages'] = 0x1388d6,
    ['darkchat'] = 0x128b7d,
    ['special'] = 0xFF0000,
    ['promoHub'] = 0xffc900,
}
