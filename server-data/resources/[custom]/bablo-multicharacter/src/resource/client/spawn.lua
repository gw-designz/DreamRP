-- Teleports the player ped to a specific world coordinate, waits for the scene and
-- collision to stream in, then fades in. Falls back to Config.SpawnPositions[1]
-- when coords is nil.
function Main:spawnAtPoint(coords)
    SendNUIMessage({ action = "SET_FADING", data = true })
    DoScreenFadeOut(300)
    waitForBlackScreen(500)

    local target = (coords and vector3(coords.x, coords.y, coords.z))
        or (Config.SpawnPositions[1] and Config.SpawnPositions[1].coords)

    self:Destroy()

    if Config.RoutingBucket ~= nil and Config.RoutingBucket ~= false then
        lib.callback.await("bablo-multicharacter:server:leaveBucket", false)
    end

    local releaseControls = blockControls(10000)
    local ped = PlayerPedId()

    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    -- Keep the ped invincible while the world streams in so it can't die from a
    -- fall or water before the ground loads. Cleared at the end of this function.
    SetEntityInvincible(ped, true)
    SetEntityCoordsNoOffset(ped, target.x, target.y, target.z, false, false, false)

    NewLoadSceneStart(target.x, target.y, target.z, 0.0, 0.0, 0.0, 50.0, 0)

    -- Hold the screen black until scene + collision are ready.
    local holdBlack = true
    CreateThread(function()
        while holdBlack do
            if not IsScreenFadedOut() and not IsScreenFadingOut() then
                DoScreenFadeOut(0)
            end
            Citizen.Wait(50)
        end
    end)

    notifyPlayerLoaded()

    -- Give skinchanger/codem-appearance time to finish applying the skin.
    -- lib.callback.await inside NotifyPlayerLoaded returns before the async
    -- TriggerEvent("skinchanger:loadSkin") finishes, so without this wait
    -- the ped model resets and the screen appears to freeze/do nothing.
    if Config.Appearance == "skinchanger" or Config.Appearance == "codem-appearance" then
        Citizen.Wait(800)
    end

    local sceneDeadline = GetGameTimer() + 5000
    while IsNetworkLoadingScene() and GetGameTimer() < sceneDeadline do
        Wait(0)
    end
    NewLoadSceneStop()

    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, target.x, target.y, target.z, false, false, false)

    local colDeadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < colDeadline do
        RequestCollisionAtCoord(target.x, target.y, target.z)
        Wait(0)
    end

    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, target.x, target.y, target.z, false, false, false)
    SetEntityVisible(ped, true)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityAlpha(ped, 255)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    Citizen.Wait(500)

    -- If the ped is airborne (e.g. spawn point not loaded yet), nudge it to the ground.
    local height = GetEntityHeightAboveGround(ped)
    if height > 2.0 then
        -- GetGroundZFor_3dCoord returns (bool found, float groundZ).
        -- The original code stored only the bool and kept using target.z — the
        -- ped was placed back at the original height instead of the ground.
        local groundFound, groundZ = GetGroundZFor_3dCoord(target.x, target.y, target.z + 10.0, false)
        if groundFound then
            SetEntityCoordsNoOffset(ped, target.x, target.y, groundZ, false, false, false)
        else
            local safeFound, safeCoords = GetSafeCoordForPed(target.x, target.y, target.z, true, 16)
            if safeFound then
                SetEntityCoords(ped, safeCoords)
            end
        end
        local airDeadline = GetGameTimer() + 1500
        while GetEntityHeightAboveGround(ped) > 1.3 and GetGameTimer() < airDeadline do
            Wait(0)
        end
    end

    holdBlack = false
    DoScreenFadeIn(500)

    Citizen.Wait(300)
    SetEntityInvincible(PlayerPedId(), false)
    releaseControls()
end

-- Delegates spawning to a framework/resource-defined event rather than teleporting
-- the ped directly. Used when Config.CustomSpawn.enabled = true and the spawn menu
-- is disabled.
function Main:spawnCustom(charId)
    SendNUIMessage({ action = "SET_FADING", data = true })
    DoScreenFadeOut(300)
    waitForBlackScreen(500)

    self:Destroy()

    if Config.RoutingBucket ~= nil and Config.RoutingBucket ~= false then
        lib.callback.await("bablo-multicharacter:server:leaveBucket", false)
    end

    local ped = PlayerPedId()
    SetEntityVisible(ped, true)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityAlpha(ped, 255)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    notifyPlayerLoaded()

    local cs = Config.CustomSpawn or {}
    if cs.event and cs.event ~= "" then
        TriggerEvent(cs.event, charId)
    else
        Trace("[Main:spawnCustom] Config.CustomSpawn.enabled but no event configured")
    end

    if cs.fadeIn then
        DoScreenFadeIn(600)
    end
end

-- Teleports the ped to a housing interior entrance, enters the interior,
-- then waits for collision to load before fading in.
function Main:spawnAtHome(entry)
    if not entry or not entry.name then
        Trace("[Main] spawnAtHome — entry missing name, bailing")
        return
    end

    SendNUIMessage({ action = "SET_FADING", data = true })
    DoScreenFadeOut(300)
    waitForBlackScreen(500)

    self:Destroy()

    if Config.RoutingBucket ~= nil and Config.RoutingBucket ~= false then
        lib.callback.await("bablo-multicharacter:server:leaveBucket", false)
    end

    local releaseControls = blockControls(12000)
    local ped             = PlayerPedId()
    local entrance        = entry.coords or {}
    local hasEntrance     = entrance.x ~= nil and entrance.y ~= nil and entrance.z ~= nil

    -- Keep the ped invincible during the interior-load sequence (see spawnAtPoint).
    SetEntityInvincible(ped, true)

    if hasEntrance then
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        SetEntityCoordsNoOffset(ped, entrance.x, entrance.y, entrance.z, false, false, false)
        NewLoadSceneStart(entrance.x, entrance.y, entrance.z, 0.0, 0.0, 0.0, 50.0, 0)
    end

    local holdBlack = true
    CreateThread(function()
        while holdBlack do
            if not IsScreenFadedOut() and not IsScreenFadingOut() then
                DoScreenFadeOut(0)
            end
            Citizen.Wait(50)
        end
    end)

    notifyPlayerLoaded()

    if hasEntrance then
        local sceneDeadline = GetGameTimer() + 5000
        while IsNetworkLoadingScene() and GetGameTimer() < sceneDeadline do
            Wait(0)
        end
        NewLoadSceneStop()

        ped = PlayerPedId()
        SetEntityCoordsNoOffset(ped, entrance.x, entrance.y, entrance.z, false, false, false)

        local colDeadline = GetGameTimer() + 5000
        while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < colDeadline do
            RequestCollisionAtCoord(entrance.x, entrance.y, entrance.z)
            Wait(0)
        end

        ped = PlayerPedId()
        SetEntityCoordsNoOffset(ped, entrance.x, entrance.y, entrance.z, false, false, false)
    end

    ped = PlayerPedId()
    SetEntityVisible(ped, true)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetEntityAlpha(ped, 255)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)

    Housing:EnterInterior(entry)

    Citizen.Wait(1000)

    ped = PlayerPedId()
    local pedPos = GetEntityCoords(ped)
    local interiorDeadline = GetGameTimer() + 5000
    while GetGameTimer() < interiorDeadline do
        if HasCollisionLoadedAroundEntity(ped) and not IsEntityWaitingForWorldCollision(ped) then
            break
        end
        RequestCollisionAtCoord(pedPos.x, pedPos.y, pedPos.z)
        Citizen.Wait(50)
    end

    Citizen.Wait(500)

    -- Safety: if still airborne after interior load, attempt a ground-snap.
    local height = GetEntityHeightAboveGround(ped)
    if height > 2.0 then
        local groundFound, groundZ = GetGroundZFor_3dCoord(pedPos.x, pedPos.y, pedPos.z + 10.0, false)
        if groundFound then
            SetEntityCoordsNoOffset(ped, pedPos.x, pedPos.y, groundZ, false, false, false)
        else
            local safeFound, safeCoords = GetSafeCoordForPed(pedPos.x, pedPos.y, pedPos.z, true, 16)
            if safeFound then
                SetEntityCoords(ped, safeCoords)
            end
        end
    end

    holdBlack = false
    DoScreenFadeIn(600)

    Citizen.Wait(400)
    SetEntityInvincible(PlayerPedId(), false)
    releaseControls()
end
