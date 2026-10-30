


if Config.Dispatch ~= "ps-dispatch" then
    return
end

if IsDuplicityVersion() then
    -- Server side functions
    ---commented by noLag
    ---@param notifyData table { label: string, coords: vector3, address: string }
    RegisterNetEvent('nolag_properties:server:property:breached', function(notifyData)
        local jobs = {}
        for jobName, _ in pairs(Config.PoliceRaid.Jobs) do
            jobs[#jobs + 1] = jobName
        end
    
        local dispatchData = {
            message = locale('property_breached', notifyData.label), -- add this into your locale
            codeName = 'houserobbery', -- this should be the same as in config.lua
            code = '10-90',
            icon = 'fas fa-house',
            priority = 2,
            coords = notifyData.coords,
            street = notifyData.address,
            jobs = jobs
        }
    
        TriggerEvent('ps-dispatch:server:notify', dispatchData)
    end)
else
    -- Client side functions
end
