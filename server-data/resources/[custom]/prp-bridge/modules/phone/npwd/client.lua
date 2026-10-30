---@param title string
---@param message string
local function sendNotification(title, message)
    exports["npwd"]:createSystemNotification({
        uniqId = tostring(math.random(100000, 999999)),
        content = message,
        secondaryTitle = title,
        keepOpen = true,
        duration = 5000,
    })
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:phone:sendNotification", sendNotification)
end

return {}
