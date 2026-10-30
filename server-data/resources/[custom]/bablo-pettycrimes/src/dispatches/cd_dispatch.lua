
Dispatch = Dispatch or {}

CreateThread(function()
    if Config.Dispatch ~= 'cd_dispatch' then
        return
    end

    function Dispatch:Send(data)
        local playerInfo = exports['cd_dispatch']:GetPlayerInfo()
        local dispatchData = {
            job_table = { 'police', },
            coords = data.coords or GetEntityCoords(cache.ped),
            title = data.title or 'Dispatch Alert ',
            message = data.message or '',
            flash = data.flash or false,
            unique_id = playerInfo.unique_id,
            sound = 1,
            blip = {
                sprite = 431,
                scale = 1.2,
                colour = 3,
                flashes = false,
                text = (data.blip.text or 'Dispatch Alert'),
                time = 5,
                radius = 0,
            }
        }

        if data._customData then
            for k, v in pairs(data._customData) do
                dispatchData[k] = v
            end
        end

        TriggerServerEvent('cd_dispatch:AddNotification', dispatchData)
    end
end)
