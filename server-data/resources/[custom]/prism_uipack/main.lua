local luaConfig  = {}
local useConvars = false

local function LoadConfig()
    local content = LoadResourceFile(GetCurrentResourceName(), 'config.lua')
    if not content then return end

    local loaded = load(content)()
    if not loaded then return end

    luaConfig  = loaded
    useConvars = loaded.useConvars == true
end

local function GetConfigValue(key, default)
    if useConvars then
        local value = GetConvar('prism:' .. key, '')
        return (value ~= '' and value) or default
    end
    return luaConfig[key] ~= nil and luaConfig[key] or default
end

local function GetConfigInt(key, default)
    if useConvars then
        return GetConvarInt('prism:' .. key, default)
    end
    return luaConfig[key] ~= nil and luaConfig[key] or default
end

local function LoadLocale(locale)
    locale = locale or 'en'
    local content = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.lua'):format(locale))
    if not content then return {} end
    return load(content)() or {}
end

local function DebugPrintConfig(config)
    Utils.debugPrint(('Locale: %s'):format(config.locale))
    Utils.debugPrint('Config Table:')

    for key, value in pairs(config) do
        if type(value) == 'table' then
            Utils.debugPrint(key .. ': {')
            for k, v in pairs(value) do
                Utils.debugPrint('  ' .. tostring(k) .. ' = ' .. tostring(v))
            end
            Utils.debugPrint('}')
        else
            Utils.debugPrint(tostring(key) .. ' = ' .. tostring(value))
        end
    end
end

LoadConfig()

RegisterNUICallback('getConfig', function(data, cb)
    local locale    = GetConfigValue('locale', 'en')
    local debugMode = GetConfigInt('debug', 0) == 1

    local config = {
        primaryColor       = GetConfigValue('primaryColor', '#BEEE11'),
        notificationDuration = GetConfigInt('notificationDuration', 3000),
        progressCancelKey  = GetConfigValue('progressCancelKey', 'X'),
        progressMinimal    = GetConfigValue('secondaryProgressMinimal', false),
        notifyPosition     = GetConfigValue('notificationPosition', 'top-center'),
        textUIPosition     = GetConfigValue('textUIPosition', 'center-left'),
        progressVariant    = GetConfigValue('progressBar', 'primary'),
        skillcheckVariant  = GetConfigValue('skillcheckVariant', 'circle'),
        debugMode          = debugMode,
        locale             = locale,
        locales            = LoadLocale(locale),
    }

    if debugMode then
        DebugPrintConfig(config)
    end

    cb(config)
end)

-- Notify
exports('Notify', Notify)
RegisterNetEvent('prism:notify', Notify)

-- TextUI
exports('ShowTextUI',   ShowTextUI)
exports('HideTextUI',   HideTextUI)
exports('IsTextUIOpen', IsTextUIOpen)

-- Progress
exports('ProgressBar',    ProgressBar)
exports('ProgressActive', ProgressActive)
exports('CancelProgress', CancelProgress)

-- Radial
exports('AddRadialItem',      AddRadialItem)
exports('RemoveRadialItem',   RemoveRadialItem)
exports('ClearRadialItems',   ClearRadialItems)
exports('RegisterRadial',     RegisterRadial)
exports('HideRadial',         HideRadial)
exports('DisableRadial',      disableRadial)
exports('GetCurrentRadialId', GetCurrentRadialId)

-- SkillCheck
exports('SkillCheck',       SkillCheck)
exports('SkillCheckActive', SkillCheckActive)
exports('CancelSkillCheck', CancelSkillCheck)

-- Input Dialog
exports('InputDialog',       InputDialog)
exports('CloseInputDialog',  CloseInputDialog)

-- Context Menu
exports('RegisterContext',    RegisterContext)
exports('ShowContext',        ShowContext)
exports('HideContext',        HideContext)
exports('GetOpenContextMenu', GetOpenContextMenu)

-- Alert Dialog
exports('AlertDialog',      AlertDialog)
exports('CloseAlertDialog',  CloseAlertDialog)

-- Menu
exports('RegisterMenu',   RegisterMenu)
exports('ShowMenu',        ShowMenu)
exports('HideMenu',        HideMenu)
exports('GetOpenMenu',     GetOpenMenu)
exports('SetMenuOptions',  SetMenuOptions)
