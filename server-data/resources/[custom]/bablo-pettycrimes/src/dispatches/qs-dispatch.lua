
Dispatch = Dispatch or {}

CreateThread(function()
    if Config.Dispatch ~= 'qs-dispatch' then
        return
    end

    function Dispatch:Send(data)
        local dispatchData = {
            job = (data.jobs or {}),
            callLocation = data.coords or GetEntityCoords(cache.ped),
            callCode = data.code,
            message = (data.message or ''),
            blip = {
                sprite = (data.blip.sprite or 58),
                scale = (data.blip.scale or 1.0),
                colour = (data.blip.color or 3),
                flashes = (data.blip.flash or false),
                text = (data.blip.text or 'Dispatch Alert'),
                time = 120000,
            },
        }

        if data._customData then
            for k, v in pairs(data._customData) do
                dispatchData[k] = v
            end
        end

        TriggerServerEvent('qs-dispatch:server:CreateDispatchCall', dispatchData)
    end
end)
