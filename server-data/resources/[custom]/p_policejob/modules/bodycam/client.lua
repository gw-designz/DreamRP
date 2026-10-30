if not Config.Bodycam.Enabled then
    return
end

-- Global Bodycam object shared across the resource
Bodycam = {}
Bodycam.isActive   = false
Bodycam.data       = nil
Bodycam.watching   = {
    camera       = nil,
    targetPed    = nil,
    targetId     = nil,
    isActive     = false,
    isRecording  = false,
    cachedCoords = nil,
}

-- ─── Exports ────────────────────────────────────────────────────────────────

exports("isBodycamActive", function()
    return Bodycam.isActive
end)

exports("ToggleBodyCam", function(forceState, data)
    Bodycam:toggle(forceState, data)
end)

exports("OpenBodyCamList", function()
    Bodycam:openList()
end)

exports("StartWatchBodyCam", function(targetServerId)
    Bodycam:startWatching(targetServerId)
end)

-- ─── Core Bodycam Methods ────────────────────────────────────────────────────

-- Shows the bodycam NUI overlay and stores the associated data
function Bodycam:open(data)
    self.isActive = true
    self.data     = data
    SendNUIMessage({ action = "setVisibleBodycam", data = true })
    SendNUIMessage({ action = "setBodycamData",    data = data })
end

-- Hides the bodycam NUI overlay and clears stored data
function Bodycam:close()
    self.isActive = false
    self.data     = nil
    SendNUIMessage({ action = "setVisibleBodycam", data = false })
end

-- Toggles the bodycam on or off.
-- forceState: true = force on, false = force off, nil = flip current state
-- data: optional bodycam metadata to display
function Bodycam:toggle(forceState, data)
    if forceState == nil then
        forceState = not self.isActive
    end

    if data then
        self.data = data
    end

    if forceState then
        local displayData = data or self.data
        self:open(displayData)
    else
        self:close()
    end
end

-- Freezes/unfreezes the local ped and toggles visibility/collision/invincibility
-- Used to hide the watcher ped while they are viewing another player's bodycam
function Bodycam:setupWatchingPed(shouldHide)
    local ped = cache.ped
    FreezeEntityPosition(ped, shouldHide)
    SetEntityVisible(ped, not shouldHide)
    SetEntityCollision(ped, not shouldHide, not shouldHide)
    SetEntityInvincible(ped, shouldHide)
    NetworkSetEntityInvisibleToNetwork(ped, shouldHide)
end

-- Begins watching a remote player's bodycam feed.
-- Fetches their coords via server callback, hides the watcher ped,
-- teleports it beneath the target, creates and attaches a scripted camera,
-- then launches the watching threads.
function Bodycam:startWatching(targetServerId)
    local targetCoords = lib.callback.await("p_policejob/server/bodycam/fetchPlayerCoords", false, targetServerId)
    if not targetCoords then
        return Bridge.Notify.showNotify(locale("bodycam_not_active"), "error")
    end

    local watcherCoords  = GetEntityCoords(cache.ped)
    local watcherHeading = GetEntityHeading(cache.ped)

    self.watching.cachedCoords = vector4(watcherCoords.x, watcherCoords.y, watcherCoords.z, watcherHeading)
    self.watching.isActive     = true
    self.watching.targetId     = targetServerId
    self.watching.isRecording  = false

    if type(Config.Bodycam.onStartWatching) == "function" then
        pcall(Config.Bodycam.onStartWatching)
    end

    LocalPlayer.state:set("isInBodycam", targetServerId, true)

    Utils:fadeOutScreen(1000)
    self:setupWatchingPed(true)

    -- Drop the watcher ped 100 units below the target so it is out of sight
    SetEntityCoords(cache.ped, targetCoords.x, targetCoords.y, targetCoords.z - 100.0)
    Wait(500)

    -- Poll until we resolve the target ped handle (up to 5 seconds)
    local targetPed   = 0
    local giveUpAt    = GetGameTimer() + 5000
    repeat
        local playerHandle = GetPlayerFromServerId(targetServerId)
        if playerHandle ~= -1 then
            local pedHandle = GetPlayerPed(playerHandle)
            if pedHandle then
                targetPed = pedHandle
            end
        else
            targetPed = 0
        end

        if targetPed ~= 0 and targetPed ~= cache.ped then
            break
        end

        targetPed = 0
        Wait(100)
    until GetGameTimer() > giveUpAt

    if targetPed == 0 then
        Bridge.Notify.showNotify(locale("bodycam_not_active"), "error")
        return self:stopWatching()
    end

    self.watching.targetPed = targetPed

    -- Create and attach the scripted camera to the target's chest bone
    local cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    self.watching.camera = cam

    AttachCamToPedBone(cam, targetPed, 46240, 0.1, 0.025, 0.1, true)
    SetCamFov(cam, 100.0)
    SetCamRot(cam, 0, 0, GetEntityHeading(targetPed), 2)

    RenderScriptCams(true, false, 0, 1, 0)
    ShakeCam(cam, "HAND_SHAKE", 1.0)
    SetCamShakeAmplitude(cam, 2.0)

    -- Apply CCTV visual filter
    SetTimecycleModifier("Island_CCTV_ChannelFuzz")
    SetTimecycleModifierStrength(0.45)

    self:startWatchingThreads()
    Utils:fadeInScreen(1000)
end

-- Ends the bodycam watch session: stops any active recording, restores the
-- watcher ped, resets the camera, clears the timecycle filter, and
-- resets the watching state table.
function Bodycam:stopWatching()
    if not self.watching.isActive then return end

    -- Stop server-side recording if it was running
    if self.watching.isRecording and self.watching.targetId then
        TriggerServerEvent("p_policejob/server/bodycam/stopRecording", self.watching.targetId)
        self.watching.isRecording = false
    end

    Utils:fadeOutScreen(1000)
    self:setupWatchingPed(false)

    -- Restore watcher ped to their original position
    local saved = self.watching.cachedCoords
    if saved then
        SetEntityCoords(cache.ped, saved.x, saved.y, saved.z)
        SetEntityHeading(cache.ped, saved.w)
    end

    RenderScriptCams(false, false, 0, 1, 0)
    SetTimecycleModifier("default")
    SetTimecycleModifierStrength(1.0)
    DoScreenFadeIn(1000)
    Wait(500)

    -- Reset watching state
    self.watching = {
        camera       = nil,
        targetPed    = nil,
        targetId     = nil,
        isActive     = false,
        isRecording  = false,
        cachedCoords = nil,
    }

    LocalPlayer.state:set("isInBodycam", false, true)

    if type(Config.Bodycam.onStopWatching) == "function" then
        pcall(Config.Bodycam.onStopWatching)
    end
end

-- Returns the appropriate TextUI label depending on recording config and state
function Bodycam:getTextUI()
    local recordingConfig = Config.Bodycam.Recording
    if not (recordingConfig and recordingConfig.Enabled) then
        return locale("bodycam_textui")
    end

    if self.watching.isRecording then
        return locale("bodycam_textui_recording")
    end

    return locale("bodycam_textui_record")
end

-- Toggles recording for the currently watched bodycam target.
-- Calls the server callback to start, or fires a server event to stop.
function Bodycam:toggleRecording()
    local recordingConfig = Config.Bodycam.Recording
    if not (recordingConfig and recordingConfig.Enabled) then
        return Bridge.Notify.showNotify(locale("bodycam_recording_disabled"), "error")
    end

    if not (self.watching.isActive and self.watching.targetId) then return end

    if self.watching.isRecording then
        -- Stop recording
        self.watching.isRecording = false
        lib.showTextUI(self:getTextUI(), { position = "bottom-center" })
        TriggerServerEvent("p_policejob/server/bodycam/stopRecording", self.watching.targetId)
        Bridge.Notify.showNotify(locale("bodycam_recording_stopped"), "inform")
    else
        -- Start recording
        local success = lib.callback.await("p_policejob/server/bodycam/startRecording", false, self.watching.targetId)
        if not success then
            return Bridge.Notify.showNotify(locale("bodycam_recording_failed_start"), "error")
        end

        self.watching.isRecording = true
        lib.showTextUI(self:getTextUI(), { position = "bottom-center" })
        Bridge.Notify.showNotify(locale("bodycam_recording_started"), "inform")
    end
end

-- Spawns two concurrent threads while watching:
--   Thread 1: input loop — disables controls, tracks camera heading, handles
--             exit (Space/key 73) and record-toggle (configured key)
--   Thread 2: proximity loop — every 2.5s teleports the hidden watcher ped
--             under the target if they drift >150 units apart; stops watching
--             if the target ped no longer exists (player disconnected)
function Bodycam:startWatchingThreads()
    local recordKey       = Config.Bodycam.Recording and Config.Bodycam.Recording.Key
    local recordingEnabled = Config.Bodycam.Recording and Config.Bodycam.Recording.Enabled or false
    local recordCooldown  = 500
    local lastRecordPress = 0

    -- Thread 1: input and camera heading
    CreateThread(function()
        lib.showTextUI(self:getTextUI(), { position = "bottom-center" })

        while self.watching.isActive do
            Wait(1)
            DisableAllControlActions(0)

            -- Keep camera aligned with the target ped's heading
            SetCamRot(self.watching.camera, 0, 0, GetEntityHeading(self.watching.targetPed), 2)

            -- Exit watching: Space (control 73)
            if IsControlJustPressed(0, 73) or IsDisabledControlJustPressed(0, 73) then
                self:stopWatching()
                break
            end

            -- Toggle recording (if enabled and key configured)
            if recordingEnabled and recordKey then
                if IsControlJustPressed(0, recordKey) or IsDisabledControlJustPressed(0, recordKey) then
                    local now = GetGameTimer()
                    if now - lastRecordPress > recordCooldown then
                        lastRecordPress = now
                        self:toggleRecording()
                    end
                end
            end
        end

        lib.hideTextUI()
    end)

    -- Thread 2: proximity — keep hidden ped under the target
    CreateThread(function()
        while self.watching.isActive do
            Wait(2500)

            if not self.watching.isActive then break end

            local targetPed = self.watching.targetPed

            if targetPed ~= cache.ped then
                if DoesEntityExist(targetPed) then
                    local watcherPos = GetEntityCoords(cache.ped)
                    local targetPos  = GetEntityCoords(targetPed)
                    local distance   = #(watcherPos - targetPos)

                    if distance > 150 then
                        -- Watcher ped drifted too far; snap it back below the target
                        SetEntityCoords(cache.ped, targetPos.x, targetPos.y, targetPos.z - 100.0,
                            false, false, false, true)
                    end
                end
            else
                -- Target ped handle equals our own ped — target has gone
                self:stopWatching()
            end
        end
    end)
end

-- Fetches the active bodycam list from the server, builds a context menu,
-- and shows it so the player can choose a feed to watch.
function Bodycam:openList()
    local camList = lib.callback.await("p_policejob/server/bodycam/fetchList", false)

    if not (camList and next(camList)) then
        return Bridge.Notify.showNotify(locale("no_active_bodycams"), "error")
    end

    local menuOptions = {}
    for serverId, camData in pairs(camList) do
        menuOptions[#menuOptions + 1] = {
            title       = locale("watch_bodycam_title", camData.name, camData.badge),
            description = locale("watch_bodycam_info",  camData.name, camData.badge),
            arrow       = true,
            onSelect    = function()
                self:startWatching(serverId)
            end,
        }
    end

    lib.registerContext({
        id      = "bodycam_list_menu",
        title   = locale("bodycam_list_menu"),
        options = menuOptions,
    })
    lib.showContext("bodycam_list_menu")
end

-- ─── Net Events ─────────────────────────────────────────────────────────────

-- Server → client: toggle the bodycam overlay (on/off) with optional data
RegisterNetEvent("p_policejob/client/bodycam/toggle", function(forceState, data)
    Bodycam:toggle(forceState, data)
end)

-- Server → client: the player being watched disconnected, force-exit the viewer
RegisterNetEvent("p_policejob/client/bodycam/forceStopWatching", function()
    if Bodycam.watching.isActive then
        Bridge.Notify.showNotify(locale("bodycam_target_disconnected"), "error")
        Bodycam:stopWatching()
    end
end)

-- Server → client: recording was uploaded successfully; copy URL to clipboard
RegisterNetEvent("p_policejob/client/bodycam/recordingUploaded", function(url)
    Bridge.Notify.showNotify(locale("bodycam_recording_uploaded"), "success")
    if url then
        lib.setClipboard(url)
    end
end)

-- Server → client: recording upload failed
RegisterNetEvent("p_policejob/client/bodycam/recordingFailed", function()
    Bridge.Notify.showNotify(locale("bodycam_recording_failed_upload"), "error")
end)

-- Hides/shows the bodycam overlay when the pause menu opens or closes
RegisterNetEvent("p_policejob:pauseMenuState", function(isPaused)
    if not Bodycam.isActive then return end
    SendNUIMessage({ action = "setVisibleBodycam", data = not isPaused })
end)

-- ─── Inventory Events ────────────────────────────────────────────────────────

-- ox_inventory: close the bodycam if the player loses their last body_cam item
AddEventHandler("ox_inventory:itemCount", function(itemName, count)
    if itemName == "body_cam" and count < 1 then
        if Bodycam.isActive then
            Bodycam:close()
        end
    end
end)

-- ─── Target Zones ────────────────────────────────────────────────────────────

-- After a short delay, register sphere target zones for each bodycam terminal
-- defined in Config.DepartmentData.bodycams
CreateThread(function()
    Citizen.Wait(2000)

    local bodycamLocations = Config.DepartmentData.bodycams or {}

    for zoneId, zoneData in pairs(bodycamLocations) do
        Bridge.Target.addSphereZone({
            coords     = zoneData.coords,
            radius     = zoneData.radius or 0.5,
            drawSprite = true,
            debug      = Bridge.Config and Bridge.Config.Debug,
            options    = {
                {
                    name     = "p_policejob:bodycam:watch_" .. zoneId,
                    label    = locale("check_bodycams"),
                    icon     = "fa-solid fa-video",
                    distance = zoneData.distance or 2,
                    groups   = Config.Jobs,
                    onSelect = function()
                        Bodycam:openList()
                    end,
                }
            },
        })
    end
end)
