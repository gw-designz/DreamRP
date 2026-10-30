ServerConfig = {}

-- Photo / video uploads (Camera, voice messages, profile pictures).
ServerConfig.Camera = {
    provider = 'fivemanage', -- 'discord' or 'fivemanage'

    discord = {
        webhook = '',
    },

    fivemanage = {
        apiKey = '4hDHMy96SSQqyOakYjB5XUfG4PrbSI13', -- your Fivemanage API key: https://fivemanage.com
        url = 'https://api.fivemanage.com/api/v3/file',
    },
}

-- GIFs (Messages). Free key from https://developers.giphy.com (pick API, not SDK).
ServerConfig.Gif = {
    apiKey = '',
}