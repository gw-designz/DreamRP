---@type { [string]: MenuProps }
local registeredMenus = {}

---@type MenuProps | nil
local openMenu = nil

---@alias MenuPosition 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right' | 'left' | 'right'
---@alias MenuChangeFunction fun(selected: number, scrollIndex?: number, args?: any, checked?: boolean)

---@class MenuOptions
---@field label string
---@field progress? number
---@field colorScheme? string
---@field icon? string | { [1]: IconProp, [2]: string }
---@field iconColor? string
---@field values? table<string | { label: string, description: string }>
---@field checked? boolean
---@field description? string
---@field defaultIndex? number
---@field args? { [any]: any }
---@field close? boolean

---@class MenuProps
---@field id string
---@field title string
---@field options MenuOptions[]
---@field position? MenuPosition
---@field disableInput? boolean
---@field canClose? boolean
---@field onClose? fun(keyPressed?: 'Escape' | 'Backspace')
---@field onSelected? MenuChangeFunction
---@field onSideScroll? MenuChangeFunction
---@field onCheck? MenuChangeFunction
---@field cb? MenuChangeFunction

---@param data MenuProps
---@param cb? MenuChangeFunction
function RegisterMenu(data, cb)
    if not data.id      then error('No menu id was provided.')       end
    if not data.title   then error('No menu title was provided.')    end
    if not data.options then error('No menu options were provided.') end

    data.cb = cb
    registeredMenus[data.id] = data
end

function StartMenuInputLoop()
    local control  = Utils.game == 'fivem' and 140 or 0xE30CD707
    local playerId = PlayerId()

    CreateThread(function()
        while openMenu do
            if openMenu.disableInput == nil or openMenu.disableInput then
                DisablePlayerFiring(playerId, true)
                if Utils.game == 'fivem' then
                    HudWeaponWheelIgnoreSelection()
                end
                DisableControlAction(0, control, true)
            end
            Wait(0)
        end
    end)
end

---@param id string
---@param startIndex? number
function ShowMenu(id, startIndex)
    local menu = registeredMenus[id]

    if not menu then
        error(('No menu with id %s was found'):format(id))
    end

    if table.type(menu.options) == 'empty' then
        error(("Can't open empty menu with id %s"):format(id))
    end

    if not openMenu then
        StartMenuInputLoop()
    end

    openMenu = menu
    Utils.setNuiFocus(not menu.disableInput, true)

    SendNUIMessage({
        action = 'setMenu',
        data = {
            position       = menu.position,
            canClose       = menu.canClose,
            title          = menu.title,
            subtitle       = menu.subtitle,
            items          = menu.options,
            startItemIndex = startIndex and startIndex - 1 or 0
        }
    })
end

---@param onExit? boolean
function HideMenu(onExit)
    local menu = openMenu
    openMenu = nil

    if not menu then return end

    Utils.resetNuiFocus()
    SendNUIMessage({ action = 'closeMenu' })

    if onExit and menu.onClose then
        menu.onClose()
    end
end

---@param id string
---@param options MenuOptions | MenuOptions[]
---@param index? number
function SetMenuOptions(id, options, index)
    if index then
        registeredMenus[id].options[index] = options
    else
        if not options[1] then error('Invalid override format used, expected table of options.') end
        registeredMenus[id].options = options
    end
end

---@return string?
function GetOpenMenu()
    return openMenu and openMenu.id
end

RegisterNUICallback('confirmSelected', function(data, cb)
    cb(1)

    local selected    = data[1] + 1
    local scrollIndex = data[2] and data[2] + 1 or nil
    local checked     = data[3]
    local menu        = openMenu

    if not menu then return end

    if menu.options[selected].close ~= false then
        Utils.resetNuiFocus()
        openMenu = nil
    end

    if menu.cb then
        menu.cb(selected, scrollIndex, menu.options[selected].args, checked)
    end
end)

RegisterNUICallback('changeIndex', function(data, cb)
    cb(1)
    if not openMenu or not openMenu.onSideScroll then return end

    local selected    = data[1] + 1
    local scrollIndex = data[2] and data[2] + 1 or nil

    openMenu.onSideScroll(selected, scrollIndex, openMenu.options[selected].args)
end)

RegisterNUICallback('changeSelected', function(data, cb)
    cb(1)
    if not openMenu or not openMenu.onSelected then return end

    local selected = data[1] + 1
    local args     = openMenu.options[selected].args

    if args and type(args) ~= 'table' then
        error("Menu args must be passed as a table")
    end

    args = args or {}

    if data[2] and not args.isCheck then
        data[2] = data[2] + 1
        args[data[3]] = true
    end

    openMenu.onSelected(selected, data[2], args)
end)

RegisterNUICallback('changeChecked', function(data, cb)
    cb(1)
    if not openMenu or not openMenu.onCheck then return end

    local selected = data[1] + 1
    openMenu.onCheck(selected, data[2], openMenu.options[selected].args)
end)

RegisterNUICallback('closeMenu', function(data, cb)
    cb(1)
    Utils.resetNuiFocus()

    local menu = openMenu
    if not menu then return end

    openMenu = nil

    if menu.onClose then
        menu.onClose(data)
    end
end)
