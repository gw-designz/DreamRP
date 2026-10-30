--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

---@class TextUIOptions
---@field position? 'right-center' | 'left-center' | 'top-center' | 'bottom-center';
---@field icon? string | {[1]: IconProp, [2]: string};
---@field iconColor? string;
---@field style? string | table;
---@field alignIcon? 'top' | 'center';
---@field scroll? boolean Treat each line of text as an option that can be scrolled through with the mouse wheel.
---@field key? string Key shown next to the selected option when `scroll` is enabled (defaults to `E`).

local isOpen = false
local currentText
local selectedOption = 1
local scrollId = 0

---@param text string
---@return number
local function countOptions(text)
    local count = 0

    for line in text:gmatch('[^\r\n]+') do
        if line:find('%S') then count = count + 1 end
    end

    return count
end

---@param count number
local function startScrolling(count)
    scrollId = scrollId + 1

    local id = scrollId

    CreateThread(function()
        while isOpen and scrollId == id do
            -- Stop the wheel from cycling weapons while scrolling through options
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true)
            DisableControlAction(0, 17, true)

            local step = IsControlJustPressed(0, 241) and -1 or IsControlJustPressed(0, 242) and 1 or 0

            if step ~= 0 and count > 1 then
                selectedOption = (selectedOption - 1 + step) % count + 1
                lib.playUiSound('navigate')

                SendNUIMessage({
                    action = 'textUiSelect',
                    data = selectedOption - 1
                })
            end

            Wait(0)
        end
    end)
end

---@param text string
---@param options? TextUIOptions
function lib.showTextUI(text, options)
    if currentText == text then return end

    if not options then options = {} end

    options.text = text
    currentText = text
    selectedOption = 1
    scrollId = scrollId + 1

    SendNUIMessage({
        action = 'textUi',
        data = options
    })

    isOpen = true

    if options.scroll then startScrolling(countOptions(text)) end
end

function lib.hideTextUI()
    SendNUIMessage({
        action = 'textUiHide'
    })

    isOpen = false
    currentText = nil
end

---@return boolean, string | nil
function lib.isTextUIOpen()
    return isOpen, currentText
end

---Returns the option (1-based) currently selected in a `scroll` text UI.
---@return number
function lib.getTextUISelected()
    return selectedOption
end
