local phone = {}

---@param src number
---@param from number
---@param message string
function phone.sendMessage(src, from, message)
      -- Source: https://www.quasar-store.com/docs ( no documentation for smartphone pro )
    local ok = exports["qs-smartphone-pro"]:sendNewMail(src, {
        sender = tostring(from),
        subject = "Message",
        message = message,
    })

    return ok ~= false
end

---@param src number
---@param from number
---@param coords vector3
function phone.sendCoords(src, from, coords)
    -- No dedicated "share location + waypoint button" export confirmed for qs-smartphone-pro,
    -- so we send the coordinates as a readable mail instead (safe fallback).
    -- Source: https://www.quasar-store.com/docs ( no documentation for smartphone pro )
    local ok = exports["qs-smartphone-pro"]:sendNewMail(src, {
        sender = tostring(from),
        subject = "Location",
        message = ("A location has been shared with you: %.2f, %.2f, %.2f"):format(coords.x, coords.y, coords.z),
    })

    return ok ~= false
end

---@param src number
---@param title string
---@param content? string
function phone.sendNotification(src, title, content)
    -- Source: https://www.quasar-store.com/docs ( no documentation for smartphone pro )
    -- Confirmed working on our qs-smartphone-pro install (tested)
    local identifier = GetPlayerIdentifier(src, 0)
    local phoneNumber = exports["qs-smartphone-pro"]:GetPhoneNumberFromIdentifier(identifier, false)

    if not phoneNumber then
        return false
    end

    exports["qs-smartphone-pro"]:sendNotification(phoneNumber, {
        app = "system",
        head = title,
        msg = content,
    }, false)

    return true
end

return phone
