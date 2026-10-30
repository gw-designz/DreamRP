local dispatch = {}

---@param src number | string
---@param coords vector3
---@param jobs string[]
---@param data AlertData
---@param blip AlertBlip
---@param alertFlash? boolean
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    -- Source: https://docs.codesign.pro/paid-scripts/dispatch/resource-integration
    TriggerEvent("cd_dispatch:AddNotification", {
        job_table = jobs,
        coords = coords,
        title = data.title,
        message = data.description,
        flash = alertFlash and 1 or 0,
        unique_id = tostring(math.random(0000000,9999999)),
        sound = 1,
        blip = {
            sprite = blip.sprite,
            scale = blip.scale,
            colour = blip.colour,
            flashes = blip.flash,
            text = blip.text,
            time = blip.length, -- in minutes
            radius = 0,
        }
    })
end

return dispatch