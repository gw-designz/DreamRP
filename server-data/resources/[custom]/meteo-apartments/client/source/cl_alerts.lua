RegisterNetEvent('meteo-apartments:client:psDispatch', function(data)
    if GetResourceState('ps-dispatch') ~= 'started' then return end

    exports['ps-dispatch']:CustomAlert({
        coords = data.coords,
        message = data.message or 'Suspicious Activity',
        dispatchCode = data.dispatchCode or '10-91',
        description = data.description or 'Apartment Security Alert',
        radius = 0,
        sprite = 161,
        color = 1,
        scale = 1.0,
        length = 3,
        priority = data.priority or 2,
    })
end)