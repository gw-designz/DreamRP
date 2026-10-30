
-- Tested and working with v1 but no testing done with v2 yet

local dispatch = {}

local function isStarted()
    return GetResourceState("kartik-mdt") == "started"
end

local function normalizeJobs(jobs)
    if not jobs then
        return { police = true }
    end

    -- Already in Kartik format: { police = true, ems = true }
    if type(jobs) == "table" then
        local normalized = {}

        for key, value in pairs(jobs) do
            if type(key) == "string" and value == true then
                normalized[key] = true
            elseif type(value) == "string" then
                normalized[value] = true
            end
        end

        return next(normalized) and normalized or { police = true }
    end

    if type(jobs) == "string" then
        return { [jobs] = true }
    end

    return { police = true }
end

local function getCoords(src, coords)
    if coords then
        return coords
    end

    if src then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            return GetEntityCoords(ped)
        end
    end

    return vector3(0.0, 0.0, 0.0)
end

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    if not isStarted() then
        print("^1[prp-bridge] kartik-mdt is not started. Dispatch alert skipped.^0")
        return false
    end

    data = data or {}
    coords = getCoords(src, coords)

    local alertData = {
        title = data.title or data.label or "Alert",
        code = data.code or data.dispatchCode or "10-90",
        description = data.description or data.message or data.text or "Dispatch alert",
        location = data.location or data.street or "Unknown",
        sound = data.sound or "dispatch",
        type = data.type or "Alert",

        x = coords.x,
        y = coords.y,
        z = coords.z,

        person = data.person,
        vehicle = data.vehicle,
        weapon = data.weapon,

        blip = {
            radius = blip and blip.radius or data.radius or 0.0,
            sprite = blip and blip.sprite or data.sprite or 161,
            color = blip and blip.color or data.color or 1,
            scale = blip and blip.scale or data.scale or 1.2,
            length = blip and blip.length or data.length or 5,
        },

        jobs = normalizeJobs(jobs or data.jobs),
    }

    TriggerEvent("kartik-mdt:server:sendDispatchNotification", alertData)
    return true
end

return dispatch
