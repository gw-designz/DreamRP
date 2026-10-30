local dispatch = {}

---@param src number | string
---@param coords vector3
---@param jobs string[]
---@param data AlertData
---@param blip AlertBlip
---@param alertFlash? boolean
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    TriggerEvent("ps-dispatch:server:notify", {
        jobs = jobs,
        coords = coords,
        code = data.code,
        message = data.title,
        length = data.length or blip.length,
        flash = alertFlash,
        alert = {
            sound = data.sound?.alert or data.sound?.name or "Lose_1st",
            sound2 = data.sound?.ref or "GTAO_FM_Events_Soundset",
            sprite = blip.sprite,
            scale = blip.scale,
            color = blip.colour,
            flashes = blip.flash,
            text = blip.text,
            length = blip.length
        }
    })
end

return dispatch