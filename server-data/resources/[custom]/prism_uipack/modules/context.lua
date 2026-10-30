---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: duplicate-doc-field

---@class ContextMenuItem
---@field title? string
---@field menu? string
---@field icon? string | { [1]: IconProp, [2]: string }
---@field iconColor? string
---@field image? string
---@field progress? number
---@field onSelect? fun(args: any)
---@field arrow? boolean
---@field description? string
---@field metadata? string | { [string]: any } | string[]
---@field disabled? boolean
---@field readOnly? boolean
---@field event? string
---@field serverEvent? string
---@field args? any

---@class ContextMenuArrayItem : ContextMenuItem
---@field title string

---@class ContextMenuProps
---@field id string
---@field title string
---@field subtitle? string
---@field titleIcon? string
---@field sectionTitle? string
---@field sectionIcon? string
---@field footerLabel? string
---@field menu? string
---@field onExit? fun()
---@field onBack? fun()
---@field canClose? boolean
---@field position? 'right' | 'left'
---@field options { [string]: ContextMenuItem } | ContextMenuArrayItem[]

local luaConfig   = {}
local useConvars  = false
local contextMenus     = {}
local openContextMenu  = nil

local function LoadConfig()
    local content = LoadResourceFile(GetCurrentResourceName(), 'config.lua')
    if not content then return end

    local loaded = load(content)()
    if not loaded then return end

    luaConfig   = loaded
    useConvars  = loaded.useConvars == true
end

local function GetConfigValue(key, default)
    if useConvars then
        local value = GetConvar('prism:' .. key, '')
        return value ~= '' and value or default
    end
    return luaConfig[key] ~= nil and luaConfig[key] or default
end

LoadConfig()

local function CloseContextInternal(cb, onExit)
    if cb then cb(1) end

    Utils.resetNuiFocus()

    if not openContextMenu then return end

    local menu = contextMenus[openContextMenu]
    if (cb or onExit) and menu.onExit then menu.onExit() end

    TriggerEvent('prism_uipack:contextClosed')

    if not cb then SendNUIMessage({ action = 'hideContext' }) end

    openContextMenu = nil
end

---@param id string
function ShowContext(id)
    if not contextMenus[id] then error('No context menu of such id found.') end

    local data = contextMenus[id]
    openContextMenu = id

    Utils.setNuiFocus(false)
    TriggerEvent('prism_uipack:contextOpened')

    local position = data.position or GetConfigValue('contextMenuPosition', 'right')

    SendNuiMessage(json.encode({
        action = 'showContext',
        data = {
            title        = data.title,
            subtitle     = data.subtitle,
            titleIcon    = data.titleIcon,
            sectionTitle = data.sectionTitle,
            sectionIcon  = data.sectionIcon,
            footerLabel  = data.footerLabel,
            canClose     = data.canClose,
            menu         = data.menu,
            position     = position,
            options      = Utils.sanitizeItems(data.options)
        }
    }, { sort_keys = true }))
end

---@param context ContextMenuProps | ContextMenuProps[]
function RegisterContext(context)
    for k, v in pairs(context) do
        if type(k) == 'number' then
            contextMenus[v.id] = v
        else
            contextMenus[context.id] = context
            break
        end
    end
end

---@return string?
function GetOpenContextMenu()
    return openContextMenu
end

---@param onExit? boolean
function HideContext(onExit)
    CloseContextInternal(nil, onExit)
end

RegisterNUICallback('openContext', function(data, cb)
    local menu = contextMenus[openContextMenu]
    if data.back and menu and menu.onBack then menu.onBack() end
    cb(1)
    ShowContext(data.id)
end)

RegisterNUICallback('clickContext', function(id, cb)
    cb(1)

    local numericId = tonumber(id)
    if math.type(numericId) == 'float' then
        id = math.tointeger(numericId)
    elseif numericId then
        id = numericId + 1
    end

    local data = contextMenus[openContextMenu].options[id]

    if not data.event and not data.serverEvent and not data.onSelect then return end

    openContextMenu = nil

    SendNUIMessage({ action = 'hideContext' })
    Utils.resetNuiFocus()
    TriggerEvent('prism_uipack:contextClosed')

    if data.onSelect    then data.onSelect(data.args)                       end
    if data.event       then TriggerEvent(data.event, data.args)            end
    if data.serverEvent then TriggerServerEvent(data.serverEvent, data.args) end
end)

RegisterNUICallback('closeContext', function(data, cb)
    CloseContextInternal(cb, false)
end)
