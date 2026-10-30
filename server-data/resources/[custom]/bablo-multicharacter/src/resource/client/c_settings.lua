-- KVP key prefix: "bablo_multichar_settings", optionally suffixed with a
-- sanitised server name so each server gets isolated storage.
local KVP_BASE_KEY  = "bablo_multichar_settings"
local sanitisedServerName = ""

-- Fetch the server name once at resource start and sanitise it for use as a KVP suffix.
CreateThread(function()
    local ok, result = pcall(function()
        return lib.callback.await("bablo-multicharacter:server:getServerName", false)
    end)
    if ok and type(result) == "string" and result ~= "" then
        sanitisedServerName = result:gsub("[^%w]", ""):lower()
    else
        sanitisedServerName = ""
    end
end)

local function buildKvpKey()
    if sanitisedServerName ~= "" then
        return KVP_BASE_KEY .. "_" .. sanitisedServerName
    end
    return KVP_BASE_KEY
end

Settings = {}

-- Load and JSON-decode the settings table from KVP storage.
-- Returns the decoded table, or nil if nothing is stored / the stored data is corrupt.
function Settings.LoadKvp(self)
    local raw = GetResourceKvpString(buildKvpKey())
    if not raw or raw == "" then return nil end
    local ok, decoded = pcall(function() return json.decode(raw) end)
    if ok and type(decoded) == "table" then return decoded end
    return nil
end

-- JSON-encode and save a table to KVP storage. Silently ignores non-table values.
function Settings.SaveKvp(self, data)
    if type(data) ~= "table" then return end
    local ok, encoded = pcall(function() return json.encode(data) end)
    if ok and type(encoded) == "string" then
        SetResourceKvp(buildKvpKey(), encoded)
    end
end

-- Resolve the active settings by merging saved KVP data on top of Config defaults.
-- Returns a flat table: { theme, music = { enabled, url, volume }, blur = { fps, intensity } }.
function Settings.Resolve(self)
    local cfgSettings = Config.Settings or {}
    local cfgMusic    = cfgSettings.music or {}
    local cfgBlur     = cfgSettings.blur  or {}
    local saved       = self:LoadKvp() or {}

    -- Prefer saved value; fall back to the provided default.
    local function pick(savedVal, default)
        if savedVal ~= nil then return savedVal end
        return default
    end

    -- Clamp a numeric value to [minVal, maxVal]. Returns nil if the value is not a number.
    local function clampNumber(val, minVal, maxVal)
        if type(val) ~= "number" then return nil end
        if val < minVal then return minVal end
        if val > maxVal then return maxVal end
        return val
    end

    local savedMusic = (type(saved.music) == "table" and saved.music) or {}
    local savedBlur  = (type(saved.blur)  == "table" and saved.blur)  or {}

    local resolved = {}

    resolved.theme = pick(saved.theme, cfgSettings.defaultTheme or "dark")

    resolved.music = {
        enabled = pick(savedMusic.enabled, cfgMusic.enabled ~= false),
        url      = pick(savedMusic.url,     cfgMusic.url     or ""),
        volume   = pick(savedMusic.volume,  cfgMusic.volume  or 0.3),
    }

    local blurFps = clampNumber(savedBlur.fps, 15, 120)
    if not blurFps then blurFps = clampNumber(cfgBlur.fps, 15, 120) or 60 end

    local blurIntensity = clampNumber(savedBlur.intensity, 1, 6)
    if not blurIntensity then blurIntensity = clampNumber(cfgBlur.intensity, 1, 6) or 3 end

    resolved.blur = { fps = blurFps, intensity = blurIntensity }

    return resolved
end

-- Build the socials list from Config.Socials, skipping entries that are disabled or have no URL.
function Settings.ResolveSocials(self)
    local socials = {}
    for _, entry in ipairs(Config.Socials or {}) do
        if entry.enabled and type(entry.url) == "string" and entry.url ~= "" then
            socials[#socials + 1] = {
                kind  = entry.kind  or "custom",
                icon  = entry.icon,
                label = entry.label,
                url   = entry.url,
            }
        end
    end
    return socials
end

-- Build currency formatting config from Config.Currency.
function Settings.ResolveCurrency(self)
    local cfg = Config.Currency or {}
    return {
        pattern   = cfg.pattern   or "$ %s",
        thousands  = cfg.thousands or ",",
    }
end

-- Build theme colours from Config.Theme.
function Settings.ResolveTheme(self)
    local cfg = Config.Theme or {}
    return {
        accent   = cfg.accent   or "#7aadff",
        accentFg = cfg.accentFg or "#0e0e0e",
    }
end

-- Build the character-detail panel config (bio flag + field/money arrays).
-- Shared helper: filter an array of field/money descriptors, keeping only enabled entries
-- that have a recognised kind.
local function filterDetailFields(fields)
    local out = {}
    if type(fields) ~= "table" then return out end
    for _, field in ipairs(fields) do
        if field and field.enabled ~= false and field.kind then
            local entry = { kind = field.kind }
            if field.kind == "custom" then
                entry.id    = field.id
                entry.icon  = field.icon
                entry.label = field.label
            end
            out[#out + 1] = entry
        end
    end
    return out
end

function Settings.ResolveCharacterDetail(self)
    local cfg = Config.CharacterDetail or {}
    return {
        bio    = cfg.bio ~= false,
        fields = filterDetailFields(cfg.fields),
        money  = filterDetailFields(cfg.money),
    }
end

-- Send the full resolved config to the NUI frontend via SET_CONFIG.
function Settings.Push(self)
    SendNUIMessage({
        action = "SET_CONFIG",
        data   = {
            settings        = self:Resolve(),
            socials         = self:ResolveSocials(),
            currency        = self:ResolveCurrency(),
            characterDetail = self:ResolveCharacterDetail(),
            theme           = self:ResolveTheme(),
            branding        = Config.Branding or {},
            enableSpawnMenu = Config.EnableSpawnMenu ~= false,
            allowDeletion   = Config.AllowCharacterDeletion ~= false,
        },
    })
end

-- Shared NUI response helper (mirrors the one in web.lua; defined here for c_settings callbacks).
local function nuiResponse(success, data, message)
    return { success = success, data = data, message = message }
end

RegisterNUICallback("SAVE_SETTINGS", function(data, cb)
    Settings:SaveKvp(data)
    cb(nuiResponse(true, {}, "OK"))
end)

RegisterNUICallback("OPEN_URL", function(data, cb)
    local url = data and data.url
    -- ⚠️ This is a Lua-side fallback. In practice the JS layer should open URLs
    -- via window.invokeNative('openUrl'). If this fires often, check the CEF build.
    Trace(("[Settings] OPEN_URL fallback hit — url=%s. " ..
           "Verify the JS-side window.invokeNative('openUrl') path is reachable in this CEF build."):format(tostring(url)))
    cb(nuiResponse(true, {}, "OK"))
end)

RegisterNUICallback("BLOCK_RAYCAST", function(data, cb)
    if Main then
        Main.raycastBlocked = (data and data.blocked) == true
    end
    cb(nuiResponse(true, {}, "OK"))
end)

RegisterNUICallback("SET_THEME", function(data, cb)
    local theme = data and data.theme
    if Main and Main.pedLabelsDui then
        Main.pedLabelsDui:SetTheme(theme)
    end
    cb(nuiResponse(true, {}, "OK"))
end)

RegisterNUICallback("SET_INPUT_FOCUS", function(data, cb)
    local focused = data and data.focused == true
    -- When a NUI text input gains focus: KeepInput(true) → keyboard goes to browser.
    -- When it loses focus: also keep KeepInput(true) because the UI is still open
    -- and other fields may be clicked next. Setting KeepInput(false) on blur
    -- permanently kills NUI keyboard input for all subsequent fields in the same
    -- session — the original bug that made identity form fields stop accepting input.
    -- KeepInput is only set to false in Destroy() when the UI is fully closed.
    SetNuiFocusKeepInput(true)
    cb(nuiResponse(true, {}, "OK"))
end)
