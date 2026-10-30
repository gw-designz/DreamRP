local phone = {}

---@param src number
---@param from number
---@param message string
function phone.sendMessage(src, from, message)
    local phoneNumber = exports["gksphone"]:GetPhoneBySource(src)
    if not phoneNumber then
        return false
    end

    local result = exports["gksphone"]:SendMessage(tostring(from), tostring(phoneNumber), message)
    return (result and result.status) or false
end

---@param src number | string
---@param from number
---@param coords vector3
function phone.sendCoords(src, from, coords)
    local phoneNumber = exports["gksphone"]:GetPhoneBySource(src)
    if not phoneNumber then
        return false
    end

    local result = exports["gksphone"]:SendMessage(tostring(from), tostring(phoneNumber), {
        x = coords.x,
        y = coords.y
    })

    return (result and result.status) or false
end

---@param src number
---@param title string
---@param content? string
function phone.sendNotification(src, title, content)
    exports["gksphone"]:sendNotification(src, {
        title = title,
        message = content or "",
        icon = '/html/img/icons/messages.png',
        duration = 5000,
        type = "info",
        buttonactive = false
    })
end

return phone
