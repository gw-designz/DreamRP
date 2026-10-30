
Dispatch = Dispatch or {}

CreateThread(function()
    if Config.Dispatch ~= 'rcore_dispatch' then
        return
    end

    function Dispatch:Send(data)
        local dispatchData = {
            code = data.code or '10-35',
            default_priority = 'medium',
            coords = data.coords or GetEntityCoords(cache.ped),
            job = data.jobs or {},
            text = data.message or '',
            type = 'alerts',
            blip_time = 120000,
            blip = {
                sprite = (data.blip.sprite or 58),
                colour = (data.blip.color or 3),
                scale = (data.blip.scale or 1.0),
                text = (data.blip.text or 'Dispatch Alert'),
                flashes = (data.flash or false),
                radius = (data.blip.radius or 0),
            }
        }
        if data._customData then
            for k, v in pairs(data._customData) do
                dispatchData[k] = v
            end
        end

        TriggerServerEvent('rcore_dispatch:server:sendAlert', dispatchData)
    end
end)
