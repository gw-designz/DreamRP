Main = {
    cameras            = {},
    peds               = {},
    characters         = {},
    currentScene       = nil,
    isOpen             = false,
    selectingCharacter = false,
    hoveredPed         = nil,
    pedLabelsDui       = nil,
    raycastBlocked     = false,
    unlockedSlots      = {},
    focusedSlot        = 1,
}

-- Log the resource version on boot.
do
    local version = GetResourceMetadata(GetCurrentResourceName(), "version", 0) or "?"
    Trace(("[bablo-multicharacter] client build v%s"):format(version))
end

-- Debug-only: log whenever the game's built-in recording starts or stops.
if Config.DEBUG and type(IsRecording) == "function" then
    CreateThread(function()
        local wasRecording = false
        while true do
            local ok, recording = pcall(IsRecording)
            if ok and recording ~= wasRecording then
                wasRecording = recording
                Trace(("[Main] game recording %s at %d"):format(
                    recording and "STARTED" or "STOPPED", GetGameTimer()))
            end
            Wait(500)
        end
    end)
end

-- ─── Camera helpers ──────────────────────────────────────────────────────────

-- Create a scripted camera from a scene camera descriptor and register it under name.
function Main:createCamera(name, camDesc)
    local cam = CreateCamWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        camDesc.coords.x, camDesc.coords.y, camDesc.coords.z,
        camDesc.rotation.x, camDesc.rotation.y, camDesc.rotation.z,
        camDesc.fov, false, 0
    )
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    table.insert(self.cameras, { name = name, camera = cam })
end

-- Return the camera handle registered under name, or nil.
function Main:getCamera(name)
    for _, entry in ipairs(self.cameras) do
        if entry.name == name then return entry.camera end
    end
end

-- Return the scene camera descriptor for the slot that owns pedHandle, or nil.
function Main:getSceneCamera(pedHandle)
    for i, char in ipairs(self.characters) do
        if char.pedHandle == pedHandle then
            return self.currentScene.scenes[i].camera
        end
    end
end

-- Return the camera offsets for the scene slot that owns pedHandle, or nil.
function Main:getCameraOffsets(pedHandle)
    local cam = self:getSceneCamera(pedHandle)
    return cam and cam.offsets
end

-- ─── Ped spawning ────────────────────────────────────────────────────────────

-- Freemode model hashes: female = -1667301416, male = 1885233650.
local FREEMODE_FEMALE = -1667301416
local FREEMODE_MALE   = 1885233650

-- Resolve the numeric model hash from a raw value that may be a string name,
-- numeric string, or integer. Returns nil if the value is unusable.
local function resolveModelHash(raw)
    if type(raw) == "string" then
        local n = tonumber(raw)
        if n then return n end
        return joaat(raw)
    end
    return tonumber(raw)
end

-- Attempt to load a model hash via CharFuncs.requestModel.
-- Returns the hash on success, nil on failure.
local function tryLoadModel(hash)
    if not hash or hash == 0 then return nil end
    if CharFuncs.requestModel(hash) then return hash end
    return nil
end

-- Spawn a showcase ped for the given slot index (1-based) using the character's
-- saved skin model, scene pedModel, or freemode fallback — in that priority order.
function Main:spawnPedForSlot(slotIndex)
    local charData  = self.characters[slotIndex]
    local sceneData = self.currentScene.scenes[slotIndex]
    if not charData or not sceneData then return end

    -- Determine sex for freemode fallback (1 = female, else male).
    local sex = (charData._skin and type(charData._skin.sex) == "number")
        and charData._skin.sex
        or charData.sex

    local freemodeHash = (sex == 1) and FREEMODE_FEMALE or FREEMODE_MALE

    -- 1. Try the skin's saved model.
    local modelHash
    if charData._skin and charData._skin.__model then
        local raw      = charData._skin.__model
        local resolved = resolveModelHash(raw)
        if resolved and resolved ~= 0 and IsModelInCdimage(resolved) and IsModelValid(resolved) then
            modelHash = resolved
        else
            Trace(("[Main:spawnPedForSlot] slot %d — saved model %s is invalid, using freemode fallback"):format(
                slotIndex, tostring(raw)))
        end
    end

    -- 2. Try the scene's pedModel (only for empty slots with no identifier).
    if not modelHash and not charData.identifier and sceneData.pedModel then
        local raw      = sceneData.pedModel
        local resolved = (type(raw) == "string") and joaat(raw) or raw
        if type(resolved) == "number" and resolved ~= 0
            and IsModelInCdimage(resolved) and IsModelValid(resolved) then
            modelHash = resolved
        else
            Trace(("[Main:spawnPedForSlot] slot %d — scene.pedModel %s is invalid, falling through to freemode"):format(
                slotIndex, tostring(raw)))
        end
    end

    -- 3. Freemode fallback with up to two retries (opposite sex as last resort).
    if not modelHash then
        modelHash = freemodeHash
    end

    if not tryLoadModel(modelHash) then
        Trace(("[Main:spawnPedForSlot] slot %d — model %s failed to load, falling back to freemode"):format(
            slotIndex, tostring(modelHash)))
        modelHash = freemodeHash
        if not tryLoadModel(modelHash) then
            -- Last-resort: opposite freemode.
            local lastResort = (sex == 1) and FREEMODE_MALE or FREEMODE_FEMALE
            Trace(("[Main:spawnPedForSlot] slot %d — freemode %s also failed, last-resort %s"):format(
                slotIndex, tostring(freemodeHash), tostring(lastResort)))
            modelHash = lastResort
            if not tryLoadModel(modelHash) then
                Trace(("[Main:spawnPedForSlot] slot %d — even the last-resort freemode failed, skipping slot"):format(slotIndex))
                return
            end
        end
    end

    local ped = CreatePed(4,
        modelHash,
        sceneData.coords.x, sceneData.coords.y, sceneData.coords.z, sceneData.coords.w,
        false, true)

    -- Studio slots float above the ocean; freezing keeps them standing idle.
    if sceneData.freeze then
        FreezeEntityPosition(ped, true)
    end

    NetworkSetEntityInvisibleToNetwork(ped, true)
    SetPedDiesWhenInjured(ped, false)
    TaskSetBlockingOfNonTemporaryEvents(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedEnableWeaponBlocking(ped, false)
    SetPedKeepTask(ped, true)
    SetPedConfigFlag(ped, 224, false)
    SetPedConfigFlag(ped, 122, false)
    SetPedConfigFlag(ped, 52,  true)
    SetEntityLoadCollisionFlag(ped, true)
    StopPedSpeaking(ped, true)
    SetEntityAlpha(ped, 255)
    SetModelAsNoLongerNeeded(modelHash)

    table.insert(self.peds, ped)
    charData.pedHandle = ped

    Citizen.Wait(150)
    if sceneData.animation then
        CharFuncs.playAnimation(ped, sceneData.animation)
    end

    if charData._skin then
        local ok, err = pcall(function() Appearance:Apply(ped, charData._skin) end)
        if not ok then
            Trace(("[Main:spawnPedForSlot] slot %d — Appearance:Apply error: %s"):format(
                slotIndex, tostring(err)))
        end
    end
end

-- Spawn peds for every slot and start a watchdog thread that re-spawns any ped
-- that disappears while the UI is open (up to 90 s).
function Main:spawnPeds()
    for i = 1, #self.characters do
        self:spawnPedForSlot(i)
    end

    CreateThread(function()
        local deadline = GetGameTimer() + 90000
        while self.isOpen and GetGameTimer() < deadline do
            Wait(5000)
            if not self.isOpen then return end

            local anyRecovered = false
            for i = 1, #self.characters do
                local char = self.characters[i]
                if char and char.pedHandle and not DoesEntityExist(char.pedHandle) then
                    self:spawnPedForSlot(i)
                    if char.pedHandle and DoesEntityExist(char.pedHandle) then
                        anyRecovered = true
                        Trace(("[Main:spawnPeds] retry recovered slot %d"):format(i))
                    end
                end
            end

            if anyRecovered and self.pedLabelsDui then
                self.pedLabelsDui:SetSlots(self:buildDuiSlots())
            end
        end
    end)
end

-- ─── Chat & misc helpers ─────────────────────────────────────────────────────

-- Enable or disable the chat resource export (silently skipped if chat isn't running).
local function setChatEnabled(enabled)
    if GetResourceState("chat") ~= "started" then return end
    pcall(function() exports.chat:setEnabled(enabled) end)
end

-- ─── Main.Init ───────────────────────────────────────────────────────────────

function Main:Init()
    if self.isOpen then return end
    self.isOpen = true

    setChatEnabled(false)

    -- Disable voice controls for the duration of the character select.
    CreateThread(function()
        while self.isOpen do
            DisableControlAction(0, 245, true)
            DisableControlAction(0, 246, true)
            DisableControlAction(0, 247, true)
            DisableControlAction(0, 248, true)
            Wait(0)
        end
    end)

    DoScreenFadeOut(0)

    if Config.RoutingBucket ~= nil and Config.RoutingBucket ~= false then
        lib.callback.await("bablo-multicharacter:server:enterBucket", false)
    end

    -- Resolve which slots the player has access to.
    local slotAccess = lib.callback.await("bablo-multicharacter:server:resolveSlotAccess", false)
    self.unlockedSlots = {}
    if type(slotAccess) == "table" and type(slotAccess.unlockedSlots) == "table" then
        for _, slotIdx in ipairs(slotAccess.unlockedSlots) do
            self.unlockedSlots[slotIdx] = true
        end
    end

    -- Pick a random scene location.
    local locations = Config.Locations
    self.currentScene = locations[math.random(1, #locations)]
    self.characters   = self:loadCharacters()

    Citizen.Wait(500)
    if self.currentScene.studio then
        -- Mid-air set: no ground collision to wait for, just hide and pin the player.
        local ped = PlayerPedId()
        local c   = self.currentScene.defaultCamera.coords
        SetEntityCoords(ped, c.x, c.y, c.z - 1.0)
        SetEntityVisible(ped, false)
        SetEntityAlpha(ped, 0)
        FreezeEntityPosition(ped, true)
    else
        CharFuncs.parkPlayer(self.currentScene.defaultCamera.coords)
    end

    -- Load interiors for each scene slot position.
    for _, scene in ipairs(self.currentScene.scenes) do
        local c = scene.coords
        RequestCollisionAtCoord(c.x, c.y, c.z)
        local interiorId = GetInteriorAtCoords(c.x, c.y, c.z)
        if interiorId and interiorId ~= 0 then
            SetInteriorActive(interiorId, true)
            RefreshInterior(interiorId)
            LoadInterior(interiorId)
        end
    end

    if self.currentScene.studio then
        StudioBackdrop:Start(self.currentScene)
    end

    Citizen.Wait(250)
    self:spawnPeds()

    -- Wait up to 30 s for the NUI to signal it has booted.
    local waitStart  = GetGameTimer()
    local nuiTimeout = waitStart + 30000
    while not self.uiBooted and GetGameTimer() < nuiTimeout do
        Wait(50)
    end

    local waitedMs = GetGameTimer() - waitStart
    if not self.uiBooted then
        Trace(("[Main:Init] NUI never booted after %dms — revealing anyway"):format(waitedMs))
    elseif waitedMs > 250 then
        Trace(("[Main:Init] held reveal %dms waiting for NUI boot"):format(waitedMs))
    end

    if Config.ShutdownLoadingScreen ~= false then
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
    end

    -- Create the close-up "character" camera aimed at the first slot.
    self:createCamera("character", self.currentScene.scenes[1].camera)

    -- Create the wide "default" overview camera with a zoom-in animation.
    local defaultCam     = self.currentScene.defaultCamera
    local targetFov      = defaultCam.fov
    local startFov       = targetFov * 0.6
    local overviewHandle = CreateCamWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        defaultCam.coords.x, defaultCam.coords.y, defaultCam.coords.z,
        defaultCam.rotation.x, defaultCam.rotation.y, defaultCam.rotation.z,
        startFov, false, 0
    )
    SetCamActive(overviewHandle, true)
    RenderScriptCams(true, false, 0, true, true)
    table.insert(self.cameras, { name = "default", camera = overviewHandle })

    -- Smoothly ease the FOV from startFov to targetFov over 3.5 s (smoothstep).
    Citizen.CreateThread(function()
        local animStart   = GetGameTimer()
        local animDuration = 3500
        while self.isOpen do
            local elapsed = GetGameTimer() - animStart
            if elapsed >= animDuration then break end
            local t = elapsed / animDuration
            local smooth = t * t * (3 - 2 * t)
            SetCamFov(overviewHandle, startFov + (targetFov - startFov) * smooth)
            Wait(0)
        end
        if self.isOpen and DoesCamExist(overviewHandle) then
            SetCamFov(overviewHandle, targetFov)
        end
    end)

    -- Push all NUI state.
    SendNUIMessage({ action = "SET_FADING",            data = true })
    SendNUIMessage({ action = "SET_VISIBLE",            data = true })
    SendNUIMessage({ action = "SET_PAGE",               data = "select" })
    SendNUIMessage({ action = "CLOSE_CHARACTER_DETAIL" })
    SendNUIMessage({ action = "HIDE_CLOTHING_TIMER" })
    SendNUIMessage({ action = "HIDE_WELCOME" })
    SendNUIMessage({ action = "CLOSE_PREMIUM_INFO" })

    local locale       = Config.Locale
    local translations = (Locales and Locales[locale]) or (Locales and Locales["en-US"]) or {}
    SendNUIMessage({ action = "SET_TRANSLATIONS", data = { locale = locale, translations = translations } })

    SendNUIMessage({ action = "SET_CHARACTERS",     data = self:exportCharacters() })
    SendNUIMessage({ action = "SET_SPAWN_POSITIONS", data = self:exportSpawnPositions() })

    Settings:Push()

    -- SetNuiFocus(true, true)     → NUI is active and the mouse cursor is visible.
    -- SetNuiFocusKeepInput(true)  → game ALSO receives all input simultaneously,
    --                               so IsDisabledControlJustPressed(0, 24) fires on click.
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)

    -- Global control lockdown: allow only attack (24) and jump/enter (176).
    CreateThread(function()
        while self.isOpen do
            DisableAllControlActions(0)
            EnableControlAction(0, 24,  true)
            EnableControlAction(0, 176, true)
            Wait(0)
        end
    end)

    -- Initialise ped name-label DUI.
    if not self.pedLabelsDui then
        self.pedLabelsDui = PedLabelsDui.new(PedLabelsDui)
    end
    self.pedLabelsDui:Init(#self.currentScene.scenes)
    self.pedLabelsDui:SetReferenceFov(self.currentScene.defaultCamera.fov)
    self.pedLabelsDui:SetSlots(self:buildDuiSlots())

    -- Initialise the server-logo DUI if configured.
    if Config.ServerLogo and Config.ServerLogo.enabled then
        if not self.logoDui then
            self.logoDui = LogoDui.new(LogoDui)
        end
        self.logoDui:Init(Config.ServerLogo)
    end

    DoScreenFadeIn(2000)
    -- Clear NUI fading flag 400 ms before the fade completes so the UI appears
    -- to arrive with the world rather than on top of a black screen.
    Citizen.SetTimeout(1600, function()
        SendNUIMessage({ action = "SET_FADING", data = false })
    end)

    self.selectingCharacter = true
    self:raycastLoop()
end

-- ─── Main.Destroy ────────────────────────────────────────────────────────────

function Main:Destroy()
    for _, entry in ipairs(self.cameras) do
        DestroyCam(entry.camera, false)
    end
    for _, ped in ipairs(self.peds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end

    RenderScriptCams(false, false, 0, true, true)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    if self.pedLabelsDui then self.pedLabelsDui:Destroy() end
    StudioBackdrop:Stop()
    if self.logoDui then
        self.logoDui:Destroy()
        self.logoDui = nil
    end

    self.cameras            = {}
    self.peds               = {}
    self.characters         = {}
    self.currentScene       = nil
    self.isOpen             = false
    self.selectingCharacter = false
    self.hoveredPed         = nil
    self.raycastBlocked     = false
    self.uiBooted           = false
    self.focusedSlot        = 1
    self.creatingSlot       = nil

    SendNUIMessage({ action = "SET_VISIBLE", data = false })
    setChatEnabled(true)

    -- Reset the one-shot guard so Init can run again if the player relogs
    -- or the server fires client:openUI. Without this reset, the flag stays
    -- true forever and the screen never reopens after the first session.
    initCalled = false

    TriggerEvent(eventName .. "client:multicharDestroyed")
end

-- ─── DUI slot helpers ────────────────────────────────────────────────────────

-- Build the descriptor array consumed by PedLabelsDui:SetSlots() from the
-- current characters and hoveredPed state.
function Main:buildDuiSlots()
    local slots  = {}
    local scenes = (self.currentScene and self.currentScene.scenes) or {}

    for i = 1, #scenes do
        local char = self.characters[i]
        if char and char.pedHandle then
            local duiScale = (scenes[i] and scenes[i].duiSize) or 1.0

            local label
            if char._locked then
                label = Translate("PREMIUM_SLOT")
            elseif char.identifier then
                label = char.firstname .. " " .. char.lastname
            else
                label = Translate("CREATE_CHARACTER_DUI")
            end

            slots[i] = {
                pedHandle = char.pedHandle,
                name      = label,
                empty     = not char.identifier,
                locked    = char._locked == true,
                hovered   = char.pedHandle == self.hoveredPed,
                duiScale  = duiScale,
            }
        else
            slots[i] = false
        end
    end

    return slots
end

-- ─── Head-position utilities ─────────────────────────────────────────────────

-- Returns the 2-D screen coords (sx, sy) of the point just above pedHandle's
-- head, or nil, nil if the point is off-screen.
function Main:projectPedHeadAbove(pedHandle)
    local boneIdx = GetPedBoneIndex(pedHandle, 31086)
    local wx, wy, wz

    if boneIdx and boneIdx ~= -1 then
        local bp = GetWorldPositionOfEntityBone(pedHandle, boneIdx)
        if bp and not (bp.x == 0.0 and bp.y == 0.0 and bp.z == 0.0) then
            wx, wy, wz = bp.x, bp.y, bp.z + 0.4
        end
    end

    if not wx then
        local p = GetEntityCoords(pedHandle)
        wx, wy, wz = p.x, p.y, p.z + 1.0
    end

    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(wx, wy, wz)
    if not onScreen then return nil, nil end
    return sx, sy
end

-- Get the head bone world position used for camera targeting (z+0.65 fallback).
local function getPedHeadForCamera(pedHandle)
    local boneIdx = GetPedBoneIndex(pedHandle, 31086)
    local hx, hy, hz

    if boneIdx and boneIdx ~= -1 then
        local bp = GetWorldPositionOfEntityBone(pedHandle, boneIdx)
        if bp and not (bp.x == 0.0 and bp.y == 0.0 and bp.z == 0.0) then
            hx, hy, hz = bp.x, bp.y, bp.z
        end
    end

    if not hx then
        local p = GetEntityCoords(pedHandle)
        hx, hy, hz = p.x, p.y, p.z + 0.65
    end

    return hx, hy, hz
end

-- Close-up camera pose for pedHandle: `distance` metres in front of the head,
-- lowered by offsets, and slid `aside` metres toward the ped's right so the
-- ped sits right of frame (leaving room for the detail sheet on the left).
-- Returns camX, camY, camZ, aimX, aimY, aimZ.
function Main:characterCamPose(pedHandle)
    local hx, hy, hz = getPedHeadForCamera(pedHandle)
    local forward    = GetEntityForwardVector(pedHandle)
    local sceneCam   = self:getSceneCamera(pedHandle) or {}
    local offsets    = sceneCam.offsets  or vector3(0.0, 0.0, 0.35)
    local distance   = sceneCam.distance or 2.0
    local aside      = sceneCam.aside    or 0.0
    local rx, ry     = forward.y, -forward.x

    return hx + forward.x * distance - offsets.x + rx * aside,
           hy + forward.y * distance - offsets.y + ry * aside,
           hz - offsets.z,
           hx + rx * aside,
           hy + ry * aside,
           hz - 0.1
end

-- ─── Raycast / hover / click loop ────────────────────────────────────────────

function Main:raycastLoop()
    self.hoveredPed = nil

    -- Per-frame control lockdown thread (allows only attack + jump/enter).
    Citizen.CreateThread(function()
        while self.isOpen do
            CharFuncs.disableActionsOneFrame()
            Citizen.Wait(0)
        end
        EnableAllControlActions(0)
    end)

    -- DUI label sync thread: rebuilds slots every 500 ms while visible so peds
    -- that finish spawning after the initial SetSlots call get their labels immediately.
    Citizen.CreateThread(function()
        local labelsVisible    = false
        local lastRebuildTime  = 0
        local REBUILD_INTERVAL = 500

        while self.isOpen do
            local shouldShow = self.pedLabelsDui
                and self.selectingCharacter
                and not self.raycastBlocked

            if shouldShow then
                local now = GetGameTimer()
                if not labelsVisible or (now - lastRebuildTime) >= REBUILD_INTERVAL then
                    self.pedLabelsDui:SetSlots(self:buildDuiSlots())
                    labelsVisible   = true
                    lastRebuildTime = now
                else
                    self.pedLabelsDui:SetHovered(self.hoveredPed)
                end
            elseif labelsVisible then
                self.pedLabelsDui:SetSlots({})
                labelsVisible   = false
                lastRebuildTime = 0
            end

            Citizen.Wait(0)
        end
    end)

    -- Hover/click thread: projects each ped to screen space each frame and
    -- checks whether the cursor is within hitRadius of any of them.
    -- This replaces the broken custom raycast which used incorrect camera basis
    -- vectors and never produced a ray that pointed at the actual cursor position.
    Citizen.CreateThread(function()
        while self.isOpen do
            if self.selectingCharacter and not self.raycastBlocked then
                -- Build a flat list of ped handles for CharFuncs.findHoveredPed.
                local pedHandles = {}
                for _, char in ipairs(self.characters) do
                    if char.pedHandle and DoesEntityExist(char.pedHandle) then
                        pedHandles[#pedHandles + 1] = char.pedHandle
                    end
                end

                local hoveredHandle = CharFuncs.findHoveredPed(pedHandles)

                if not hoveredHandle then
                    -- No mouse hover: keep highlighting the keyboard-focused slot.
                    local focused = self.characters[self.focusedSlot or 0]
                    self.hoveredPed = focused and focused.pedHandle or nil
                else
                    self.hoveredPed = hoveredHandle

                    -- Tell the NUI which slot the mouse moved onto so its
                    -- bottom bar / arrow navigation follows the cursor.
                    for i, char in ipairs(self.characters) do
                        if char.pedHandle == hoveredHandle and self.focusedSlot ~= i then
                            self.focusedSlot = i
                            SendNUIMessage({ action = "HOVER_SLOT", data = { slot = i } })
                            break
                        end
                    end

                    -- Mouse click only; Enter is handled by the NUI (PICK_SLOT)
                    -- so a keypress never selects twice.
                    local clicked = IsDisabledControlJustPressed(0, 24)

                    if clicked then
                        -- Find the character record for the hovered ped.
                        for _, char in ipairs(self.characters) do
                            if char.pedHandle == hoveredHandle then
                                self:onPedClicked(char)
                                break
                            end
                        end
                    end
                end
            else
                self.hoveredPed = nil
            end

            Citizen.Wait(0)
        end
    end)
end

-- ─── Camera interp helpers ───────────────────────────────────────────────────

-- Move and aim the "character" camera at pedHandle's head, interpolate from
-- the "default" camera, wait 1.5 s, then return true. Returns false on error.
function Main:interpCamToPedHead(pedHandle)
    if not DoesEntityExist(pedHandle) then return false end

    local camX, camY, camZ, aimX, aimY, aimZ = self:characterCamPose(pedHandle)

    local charCam = self:getCamera("character")
    if not charCam then return false end

    SetCamCoord(charCam, camX, camY, camZ)
    PointCamAtCoord(charCam, aimX, aimY, aimZ)
    SetCamActiveWithInterp(charCam, self:getCamera("default"), 1500, true, true)
    Citizen.Wait(1500)
    return true
end

-- Interp the "default" camera back from "character" and re-enable selection.
function Main:unSelectCharacter()
    SetCamActiveWithInterp(self:getCamera("default"), self:getCamera("character"), 1500, true, true)
    Citizen.Wait(1500)
    -- Reset raycastBlocked: the NUI sends BLOCK_RAYCAST{true} when the detail
    -- panel opens. If it doesn't send {false} before UNSELECT_CHARACTER fires,
    -- the hover/click loop stays blocked and no character can be selected again.
    self.raycastBlocked     = false
    self.selectingCharacter = true
    -- Rebuild DUI slot state so name-label hover tracking resumes correctly.
    if self.pedLabelsDui then
        self.pedLabelsDui:SetSlots(self:buildDuiSlots())
    end
    SendNUIMessage({ action = "CLOSE_CHARACTER_DETAIL" })
end

-- ─── Ped click handler ───────────────────────────────────────────────────────

function Main:onPedClicked(char)
    if char._locked then
        SendNUIMessage({ action = "OPEN_PREMIUM_INFO", data = { slotIndex = char._slotIndex } })
        return
    end

    self.selectingCharacter = false

    if not DoesEntityExist(char.pedHandle) then
        Trace("onPedClicked: ped does not exist, aborting")
        self.selectingCharacter = true
        return
    end

    Trace(("[Main] ped clicked at %d"):format(GetGameTimer()))
    SendNUIMessage({ action = "BEGIN_TRANSITION" })

    -- Empty slots render as a silhouette (client/studio.lua); show the real
    -- ped for the slot being created so body selection previews the model.
    if not char.identifier then
        self.creatingSlot = char._slotIndex
    end

    if not self:interpCamToPedHead(char.pedHandle) then
        self.selectingCharacter = true
        return
    end

    if char.identifier then
        Trace(("[Main] OPEN_CHARACTER_DETAIL sent at %d"):format(GetGameTimer()))
        SendNUIMessage({ action = "OPEN_CHARACTER_DETAIL", data = self:exportCharacter(char) })
    else
        SendNUIMessage({ action = "OPEN_CREATE_CHARACTER" })
    end
end

-- ─── Control blocking ────────────────────────────────────────────────────────

-- Block all controls except attack (24) and jump/enter (176) for durationMs
-- milliseconds (default 4000). Returns a release callback that can be called
-- early to stop the block.
function blockControls(durationMs)
    local active = true

    CreateThread(function()
        while active do
            DisableAllControlActions(0)
            EnableControlAction(0, 24,  true)
            EnableControlAction(0, 176, true)
            Wait(0)
        end
    end)

    SetTimeout(durationMs or 4000, function() active = false end)

    return function() active = false end
end

-- ─── Shared spawn/load helpers ───────────────────────────────────────────────

function notifyPlayerLoaded()
    Framework:NotifyPlayerLoaded()
end

-- Block until the screen is fully faded out or timeoutMs elapses (default 1500).
function waitForBlackScreen(timeoutMs)
    if not timeoutMs then timeoutMs = 1500 end
    local deadline = GetGameTimer() + timeoutMs
    while not IsScreenFadedOut() and GetGameTimer() < deadline do
        Citizen.Wait(0)
    end
end

-- Request collision at coords and wait for both collision and scene load,
-- or until timeoutMs elapses (default 3000).
function waitForWorldReady(ped, coords, timeoutMs)
    if not timeoutMs then timeoutMs = 3000 end
    local deadline = GetGameTimer() + timeoutMs
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    NewLoadSceneStart(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 50.0, 0)
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        local colReady = HasCollisionLoadedAroundEntity(ped)
            and not IsEntityWaitingForWorldCollision(ped)
        if colReady and IsNewLoadSceneLoaded() then break end
        Citizen.Wait(50)
    end
    NewLoadSceneStop()
end

-- ─── Character creation flow ─────────────────────────────────────────────────

function Main:cancelCreate()
    SetCamActiveWithInterp(self:getCamera("default"), self:getCamera("character"), 1500, true, true)
    Citizen.Wait(1500)
    self.creatingSlot       = nil
    self.raycastBlocked     = false
    self.selectingCharacter = true
    -- Rebuild DUI slot state so name-label hover tracking resumes correctly.
    if self.pedLabelsDui then
        self.pedLabelsDui:SetSlots(self:buildDuiSlots())
    end
    SendNUIMessage({ action = "CLOSE_CREATE_CHARACTER" })
end

-- Called by web.lua after Framework.CreateCharacter succeeds.
-- charFormData = the submitted form; charRecord = the created character record.
function Main:submitCreate(charFormData, charRecord)
    if not charRecord then
        self:cancelCreate()
        return
    end
    self:runCreateFlow(charFormData, charRecord)
end

-- Full post-creation flow: fade out, set player model, handle housing integration,
-- show welcome banner, open clothing editor.
function Main:runCreateFlow(charFormData, charRecord)
    SendNUIMessage({ action = "SET_FADING", data = true })
    DoScreenFadeOut(500)
    waitForBlackScreen(1500)

    self:Destroy()

    if Config.RoutingBucket ~= nil and Config.RoutingBucket ~= false then
        lib.callback.await("bablo-multicharacter:server:leaveBucket", false)
    end

    local releaseControls = blockControls(10000)
    local postCreate      = Config.PostCreate or {}
    local spawnCfg        = Config.SpawnCoords

    -- Optional: teleport the new ped to SpawnCoords before applying model.
    if postCreate.TeleportToSpawn and spawnCfg and spawnCfg.coords then
        SetEntityCoordsNoOffset(PlayerPedId(),
            spawnCfg.coords.x, spawnCfg.coords.y, spawnCfg.coords.z,
            false, false, false)
    end

    -- Set gender-appropriate freemode model.
    local isFemale   = charFormData and charFormData.gender == "Female"
    local modelHash  = isFemale and FREEMODE_FEMALE or FREEMODE_MALE

    if CharFuncs.requestModel(modelHash) then
        SetPlayerModel(PlayerId(), modelHash)
        SetModelAsNoLongerNeeded(modelHash)
    else
        Trace(("[Main:runCreateFlow] failed to load model %s — opening clothing on whatever ped is present"):format(tostring(modelHash)))
    end

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)

    -- Apply SpawnCoords position and heading after model swap.
    if postCreate.TeleportToSpawn and spawnCfg and spawnCfg.coords then
        SetEntityCoordsNoOffset(ped,
            spawnCfg.coords.x, spawnCfg.coords.y, spawnCfg.coords.z,
            false, false, false)
        SetEntityHeading(ped, spawnCfg.heading or 0.0)
    end

    SetEntityVisible(ped, true)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityAlpha(ped, 255)
    SetEntityInvincible(ped, true)

    notifyPlayerLoaded()
    Citizen.Wait(300)

    -- ── Housing integration ──
    -- Known apartment resources that provide their own spawn UI.
    local apartmentResources = { "qb-apartments", "qbx_apartments", "qbx-apartments", "qb-spawn" }

    local function findRunningApartmentResource()
        for _, res in ipairs(apartmentResources) do
            if IsResourceStartedOrStarting(res) then return res end
        end
    end

    local housingIntegrations = { ["qb-houses"] = true, ["qbx-apartments"] = true }
    local housingEnabled      = housingIntegrations[Config.Housing or ""]

    if housingEnabled then
        local apartmentRes = findRunningApartmentResource()
        if apartmentRes then
            -- Build charinfo payload, normalising firstName/firstname variants.
            local firstName = (charFormData and (charFormData.firstName or charFormData.firstname)) or ""
            local lastName  = (charFormData and (charFormData.lastName  or charFormData.lastname))  or ""
            local charinfo  = { firstname = firstName, lastname = lastName }
            local citizenid = charRecord or ""
            local payload   = { citizenid = citizenid, charinfo = charinfo }

            if IsResourceStartedOrStarting("qb-apartments") then
                TriggerEvent("apartments:client:setupSpawnUI", payload)
            elseif IsResourceStartedOrStarting("qb-spawn") then
                TriggerEvent("qb-spawn:client:setupSpawns", payload, false, nil)
                TriggerEvent("qb-spawn:client:openUI", true)
            end

            Citizen.Wait(200)
            DoScreenFadeIn(1500)
            ped = PlayerPedId()
            FreezeEntityPosition(ped, false)
            SetEntityInvincible(ped, false)
            releaseControls()
            return
        end
    end

    -- ── Standard post-create flow ──

    -- Anchor guard: if TeleportToSpawn is set, push the ped back to spawn coords
    -- for up to 15 s while the welcome banner displays, in case the server moves it.
    local anchorActive = false
    if postCreate.TeleportToSpawn and spawnCfg and spawnCfg.coords then
        anchorActive = true
        CreateThread(function()
            local target   = vector3(spawnCfg.coords.x, spawnCfg.coords.y, spawnCfg.coords.z)
            local deadline = GetGameTimer() + 15000
            while anchorActive and GetGameTimer() < deadline do
                local p = PlayerPedId()
                if #(GetEntityCoords(p) - target) > 5.0 then
                    SetEntityCoordsNoOffset(p, target.x, target.y, target.z, false, false, false)
                    SetEntityHeading(p, spawnCfg.heading or 0.0)
                end
                Wait(100)
            end
        end)
    end

    -- Intro cinematic camera sequence (3 cams, ~4.5 s total).
    -- ⚠️ Camera positions are all relative to the local player ped using
    -- GetOffsetFromEntityInWorldCoords. The total duration passed in controls the
    -- interp timing; changing it will affect the feel of the intro.
    waitForWorldReady(PlayerPedId(), spawnCfg and spawnCfg.coords or GetEntityCoords(PlayerPedId()))

    -- Build welcome name string (UPPER CASE, trimmed).
    local firstName = (charFormData and (charFormData.firstName or charFormData.firstname)) or ""
    local lastName  = (charFormData and (charFormData.lastName  or charFormData.lastname))  or ""
    local fullName  = (firstName .. " " .. lastName):gsub("^%s+", ""):gsub("%s+$", ""):upper()

    SendNUIMessage({ action = "SHOW_WELCOME", data = { name = fullName } })
    Citizen.Wait(200)
    DoScreenFadeIn(1500)
    Citizen.Wait(5300)

    -- Guided tutorial cards, if the player picked "View Tutorial" on creation.
    if charFormData and charFormData.tutorial == true then
        self:runTutorial()
    end

    -- Wait for collision before unfreezing.
    ped = PlayerPedId()
    if postCreate.TeleportToSpawn and spawnCfg and spawnCfg.coords then
        local colDeadline = GetGameTimer() + 3000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < colDeadline do
            RequestCollisionAtCoord(spawnCfg.coords.x, spawnCfg.coords.y, spawnCfg.coords.z)
            Wait(0)
        end
    end

    anchorActive = false
    FreezeEntityPosition(ped, false)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    Citizen.Wait(300)
    SetEntityInvincible(ped, false)
    releaseControls()

    -- Optional clothing timer before opening the appearance editor.
    if postCreate.UseClothingTimer then
        local timerMs = postCreate.ClothingTimerMs or 10000
        SendNUIMessage({ action = "SHOW_CLOTHING_TIMER", data = { durationMs = timerMs } })
        Citizen.Wait(timerMs)
        SendNUIMessage({ action = "HIDE_CLOTHING_TIMER" })
    end

    Appearance:OpenEditor()
end

-- ─── Tutorial ────────────────────────────────────────────────────────────────

-- Shows Config.Tutorial.steps one card at a time. NUI focus is already released
-- at this point, so Enter (191) / Backspace (194) are read from game controls
-- and forwarded to the NUI. Blocks until the last card is dismissed.
function Main:runTutorial()
    local steps = (Config.Tutorial and Config.Tutorial.steps) or {}
    if #steps == 0 then return end

    SendNUIMessage({ action = "SHOW_TUTORIAL", data = { steps = steps } })

    local index    = 1
    local deadline = GetGameTimer() + 5 * 60000
    while index <= #steps and GetGameTimer() < deadline do
        DisableAllControlActions(0)
        if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then
            index = index + 1
            SendNUIMessage({ action = "TUTORIAL_STEP", data = { index = index } })
        elseif IsDisabledControlJustPressed(0, 194) and index > 1 then
            index = index - 1
            SendNUIMessage({ action = "TUTORIAL_STEP", data = { index = index } })
        end
        Wait(0)
    end

    SendNUIMessage({ action = "HIDE_TUTORIAL" })
end

-- ─── Character switching ──────────────────────────────────────────────────────

-- Called when the player selects a different character from the detail panel
-- while already logged in. Creates a snapshot camera at the current "character"
-- cam position, interpols to the existing "character" cam, then destroys the temp.
function Main:switchToCharacter(identifier)
    if not self.isOpen or not self.currentScene then return end

    -- Find the character record by identifier.
    local char
    for _, c in ipairs(self.characters) do
        if c.identifier == identifier then char = c; break end
    end
    if not char or not char.pedHandle or not DoesEntityExist(char.pedHandle) then return end

    local charCam = self:getCamera("character")
    if not charCam then return end

    -- Snapshot the current camera state and create a temp cam there.
    local camPos = GetCamCoord(charCam)
    local camRot = GetCamRot(charCam, 2)
    local camFov = GetCamFov(charCam)
    local snapCam = CreateCamWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        camPos.x, camPos.y, camPos.z,
        camRot.x, camRot.y, camRot.z,
        camFov, false, 0
    )
    SetCamActive(snapCam, true)

    -- Aim the "character" cam at the new ped.
    local camX, camY, camZ, aimX, aimY, aimZ = self:characterCamPose(char.pedHandle)
    SetCamCoord(charCam, camX, camY, camZ)
    PointCamAtCoord(charCam, aimX, aimY, aimZ)

    SetCamActiveWithInterp(charCam, snapCam, 1200, true, true)
    SetTimeout(1500, function()
        if DoesCamExist(snapCam) then DestroyCam(snapCam, false) end
    end)
end

-- ─── refreshCast ─────────────────────────────────────────────────────────────

-- Called after a character is deleted. Removes the deleted ped, resets that slot
-- to an empty character, respawns the showcase ped, then refreshes the NUI.
function Main:refreshCast(identifier)
    if not self.isOpen or not self.currentScene then return end

    -- Find the slot index for this identifier.
    local slotIndex
    for i, char in ipairs(self.characters) do
        if char.identifier == identifier then slotIndex = i; break end
    end

    if not slotIndex then
        Trace(("[Main:refreshCast] no slot found for identifier=%s"):format(tostring(identifier)))
        return
    end

    SendNUIMessage({ action = "SET_FADING",            data = true })
    SendNUIMessage({ action = "CLOSE_CHARACTER_DETAIL" })
    DoScreenFadeOut(400)
    waitForBlackScreen(1200)

    -- Reset camera to default (wide) view.
    -- Must activate default THEN deactivate character, then re-render,
    -- otherwise the scripted camera system has no active cam and the view freezes.
    local defaultCam    = self:getCamera("default")
    local characterCam  = self:getCamera("character")
    if defaultCam   then SetCamActive(defaultCam,   true)  end
    if characterCam then SetCamActive(characterCam, false) end
    RenderScriptCams(true, false, 0, true, true)

    -- Delete the ped for the deleted slot.
    local oldChar = self.characters[slotIndex]
    if oldChar and oldChar.pedHandle and DoesEntityExist(oldChar.pedHandle) then
        for i, ped in ipairs(self.peds) do
            if ped == oldChar.pedHandle then
                table.remove(self.peds, i)
                break
            end
        end
        DeleteEntity(oldChar.pedHandle)
    end

    -- Determine whether this slot is locked.
    local scene = self.currentScene.scenes[slotIndex]
    local isLocked = scene and scene.locked and not self.unlockedSlots[slotIndex]

    self.characters[slotIndex] = {
        identifier  = false,
        sex         = 0,
        _locked     = isLocked or false,
        _slotIndex  = slotIndex,
    }

    self:spawnPedForSlot(slotIndex)

    if self.pedLabelsDui then
        self.pedLabelsDui:SetSlots(self:buildDuiSlots())
    end

    SendNUIMessage({ action = "SET_CHARACTERS", data = self:exportCharacters() })

    Citizen.Wait(500)
    DoScreenFadeIn(800)
    Citizen.SetTimeout(400, function()
        SendNUIMessage({ action = "SET_FADING", data = false })
    end)

    self.selectingCharacter = true
end

-- ─── Character data helpers ───────────────────────────────────────────────────

-- Collect custom field values from a character record according to the configured
-- field descriptors. formatFn converts each raw value (tostring for fields, tonumber for money).
local function collectCustomFields(charData, fieldDescs, formatFn)
    local out = {}
    if type(fieldDescs) ~= "table" then return out end
    for _, desc in ipairs(fieldDescs) do
        if desc and desc.enabled ~= false and desc.kind == "custom" and desc.id then
            if type(desc.fetch) == "function" then
                local ok, val = pcall(desc.fetch, charData)
                if ok and val ~= nil then
                    out[desc.id] = formatFn(val)
                end
            end
        end
    end
    return out
end

-- Normalise a raw character record from the Framework into the shape expected
-- by the NUI. Used both for the character list and the detail panel.
local function normaliseCharRecord(raw)
    return {
        identifier     = raw.id,
        firstname      = raw.firstname,
        lastname       = raw.lastname,
        gender         = raw.gender,
        dob            = raw.dob,
        cash           = raw.cash,
        bank           = raw.bank,
        playtimeMinutes = raw.playtimeMinutes,
        sex            = (raw.gender == "Female") and 1 or 0,
        job            = raw.job,
        jobLabel       = raw.jobLabel,
        jobGrade       = raw.jobGrade,
        bio            = raw.bio,
        lastLocation   = raw.lastLocation,
        _skin          = raw._skin,
        houses         = raw.houses,
    }
end

-- Build the NUI-facing export for a single character slot (used for the detail panel).
function Main:exportCharacter(charData)
    local charDetail = Config.CharacterDetail or {}

    -- Resolve display name.
    local displayName
    if charData.identifier then
        local first = charData.firstname or ""
        local last  = charData.lastname  or ""
        displayName = (first .. " " .. last):gsub("^%s+", ""):gsub("%s+$", "")
        if displayName == "" then displayName = "Character" end
    else
        displayName = Translate("CREATE_NEW")
    end

    -- Resolve last location (plain x/y/z table).
    local lastLocation
    if charData.lastLocation then
        lastLocation = {
            x = charData.lastLocation.x,
            y = charData.lastLocation.y,
            z = charData.lastLocation.z,
        }
    end

    -- Resolve houses (filter to those with coords).
    local houses
    if type(charData.houses) == "table" and #charData.houses > 0 then
        houses = {}
        for _, h in ipairs(charData.houses) do
            if h and h.coords then
                houses[#houses + 1] = {
                    name   = h.name,
                    label  = h.label,
                    coords = { x = h.coords.x, y = h.coords.y, z = h.coords.z },
                }
            end
        end
        if #houses == 0 then houses = nil end
    end

    local customFields = collectCustomFields(charData, charDetail.fields, tostring)
    local customMoney  = collectCustomFields(charData, charDetail.money,  function(v)
        return tonumber(v) or 0
    end)

    return {
        id              = charData.identifier or false,
        name            = displayName,
        gender          = charData.gender,
        dob             = charData.dob,
        cash            = charData.cash,
        bank            = charData.bank,
        playtimeMinutes = charData.playtimeMinutes,
        job             = charData.job,
        jobLabel        = charData.jobLabel,
        jobGrade        = charData.jobGrade,
        bio             = charData.bio,
        lastLocation    = lastLocation,
        houses          = houses,
        customFields    = customFields,
        customMoney     = customMoney,
        locked          = charData._locked == true,
    }
end

-- Build the full characters export array for SET_CHARACTERS.
function Main:exportCharacters()
    local out = {}
    for _, char in ipairs(self.characters) do
        table.insert(out, self:exportCharacter(char))
    end
    return out
end

-- Build the spawn positions array for SET_SPAWN_POSITIONS.
-- Normalises both jobs (array) and job (single string) fields; validates hex color.
function Main:exportSpawnPositions()
    local out = {}
    for _, pos in ipairs(Config.SpawnPositions or {}) do
        local entry = {
            label       = pos.label,
            icon        = pos.icon,
            description = pos.description,
            image       = pos.image,
            coords = { x = pos.coords.x, y = pos.coords.y, z = pos.coords.z },
        }

        if type(pos.jobs) == "table" then
            entry.jobs = pos.jobs
        elseif type(pos.job) == "string" then
            entry.jobs = { pos.job }
        end

        if type(pos.color) == "string" and pos.color:match("^#%x%x%x%x%x%x$") then
            entry.color = pos.color
        end

        out[#out + 1] = entry
    end
    return out
end

-- ─── Character loading ────────────────────────────────────────────────────────

-- Fetch characters from the Framework and map them into slots defined by the scene.
-- Slots marked as locked (and not in unlockedSlots) get a placeholder _locked entry.
-- Extra slots beyond the character list get empty placeholder entries.
function Main:loadCharacters()
    local sceneCount = #self.currentScene.scenes
    local rawChars   = Framework:GetCharactersSync() or {}

    -- Flatten to a simple indexed list.
    local charList = {}
    for _, raw in ipairs(rawChars) do
        charList[#charList + 1] = normaliseCharRecord(raw)
    end

    local slots    = {}
    local charIdx  = 1

    for slotIndex = 1, sceneCount do
        local scene    = self.currentScene.scenes[slotIndex]
        local isLocked = scene and scene.locked and not self.unlockedSlots[slotIndex]

        local entry
        if isLocked then
            entry = { identifier = false, sex = 0, _locked = true }
        elseif charList[charIdx] then
            entry    = charList[charIdx]
            charIdx  = charIdx + 1
        else
            entry = { identifier = false, sex = 0 }
        end

        entry._slotIndex = slotIndex
        slots[#slots + 1] = entry
    end

    return slots
end

-- ─── Bootstrap ───────────────────────────────────────────────────────────────

-- Guard against Init running more than once (e.g. playerSpawned fires twice).
local initCalled = false

-- Wait for known framework resources before starting, then call Init.
local function waitForFrameworkAndInit()
    if initCalled then return end
    initCalled = true

    DoScreenFadeOut(0)

    local frameworkResources = { "qbx_core", "qb-core", "es_extended" }
    local deadline           = GetGameTimer() + 15000
    while GetGameTimer() < deadline do
        for _, res in ipairs(frameworkResources) do
            if GetResourceState(res) == "started" then goto frameworkReady end
        end
        Citizen.Wait(100)
    end
    ::frameworkReady::

    Citizen.Wait(2000)

    -- ShutdownLoadingScreen is called inside Main:Init() — calling it here
    -- as well caused a double-call on every initial load. Removed.
    Main:Init()
end

-- Wait until the player is network-active before attempting Init.
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Citizen.Wait(100)
    end
    waitForFrameworkAndInit()
end)

AddEventHandler("playerSpawned", function()
    waitForFrameworkAndInit()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Main:Destroy()
    end
end)

RegisterNetEvent(eventName .. "client:openUI")
AddEventHandler(eventName .. "client:openUI", function()
    if not Main.isOpen then Main:Init() end
end)

RegisterNetEvent(eventName .. "client:closeUI")
AddEventHandler(eventName .. "client:closeUI", function()
    Main:Destroy()
end)

-- client:prepareRelog: fired by the server relog command BEFORE LogoutCharacter.
-- Fades the screen to black and releases all controls so the player can't move
-- while the framework is tearing down the character. If the multichar UI is somehow
-- still open, Destroy() it first so Init() can run cleanly afterwards.
RegisterNetEvent(eventName .. "client:prepareRelog")
AddEventHandler(eventName .. "client:prepareRelog", function()
    -- If the UI is somehow still open, tear it down cleanly first.
    if Main.isOpen then
        Main:Destroy()
    end

    -- Fade to black immediately so the player sees a clean transition.
    DoScreenFadeOut(300)

    -- Disable all controls for up to 10 s while we wait for the server
    -- to finish logout and fire client:openUI. blockControls() is used
    -- so the lock is automatically released if something goes wrong.
    blockControls(10000)

    -- Freeze and hide the player ped during the transition.
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    SetEntityAlpha(ped, 0)
end)

-- client:cancelRelog: fired by the server if LogoutCharacter fails.
-- Restores the player to a playable state.
RegisterNetEvent(eventName .. "client:cancelRelog")
AddEventHandler(eventName .. "client:cancelRelog", function()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    SetEntityAlpha(ped, 255)
    DoScreenFadeIn(500)
end)