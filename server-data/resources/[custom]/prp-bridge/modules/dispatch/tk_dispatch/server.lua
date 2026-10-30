local dispatch = {}

---@param src number | string
---@param coords vector3
---@param jobs string[]
---@param data AlertData
---@param blip AlertBlip
---@param alertFlash? boolean
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    -- Source: https://tk-scripts.gitbook.io/docs/tk_dispatch/exports
    exports.tk_dispatch:addCall({
        title = data.title,
        code = data.code,
        message = data.description,
        coords = coords,
        flash = alertFlash,
        playSound = true,
        jobs = jobs,
        blip = {
            sprite = blip.sprite,
            scale = blip.scale,
            color = blip.colour,
            flash = blip.flash,
        },
    })
end

return dispatch
