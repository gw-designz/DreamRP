
-- shared file used to retrieve config values
-- used by our version of ox_target to retrieve the primary color

local luaConfig = {}
local useConvars = false

local function loadLuaConfig()
    local configContent = LoadResourceFile("prism_uipack", "config.lua")
    if configContent then
        local loadedConfig = load(configContent)()
        if loadedConfig then
            luaConfig = loadedConfig
            useConvars = loadedConfig.useConvars == true
        end
    end
end

local function getConfigValue(key, defaultValue)
    if useConvars then
        local convarValue = GetConvar("prism:" .. key, "")
        return convarValue ~= "" and convarValue or defaultValue
    end
    return luaConfig[key] ~= nil and luaConfig[key] or defaultValue
end

local function getConfigValueInt(key, defaultValue)
    if useConvars then
        return GetConvarInt("prism:" .. key, defaultValue)
    end
    return luaConfig[key] ~= nil and luaConfig[key] or defaultValue
end

loadLuaConfig()

RegisterNuiCallback('getConfig', function(data, cb)
    cb({
        primaryColor = getConfigValue('primaryColor', '#BEEE11'),
        notificationDuration = getConfigValueInt('notificationDuration', 3000),
        progressCancelKey = getConfigValue('progressCancelKey', 'X'),
        targetIcon = getConfigValue('targetIcon', 'fas fa-share')
    })
end)

RegisterNuiCallback('getConfigValue', function(property, cb)
    if not property then return end

    local value = getConfigValue(property, '')
    cb(value)
end)
