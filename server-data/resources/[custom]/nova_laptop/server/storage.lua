Storage = {}
local function defaults()
    return {
        theme = Config.DefaultSettings.theme,
        wallpaper = Config.DefaultSettings.wallpaper,
        accent = Config.DefaultSettings.accent,
        sounds = Config.DefaultSettings.sounds
    }
end

function Storage.Read(key)
    local raw = GetResourceKvpString('nova:v1:' .. key)
    if not raw then return { version = 1, notes = {}, settings = defaults() } end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' or data.version ~= 1 or type(data.notes) ~= 'table' then
        -- Never silently overwrite unreadable persisted notes.
        error('Stored laptop data could not be read. Restore the server KVP backup.')
    end
    data.settings = type(data.settings) == 'table' and data.settings or defaults()
    return data
end

function Storage.Write(key, data)
    local encoded = json.encode(data)
    SetResourceKvp('nova:v1:' .. key, encoded)
    if GetResourceKvpString('nova:v1:' .. key) ~= encoded then
        error('The server could not save laptop data.')
    end
end


function Storage.SaveSettings(key, settings)
    if type(settings) ~= 'table' then return nil, 'Invalid settings.' end
    local themes = { light = true, dark = true }
    local wallpapers = { bloom = true, dusk = true, aurora = true }
    local accents = { red = true, blue = true, violet = true, mint = true }
    if not themes[settings.theme] or not wallpapers[settings.wallpaper] or not accents[settings.accent]
        or type(settings.sounds) ~= 'boolean' then return nil, 'Invalid appearance settings.' end
    local clean = { theme = settings.theme, wallpaper = settings.wallpaper,
        accent = settings.accent, sounds = settings.sounds }
    local data = Storage.Read(key)
    data.settings = clean
    Storage.Write(key, data)
    return clean
end
