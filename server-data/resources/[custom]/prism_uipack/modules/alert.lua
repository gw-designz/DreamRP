---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: duplicate-doc-field

---@class AlertDialogProps
---@field header string
---@field content string
---@field centered? boolean
---@field size? 'xs' | 'sm' | 'md' | 'lg' | 'xl'
---@field overflow? boolean
---@field cancel? boolean
---@field labels? { cancel?: string, confirm?: string }

---@type promise?
local activeAlert = nil
local alertId = 0

---@param data AlertDialogProps
---@param timeout? number
---@return 'cancel' | 'confirm' | nil
function AlertDialog(data, timeout)
    if activeAlert then return end

    alertId = alertId + 1
    local currentId = alertId
    activeAlert = promise.new()

    Utils.setNuiFocus(false)
    SendNUIMessage({ action = 'sendAlert', data = data })

    if timeout then
        SetTimeout(timeout, function()
            if currentId == alertId then CloseAlertDialog('timeout') end
        end)
    end

    return Citizen.Await(activeAlert)
end

---@param reason? string
function CloseAlertDialog(reason)
    if not activeAlert then return end

    Utils.resetNuiFocus()
    SendNUIMessage({ action = 'closeAlertDialog' })

    local p = activeAlert
    activeAlert = nil

    if reason then p:reject(reason) else p:resolve() end
end

RegisterNUICallback('closeAlert', function(data, cb)
    cb(1)
    Utils.resetNuiFocus()

    local p = activeAlert
    activeAlert = nil

    p:resolve(data)
end)

RegisterNetEvent('ox_lib:alertDialog', AlertDialog)
