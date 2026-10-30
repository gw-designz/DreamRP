if not Config.Trunks.enabled then return end

Trunks = {}
Trunks.occupiedTrunks = {}

-- Publish initial (empty) state to all clients via GlobalState
GlobalState["p_policejob:occupiedTrunks"] = Trunks.occupiedTrunks

-- ============================================================
--  Load saved offsets from trunks.json on resource start
-- ============================================================

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(100)

    local raw = LoadResourceFile(resourceName, "trunks.json")
    if not raw then return end

    local decoded = json.decode(raw)
    if decoded then
        Bridge.Debug(("[Trunks] Loaded %d saved offsets"):format(#decoded))
    end
end)

-- ============================================================
--  setOccupied: marks/clears a trunk (by vehicle netId)
-- ============================================================

RegisterNetEvent("p_policejob/server/trunks/setOccupied", function(netId, isOccupied)
    local playerSource = source
    -- Store the occupying player's server ID, or nil if vacating
    Trunks.occupiedTrunks[netId] = (isOccupied and playerSource) and playerSource or nil
    GlobalState["p_policejob:occupiedTrunks"] = Trunks.occupiedTrunks
end)

-- ============================================================
--  save: write offset data to trunks.json
-- ============================================================

RegisterNetEvent("p_policejob/server/trunks/save", function(data)
    local playerSource = source

    if not (type(data) == "table" and data.model) then return end

    -- Permission check
    if not Bridge.Framework.checkPermissions(playerSource, Config.Trunks.allowedGroups) then
        return Bridge.Notify.showNotify(playerSource, locale("trunk_editor_no_access"), "error")
    end

    -- Load existing offsets
    local resourceName = GetCurrentResourceName()
    local raw          = LoadResourceFile(resourceName, "trunks.json") or "{}"
    local offsets      = json.decode(raw) or {}

    -- Update entry for this model
    offsets[data.model] = { coords = data.coords, rotation = data.rotation }

    -- Save to file
    SaveResourceFile(resourceName, "trunks.json",
        json.encode(offsets, { indent = true }), -1)

    Bridge.Notify.showNotify(playerSource, locale("trunk_saved", data.model), "success")

    -- Sync updated offsets to all clients
    TriggerClientEvent("p_policejob/client/trunks/refreshOffsets", -1, offsets)
end)

-- ============================================================
--  takeOut: force-eject the player currently in a trunk
-- ============================================================

RegisterNetEvent("p_policejob/server/trunks/takeOut", function(netId)
    local officerSource = source
    if not netId then return end

    local occupant = Trunks.occupiedTrunks[netId]
    if not occupant then return end

    TriggerClientEvent("p_policejob/client/trunks/exit", occupant)

    local webhook = (Config.Webhooks and Config.Webhooks.trunks) or ""
    Bridge.Logs.Send(officerSource, "Trunks",
        locale("player_took_out_player_from_trunk", occupant),
        webhook)
end)

-- ============================================================
--  putIn: force another player into the trunk of the nearest vehicle
-- ============================================================

RegisterNetEvent("p_policejob/server/trunks/putIn", function(targetSource)
    local officerSource = source
    if not targetSource then return end

    local targetPed = GetPlayerPed(targetSource)
    if not targetPed then return end

    -- Distance check between officer and target
    local officerCoords = GetEntityCoords(GetPlayerPed(officerSource))
    local targetCoords  = GetEntityCoords(targetPed)
    if #(officerCoords - targetCoords) > 5.0 then return end

    TriggerClientEvent("p_policejob/client/trunks/enter", targetSource)

    local webhook = (Config.Webhooks and Config.Webhooks.trunks) or ""
    Bridge.Logs.Send(officerSource, "Trunks",
        locale("player_put_player_in_trunk", targetSource),
        webhook)
end)

-- ============================================================
--  Cleanup on disconnect
-- ============================================================

AddEventHandler("playerDropped", function()
    local playerSource = source
    for netId, occupant in pairs(Trunks.occupiedTrunks) do
        if occupant == playerSource then
            Trunks.occupiedTrunks[netId] = nil
        end
    end
    GlobalState["p_policejob:occupiedTrunks"] = Trunks.occupiedTrunks
end)
