local phone = {}

---@param src number
---@param from number
---@param message string
function phone.sendMessage(src, from, message)
    return exports["17mov_Phone"]:Messages_SendMessageToSrc(src, message, from)
end

---@param src number | string
---@param from number
---@param coords vector3
function phone.sendCoords(src, from, coords)
    -- shrug --
    return true
end

---@param src number
---@param title string
---@param content? string
function phone.sendNotification(src, title, content)
    exports["17mov_Phone"]:SendNotificationToSrc(src, {
        app = "SYSTEM",
        title = title,
        message = content
    })
end

return phone
