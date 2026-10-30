-- ============================================================
-- Pointing — animation + per-frame network signal updates
-- ============================================================

local POINT_DICT = "anim@mp_point"
local POINT_TASK = "task_mp_pointing"

local isPointing = false


function startPointing()
    local ped = PlayerPedId()

    RequestAnimDict(POINT_DICT)
    while not HasAnimDictLoaded(POINT_DICT) do
        Wait(0)
    end

    SetPedCurrentWeaponVisible(ped, 0, 1, 1, 1)
    SetPedConfigFlag(ped, 36, 1)
    TaskMoveNetworkByName(ped, POINT_TASK, 0.5, 0, POINT_DICT, 24)
    RemoveAnimDict(POINT_DICT)
end

function stopPointing()
    local ped = PlayerPedId()

    RequestTaskMoveNetworkStateTransition(ped, "Stop")

    if not IsPedInjured(ped) then
        ClearPedSecondaryTask(ped)
    end

    if not IsPedInAnyVehicle(ped, 1) then
        SetPedCurrentWeaponVisible(ped, 1, 1, 1, 1)
    end

    SetPedConfigFlag(ped, 36, 0)
    ClearPedSecondaryTask(ped)
end


-- ============================================================
-- Register keybind if enabled in config
-- ============================================================

if Config.Pointing.enabled then
    RegisterCommand("+point", function()
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then return end

        startPointing()
        isPointing = true

        -- Per-frame loop: feed pitch/heading/blocked/firstperson signals to the network task
        while isPointing do
            ped = PlayerPedId()

            -- Pitch: clamp camera pitch to [-70, 42] then normalise to [0, 1]
            local pitch = GetGameplayCamRelativePitch()
            pitch = math.max(-70.0, math.min(42.0, pitch))
            local pitchNorm = (pitch + 70.0) / 112.0

            -- Heading: clamp to [-180, 180] then normalise to [0, 1]
            local heading = GetGameplayCamRelativeHeading()
            heading = math.max(-180.0, math.min(180.0, heading))
            local headingNorm = (heading + 180.0) / 360.0

            local cosH = Cos(heading)
            local sinH = Sin(heading)

            -- Build a small origin offset from the ped for the raycast
            local offsetX = cosH * -0.2 - sinH * (0.4 * headingNorm + 0.3)
            local offsetY = sinH * -0.2 + cosH * (0.4 * headingNorm + 0.3)
            local origin  = GetOffsetFromEntityInWorldCoords(ped, offsetX, offsetY, 0.6)

            -- Short vertical raycast to check if the pointing direction is blocked
            local rayHandle = Cast_3dRayPointToPoint(
                origin.x, origin.y, origin.z - 0.2,
                origin.x, origin.y, origin.z + 0.2,
                0.4, 95, ped, 7
            )
            local _, hitResult, _, _ = GetRaycastResult(rayHandle)
            local isBlocked = hitResult

            -- Push signals to the move-network task
            SetTaskMoveNetworkSignalFloat(ped, "Pitch",   pitchNorm)
            SetTaskMoveNetworkSignalFloat(ped, "Heading", headingNorm * -1.0 + 1.0)
            SetTaskMoveNetworkSignalBool(ped,  "isBlocked",    isBlocked)
            SetTaskMoveNetworkSignalBool(ped,  "isFirstPerson",
                GetCamViewModeForContext(GetCamActiveViewModeContext()) == 4)

            Wait(0)
        end
    end, false)

    RegisterCommand("-point", function()
        isPointing = false
        stopPointing()
    end, false)

    RegisterKeyMapping("+point", "Point-Finger", "keyboard", Config.Pointing.keybind)
end