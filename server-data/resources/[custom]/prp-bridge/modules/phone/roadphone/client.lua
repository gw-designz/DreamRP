---@type table<string, vector3>
local locationsCache = {}
local function generateId()
    local id = lib.string.random("........", 8)

    if locationsCache[id] then
        return generateId()
    end

    return id
end

---@param message string
local function sendMail(message)
    exports['roadphone']:sendMail({
        sender = ("Anon%s"):format(generateId()),
        subject = "Information",
        message = message
    })
end

local function sendCoordsMail(coords)
    local id = generateId()

    locationsCache[id] = coords

    exports['roadphone']:sendMail({
        sender = ("Anon%s"):format(generateId()),
        subject = "Location",
        message = "A location has been shared with you.",
        button = {
            buttonEvent = "prp-bridge:phone:markLocation",
            buttonData = id,
            buttonname = "Mark Location on GPS"
        }
    })
end

local function markLocation(id)
    local coords = locationsCache[id]

    if not coords then
        return
    end

    SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
end

---@param title string
---@param message string
local function sendNotification(title, message)
    exports["roadphone"]:sendNotification({
        apptitle = "SYSTEM",
        title = title,
        message = message,
        img = "https://cfx-nui-roadphone/public/img/user.png"
    })
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent("prp-bridge:phone:sendMail", sendMail)
    RegisterNetEvent("prp-bridge:phone:sendCoordsMail", sendCoordsMail)
    AddEventHandler("prp-bridge:phone:markLocation", markLocation)
    RegisterNetEvent("prp-bridge:phone:sendNotification", sendNotification)
end

return {}
