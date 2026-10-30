

Dispatch = Dispatch or {}

CreateThread(function()
    if Config.Dispatch ~= 'tk_dispatch' then
        return
    end

    function Dispatch:Send(data)
        local dispatchData = {
            title = data.message or 'Dispatch Alert ',
            code = '10-58',
            priority = 'Priority 3',
            coords = data.coords or GetEntityCoords(cache.ped),
            showLocation = true,
            showGender = true,
            playSound = true,
            blip = {
                color = 3,
                sprite = 357,
                scale = 1.0,
            },
            jobs = { 'police' }
        }

        if data._customData then
            for k, v in pairs(data._customData) do
                dispatchData[k] = v
            end
        end

        exports.tk_dispatch:addCall(dispatchData)
    end
end)

