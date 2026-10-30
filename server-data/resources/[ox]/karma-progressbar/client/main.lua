local progressOpen = false
local progressCanceled = false
local progressToken = 0
local cancelControl = 322

local function send(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

local function stopProgress()
    if not progressOpen then
        send('progress:stop')
        return
    end

    progressOpen = false
    send('progress:stop')
end

local function cancelProgress()
    if not progressOpen then
        progressCanceled = true
        send('progress:stop')
        return
    end

    progressCanceled = true
    stopProgress()
end

local function startProgress(label, duration, control)
    duration = math.max(1, tonumber(duration) or 1)
    cancelControl = tonumber(control) or 322
    progressOpen = true
    progressCanceled = false
    progressToken = progressToken + 1

    local token = progressToken
    send('progress:start', {
        label = label or 'PROGRESS...',
        duration = duration
    })

    CreateThread(function()
        local endsAt = GetGameTimer() + duration

        while progressOpen and progressToken == token and GetGameTimer() < endsAt do
            Wait(0)

            if IsControlJustPressed(0, cancelControl) then
                cancelProgress()
                return
            end
        end

        if progressOpen and progressToken == token then
            stopProgress()
        end
    end)

    return true
end

exports('start', startProgress)
exports('show', startProgress)
exports('stop', stopProgress)
exports('hide', stopProgress)
exports('cancel', cancelProgress)
exports('isOpen', function()
    return progressOpen
end)
exports('wasCanceled', function()
    return progressCanceled
end)

RegisterCommand('kpb', function(_, args)
    local duration = 5000
    local label = table.concat(args, ' ')

    if tonumber(args[1]) then
        duration = tonumber(args[1])
        label = table.concat(args, ' ', 2)
    end

    if label == '' then
        label = 'SHOWCASE PROGRESS...'
    end

    startProgress(label, duration)
end, false)

RegisterCommand('kpbshort', function()
    startProgress('GRABBING ITEM...', 3000)
end, false)

RegisterCommand('kpblong', function()
    startProgress('CRAFTING ITEM...', 10000)
end, false)

RegisterCommand('kpbcancel', function()
    cancelProgress()
end, false)

RegisterCommand('kpbstatus', function()
    print(('[karma-progressbar] Open: %s | Last cancelled: %s'):format(tostring(progressOpen), tostring(progressCanceled)))
end, false)

RegisterCommand('kpbshowcase', function()
    if progressOpen then
        return
    end

    CreateThread(function()
        local steps = {
            { label = 'GRABBING ITEM...', duration = 2500 },
            { label = 'CRAFTING ITEM...', duration = 5000 },
            { label = 'UPLOADING DATA...', duration = 7500 }
        }

        for i = 1, #steps do
            startProgress(steps[i].label, steps[i].duration)

            while progressOpen do
                Wait(0)
            end

            if progressCanceled then
                return
            end

            Wait(500)
        end
    end)
end, false)

RegisterNUICallback('progressCancel', function(_, cb)
    cancelProgress()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopProgress()
end)
