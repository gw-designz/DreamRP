local dispatch = {}

---@param src number | string
---@param coords vector3
---@param jobs string[]
---@param data AlertData
---@param blip AlertBlip
---@param alertFlash? boolean
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    -- Source: https://documentation.rcore.cz/paid-resources/rcore_dispatch/add-alerts#sending-alerts-from-server
    local alertData = {
        code = data.code,
        default_priority = "high",
        coords = coords,
        job = jobs,
        text = data.title,
        type = "alerts",
        blip_time = (data.length * 60), -- in seconds
        blip = {
            sprite = blip.sprite,
            colour = blip.colour,
            scale = blip.scale,
            text = blip.text
        }
    }

    TriggerEvent("rcore_dispatch:server:sendAlert", alertData)
end

return dispatch