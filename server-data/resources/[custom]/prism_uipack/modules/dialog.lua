---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: duplicate-doc-field

---@class InputDialogRowProps
---@field type 'input' | 'number' | 'checkbox' | 'select' | 'slider' | 'multi-select'
---@field label string
---@field options? { value: string, label: string, default?: string }[]
---@field password? boolean
---@field icon? string | { [1]: IconProp, [2]: string }
---@field placeholder? string
---@field default? string | number
---@field disabled? boolean
---@field checked? boolean
---@field min? number
---@field max? number
---@field step? number
---@field required? boolean
---@field description? string
---@field maxSelectedValues? number

---@class InputDialogOptionsProps
---@field allowCancel? boolean
---@field description? string

---@type promise?
local activeInput = nil

---@param heading string
---@param rows string[] | InputDialogRowProps[]
---@param options? InputDialogOptionsProps[]
---@return string[] | number[] | boolean[] | nil
function InputDialog(heading, rows, options)
    if activeInput then return end
    activeInput = promise.new()

    for i = 1, #rows do
        if type(rows[i]) == 'string' then
            rows[i] = { type = 'input', label = rows[i] }
        end
    end

    Utils.setNuiFocus(false)
    SendNUIMessage({
        action = 'openDialog',
        data = { heading = heading, rows = rows, options = options }
    })

    return Citizen.Await(activeInput)
end

function CloseInputDialog()
    if not activeInput then return end

    Utils.resetNuiFocus()
    SendNUIMessage({ action = 'closeInputDialog' })

    activeInput:resolve(nil)
    activeInput = nil
end

RegisterNUICallback('inputData', function(data, cb)
    cb(1)
    Utils.resetNuiFocus()

    local p = activeInput
    activeInput = nil

    p:resolve(data)
end)
