if not Config.Bodycam.Enabled then
    return
end

-- Global Bodycam object shared across the resource
Bodycam = {}
Bodycam.activeBodycams = {}  -- [serverId] = { name, badge, jobName }
Bodycam.watchers       = {}  -- [targetId][watcherId] = true
Bodycam.recordings     = {}  -- [targetId] = { watcherId, startedAt }

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Returns true if the "screencapture" resource is currently running
function IsScreencaptureAvailable()
    return GetResourceState("screencapture") == "started"
end

-- ─── Recording ───────────────────────────────────────────────────────────────

-- Stops an active recording for targetId.
-- If watcherId is provided, only stops if that watcher owns the recording.
-- Returns true on success, false if no recording existed or ownership mismatch.
function Bodycam:stopRecording(targetId, watcherId)
    local recording = self.recordings[targetId]
    if not recording then return false end

    if watcherId and recording.watcherId ~= watcherId then
        return false
    end

    self.recordings[targetId] = nil

    if IsScreencaptureAvailable() then
        local ok, err = pcall(function()
            exports.screencapture:INTERNAL_stopServerCaptureStream(recording.watcherId)
        end)

        if not ok and Config.Debug then
            print(string.format("[Bodycam] Failed to stop recording for %s: %s", targetId, err))
        end
    end

    return true
end

-- Starts a screencapture recording of targetId's screen, uploaded via the
-- URL defined in BodycamRecordingConfig. watcherId is the observer's server id.
-- Returns true on success, false on any pre-condition failure.
function Bodycam:startRecording(targetId, watcherId)
    local recordingConfig = Config.Bodycam.Recording
    if not (recordingConfig and recordingConfig.Enabled) then
        return false
    end

    if not IsScreencaptureAvailable() then
        Bridge.Debug("screencapture resource is not started - recording disabled")
        return false
    end

    if not self.activeBodycams[targetId] then return false end
    if self.recordings[targetId] then return false end  -- already recording

    local uploadConfig = BodycamRecordingConfig or {}
    if not (uploadConfig.Url and uploadConfig.Url ~= "") then
        return false
    end

    -- Register the recording entry before the async call
    self.recordings[targetId] = {
        watcherId = watcherId,
        startedAt = os.time(),
    }

    local streamOptions = {
        headers   = { Authorization = uploadConfig.ApiKey or "" },
        formField = uploadConfig.FormField or "file",
        filename  = string.format("bodycam_%s_%s", targetId, os.time()),
        maxWidth  = recordingConfig.MaxWidth  or 1280,
        maxHeight = recordingConfig.MaxHeight or 720,
    }

    -- Called by screencapture once the upload finishes (success or fail)
    local function onUploadComplete(uploadedUrl)
        -- Resolve display names for the target and watcher
        local targetName  = Bridge.Framework.getPlayerName(targetId) or ("ID " .. tostring(targetId))
        local watcherName = "Unknown"
        if watcherId then
            watcherName = Bridge.Framework.getPlayerName(watcherId) or ("ID " .. tostring(watcherId))
        end

        -- Apply a custom URL transform if configured
        local finalUrl = uploadConfig.GetUrl and uploadConfig.GetUrl(uploadedUrl) or nil

        if finalUrl then
            if watcherId then
                TriggerClientEvent("p_policejob/client/bodycam/recordingUploaded", watcherId, finalUrl)
            end

            local logSource = watcherId or targetId
            Bridge.Logs.Send(
                logSource,
                "Bodycam",
                locale("bodycam_recording_log", watcherName, targetName, finalUrl),
                Config.Webhooks.bodycam
            )
        else
            if watcherId then
                TriggerClientEvent("p_policejob/client/bodycam/recordingFailed", watcherId)
            end

            if Config.Debug then
                print(string.format("[Bodycam] Recording upload failed for target %s", targetId))
            end
        end
    end

    local ok, err = pcall(function()
        exports.screencapture:remoteUploadStream(watcherId, uploadConfig.Url, streamOptions, onUploadComplete)
    end)

    if not ok then
        self.recordings[targetId] = nil
        if Config.Debug then
            print(string.format("[Bodycam] Failed to start recording for %s: %s", targetId, err))
        end
        return false
    end

    return true
end

-- ─── Watcher Registry ────────────────────────────────────────────────────────

-- Registers watcherId as an active observer of targetId's bodycam feed
function Bodycam:addWatcher(targetId, watcherId)
    if not self.watchers[targetId] then
        self.watchers[targetId] = {}
    end
    self.watchers[targetId][watcherId] = true
end

-- Removes watcherId from targetId's observer list; cleans up the entry when empty
function Bodycam:removeWatcher(targetId, watcherId)
    if not self.watchers[targetId] then return end

    self.watchers[targetId][watcherId] = nil

    if not next(self.watchers[targetId]) then
        self.watchers[targetId] = nil
    end
end

-- Notifies all watchers of targetId to stop viewing and clears the watcher list
function Bodycam:notifyWatchersToStop(targetId)
    if not self.watchers[targetId] then return end

    for watcherId in pairs(self.watchers[targetId]) do
        TriggerClientEvent("p_policejob/client/bodycam/forceStopWatching", watcherId)
    end

    self.watchers[targetId] = nil
end

-- ─── Bodycam Lifecycle ───────────────────────────────────────────────────────

-- Enables the bodycam for playerSource after verifying their job.
-- Registers them in activeBodycams, syncs GlobalState, and notifies the client.
function Bodycam:enable(playerSource)
    local playerJob = Bridge.Framework.getPlayerJob(playerSource)

    if not Config.Jobs[playerJob.name] then
        return Bridge.Notify.showNotify(playerSource, locale("bodycam_not_allowed"), "error")
    end

    local playerName = Bridge.Framework.getPlayerName(playerSource)
    local uniqueId   = Bridge.Framework.getUniqueId(playerSource)

    -- ⚠️ Badge is hardcoded to "000" — the original had no badge lookup logic.
    --    Clarify whether this should pull from the player's character data.
    local camData = {
        name    = playerName,
        badge   = "000",
        jobName = playerJob.name,
    }

    self.activeBodycams[playerSource]     = camData
    GlobalState["p_policejob/BodyCams"]   = self.activeBodycams

    TriggerClientEvent("p_policejob/client/bodycam/toggle", playerSource, true, camData)

    Bridge.Logs.Send(
        playerSource,
        "Bodycam",
        locale("player_enabled_bodycam"),
        Config.Webhooks.bodycam
    )
end

-- Disables the bodycam for playerSource: stops any recording, evicts all watchers,
-- removes them from activeBodycams, and syncs GlobalState.
function Bodycam:disable(playerSource)
    if not self.activeBodycams[playerSource] then return end

    if self.recordings[playerSource] then
        self:stopRecording(playerSource)
    end

    self:notifyWatchersToStop(playerSource)

    self.activeBodycams[playerSource]   = nil
    GlobalState["p_policejob/BodyCams"] = self.activeBodycams

    TriggerClientEvent("p_policejob/client/bodycam/toggle", playerSource, false)

    Bridge.Logs.Send(
        playerSource,
        "Bodycam",
        locale("player_disabled_bodycam"),
        Config.Webhooks.bodycam
    )
end

-- Toggles the bodycam for playerSource (enable if off, disable if on)
function Bodycam:toggle(playerSource)
    if self.activeBodycams[playerSource] then
        self:disable(playerSource)
    else
        self:enable(playerSource)
    end
end

-- Returns the filtered list of active bodycams visible to playerSource.
-- If Config.Bodycam.jobRestricted is true, only shows cams from the same job.
function Bodycam:getList(playerSource)
    if Config.Bodycam.jobRestricted then
        local playerJob    = Bridge.Framework.getPlayerJob(playerSource)
        local filteredList = {}

        for serverId, camData in pairs(self.activeBodycams) do
            if camData.jobName == playerJob.name then
                filteredList[serverId] = camData
            end
        end

        return filteredList
    end

    return self.activeBodycams
end

-- Returns the world coords of playerSource's ped, or false if the ped is invalid
function Bodycam:getPlayerCoords(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not (ped and ped ~= 0 and DoesEntityExist(ped)) then
        return false
    end
    return GetEntityCoords(ped)
end

-- ─── Exports ─────────────────────────────────────────────────────────────────

-- Allows other resources to toggle a player's bodycam by server id
exports("useBodyCamItem", function(playerSource)
    Bodycam:toggle(playerSource)
end)

-- ox_inventory item hook: called when a body_cam item is used
exports("body_cam", function(action, _, itemData)
    if action == "usingItem" then
        Bodycam:toggle(itemData.id)
    end
end)

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Client → server: player toggled their own bodycam via item/command
RegisterNetEvent("p_policejob/server/bodycam/toggle", function()
    Bodycam:toggle(source)
end)

-- Client → server: watcher is stopping a recording for targetId
RegisterNetEvent("p_policejob/server/bodycam/stopRecording", function(targetId)
    local watcherId = source
    if not targetId then return end
    Bodycam:stopRecording(targetId, watcherId)
end)

-- Player disconnected: clean up their bodycam, any recording they owned,
-- any recordings they were watching, and remove them from all watcher lists
AddEventHandler("playerDropped", function()
    local droppedSource = source

    -- Stop their own recording if active
    if Bodycam.recordings[droppedSource] then
        Bodycam:stopRecording(droppedSource)
    end

    -- Stop any recordings this player was watching
    for targetId, recording in pairs(Bodycam.recordings) do
        if recording.watcherId == droppedSource then
            Bodycam:stopRecording(targetId)
        end
    end

    -- Clean up their active bodycam and notify its watchers
    if Bodycam.activeBodycams[droppedSource] then
        Bodycam:notifyWatchersToStop(droppedSource)
        Bodycam.activeBodycams[droppedSource]  = nil
        GlobalState["p_policejob/BodyCams"]    = Bodycam.activeBodycams
    end
end)

-- ─── Callbacks ───────────────────────────────────────────────────────────────

-- Validates that the watcher has permission to record the target, then starts
lib.callback.register("p_policejob/server/bodycam/startRecording", function(watcherSource, targetId)
    if not targetId then return false end

    -- Watcher must already be in the target's watcher list
    local isAllowed = Bodycam.watchers[targetId] and Bodycam.watchers[targetId][watcherSource]
    if not isAllowed then return false end

    return Bodycam:startRecording(targetId, watcherSource)
end)

-- Returns the filtered bodycam list for the requesting player
lib.callback.register("p_policejob/server/bodycam/fetchList", function(playerSource)
    return Bodycam:getList(playerSource)
end)

-- Returns the world coords of a specific player's ped
lib.callback.register("p_policejob/server/bodycam/fetchPlayerCoords", function(_, targetId)
    return Bodycam:getPlayerCoords(targetId)
end)

-- ─── State Bag Handler ───────────────────────────────────────────────────────

-- Fires when any player's "isInBodycam" state bag changes.
-- A truthy value means the player started watching a bodycam feed (value = targetId).
-- A falsy value means they stopped watching.
AddStateBagChangeHandler("isInBodycam", nil, function(bagName, _, newValue)
    if not bagName then return end

    local watcherSource = GetPlayerFromStateBagName(bagName)
    if not watcherSource then return end

    if newValue then
        -- Player started watching: register them and fire the config hook
        Config.Bodycam.onStartWatching_Server(watcherSource)
        Bodycam:addWatcher(newValue, watcherSource)

        if Config.Debug then
            print(string.format("[Bodycam] Player %s started watching bodycam of player %s",
                watcherSource, newValue))
        end
    else
        -- Player stopped watching: fire config hook, stop their recordings,
        -- and remove them from all watcher lists
        Config.Bodycam.onStopWatching_Server(watcherSource)

        for targetId, recording in pairs(Bodycam.recordings) do
            if recording.watcherId == watcherSource then
                Bodycam:stopRecording(targetId)
            end
        end

        for targetId in pairs(Bodycam.watchers) do
            Bodycam:removeWatcher(targetId, watcherSource)
        end

        if Config.Debug then
            print(string.format("[Bodycam] Player %s stopped watching bodycam", watcherSource))
        end
    end
end)

-- ─── Inventory Hook ──────────────────────────────────────────────────────────

-- If the inventory bridge supports item hooks, automatically disable the bodycam
-- when a body_cam item is moved out of a player's inventory
if Bridge.Inventory.registerHook then
    Bridge.Inventory.registerHook("swapItems", function(payload)
        local isMovingOut = payload.action == "swap" or payload.action == "move"

        if isMovingOut
        and payload.toInventory ~= payload.fromInventory
        and payload.fromType == "player"
        then
            if Bodycam.activeBodycams[payload.fromInventory] then
                Bodycam:disable(payload.fromInventory)
            end
        end
    end, { itemFilter = { body_cam = true } })
end
