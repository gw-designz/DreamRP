local dispatch = {}

---@param src number | string
---@param coords vector3
---@param jobs string[]
---@param data AlertData
---@param blip AlertBlip
---@param alertFlash? boolean
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    -- coords: Coordinates vector3(x, y, z) in which the alert is triggered
    -- title: Title of the alert
    -- type: Type of alert (GENERAL, RADARS, 215, DRUGS, FORCE, 48X) This is to filter the alerts in the dashboard
    -- message: Alert message
    -- job: Job group related to the alert
    -- metadata: Additional metadata of the alert (vehicle model, color, plate, speed, weapon, ammo type, name of the subject, unit)
    -- Source: https://docs.origennetwork.store/origen-police/exports/server-exports

    for i=1, #jobs do
        exports["origen_police"]:SendAlert({
            coords = coords,
            title = data.title,
            type = "GENERAL",
            message = data.description,
            job = jobs[i],
            -- metadata = {
            --     model = 'Vehicle label',
            --     color = {255, 255, 255},
            --     plate = 'PLATE',
            --     speed = '100 kmh',
            --     weapon = 'Weapon name',
            --     ammotype = 'AMMO_PISTOL',
            --     name = 'Subject name',
            --     unit = 'ADAM-10',
            -- }
        })
    end
end

return dispatch