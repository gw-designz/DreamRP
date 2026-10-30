local dispatch = {}

---@param src number | string
---@param coords vector3
---@param jobs string[]
---@param data AlertData
---@param blip AlertBlip
---@param alertFlash? boolean
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    -- Source: https://www.quasar-store.com/docs/dispatch-and-mdt/commands-and-exports
    TriggerEvent("qs-dispatch:server:CreateDispatchCall", {
        job = jobs,
        callLocation = coords,
        callCode = {
            code = data.code,
            snippet = data.title,
        },
        message = data.description,
        flashes = alertFlash,
        blip = {
            sprite = blip.sprite,
            scale = blip.scale,
            colour = blip.colour,
            flashes = blip.flash,
            text = blip.text,
            time = (data.length and data.length * 60 * 1000) or (blip.length and blip.length * 1000),
        },
    })
end

return dispatch