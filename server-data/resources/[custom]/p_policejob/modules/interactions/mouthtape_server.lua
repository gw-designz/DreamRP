if not (Config and Config.Interactions and Config.Interactions.MouthTape) then return end

MouthTape = {}

-- ============================================================
--  Toggle mouth tape (from client export or net event)
-- ============================================================

RegisterNetEvent("p_policejob:mouthtape:toggleTape", function(data)
    local officerSource = source
    local officerJob    = Bridge.Framework.getPlayerJob(officerSource)

    if not officerJob or not Config.Jobs[officerJob.name] then return end

    local targetState = Player(data.player).state
    if not targetState then return end

    -- No-op if already in target state
    if data.state and targetState.mouthTaped then return end
    if not data.state and not targetState.mouthTaped then return end

    -- Item check
    if data.state then
        local count = Bridge.Inventory.getItemCount(officerSource, "mouthtape")
        if count < 1 then return end
        Bridge.Inventory.removeItem(officerSource, "mouthtape", 1)
    else
        Bridge.Inventory.addItem(officerSource, "mouthtape", 1)
    end

    targetState:set("mouthTaped", data.state, true)

    local action = data.state and "Mouth-taped" or "Removed mouth tape from"
    Bridge.Logs.Send(officerSource, "Interactions",
        ("%s player %s"):format(action, tostring(data.player)),
        Config.Webhooks.interactions)
end)

-- ============================================================
--  Exports
-- ============================================================

-- Direct server-side state set (no item check — caller is trusted)
exports("setPlayerMouthTape", function(playerSource, state)
    local playerState = Player(playerSource).state
    if not playerState then return false end
    playerState:set("mouthTaped", state, true)
    return true
end)

exports("isPlayerMouthTaped", function(playerSource)
    local playerState = Player(playerSource).state
    if not playerState then return false end
    return playerState.mouthTaped == true
end)
