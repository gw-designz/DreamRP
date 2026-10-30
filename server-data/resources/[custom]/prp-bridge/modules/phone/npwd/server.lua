local phone = {}

---@param src number
---@param from number
---@param message string
function phone.sendMessage(src, from, message)
    local playerData = exports.npwd:getPlayerData({ source = src })
    if not playerData or not playerData.phoneNumber then
        return false
    end

    local result = exports.npwd:emitMessage({
        senderNumber = tostring(from),
        targetNumber = playerData.phoneNumber,
        message = message,
    })

    return result
end

---@param src number | string
---@param from number
---@param coords vector3
function phone.sendCoords(src, from, coords)
    local playerData = exports.npwd:getPlayerData({ source = src })
    if not playerData or not playerData.phoneNumber then
        return false
    end

    local result = exports.npwd:emitMessage({
        senderNumber = tostring(from),
        targetNumber = playerData.phoneNumber,
        message = '',
        embed = {
            type = "location",
            coords = { coords.x, coords.y, coords.z },
            phoneNumber = tostring(from)
        }
    })

    return result
end

---@param src number
---@param title string
---@param content? string
function phone.sendNotification(src, title, content)
    TriggerClientEvent("prp-bridge:phone:sendNotification", src, title, content)
end

return phone
