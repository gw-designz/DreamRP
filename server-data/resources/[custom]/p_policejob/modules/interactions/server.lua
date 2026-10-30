if not (Config and Config.Interactions and Config.Interactions.Enabled) then return end

Interactions = {}
Interactions.cuffedBy = {}  -- [targetSource] = officerSource who applied cuffs (for key tracking)

-- ============================================================
--  Helpers (file-local)
-- ============================================================

function Interactions.canInteract(self, officerSource, targetSource, maxDist)
    return Editable:canInteract(officerSource, targetSource, maxDist)
end

function Interactions.isPlayerDead(self, playerSource)
    return Editable:isPlayerDead(playerSource)
end

-- Force-uncuff: clears state bags and triggers client cleanup.
-- Used by: `ForceUncuff` export, `compatSelfCuff`, `isCuffed` state bag handler.
local function forceUncuff(playerSource)
    local playerState = Player(playerSource).state
    if not playerState.isCuffed then return end

    playerState:set("cuffed",    false,   true)
    playerState:set("isCuffed",  false,   true)
    playerState:set("cuffType",  "none",  true)

    -- Wait for state to propagate, then nudge client if still showing cuffed
    local attempts = 0
    Wait(1000)
    while Player(playerSource).state.isCuffed and attempts < 5 do
        Wait(500)
        attempts = attempts + 1
    end

    TriggerClientEvent("p_policejob/client/interactions/ForceUncuff", playerSource)
    Bridge.Logs.Send(playerSource, "Interactions",
        locale("player_has_been_force_uncuffed"),
        Config.Webhooks.interactions)
end

-- Force-cuff: sets state bags and triggers client visual.
local function forceCuff(playerSource)
    local playerState = Player(playerSource).state
    if playerState.isCuffed then return end

    playerState:set("cuffed",    true,    true)
    playerState:set("isCuffed",  true,    true)
    playerState:set("cuffType",  "cuffs", true)

    TriggerClientEvent("p_policejob/client/interactions/ForceCuff", playerSource)
    Bridge.Logs.Send(playerSource, "Interactions",
        locale("player_has_been_force_cuffed"),
        Config.Webhooks.interactions)
end

-- ============================================================
--  ESX/QBCore persistence helpers
-- ============================================================

-- Returns true when cuff-state should be persisted to DB (ESX save-after-logout)
local function shouldPersistCuffs()
    if not Config.Interactions.Cuffs.saveAfterLogout then return false end
    return GetResourceState("es_extended") == "started"
end

-- Set "ishandcuffed" metadata on a framework player object
local function setHandcuffMeta(frameworkPlayer, state)
    if not frameworkPlayer then return end
    local value = state and 1 or 0

    -- ESX style
    if frameworkPlayer.setMeta then
        pcall(frameworkPlayer.setMeta, "ishandcuffed", value)
    -- QBCore style
    elseif frameworkPlayer.Functions and frameworkPlayer.Functions.SetMetaData then
        frameworkPlayer.Functions.SetMetaData("ishandcuffed", state)
    end
end

-- Read "ishandcuffed" from a framework player object
local function getHandcuffMeta(frameworkPlayer)
    if not frameworkPlayer then return false end
    local val = nil

    if frameworkPlayer.getMeta then
        val = frameworkPlayer.getMeta("ishandcuffed")
    elseif frameworkPlayer.PlayerData and frameworkPlayer.PlayerData.metadata then
        val = frameworkPlayer.PlayerData.metadata.ishandcuffed
    end

    return val == true or val == 1 or val == "true"
end

-- ============================================================
--  Resolve player: accepts server ID (number) or unique ID (string)
--  Returns: identifier (string), playerSource (number|nil)
-- ============================================================

local function resolvePlayer(input)
    if input == nil then return nil, nil end

    if type(input) == "number" then
        local identifier = Bridge.Framework.getUniqueId(input)
        return identifier, input
    end

    input = tostring(input)
    local frameworkPlayer = Bridge.Framework.getPlayerByUniqueId(input)

    -- Try uppercase variant (e.g. Steam hex case difference)
    if not frameworkPlayer then
        local upper = input:upper()
        if upper ~= input then
            local fp2 = Bridge.Framework.getPlayerByUniqueId(upper)
            if fp2 then frameworkPlayer = fp2; input = upper end
        end
    end

    if not frameworkPlayer then return input, nil end

    local playerSource = frameworkPlayer.source
        or (frameworkPlayer.PlayerData and frameworkPlayer.PlayerData.source)
    return input, playerSource
end

-- ============================================================
--  Stop-drag helper (clears both sides' state bags)
-- ============================================================

local function stopDrag(draggerSource, draggedSource)
    TriggerClientEvent("p_policejob/client/interactions/StartDrag", draggerSource, {
        state = false, isDragging = true,  player = draggedSource
    })
    TriggerClientEvent("p_policejob/client/interactions/StartDrag", draggedSource, {
        state = false, isDragging = false, player = draggerSource
    })
    Player(draggerSource).state:set("draggingPlayer", nil,   true)
    Player(draggedSource).state:set("draggedBy",       nil,   true)
    Player(draggedSource).state:set("escorted",        false, true)
end

-- Stop-carry helper
local function stopCarry(carrierSource, carriedSource)
    TriggerClientEvent("p_policejob/client/interactions/StopCarryPlayer", carrierSource)
    TriggerClientEvent("p_policejob/client/interactions/StopCarryPlayer", carriedSource)
    Player(carrierSource).state:set("carryingPlayer", nil, true)
    Player(carriedSource).state:set("carriedBy",       nil, true)
end

-- ============================================================
--  Exports
-- ============================================================

exports("forceUncuff", forceUncuff)
exports("forceCuff",   forceCuff)

-- ForceClearCuffState: clears ALL interaction states for a player (drag, carry, bag, tape, cuffs)
exports("ForceClearCuffState", function(callerSource, targetSource)
    targetSource = tonumber(targetSource)
    if not targetSource then return false, "player_not_found" end

    local identifier = Bridge.Framework.getUniqueId(targetSource)
    if not identifier then return false, "player_not_found" end

    local targetState = Player(targetSource).state

    if targetState.draggedBy       then stopDrag(targetState.draggedBy, targetSource) end
    if targetState.draggingPlayer  then stopDrag(targetSource, targetState.draggingPlayer) end
    if targetState.carriedBy       then stopCarry(targetState.carriedBy, targetSource) end
    if targetState.carryingPlayer  then stopCarry(targetSource, targetState.carryingPlayer) end

    if targetState.hasHeadBag then
        targetState:set("hasHeadBag", false, true)
        TriggerClientEvent("p_policejob/client/interactions/ToggleHeadBag", targetSource, false)
    end

    if targetState.mouthTaped then
        targetState:set("mouthTaped", false, true)
    end

    if targetState.isCuffed then
        forceUncuff(targetSource)
    end

    if callerSource then
        Bridge.Logs.Send(callerSource, "Interactions",
            ("Force-cleared interaction state on player %s (export)"):format(targetSource),
            Config.Webhooks.interactions)
    end

    return true, "cleared"
end)

-- GetPlayerStatus: returns a rich status table for a player (by server ID or unique ID)
exports("GetPlayerStatus", function(input)
    local identifier, playerSource = resolvePlayer(input)
    if not identifier then return nil end

    local status = {
        cid         = identifier,
        isOnline    = playerSource ~= nil,
        cuffed      = false,
        cuffType    = "none",
        draggedBy   = nil,
        carriedBy   = nil,
        hasHeadBag  = false,
        mouthTaped  = false,
        jailMinutes = 0,
        hasBand     = false,
    }

    if playerSource then
        local playerState = Player(playerSource).state
        status.source     = playerSource
        status.cuffed     = playerState.isCuffed == true
        status.cuffType   = playerState.cuffType or "none"
        status.draggedBy  = playerState.draggedBy
        status.carriedBy  = playerState.carriedBy
        status.hasHeadBag = playerState.hasHeadBag == true
        status.mouthTaped = playerState.mouthTaped == true
    end

    -- Optional Prison integration
    if Prison and Prison.sentences and Prison.sentences[identifier] then
        local sentence = Prison.sentences[identifier]
        if sentence.status == "active" then
            if sentence.isLife then
                status.jailMinutes = -1
            else
                status.jailMinutes = math.ceil(math.max(0, (sentence.releaseAt or 0) - os.time()) / 60)
            end
        end
    end

    -- Optional Band integration
    if Band and Band.playersWithBand then
        status.hasBand = Band.playersWithBand[identifier] ~= nil
    end

    return status
end)

-- ============================================================
--  HandCuffs net event
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/HandCuffs", function(data)
    local officerSource = source

    if not Interactions:canInteract(officerSource, data.player, 5.0) then
        Bridge.Debug(("[Interactions] Player %s invalid cuff attempt on %s"):format(officerSource, tostring(data.player)))
        Bridge.Logs.Send(officerSource, "Interactions",
            "Attempted invalid cuff on " .. tostring(data.player),
            Config.Webhooks.interactions)
        return
    end

    -- ---- Item / key management ----
    if data.type == "cuffs" then
        if Config.Interactions.Cuffs.cuffKeys then
            -- Track who cuffed whom for key handback on uncuff
            Interactions.cuffedBy[data.player] = data.state and officerSource or nil

            if data.state then
                if Bridge.Inventory.getItemCount(officerSource, "handcuffs") < 1 then return end
                Bridge.Inventory.removeItem(officerSource, "handcuffs", 1)
                Bridge.Inventory.addItem(officerSource, "cuffs_key", 1, data.player)
            else
                if Bridge.Inventory.getItemCount(officerSource, "cuffs_key", data.player) < 1 then return end
                Bridge.Inventory.removeItem(officerSource, "cuffs_key", 1, data.player)
                Bridge.Inventory.addItem(officerSource, "handcuffs", 1)
            end
        else
            if Bridge.Inventory.getItemCount(officerSource, "handcuffs") < 1 then return end
        end
    else
        -- cable_ties
        if data.state then
            if Bridge.Inventory.getItemCount(officerSource, "cable_ties") < 1 then return end
            Bridge.Inventory.removeItem(officerSource, "cable_ties", 1)
        else
            Bridge.Inventory.addItem(officerSource, "cable_ties", 1)
        end
    end

    -- ---- Config callbacks ----
    if data.state then
        Config.Interactions.onCuff_Server(officerSource, data.player, data.type)
    else
        Config.Interactions.onUnCuff_Server(officerSource, data.player, data.type)
    end

    -- ---- Trigger animations on both sides ----
    TriggerClientEvent("p_policejob/client/interactions/HandCuffsAnimation", officerSource, {
        isCuff     = data.state,
        isArrested = false,
        player     = data.player,
        type       = data.type,
        timer      = data.timer,
        time       = data.time,
        front      = data.front,
        isHard     = data.isHard,
    })

    TriggerClientEvent("p_policejob/client/interactions/HandCuffsAnimation", data.player, {
        isCuff     = data.state,
        isArrested = true,
        player     = officerSource,
        type       = data.type,
        timer      = data.timer,
        time       = data.time,
        front      = data.front,
        isHard     = data.isHard,
    })

    -- ---- Log ----
    local action = data.state and "Cuffed" or "Uncuffed"
    Bridge.Logs.Send(officerSource, "Interactions",
        ("%s player %s (%s)"):format(action, tostring(data.player), data.type),
        Config.Webhooks.interactions)
    Bridge.Debug(("[Interactions] Player %s %s player %s (%s)"):format(
        officerSource, data.state and "cuffed" or "uncuffed", tostring(data.player), data.type))
end)

-- ============================================================
--  isCuffed state bag — handle key handback and persistence
-- ============================================================

AddStateBagChangeHandler("isCuffed", nil, function(bagName, _, newValue)
    local playerSource = GetPlayerFromStateBagName(bagName)
    if not playerSource then return end

    local officerWhoApplied = Interactions.cuffedBy[playerSource]
    if officerWhoApplied and not newValue then
        -- Return key to officer, give handcuffs back
        Bridge.Inventory.removeItem(officerWhoApplied, "cuffs_key", 1, playerSource)
        Bridge.Inventory.addItem(officerWhoApplied, "handcuffs", 1)
    end

    if shouldPersistCuffs() then
        local frameworkPlayer = Bridge.Framework.getPlayerById(playerSource)
        setHandcuffMeta(frameworkPlayer, newValue)
    end
end)

-- ============================================================
--  Player loaded — restore cuff state from DB if applicable
-- ============================================================

AddEventHandler("p_bridge/server/playerLoaded", function(playerSource)
    Wait(1000)
    if not shouldPersistCuffs() then return end

    local frameworkPlayer = Bridge.Framework.getPlayerById(playerSource)
    if getHandcuffMeta(frameworkPlayer) then
        forceCuff(playerSource)
    end
end)

-- ============================================================
--  Lockpick cuffs
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/OpenCuffs", function(data)
    local officerSource = source
    if not Interactions:canInteract(officerSource, data.player) then return end

    local success = lib.callback.await("p_policejob/client/interactions/attemptOpenCuffs", officerSource)
    if success then
        forceUncuff(data.player)
        Bridge.Notify.showNotify(officerSource, locale("you_opened_cuffs"), "success")
        Bridge.Logs.Send(officerSource, "Interactions",
            "Lockpicked cuffs on player " .. tostring(data.player),
            Config.Webhooks.interactions)
    end
end)

-- ============================================================
--  Drag / Escort
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/DragPlayer", function(data)
    local officerSource  = source
    local officerState   = Player(officerSource).state
    local targetState    = Player(data.player).state

    if not Interactions:canInteract(officerSource, data.player, 5.0) then return end

    -- Prevent double-drag
    if data.state and targetState.draggedBy then return end

    -- Target must be dead, cuffed, or already being dragged by this officer
    local targetQualifies = Interactions:isPlayerDead(data.player)
        or targetState.isCuffed
        or (officerState.draggingPlayer and officerState.draggingPlayer == data.player)

    if not targetQualifies then return end

    TriggerClientEvent("p_policejob/client/interactions/StartDrag", officerSource, {
        state = data.state, isDragging = true,  player = data.player
    })
    TriggerClientEvent("p_policejob/client/interactions/StartDrag", data.player, {
        state = data.state, isDragging = false, player = officerSource
    })

    officerState:set("draggingPlayer", data.state and data.player or nil, true)
    targetState:set("draggedBy",       data.state and officerSource or nil, true)
    targetState:set("escorted",        data.state, true)

    local action = data.state and "Started dragging" or "Stopped dragging"
    Bridge.Logs.Send(officerSource, "Interactions",
        ("%s player %s"):format(action, tostring(data.player)),
        Config.Webhooks.interactions)
end)

-- ============================================================
--  Take out of vehicle
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/OutVehicle", function(data)
    local officerSource = source
    if not Interactions:canInteract(officerSource, data.player) then return end

    local targetQualifies = Interactions:isPlayerDead(data.player)
        or Player(data.player).state.isCuffed

    if not targetQualifies then return end

    TriggerClientEvent("p_policejob/client/interactions/TakeOutVehicle", data.player)
    Bridge.Logs.Send(officerSource, "Interactions",
        ("Took out player %s from vehicle"):format(tostring(data.player)),
        Config.Webhooks.interactions)
end)

-- ============================================================
--  Put in vehicle
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/PutInVehicle", function(data)
    local officerSource = source
    if not Interactions:canInteract(officerSource, data.player) then return end

    local targetState    = Player(data.player).state
    local targetQualifies = Interactions:isPlayerDead(data.player) or targetState.isCuffed

    if not targetQualifies then return end

    -- Stop drag if active
    if targetState.draggedBy then
        stopDrag(officerSource, data.player)
        Wait(100)
    end

    TriggerClientEvent("p_policejob/client/interactions/PutInVehicle", data.player, {
        player = officerSource,
        seat   = data.seat,
    })

    Bridge.Logs.Send(officerSource, "Interactions",
        ("Put player %s in vehicle seat %s"):format(tostring(data.player), tostring(data.seat)),
        Config.Webhooks.interactions)
end)

-- ============================================================
--  Gunpowder check
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/CheckGunPowder", function(targetSource)
    local officerSource = source
    if not Interactions:canInteract(officerSource, targetSource) then return end

    local hasGunPowder = lib.callback.await("p_policejob/client/evidence/checkGunPowder", targetSource)
    local notifyKey    = hasGunPowder and "this_player_have_gun_powder" or "this_player_dont_have_gun_powder"
    Bridge.Notify.showNotify(officerSource, locale(notifyKey), "info")

    Bridge.Logs.Send(officerSource, "Interactions",
        ("Checked gunpowder on %s (%s)"):format(tostring(targetSource), hasGunPowder and "+" or "-"),
        Config.Webhooks.interactions)
end)

-- ============================================================
--  Head bag
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/ToggleHeadBag", function(data)
    local officerSource = source
    if not Interactions:canInteract(officerSource, data.player) then return end

    local targetState = Player(data.player).state
    if data.state and targetState.hasHeadBag then return end
    if not data.state and not targetState.hasHeadBag then return end

    if data.state then
        if Bridge.Inventory.getItemCount(officerSource, "headbag") < 1 then return end
        Bridge.Inventory.removeItem(officerSource, "headbag", 1)
    else
        Bridge.Inventory.addItem(officerSource, "headbag", 1)
    end

    targetState:set("hasHeadBag", data.state, true)
    TriggerClientEvent("p_policejob/client/interactions/ToggleHeadBag", data.player, data.state)

    local action = data.state and "Put head bag on" or "Removed head bag from"
    Bridge.Logs.Send(officerSource, "Interactions",
        ("%s player %s"):format(action, tostring(data.player)),
        Config.Webhooks.interactions)
end)

-- ============================================================
--  Mouth tape
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/ToggleMouthTape", function(data)
    local officerSource = source
    if not Interactions:canInteract(officerSource, data.player) then return end

    local targetState = Player(data.player).state
    if data.state and targetState.mouthTaped then goto skipIdempotent end
    if not data.state and not targetState.mouthTaped then return end
    ::skipIdempotent::

    if data.state then
        if Bridge.Inventory.getItemCount(officerSource, "mouthtape") < 1 then return end
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
--  Carry
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/StartCarryPlayer", function(targetSource)
    local officerSource = source
    if not Interactions:canInteract(officerSource, targetSource) then return end

    local targetState = Player(targetSource).state
    if targetState.carriedBy then return end

    local consented = true
    if Config.Interactions.Carry.useRequest then
        consented = lib.callback.await(
            "p_policejob/client/interactions/RequestCarryPlayer",
            targetSource, officerSource)
    end

    if not consented then return end

    Player(targetSource).state:set("carriedBy",       officerSource,  true)
    Player(officerSource).state:set("carryingPlayer", targetSource,   true)

    TriggerClientEvent("p_policejob/client/interactions/StartCarryPlayer", officerSource, {
        isCarrying = true,  playerId = targetSource
    })
    TriggerClientEvent("p_policejob/client/interactions/StartCarryPlayer", targetSource, {
        isCarrying = false, playerId = officerSource
    })

    Bridge.Logs.Send(officerSource, "Interactions",
        "Started carrying player " .. tostring(targetSource),
        Config.Webhooks.interactions)
end)

RegisterNetEvent("p_policejob/server/interactions/StopCarryPlayer", function(targetSource)
    local officerSource = source
    if not Interactions:canInteract(officerSource, targetSource) then return end

    local targetState = Player(targetSource).state
    if not targetState.carriedBy or targetState.carriedBy ~= officerSource then return end

    stopCarry(officerSource, targetSource)

    Bridge.Logs.Send(officerSource, "Interactions",
        "Stopped carrying player " .. tostring(targetSource),
        Config.Webhooks.interactions)
end)

-- ============================================================
--  Compat events (from legacy police resources)
-- ============================================================

RegisterNetEvent("p_policejob/server/interactions/compatSelfCuff", function(data)
    if type(data) ~= "table" then return end
    if data.state then forceCuff(source) else forceUncuff(source) end
end)

RegisterNetEvent("police:server:SetHandcuffStatus", function(state)
    if state then forceCuff(source) else forceUncuff(source) end
end)

RegisterNetEvent("p_policejob/server/interactions/compatEscortRequest", function(targetSource)
    local officerSource = source
    targetSource = tonumber(targetSource)
    if not targetSource or targetSource == officerSource then return end

    local targetPed  = GetPlayerPed(targetSource)
    local officerPed = GetPlayerPed(officerSource)
    if not (targetPed and targetPed ~= 0 and officerPed and officerPed ~= 0) then return end

    local dist = #(GetEntityCoords(targetPed) - GetEntityCoords(officerPed))
    if dist > 5.0 then return end

    TriggerClientEvent("p_policejob/escortPlayer", targetSource)
end)

-- ============================================================
--  Cleanup on disconnect
-- ============================================================

AddEventHandler("playerDropped", function()
    Interactions.cuffedBy[source] = nil
end)
