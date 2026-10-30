CharFuncs = {}

-- Returns the cursor position in normalised screen space [0,1].
function CharFuncs.getCursorPos()
    return GetDisabledControlNormal(2, 239),
           GetDisabledControlNormal(2, 240)
end

-- Projects a ped's torso to screen space [0,1]. Returns sx, sy or nil if off-screen.
function CharFuncs.getPedScreenPos(pedHandle)
    if not DoesEntityExist(pedHandle) then return nil, nil end
    local boneIdx = GetPedBoneIndex(pedHandle, 0x796e)
    local wx, wy, wz
    if boneIdx and boneIdx ~= -1 then
        local bp = GetWorldPositionOfEntityBone(pedHandle, boneIdx)
        if bp then wx, wy, wz = bp.x, bp.y, bp.z + 0.5 end
    end
    if not wx then
        local p = GetEntityCoords(pedHandle)
        wx, wy, wz = p.x, p.y, p.z + 0.5
    end
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(wx, wy, wz)
    if not onScreen then return nil, nil end
    return sx, sy
end

-- Finds which ped in pedList the cursor is closest to, within hitRadius (screen units 0-1).
-- Returns the matching ped handle or nil. hitRadius 0.07 ≈ 134px on 1920-wide screen.
function CharFuncs.findHoveredPed(pedList, hitRadius)
    if not hitRadius then hitRadius = 0.07 end
    local cx, cy   = CharFuncs.getCursorPos()
    local bestPed  = nil
    local bestDist = hitRadius
    for _, pedHandle in ipairs(pedList) do
        local sx, sy = CharFuncs.getPedScreenPos(pedHandle)
        if sx then
            local dist = math.sqrt((cx - sx)^2 + (cy - sy)^2)
            if dist < bestDist then
                bestDist = dist
                bestPed  = pedHandle
            end
        end
    end
    return bestPed
end

-- LEGACY STUB — no longer called. The custom ray builder had wrong basis vectors
-- (x-offset used as yaw, z-offset as pitch) so it never pointed at the cursor.
-- Replaced by CharFuncs.findHoveredPed (screen-space proximity).
function CharFuncs.screenToWorld(filterType, filterEntity)
    local function degToRad(deg)
        return deg * math.pi / 180.0
    end

    local function vecScale(v, s)
        return { x = v.x * s, y = v.y * s, z = v.z * s }
    end

    local function vecAdd(a, b)
        return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
    end

    local function vecSub(a, b)
        return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
    end

    -- Converts a rotation vector (GTA euler, degrees) to a normalised forward direction.
    -- GTA camera rotation: rot.x = pitch (up/down), rot.z = yaw (left/right).
    -- The original code had these swapped (rot.z used as pitch, rot.x as yaw),
    -- which pointed the ray in the wrong direction in world space.
    local function rotToDir(rot)
        local pitchRad = degToRad(rot.x)
        local yawRad   = degToRad(rot.z)
        local absCos   = math.abs(math.cos(pitchRad))
        return {
            x = -math.sin(yawRad) * absCos,
            y =  math.cos(yawRad) * absCos,
            z =  math.sin(pitchRad),
        }
    end

    -- Projects a world coordinate to normalised screen space [-1, 1].
    local function worldToScreen(worldPos)
        local onScreen, sx, sy = GetScreenCoordFromWorldCoord(worldPos.x, worldPos.y, worldPos.z)
        if not onScreen then return nil end
        return { x = (sx - 0.5) * 2, y = (sy - 0.5) * 2, z = 0 }
    end

    -- Converts pixel cursor coords to a signed offset from screen centre [-1, 1].
    -- math.abs() was previously applied here, which collapsed all four screen
    -- quadrants into one and made it impossible to click anything on the left
    -- half or bottom half of the screen.
    -- Control 239 (cursorX): 0.0 = left edge, 1.0 = right edge.
    -- buildCursorRay expects: -1.0 = left, +1.0 = right.
    -- Correct formula: (px / resW) * 2 - 1.0
    -- The previous formula (1.0 - ...) mirrored the X axis, making the ray
    -- fire to the opposite horizontal side from where the cursor actually was.
    local function pixelToScreenOffset(px, py)
        local resW, resH = GetActiveScreenResolution()
        local nx = (px / resW) * 2 - 1.0
        local ny = 1.0 - (py / resH) * 2
        return { x = nx, y = ny }
    end

    -- Builds a camera-relative ray direction from rotation and screen-space offset.
    -- ⚠️ This is a non-trivial custom unprojection routine. The logic derives left/right
    -- and up/down basis vectors from camera rotation, then lerps between them using the
    -- screen cursor position to produce a ray direction. Verify before changing.
    local function buildCursorRay(camRot, screenX, screenY)
        local camDir   = rotToDir(camRot)
        local rightRot = vecAdd(camRot, { x = 10, y = 0, z = 0 })
        local leftRot  = vecAdd(camRot, { x = -10, y = 0, z = 0 })
        local upRot    = vecAdd(camRot, { x = 0, y = 0, z = -10 })
        local downRot  = vecAdd(camRot, { x = 0, y = 0, z = 10 })

        local rightDir = vecSub(rotToDir(downRot), rotToDir(upRot))
        local upDir    = vecSub(rotToDir(rightRot), rotToDir(leftRot))

        local pitchRad = -degToRad(camRot.y)
        local rightScaled = vecScale(rightDir, math.cos(pitchRad))
        local upScaled    = vecScale(upDir, math.sin(pitchRad))
        local right2      = vecScale(rightDir, math.sin(pitchRad))
        local up2         = vecScale(upDir, math.cos(pitchRad))

        local halfX = vecAdd(vecScale(camDir, 10.0), vecScale(rightScaled, screenX))
        local halfY = vecAdd(vecScale(camDir, 10.0), vecScale(upScaled, screenY))

        if not worldToScreen(halfX) then
            return vecAdd(vecScale(camDir, 10.0), vecScale(rightScaled, screenX))
        end
        local screenHalfX = worldToScreen(halfX)
        if not worldToScreen(halfY) then
            return vecAdd(vecScale(camDir, 10.0), vecScale(rightScaled, screenX))
        end
        local screenHalfY = worldToScreen(halfY)

        -- Convergence check: if both halves map to nearly the same screen point,
        -- use a direct interpolation instead.
        if math.abs(screenHalfX.x - screenHalfY.x) < 0.001 and
           math.abs(screenHalfX.y - screenHalfY.y) < 0.001 then
            return vecAdd(vecScale(camDir, 10.0), vecScale(rightScaled, screenX))
        end

        local tX = (screenX - screenHalfY.x) / (screenHalfX.x - screenHalfY.x)
        local tY = (screenY - screenHalfY.y) / (screenHalfX.y - screenHalfY.y)
        return vecAdd(
            vecAdd(vecScale(camDir, 10.0), vecScale(rightScaled, tX)),
            vecScale(upScaled, tY)
        )
    end

    local resW, resH = GetActiveScreenResolution()
    local cursorX = GetDisabledControlNormal(2, 239) * resW
    local cursorY = GetDisabledControlNormal(2, 240) * resH

    local camRot
    if IsGameplayCamRendering() then
        camRot = GetGameplayCamRot(0)
    else
        camRot = GetCamRot(GetRenderingCam(), 0)
    end

    local camCoord
    if IsGameplayCamRendering() then
        camCoord = GetGameplayCamCoord()
    else
        camCoord = GetCamCoord(GetRenderingCam())
    end

    local cursorOffset = pixelToScreenOffset(cursorX, cursorY)
    local rayDir       = buildCursorRay(camRot, cursorOffset.x, cursorOffset.y)
    -- Start the ray 1.0 unit in front of the camera (was 0.05, which caused
    -- the probe origin to sit inside the camera or clip into nearby geometry).
    local farPoint     = vecAdd(camCoord, vecScale(rayDir, 1.0))
    local farFar       = vecAdd(camCoord, vecScale(rayDir, 300))

    -- ⚠️ Uses _ENV lookup for StartExpensiveSynchronousShapeTestLosProbe because the
    -- native may not be in scope at parse time in some FiveM builds.
    local probe = _ENV["StartExpensiveSynchronousShapeTestLosProbe"](
        farPoint.x, farPoint.y, farPoint.z,
        farFar.x,   farFar.y,   farFar.z,
        filterType, filterEntity, 0
    )
    return GetShapeTestResult(probe)
end

-- Requests a model and waits until it is loaded, or until timeoutMs elapses.
-- Returns true if the model loaded successfully, false on timeout.
function CharFuncs.requestModel(modelHash, timeoutMs)
    if not timeoutMs then timeoutMs = 10000 end
    local startTime = GetGameTimer()
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() - startTime >= timeoutMs then break end
        RequestModel(modelHash)
        Citizen.Wait(0)
    end
    return HasModelLoaded(modelHash)
end

-- Plays an animation or scenario on a ped.
-- animData must have .type = "animation" (with .lib and .anim) or .type = "scenario" (with .scenario).
function CharFuncs.playAnimation(ped, animData)
    if animData.type == "animation" then
        RequestAnimDict(animData.lib)
        local startTime = GetGameTimer()
        while not HasAnimDictLoaded(animData.lib) do
            if GetGameTimer() - startTime >= 5000 then break end
            Citizen.Wait(0)
        end
        if HasAnimDictLoaded(animData.lib) then
            TaskPlayAnim(ped, animData.lib, animData.anim, 8.0, -8, -1, 1, false, false, false)
        end
    elseif animData.type == "scenario" then
        TaskStartScenarioInPlace(ped, animData.scenario, 0, true)
    end
end

-- Teleports the local player ped to coords (z offset by -1.0), loads collision,
-- activates any interior at that position, then hides and freezes the ped.
-- Used to "park" the player invisibly at a character-select location.
function CharFuncs.parkPlayer(coords)
    local ped        = PlayerPedId()
    local targetPos  = vector3(coords.x, coords.y, coords.z - 1.0)

    SetEntityCoords(ped, targetPos.x, targetPos.y, targetPos.z)
    RequestCollisionAtCoord(targetPos.x, targetPos.y, targetPos.z)

    local interiorId = GetInteriorAtCoords(targetPos.x, targetPos.y, targetPos.z)
    if interiorId ~= 0 then
        SetInteriorActive(interiorId, true)
        RefreshInterior(interiorId)
    end

    local startTime = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) do
        if GetGameTimer() - startTime >= 5000 then break end
        RequestCollisionAtCoord(targetPos.x, targetPos.y, targetPos.z)
        Citizen.Wait(0)
    end

    SetEntityCoords(ped, targetPos.x, targetPos.y, targetPos.z)
    SetEntityVisible(ped, false)
    SetEntityAlpha(ped, 0)
    FreezeEntityPosition(ped, true)
end

-- Disables HUD, radar, and player-specific actions for one frame.
-- Called every frame from the raycastLoop thread while character select is open.
-- NOTE: do NOT disable control 24 (attack / left-click) here — the main lockdown
-- thread in Init re-enables it with EnableControlAction so the raycast click fires.
-- The old code explicitly disabled 24 then called DisableAllControlActions, which
-- clobbered the EnableControlAction(24) and made peds un-clickable.
function CharFuncs.disableActionsOneFrame()
    local ped = PlayerPedId()
    HideHudAndRadarThisFrame()
    DisableControlAction(0, 1,   true)   -- look L/R
    DisableControlAction(0, 2,   true)   -- look U/D
    DisableControlAction(0, 142, true)   -- melee attack
    DisableControlAction(0, 106, true)   -- vehicle attack
    DisablePlayerFiring(ped, true)
    -- DisableAllControlActions is NOT called here; the Init lockdown thread
    -- already handles that and selectively re-enables 24 and 176.
end
