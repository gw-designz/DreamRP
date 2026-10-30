-- Send a coloured chat message to a player, or print to console if src <= 0.
local function notify(src, message)
    if src > 0 then
        TriggerClientEvent("chat:addMessage", src, {
            color = { 255, 200, 80 },
            args  = { "[multicharacter]", message },
        })
    else
        print(("[bablo-multicharacter] %s"):format(message))
    end
end

-- Register the relog command one tick after resource start so Config is ready.
CreateThread(function()
    Wait(0)

    local cfg = Config.RelogCommand
    if not cfg or cfg.enabled == false then return end

    local commandName = cfg.command or "relog"

    RegisterCommand(commandName, function(src, args, rawCommand)
        -- Console cannot use a player command.
        if src <= 0 then
            notify(src, ("/%s is a player command."):format(commandName))
            return
        end

        -- Admin-only gate.
        if cfg.adminOnly then
            if not Framework.IsAdmin or not Framework:IsAdmin(src) then
                notify(src, "You do not have permission to use this command.")
                return
            end
        end

        -- Framework must support logout.
        if not Framework.LogoutCharacter then
            notify(src, "Relog is not supported on this framework.")
            return
        end

        -- Step 1: Tell the client to prepare for relog (fade out, release controls).
        -- This runs before LogoutCharacter so the screen is black while the
        -- framework state is being torn down.
        TriggerClientEvent(eventName .. "client:prepareRelog", src)

        -- Step 2: Give the client time to fade out (500 ms) before destroying the
        -- framework player object. Without this Wait the client still has full
        -- control when QBCore/ESX clears the player, causing a visible glitch.
        Wait(500)

        local ok = Framework:LogoutCharacter(src)
        if not ok then
            -- Logout failed — tell the client to abort the relog sequence.
            TriggerClientEvent(eventName .. "client:cancelRelog", src)
            notify(src, "Relog failed — framework logout returned an error.")
            return
        end

        -- Step 3: Give the framework another 500 ms to fully unload the character
        -- (clear inventory, job, etc.) before we reopen the selection screen.
        -- Without this second wait, LoadCharacter may find a partially-cleaned state.
        Wait(500)

        TriggerClientEvent(eventName .. "client:openUI", src)
    end, false)
end)
