
Framework = Framework or {};

CreateThread(function()
    local identifier

    if Config.Framework ~= 'standalone' then
        return
    end

    function Framework:Notify(message)
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, true)
    end

    function Framework:skillCheck()
        local success = lib.skillCheck({'easy', 'easy', {areaSize = 60, speedMultiplier = 2}, 'hard'}, {'w', 'a', 's', 'd'})

        while lib.skillCheckActive() do
            Wait(0)
        end

        return success
    end

    function Framework:doProgress(progess, cb)
        if lib.progressBar({
            duration = progess.time,
            label = progess.text,
            useWhileDead = false,
            canCancel = true,
        }) then cb(true) else cb(false) end
    end

    function Framework:isCurrentJob(jobName)
        return false
    end

    function Framework:getPlayerJob()
        return nil
    end

    function Framework:canDoAction(action)
        if not Config.Modules[action] then return false end
        if Main and type(Main.isJobBlacklisted) == 'function' and Main:isJobBlacklisted(action) then
            return false
        end

        if action == 'MAILBOX_ROBBERY' then
            return true
        elseif action == 'PARKING_METER_ROBBERY' then
            return true
        elseif action == 'PARCEL_THEFT' then
            return true
        elseif action == 'PICKPOCKETING' then
            return true
        elseif action == 'SMASH_N_GRAB' then
            return true
        elseif action == 'MUGGING' then
            return true
        elseif action == 'ATM_ROBBERY' then
            return true
        elseif action == 'VENDING_MACHINE' then
            return true
        elseif action == 'TIRE_SLASH' then
            return true
        elseif action == 'PEDAL_BRICK' then
            return true
        elseif action == 'CASH_REGISTER_ROBBERY' then
            return true
        elseif action == 'STORE_SHELVES' then
            return true
        end

        return false
    end

    function Framework:onFinished(action)
        -- Override this per-module if you need custom logic when a crime finishes
    end

    -- Event when the player ped is loaded
    RegisterNetEvent('playerSpawned', function()
        Citizen.Wait(1000)

        local animationData, isNew = Main:getCache()
    
        if not isNew then
            Main:playAnimation(cache.ped, animationData.walkingstyle or nil, false, true)
            Main:playAnimation(cache.ped, animationData.expression or nil, false, true)
            Main:playAnimation(cache.ped, animationData.weaponstyle or nil, false, true)
        end
    end)
end)
