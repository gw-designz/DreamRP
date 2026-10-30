
Framework = Framework or {};

CreateThread(function()
    if Config.Framework ~= 'standalone' then
        return
    end

    function Framework:fetchPlayer(source)
        return source
    end

    -- Standalone has no job system. Return the player's job name here if you
    -- wire up a custom framework so the petty-crime blacklist can enforce it.
    function Framework:getPlayerJob(source)
        return nil
    end

    function Framework:getIdentifier()
        return GetPlayerIdentifiers(source)[1]
    end

    function Framework:getPlayerName(source)
        return GetPlayerName(source)
    end

    function Framework:isAdmin(source)
        source = tonumber(source)
        if not source then return false end

        return IsPlayerAceAllowed(source, 'command')
    end

    RegisterServerCallback({
        eventName = eventName .. 'server:getIdentifier',
        eventCallback = function(source)
            if not source then
                return { status = false, message = "NO_SOURCE" }
            end

            return { status = true, identifier = Framework:getIdentifier(source) }
        end
    })
end)
