local resourceName = GetCurrentResourceName()
local localeData   = nil

function splitString(str, separator)
    if separator == nil then separator = "%s" end
    local parts = {}
    for part in string.gmatch(str, "([^" .. separator .. "]+)") do
        table.insert(parts, part)
    end
    return parts
end

local function loadLocaleFile(localeName)
    local filePath = string.format("src/locales/%s.json", localeName)
    local content  = LoadResourceFile(resourceName, filePath)
    if not content then
        Debug.error(Debug, "Locale file not found: " .. filePath)
    end
    return content
end

function loadLocale(localeName)
    if not localeName then
        localeName = Config.Locale
    end

    local content = loadLocaleFile(localeName)
    if not content then
        content = loadLocaleFile("en")
    end
    if not content then
        Debug.error(Debug, "No locale file found.")
        return {}
    end

    local decoded = json.decode(content)
    if not decoded then
        Debug.error(Debug, "Failed to decode locale file.")
        return {}
    end

    return decoded[1]
end

function t(key, vars)
    local function resolveKey()
        local parts  = splitString(key, ".")
        local node   = nil
        for _, part in pairs(parts) do
            node = node and node[part] or localeData[part]
        end
        return node
    end

    local value = resolveKey()

    if vars then
        for placeholder, replacement in pairs(vars) do
            value = string.gsub(value, "{" .. placeholder .. "}", replacement)
        end
    end

    return value
end

localeData = loadLocale()