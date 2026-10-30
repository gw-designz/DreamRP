local phone = {}

---@param src number
---@param from number
---@param message string
function phone.sendMessage(src, from, message)
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(src)
    if not phoneNumber then
        return false
    end

    local result = exports["lb-phone"]:SendMessage(tostring(from), phoneNumber, message)

    return result
end

---@param src number
---@param from number
---@param coords vector3
function phone.sendCoords(src, from, coords)
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(src)
    if not phoneNumber then
        return false
    end

    exports["lb-phone"]:SendCoords(from, phoneNumber, vector2(coords.x, coords.y))
end

---@param src number
---@param title string
---@param content? string
function phone.sendNotification(src, title, content)
    exports['lb-phone']:SendNotification(src, {
        title = title,
        content = content
    })
end

return phone