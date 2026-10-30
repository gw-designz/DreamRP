local function Notify(message, notifyType, duration)
    message = tostring(message or '')
    notifyType = string.lower(tostring(notifyType or 'inform'))
    duration = tonumber(duration) or 4000

    -- Accept the common typo too.
    if notifyType == 'sucess' then
        notifyType = 'success'
    end

    if notifyType ~= 'success' and notifyType ~= 'inform' and notifyType ~= 'error' then
        notifyType = 'inform'
    end

    duration = math.max(500, math.min(duration, 30000))

    SendNUIMessage({
        action = 'notify',
        message = message,
        type = notifyType,
        duration = duration
    })
end

exports('Notify', Notify)

RegisterNetEvent('standalone_notify:notify', function(message, notifyType, duration)
    Notify(message, notifyType, duration)
end)

-- Test commands:
-- /notifysuccess Vehicle has been locked
-- /notifyinform This is an information notification
-- /notifyerror Something went wrong

RegisterCommand('notifysuccess', function(_, args)
    Notify(
        #args > 0 and table.concat(args, ' ') or 'Vehicle has been locked',
        'success',
        4000
    )
end, false)

RegisterCommand('notifyinform', function(_, args)
    Notify(
        #args > 0 and table.concat(args, ' ') or 'This is an information notification',
        'inform',
        4000
    )
end, false)

RegisterCommand('notifyerror', function(_, args)
    Notify(
        #args > 0 and table.concat(args, ' ') or 'Something went wrong',
        'error',
        4000
    )
end, false)

-- Preview all notifications at once
RegisterCommand('notifyall', function()
    Notify('Vehicle has been locked', 'success', 10000)
    Citizen.Wait(1500)
    Notify('Something went wrong', 'error', 10000)
    Citizen.Wait(1500)
    Notify('This is an information notification', 'inform', 10000)
end, false)

-- Press L to preview all notification styles
RegisterKeyMapping(
    'notifyall',
    'Preview all Karma notifications',
    'keyboard',
    'L'
)