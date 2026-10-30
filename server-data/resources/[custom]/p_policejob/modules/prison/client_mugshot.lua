if not (Config and Config.Prison and Config.Prison.Enabled) then return end
if not Config.Prison.Mugshot.enabled then return end

-- ─── Module State ────────────────────────────────────────────────────────────

local mugshotCam     = nil     -- scripted camera handle
local isBusy         = false   -- prevents re-entrancy
local boardEntity    = nil     -- mugshot board object
local signEntity     = nil     -- mugshot sign object
local renderThreadActive = false
local spawnedPeds    = {}      -- NPC peds for the mugshot scene

-- ─── NPC Scene Peds ─────────────────────────────────────────────────────────

-- Spawns all NPC peds defined in the mugshot map config
local function SpawnMugshotPeds(pedsConfig)
    if not (pedsConfig and #pedsConfig > 0) then return end

    for _, pedCfg in ipairs(pedsConfig) do
        local modelHash = type(pedCfg.model) == "string" and joaat(pedCfg.model) or pedCfg.model
        lib.requestModel(modelHash)

        local coords = pedCfg.coords
        local ped    = CreatePed(4, modelHash,
            coords.x, coords.y, coords.z - 1.0,
            coords.w or 0.0,
            false, false
        )

        SetEntityAsMissionEntity(ped, true, true)
        SetPedFleeAttributes(ped, 0, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        SetPedConfigFlag(ped, 32, true)
        FreezeEntityPosition(ped, true)

        if pedCfg.anim and pedCfg.anim.dict and pedCfg.anim.clip then
            lib.requestAnimDict(pedCfg.anim.dict)
            TaskPlayAnim(ped, pedCfg.anim.dict, pedCfg.anim.clip,
                8.0, -8.0, -1, pedCfg.anim.flag or 1, 0, false, false, false)
        end

        SetModelAsNoLongerNeeded(modelHash)
        spawnedPeds[#spawnedPeds + 1] = ped
    end
end

-- Deletes all spawned scene peds
local function DeleteMugshotPeds()
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    spawnedPeds = {}
end

-- ─── Scaleform Helpers ───────────────────────────────────────────────────────

-- Requests a scaleform movie and blocks until loaded
local function LoadScaleformMovie(name)
    local handle = RequestScaleformMovie(name)
    while not HasScaleformMovieLoaded(handle) do Wait(0) end
    return handle
end

-- Registers and links a named render target; returns its render id
local function SetupNamedRenderTarget(targetName, modelHash)
    if not IsNamedRendertargetRegistered(targetName) then
        RegisterNamedRendertarget(targetName, 0)
    end
    if not IsNamedRendertargetLinked(modelHash) then
        LinkNamedRendertarget(modelHash)
    end
    if IsNamedRendertargetRegistered(targetName) then
        return GetNamedRendertargetRenderId(targetName)
    end
    return 0
end

-- ─── Mugshot Board ───────────────────────────────────────────────────────────

-- Initialises the mugshot board scaleform and starts the render thread
-- Returns the scaleform handle
local function InitMugshotBoard()
    renderThreadActive = true

    local scaleform = LoadScaleformMovie("mugshot_board_01")
    local renderId  = SetupNamedRenderTarget("ID_Text", -955488312)

    CreateThread(function()
        while renderThreadActive do
            HideHudAndRadarThisFrame()
            SetTextRenderId(renderId)
            Set_2dLayer(4)
            SetScriptGfxDrawBehindPausemenu(1)
            DrawScaleformMovie(scaleform, 0.405, 0.37, 0.81, 0.74, 255, 255, 255, 255, 0)
            SetScriptGfxDrawBehindPausemenu(0)
            SetTextRenderId(GetDefaultScriptRendertargetRenderId())
            Wait(0)
        end
    end)

    return scaleform
end

-- Calls SET_BOARD on the scaleform to populate all text fields
local function PopulateMugshotBoard(scaleformHandle, boardData)
    BeginScaleformMovieMethod(scaleformHandle, "SET_BOARD")
    PushScaleformMovieMethodParameterString(boardData.title    or "")
    PushScaleformMovieMethodParameterString(boardData.text     or "")
    PushScaleformMovieMethodParameterString(boardData.subtitle or "")
    PushScaleformMovieMethodParameterString(boardData.footer   or "")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieMethodParameterString(boardData.level    or "")
    PushScaleformMovieFunctionParameterInt(116)
    EndScaleformMovieMethod()
end

-- ─── Board Prop Attachment ────────────────────────────────────────────────────

-- Creates the board and sign props and attaches them to the ped hand
-- Returns (boardEntity, signEntity)
local function AttachMugshotBoardToPed(pedEntity)
    lib.requestModel(-1623189257)
    lib.requestModel(-955488312)

    local pedCoords = GetEntityCoords(pedEntity)

    local board = CreateObject(-1623189257, pedCoords, true, true, false)
    local sign  = CreateObject(-955488312,  pedCoords, true, true, false)

    -- Attach sign to board
    AttachEntityToEntity(sign, board, -1, 4103,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        false, false, false, false, 2, true)

    -- Equip suppressor weapon (used as dummy for board hold anim)
    SetCurrentPedWeapon(pedEntity, -1569615261, 1)
    ClearPedWetness(pedEntity)
    ClearPedBloodDamage(pedEntity)

    -- Attach board to ped left hand bone
    local boneIndex = GetPedBoneIndex(pedEntity, 28422)
    AttachEntityToEntity(board, pedEntity, boneIndex,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0, 0, 0, 0, 2, 1)

    SetModelAsNoLongerNeeded(-1623189257)
    SetModelAsNoLongerNeeded(-955488312)

    return board, sign
end

-- ─── Scene Cleanup ───────────────────────────────────────────────────────────

local function CleanupMugshotScene()
    renderThreadActive = false

    if boardEntity and DoesEntityExist(boardEntity) then DeleteEntity(boardEntity) end
    if signEntity  and DoesEntityExist(signEntity)  then DeleteEntity(signEntity) end
    boardEntity = nil
    signEntity  = nil
end

-- ─── Sound / Flash ───────────────────────────────────────────────────────────

local function PlayCameraShutter()
    PlaySoundFrontend(-1, "Camera_Shoot", "Phone_SoundSet_Default", true)
end

local function PlayFlashEffect(durationMs)
    AnimpostfxStop("SuccessNeutral")
    AnimpostfxPlay("SuccessNeutral", durationMs or 250, false)
end

-- ─── Board Content Fill ───────────────────────────────────────────────────────

-- Builds and calls PopulateMugshotBoard with prisoner data and a view label
local function SetBoardForShot(scaleformHandle, sentenceData, viewLabel)
    local sentenceMins = math.ceil((sentenceData.sentenceTime or 0) / 60)
    local levelStr     = sentenceData.isLife and "LIFE"
        or (tostring(sentenceMins) .. " MO")

    local prisonerId = string.format("%05d", math.random(10000, 99999))

    PopulateMugshotBoard(scaleformHandle, {
        title    = "BOLINGBROKE PENITENTIARY",
        text     = string.upper(sentenceData.playerName or "Unknown"),
        subtitle = "ID #" .. prisonerId .. "  -  " .. viewLabel,
        footer   = string.upper(sentenceData.reason or ""),
        level    = levelStr,
    })
end

-- ─── Heading Wait ────────────────────────────────────────────────────────────

-- Waits until the ped's heading is within 3° of targetHeading (timeout ms)
local function WaitForPedHeading(pedEntity, targetHeading, timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 2500)
    while GetGameTimer() < deadline do
        local diff = math.abs(((GetEntityHeading(pedEntity) - targetHeading) + 540.0) % 360.0 - 180.0)
        if diff < 3.0 then return end
        Wait(0)
    end
end

-- ─── Full Mugshot Sequence ────────────────────────────────────────────────────

local function RunMugshotSequence(sentenceData)
    if isBusy then return end
    isBusy = true

    local mugshotMap = Prison.Map and Prison.Map.mugshot

    -- No mugshot location: skip straight to Prison.enter
    if not mugshotMap then
        if Prison.playCellArrival then
            pcall(Prison.playCellArrival, Prison, sentenceData)
        end
        Prison:enter(sentenceData)
        isBusy = false
        return
    end

    local ped          = cache.ped
    local cameraCfg    = mugshotMap.camera
    local pedCoordsCfg = mugshotMap.pedCoords
    local pedHeading   = pedCoordsCfg.w or 0.0

    -- Init board scaleform (starts render thread)
    local scaleformHandle = InitMugshotBoard()

    Wait(200)
    DoScreenFadeOut(500)
    Wait(600)

    -- Teleport ped to mugshot spot
    SetEntityCoords(ped, pedCoordsCfg.x, pedCoordsCfg.y, pedCoordsCfg.z,
        false, false, false, true)
    SetEntityHeading(ped, pedHeading)

    -- Spawn scene peds
    SpawnMugshotPeds(mugshotMap.peds)

    -- Attach board
    boardEntity, signEntity = AttachMugshotBoardToPed(ped)

    -- Create scripted camera
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    mugshotCam = cam

    SetCamCoord(cam, cameraCfg.coords.x, cameraCfg.coords.y, cameraCfg.coords.z)
    SetCamRot(cam, cameraCfg.rotation.x, cameraCfg.rotation.y, cameraCfg.rotation.z, 2)
    SetCamFov(cam, cameraCfg.fov or 40.0)
    RenderScriptCams(true, false, 0, true, true)

    -- First shot: FRONT
    SetBoardForShot(scaleformHandle, sentenceData, "FRONT")

    -- Standard hold animation
    lib.requestAnimDict("mp_character_creation@customise@male_a")
    TaskPlayAnim(ped, "mp_character_creation@customise@male_a", "loop",
        4.0, -4.0, -1, 49, 0, false, false, false)

    Wait(1000)
    DoScreenFadeIn(700)
    Wait(500)

    -- Per-shot timing
    local totalDuration = Config.Prison.Mugshot.duration or 5000
    local shotDuration  = math.max(700, math.floor(totalDuration / 3))

    local shots = {
        { heading = pedHeading,        label = "FRONT"         },
        { heading = pedHeading + 90.0, label = "RIGHT PROFILE" },
        { heading = pedHeading - 90.0, label = "LEFT PROFILE"  },
    }

    for i, shot in ipairs(shots) do
        SetBoardForShot(scaleformHandle, sentenceData, shot.label)

        if i > 1 then
            ClearPedSecondaryTask(ped)

            -- For shot 3 (LEFT), reset to front first
            if i == 3 then
                TaskAchieveHeading(ped, pedHeading, 1200)
                WaitForPedHeading(ped, pedHeading, 1400)
            end

            TaskAchieveHeading(ped, shot.heading, 1500)
            WaitForPedHeading(ped, shot.heading, 1800)

            TaskPlayAnim(ped, "mp_character_creation@customise@male_a", "loop",
                4.0, -4.0, -1, 49, 0, false, false, false)
        end

        Wait(shotDuration)
        PlayCameraShutter()
        PlayFlashEffect(200)
        Wait(350)
    end

    -- Return to facing front
    ClearPedSecondaryTask(ped)
    TaskAchieveHeading(ped, pedHeading, 1200)
    WaitForPedHeading(ped, pedHeading, 1400)
    TaskPlayAnim(ped, "mp_character_creation@customise@male_a", "loop",
        4.0, -4.0, -1, 49, 0, false, false, false)
    Wait(250)

    DoScreenFadeOut(500)
    Wait(600)

    -- Restore camera
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    mugshotCam = nil

    CleanupMugshotScene()
    DeleteMugshotPeds()

    ClearPedTasks(ped)
    SetEntityHeading(ped, pedHeading)

    isBusy = false

    -- Optional cell-arrival hook, then enter prison
    if Prison.playCellArrival then
        pcall(Prison.playCellArrival, Prison, sentenceData)
    end
    Prison:enter(sentenceData)
end

-- ─── Net Event / Command ─────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/client/prison/mugshot", function(sentenceData)
    if type(sentenceData) ~= "table" then return end
    RunMugshotSequence(sentenceData)
end)

RegisterCommand("mugshot", function()
    RunMugshotSequence({
        playerName   = GetPlayerName(cache.serverId),
        reason       = "Testing Mugshot",
        sentenceTime = 900,
    })
end, false)
