-- Wait for Config.HandRadar to be available
while not (Config and Config.HandRadar) do Citizen.Wait(500) end

if not Config.HandRadar.enabled then return end

local radarConfig = Config.HandRadar

-- Global HandRadar state object
HandRadar = {
    active      = false,
    dui         = nil,
    scaleform   = nil,
    target      = nil,
    locked      = false,
    snapshot    = nil,
    calmedPed   = nil,
}

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Returns true if the local player's job meets the HandRadar access threshold
function PlayerHasHandRadarAccess()
    if not Config.Jobs then return true end

    local job = Bridge.Framework.fetchPlayerJob and Bridge.Framework.fetchPlayerJob()
    if not (job and job.name) then return false end

    local threshold = Config.Jobs[job.name]
    if threshold == nil then return false end

    return threshold <= (job.grade or 0)
end

-- Converts a raw m/s speed to the configured unit (kmh or mph)
function ConvertSpeed(metersPerSecond)
    if radarConfig.Unit == "kmh" then
        return metersPerSecond * 3.6
    end
    return metersPerSecond * 2.236936
end

-- Returns the uppercase unit label ("KMH" or "MPH")
function GetSpeedUnitLabel()
    return radarConfig.Unit == "kmh" and "KMH" or "MPH"
end

-- Returns the plate text for the given vehicle entity, falling back to "--------"
function GetVehiclePlate(vehicleEntity)
    local plate = ""
    if vehicleEntity then
        plate = GetVehicleNumberPlateText(vehicleEntity) or ""
    end
    plate = plate:gsub("%s+$", "")
    return (plate == "") and "--------" or plate
end

-- Returns the forward direction vector for the final rendered camera
function GetCameraForwardVector()
    local camRot = GetFinalRenderedCamRot(2)
    local radX   = math.rad(camRot.x)
    local radZ   = math.rad(camRot.z)
    local cosX   = math.abs(math.cos(radX))

    return vector3(
        -math.sin(radZ) * cosX,
         math.cos(radZ) * cosX,
         math.sin(radX)
    )
end

-- ─── DUI / Scaleform ─────────────────────────────────────────────────────────

-- Builds the state table to push to the DUI every frame
function BuildRadarUpdateMessage()
    local unitLabel = GetSpeedUnitLabel()

    -- Locked snapshot: freeze the last reading
    if HandRadar.locked and HandRadar.snapshot then
        return {
            action = "update",
            target = true,
            locked = true,
            speed  = HandRadar.snapshot.speed,
            plate  = HandRadar.snapshot.plate,
            unit   = unitLabel,
        }
    end

    -- No target or target gone
    if not (HandRadar.target and DoesEntityExist(HandRadar.target)) then
        return {
            action = "update",
            target = false,
            locked = false,
            unit   = unitLabel,
        }
    end

    -- Live target
    return {
        action = "update",
        target = true,
        locked = false,
        speed  = math.floor(ConvertSpeed(GetEntitySpeed(HandRadar.target)) + 0.5),
        plate  = GetVehiclePlate(HandRadar.target),
        unit   = unitLabel,
    }
end

-- Sends the current state to the DUI
function SendRadarUpdate()
    if HandRadar.dui then
        HandRadar.dui:sendMessage(BuildRadarUpdateMessage())
    end
end

-- Creates the DUI and attaches it to the hand_radar_texture scaleform
function InitialiseDui()
    if HandRadar.dui then return end

    HandRadar.dui = lib.dui.new({
        url    = string.format("nui://%s/web/handradar.html", GetCurrentResourceName()),
        width  = 512,
        height = 256,
    })

    local scaleformHandle = RequestScaleformMovie("hand_radar_texture")
    while not HasScaleformMovieLoaded(scaleformHandle) do
        Wait(0)
    end

    BeginScaleformMovieMethod(scaleformHandle, "SET_TEXTURE")
    _ENV["ScaleformMovieMethodAddParamTextureNameString"](HandRadar.dui.dictName)
    _ENV["ScaleformMovieMethodAddParamTextureNameString"](HandRadar.dui.txtName)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(512)
    ScaleformMovieMethodAddParamInt(256)
    EndScaleformMovieMethod()

    HandRadar.scaleform = scaleformHandle
end

-- Returns the world position offset from the weapon entity (for 3D scaleform placement)
function GetWeaponWorldPosition()
    local weaponEntity = GetCurrentPedWeaponEntityIndex(cache.ped)
    if not (weaponEntity and weaponEntity ~= 0 and DoesEntityExist(weaponEntity)) then
        return nil
    end

    local offset = radarConfig.Dui.offset
    return GetOffsetFromEntityInWorldCoords(weaponEntity, 0.0, offset.forward, offset.up)
end

-- Toggles the lock on the current target: if locked, unlocks; if not, snapshots the target
function ToggleLock()
    if not HandRadar.active then return end

    if HandRadar.locked then
        HandRadar.locked   = false
        HandRadar.snapshot = nil
    elseif HandRadar.target and DoesEntityExist(HandRadar.target) then
        HandRadar.snapshot = {
            speed = math.floor(ConvertSpeed(GetEntitySpeed(HandRadar.target)) + 0.5),
            plate = GetVehiclePlate(HandRadar.target),
        }
        HandRadar.locked = true
    end

    SendRadarUpdate()
end

-- ─── Target / NPC Calming ─────────────────────────────────────────────────────

-- Updates the "calmed ped" (blocks AI events on the driver of the targeted vehicle).
-- Pass nil to clear without setting a new one.
function UpdateCalmedPed(vehicleEntity)
    local driverPed = 0
    if vehicleEntity and DoesEntityExist(vehicleEntity) then
        driverPed = GetPedInVehicleSeat(vehicleEntity, -1) or 0
    end

    if driverPed == HandRadar.calmedPed then return end

    -- Restore previous calmed ped
    if HandRadar.calmedPed and DoesEntityExist(HandRadar.calmedPed) then
        SetBlockingOfNonTemporaryEvents(HandRadar.calmedPed, false)
    end
    HandRadar.calmedPed = nil

    -- Calm new ped (only NPC peds, not players)
    if driverPed ~= 0 and DoesEntityExist(driverPed) and not IsPedAPlayer(driverPed) then
        SetBlockingOfNonTemporaryEvents(driverPed, true)
        HandRadar.calmedPed = driverPed
    end
end

-- ─── Aim Cone Vehicle Detection ───────────────────────────────────────────────

-- Returns the vehicle most directly in line with the camera's aim cone,
-- within radarConfig.AimDistance and radarConfig.AimCone degrees.
function FindAimedVehicle()
    local camPos    = GetFinalRenderedCamCoord()
    local camFwd    = GetCameraForwardVector()
    local maxDist   = radarConfig.AimDistance
    local coneCos   = math.cos(math.rad(radarConfig.AimCone or 5.0))

    local bestVehicle = nil
    local bestDot     = nil

    local function CheckEntity(entity)
        local entityPos = GetEntityCoords(entity)
        local delta     = entityPos - camPos
        local dist      = #delta

        if dist <= 1.0 or dist > maxDist then return end

        local dot = (delta.x * camFwd.x + delta.y * camFwd.y + delta.z * camFwd.z) / dist

        if dot >= coneCos and (not bestDot or dot > bestDot) then
            bestVehicle = entity
            bestDot     = dot
        end
    end

    for _, v in ipairs(GetGamePool("CVehicle")) do CheckEntity(v) end

    return bestVehicle
end

-- ─── Active Threads ───────────────────────────────────────────────────────────

-- Spawns the 3D scaleform render thread (runs while HandRadar.active)
function StartScaleformThread()
    local duiConfig = radarConfig.Dui
    CreateThread(function()
        while HandRadar.active do
            Wait(0)
            if HandRadar.scaleform and IsPlayerFreeAiming(PlayerId()) then
                local weaponPos = GetWeaponWorldPosition()
                if weaponPos then
                    local camDist = #(weaponPos - GetFinalRenderedCamCoord())
                    if camDist <= duiConfig.maxDistance then
                        local rotation
                        if duiConfig.faceCam then
                            rotation = GetGameplayCamRot(2)
                        else
                            rotation = vector3(0.0, 0.0, GetEntityHeading(cache.ped))
                        end

                        DrawScaleformMovie_3dNonAdditive(
                            HandRadar.scaleform,
                            weaponPos.x, weaponPos.y, weaponPos.z,
                            rotation.x, rotation.y, rotation.z,
                            1.0, 1.0, 1.0,
                            duiConfig.scale.x, duiConfig.scale.y, duiConfig.scale.z,
                            0
                        )
                    end
                end
            end
        end
    end)
end

-- Spawns the target-detection + DUI-update thread (runs while HandRadar.active)
function StartTargetThread()
    CreateThread(function()
        while HandRadar.active do
            local sleepMs = 250

            if not HandRadar.locked then
                if IsPlayerFreeAiming(PlayerId()) then
                    sleepMs             = 0
                    HandRadar.target    = FindAimedVehicle()
                else
                    HandRadar.target    = nil
                end

                UpdateCalmedPed(HandRadar.target)
                SendRadarUpdate()
            end

            Wait(sleepMs)
        end
    end)
end

-- Spawns the input-blocking thread: disables fire/weapon controls while radar is active
function StartInputThread()
    CreateThread(function()
        while HandRadar.active do
            Wait(0)
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24,  true)  -- Attack
            DisableControlAction(0, 257, true)  -- Attack 2
            DisableControlAction(0, 69,  true)  -- Aim
            DisableControlAction(0, 70,  true)  -- Aim 2
            DisableControlAction(0, 92,  true)  -- Vehicle Sub Action
            DisableControlAction(0, 114, true)  -- Vehicle Mouse Control
            DisableControlAction(0, 331, true)  -- Phone

            -- Press Attack (control 24) while aiming → lock/unlock
            if IsDisabledControlJustPressed(0, 24) then
                ToggleLock()
            end
        end
    end)
end

-- ─── Activate / Deactivate ────────────────────────────────────────────────────

function ActivateHandRadar()
    if HandRadar.active then return end

    if not PlayerHasHandRadarAccess() then
        Bridge.Notify.showNotify(locale("no_access"), "error")
        return
    end

    HandRadar.active   = true
    HandRadar.target   = nil
    HandRadar.locked   = false
    HandRadar.snapshot = nil

    SetEveryoneIgnorePlayer(PlayerId(), true)
    InitialiseDui()
    SendRadarUpdate()
    StartInputThread()
    StartScaleformThread()
    StartTargetThread()
end

function DeactivateHandRadar()
    if not HandRadar.active then return end

    HandRadar.active = false
    HandRadar.target = nil
    HandRadar.locked = false
    HandRadar.snapshot = nil

    UpdateCalmedPed(nil)
    SetEveryoneIgnorePlayer(PlayerId(), false)
    SendRadarUpdate()
end

-- ─── Weapon Cache Handler ─────────────────────────────────────────────────────

-- Activate when the configured radar weapon is drawn; deactivate otherwise
lib.onCache("weapon", function(weaponHash)
    if weaponHash == radarConfig.Weapon then
        ActivateHandRadar()
    else
        DeactivateHandRadar()
    end
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if HandRadar.scaleform then
        SetScaleformMovieAsNoLongerNeeded(HandRadar.scaleform)
        HandRadar.scaleform = nil
    end

    if HandRadar.dui then
        HandRadar.dui:remove()
        HandRadar.dui = nil
    end
end)
