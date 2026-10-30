

Dispatch = Dispatch or {}

CreateThread(function()
    if Config.Dispatch ~= 'standalone' then
        return
    end

    while not eventName do
        Wait(0)
    end

    function Dispatch:Send(data)
        local dispatchData = {
            coords = data.coords or GetEntityCoords(cache.ped),
            jobs = data.jobs or { 'police' },

            title = data.message or '',
            subtitle = data.description or '',

            duration = 120000,

            blip = {
                sprite = (data.blip.sprite or 58),
                color = (data.blip.color or 1),
                scale = (data.blip.scale or 1.0),
                text = (data.blip.text or 'Dispatch Alert'),
                flash = (data.blip.flash or false),
            }
        }

        if data._customData then
            for k, v in pairs(data._customData) do
                dispatchData[k] = v
            end
        end

        TriggerServerEvent(eventName .. 'server:sendAlert', dispatchData)
    end

    RegisterNetEvent(eventName .. 'client:sendAlert')
    AddEventHandler(eventName .. 'client:sendAlert', function(data)
        local found = false
        local playerJob = Framework:getPlayerJob()

        for _, job in ipairs(data.jobs) do
            if job == playerJob then
                found = true
                break
            end
        end

        if not found then
            return
        end

        Citizen.CreateThread(function()
            local blipData = data.blip
            local blip = AddBlipForCoord(data.coords)

            SetBlipSprite(blip, blipData.sprite)
            SetBlipHighDetail(blip, true)
            SetBlipColour(blip, blipData.color)
            SetBlipAlpha(blip, 255)
            SetBlipFlashes(blip, blipData.flash)
            SetBlipScale(blip, blipData.scale)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(blipData.text)
            EndTextCommandSetBlipName(blip)
            SetBlipAsShortRange(blip, false)

            Citizen.SetTimeout(blipData.duration or 120000, function()
                RemoveBlip(blip)
            end)
        end)

        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(data.subtitle)

        EndTextCommandThefeedPostMessagetext('CHAR_CALL911', 'CHAR_CALL911', false, 0, data.title, '')
        EndTextCommandThefeedPostTicker(false, true)
    end)
end)

