--[[
    Server-only settings. This file is loaded by the server alone and never
    sent to players, so secrets go here (config.lua is sent to everyone).
]]

ServerConfig = {}

-- Photos from the Camera app are uploaded to Fivemanage.
ServerConfig.Fivemanage = {
    apiKey = '4hDHMy96SSQqyOakYjB5XUfG4PrbSI13', -- your Fivemanage API key: https://fivemanage.com
    url = 'https://api.fivemanage.com/api/v3/file',
}
