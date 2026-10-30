---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: duplicate-doc-field

---@class TextUIOptions
---@field position? 'right-center' | 'left-center' | 'top-center' | 'bottom-center'
---@field key? string
---@field heading? string

local isOpen = false
local currentText = nil

---@param text string
---@param options? TextUIOptions
function ShowTextUI(text, options)
    if currentText == text then return end

    options = options or {}
    options.text = text
    currentText = text

    SendNUIMessage({ action = 'textUi', data = options })
    isOpen = true
end

function HideTextUI()
    SendNUIMessage({ action = 'textUiHide' })
    isOpen = false
    currentText = nil
end

---@return boolean, string | nil
function IsTextUIOpen()
    return isOpen, currentText
end
