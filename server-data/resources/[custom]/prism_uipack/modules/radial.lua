---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: duplicate-doc-field

---@class RadialItem
---@field icon string | { [1]: IconProp, [2]: string }
---@field label string
---@field menu? string
---@field onSelect? fun(currentMenu: string | nil, itemIndex: number) | string
---@field keepOpen? boolean
---@field iconWidth? number
---@field iconHeight? number
---@field [string] any

---@class RadialMenuItem : RadialItem
---@field id string

---@class RadialMenuProps
---@field id string
---@field items RadialItem[]
---@field [string] any

local isOpen    = false
local isDisabled = false

---@type table<string, RadialMenuProps>
local menus = {}

---@type RadialMenuItem[]
local menuItems = {}

---@type table<{ id: string, option: string }>
local menuHistory = {}

---@type RadialMenuProps?
local currentRadial = nil

local function SendRadialOpen(data)
    SendNUIMessage({ action = 'openRadialMenu', data = data })
end

---@param id? string
---@param option? number
local function ShowRadial(id, option)
    local radial = id and menus[id]

    if id and not radial then
        error('No radial menu with such id found.')
    end

    currentRadial = radial

    SendRadialOpen(false)
    Wait(100)

    if not isOpen then return end

    local items = radial and radial.items or menuItems
    SendRadialOpen({
        items  = Utils.sanitizeItems(items),
        sub    = radial and true or nil,
        option = option
    })
end

local function RefreshRadial(menuId)
    if not isOpen then return end

    if currentRadial and menuId then
        if menuId == currentRadial.id then
            return ShowRadial(menuId)
        end

        for i = 1, #menuHistory do
            local entry  = menuHistory[i]
            local parent = menus[entry.id]

            if entry.id == menuId and parent then
                local stillLinked = false

                for j = 1, #parent.items do
                    if parent.items[j].menu == currentRadial.id then
                        stillLinked = true
                        break
                    end
                end

                if not stillLinked then
                    currentRadial = parent

                    for j = #menuHistory, i, -1 do
                        menuHistory[j] = nil
                    end

                    return ShowRadial(currentRadial.id)
                end

                return
            end
        end

        return
    end

    table.wipe(menuHistory)
    ShowRadial()
end

---@param radial RadialMenuProps
function RegisterRadial(radial)
    menus[radial.id] = radial
    radial.resource  = GetInvokingResource()

    if currentRadial then
        RefreshRadial(radial.id)
    end
end

---@return string?
function GetCurrentRadialId()
    return currentRadial and currentRadial.id
end

function HideRadial()
    if not isOpen then return end

    SendRadialOpen(false)
    Utils.resetNuiFocus()
    table.wipe(menuHistory)

    isOpen      = false
    currentRadial = nil
end

---@param items RadialMenuItem | RadialMenuItem[]
function AddRadialItem(items)
    local invokingResource = GetInvokingResource()
    items = table.type(items) == 'array' and items or { items }

    for i = 1, #items do
        local item     = items[i]
        item.resource  = invokingResource
        local menuSize = #menuItems
        local found    = false

        for j = 1, menuSize do
            if menuItems[j].id == item.id then
                menuItems[j] = item
                found = true
                break
            end
        end

        if not found then
            menuItems[menuSize + 1] = item
        end
    end

    if isOpen and not currentRadial then
        RefreshRadial()
    end
end

---@param id string
function RemoveRadialItem(id)
    for i = 1, #menuItems do
        if menuItems[i].id == id then
            table.remove(menuItems, i)
            break
        end
    end

    if isOpen then
        RefreshRadial(id)
    end
end

function ClearRadialItems()
    table.wipe(menuItems)

    if isOpen then
        RefreshRadial()
    end
end

---Disallow players from opening the radial menu.
---@param state boolean
function disableRadial(state)
    isDisabled = state

    if isOpen and state then
        HideRadial()
    end
end

RegisterNUICallback('radialClick', function(index, cb)
    cb(1)

    local itemIndex  = index + 1
    local item, currentMenu

    if currentRadial then
        item        = currentRadial.items[itemIndex]
        currentMenu = currentRadial.id
    else
        item = menuItems[itemIndex]
    end

    local menuResource = currentRadial and currentRadial.resource or item.resource

    if item.menu then
        menuHistory[#menuHistory + 1] = { id = currentRadial and currentRadial.id, option = item.menu }
        ShowRadial(item.menu)
    elseif not item.keepOpen then
        HideRadial()
    end

    local onSelect = item.onSelect
    if not onSelect then return end

    if type(onSelect) == 'string' then
        exports[menuResource][onSelect](0, currentMenu, itemIndex)
    else
        onSelect(currentMenu, itemIndex)
    end
end)

RegisterNUICallback('radialBack', function(_, cb)
    cb(1)

    local numHistory = #menuHistory
    local lastMenu   = numHistory > 0 and menuHistory[numHistory]

    if not lastMenu then return end

    menuHistory[numHistory] = nil

    if lastMenu.id then
        return ShowRadial(lastMenu.id, lastMenu.option)
    end

    currentRadial = nil

    SendRadialOpen(false)
    Wait(100)

    if not isOpen then return end

    SendRadialOpen({
        items  = Utils.sanitizeItems(menuItems),
        option = lastMenu.option
    })
end)

RegisterNUICallback('radialClose', function(_, cb)
    cb(1)

    if not isOpen then return end

    Utils.resetNuiFocus()
    isOpen      = false
    currentRadial = nil
end)

RegisterNUICallback('radialTransition', function(_, cb)
    Wait(100)
    cb(isOpen or false)
end)

AddEventHandler('onClientResourceStop', function(resource)
    for i = #menuItems, 1, -1 do
        if menuItems[i].resource == resource then
            table.remove(menuItems, i)
        end
    end
end)

-- Defer keybind registration until Utils is ready
CreateThread(function()
    local attempts = 0
    while not Utils and attempts < 100 do
        Wait(100)
        attempts = attempts + 1
    end

    if not Utils then
        error(('Failed to load Utils dependency after %dms'):format(attempts * 100))
    end

    Utils.addKeybind({
        name        = 'prism-radial',
        description = 'Open radial menu',
        defaultKey  = GetConvar('prism:radialOpenKey', 'z'),
        onReleased  = GetConvar('prism:radialOpenMode', 'press') == 'hold' and HideRadial or nil,
        onPressed   = function()
            if isDisabled then return end
            if isOpen     then return HideRadial() end
            if #menuItems == 0 or IsNuiFocused() or IsPauseMenuActive() then return end

            isOpen = true

            SendRadialOpen({ items = Utils.sanitizeItems(menuItems) })
            Utils.setNuiFocus(true)
            SetCursorLocation(0.5, 0.5)

            local playerId = PlayerId()
            while isOpen do
                DisablePlayerFiring(playerId, true)
                DisableControlAction(0, 1,   true)
                DisableControlAction(0, 2,   true)
                DisableControlAction(0, 142, true)
                DisableControlAction(2, 199, true)
                DisableControlAction(2, 200, true)
                Wait(0)
            end
        end
    })
end)
