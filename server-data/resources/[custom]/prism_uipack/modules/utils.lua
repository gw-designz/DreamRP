Utils = {}
Utils.game = GetGameName()

---@generic T
---@param cb fun(): T?
---@param errMessage? string
---@param timeout? number | false
---@return T
---@async
function Utils.waitFor(cb, errMessage, timeout)
    local value = cb()
    if value ~= nil then return value end

    if timeout == nil then timeout = 1000 end
    if timeout ~= false and type(timeout) ~= 'number' then timeout = 1000 end

    local start = timeout and GetGameTimer()

    while value == nil do
        Wait(0)

        if timeout then
            local elapsed = GetGameTimer() - start
            if elapsed > timeout then
                error(('%s (waited %.1fms)'):format(errMessage or 'failed to resolve callback', elapsed), 2)
            end
        end

        value = cb()
    end

    return value
end

local ASSET_LOAD_ERROR = "failed to load %s '%s' - this may be caused by\n- too many loaded assets\n- oversized, invalid, or corrupted assets"

---@param audioBank string
---@param timeout? number
---@return string
function Utils.requestAudioBank(audioBank, timeout)
    return Utils.waitFor(function()
        if RequestScriptAudioBank(audioBank, false) then return audioBank end
    end, ASSET_LOAD_ERROR:format('audiobank', audioBank), timeout or 30000)
end

---@async
---@generic T : string | number
---@param request function
---@param hasLoaded function
---@param assetType string
---@param asset T
---@param timeout? number
---@param ... any
function Utils.streamingRequest(request, hasLoaded, assetType, asset, timeout, ...)
    if hasLoaded(asset) then return asset end

    request(asset, ...)

    return Utils.waitFor(function()
        if hasLoaded(asset) then return asset end
    end, ASSET_LOAD_ERROR:format(assetType, asset), timeout or 30000)
end

---@param animDict string
---@param timeout? number
---@return string
function Utils.requestAnimDict(animDict, timeout)
    if type(animDict) ~= 'string' then
        error(("expected animDict to have type 'string' (received %s)"):format(type(animDict)))
    end

    if HasAnimDictLoaded(animDict) then return animDict end

    if not DoesAnimDictExist(animDict) then
        error(("attempted to load invalid animDict '%s'"):format(animDict))
    end

    return Utils.streamingRequest(RequestAnimDict, HasAnimDictLoaded, 'animDict', animDict, timeout)
end

---@param model number | string
---@param timeout? number
---@return number
function Utils.requestModel(model, timeout)
    if type(model) ~= 'number' then model = joaat(model) end
    if HasModelLoaded(model) then return model end

    if not IsModelValid(model) and not IsModelInCdimage(model) then
        error(("attempted to load invalid model '%s'"):format(model))
    end

    return Utils.streamingRequest(RequestModel, HasModelLoaded, 'model', model, timeout)
end

local previousKeepInput = IsNuiFocusKeepingInput()

function Utils.setNuiFocus(allowInput, disableCursor)
    previousKeepInput = IsNuiFocusKeepingInput()
    SetNuiFocus(true, not disableCursor)
    SetNuiFocusKeepInput(allowInput)
end

function Utils.resetNuiFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(previousKeepInput)
end

---@class KeybindProps
---@field name string
---@field description string
---@field defaultMapper? string
---@field defaultKey? string
---@field disabled? boolean
---@field disable? fun(self: CKeybind, toggle: boolean)
---@field onPressed? fun(self: CKeybind)
---@field onReleased? fun(self: CKeybind)
---@field [string] any

---@class CKeybind : KeybindProps
---@field currentKey string
---@field disabled boolean
---@field isPressed boolean
---@field hash number
---@field getCurrentKey fun(): string
---@field isControlPressed fun(): boolean

local keybinds = {}

local IsPauseMenuActive              = IsPauseMenuActive
local GetControlInstructionalButton  = GetControlInstructionalButton

local keybind_mt = {
    disabled   = false,
    isPressed  = false,
    defaultKey = '',
    defaultMapper = 'keyboard',
}

function keybind_mt:__index(index)
    return index == 'currentKey' and self:getCurrentKey() or keybind_mt[index]
end

function keybind_mt:getCurrentKey()
    return GetControlInstructionalButton(0, self.hash, true):sub(3)
end

function keybind_mt:isControlPressed()
    return self.isPressed
end

function keybind_mt:disable(toggle)
    self.disabled = toggle
end

---@param data KeybindProps
---@return CKeybind
function Utils.addKeybind(data)
    ---@cast data CKeybind
    data.hash = joaat('+' .. data.name) | 0x80000000
    keybinds[data.name] = setmetatable(data, keybind_mt)

    RegisterCommand('+' .. data.name, function()
        if data.disabled or IsPauseMenuActive() then return end
        data.isPressed = true
        if data.onPressed then data:onPressed() end
    end)

    RegisterCommand('-' .. data.name, function()
        if data.disabled or IsPauseMenuActive() then return end
        data.isPressed = false
        if data.onReleased then data:onReleased() end
    end)

    RegisterKeyMapping('+' .. data.name, data.description, data.defaultMapper, data.defaultKey)

    if data.secondaryKey then
        RegisterKeyMapping('~!+' .. data.name, data.description, data.secondaryMapper or data.defaultMapper, data.secondaryKey)
    end

    SetTimeout(500, function()
        TriggerEvent('chat:removeSuggestion', ('/+%s'):format(data.name))
        TriggerEvent('chat:removeSuggestion', ('/-%s'):format(data.name))
    end)

    return data
end

function Utils.sanitizeItems(items)
    local sanitized = {}

    for i = 1, #items do
        local item      = items[i]
        local safeItem  = {}

        for key, value in pairs(item) do
            if type(value) ~= 'function' and key ~= 'onSelect' then
                safeItem[key] = value
            end
        end

        sanitized[#sanitized + 1] = safeItem
    end

    return sanitized
end

function Utils.debugPrint(message)
    print('[prism-uipack-debug]', message)
end
