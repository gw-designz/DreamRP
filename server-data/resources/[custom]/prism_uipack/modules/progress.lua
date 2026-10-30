---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: duplicate-doc-field

---@class ProgressPropProps
---@field model string
---@field bone? number
---@field pos vector3
---@field rot vector3
---@field rotOrder? number

---@class ProgressProps
---@field variant? 'primary' | 'secondary'
---@field label? string
---@field duration number
---@field position? 'top-center' | 'bottom-center' | 'right-center' | 'left-center'
---@field useWhileDead? boolean
---@field allowRagdoll? boolean
---@field allowCuffed? boolean
---@field allowFalling? boolean
---@field allowSwimming? boolean
---@field canCancel? boolean
---@field cancelKey? string
---@field anim? { dict?: string, clip: string, flag?: number, blendIn?: number, blendOut?: number, duration?: number, playbackRate?: number, lockX?: boolean, lockY?: boolean, lockZ?: boolean, scenario?: string, playEnter?: boolean }
---@field prop? ProgressPropProps | ProgressPropProps[]
---@field disable? { move?: boolean, sprint?: boolean, car?: boolean, combat?: boolean, mouse?: boolean }

local DisableControlAction = DisableControlAction
local DisablePlayerFiring  = DisablePlayerFiring

local playerState  = LocalPlayer.state
local createdProps = {}
local maxProps     = GetConvarInt('ox:progressPropLimit', 2)

-- false = cancelled, nil = idle, table = active
local activeProgress = nil

local controls = {
    INPUT_LOOK_LR                   = 1,
    INPUT_LOOK_UD                   = 2,
    INPUT_SPRINT                    = 21,
    INPUT_AIM                       = 25,
    INPUT_MOVE_LR                   = 30,
    INPUT_MOVE_UD                   = 31,
    INPUT_DUCK                      = 36,
    INPUT_VEH_MOVE_LEFT_ONLY        = 63,
    INPUT_VEH_MOVE_RIGHT_ONLY       = 64,
    INPUT_VEH_ACCELERATE            = 71,
    INPUT_VEH_BRAKE                 = 72,
    INPUT_VEH_EXIT                  = 75,
    INPUT_VEH_MOUSE_CONTROL_OVERRIDE = 106
}

local function CreateProgressProp(ped, prop)
    Utils.requestModel(prop.model)

    local coords = GetEntityCoords(ped)
    local object = CreateObject(prop.model, coords.x, coords.y, coords.z, false, false, false)

    AttachEntityToEntity(
        object, ped, GetPedBoneIndex(ped, prop.bone or 60309),
        prop.pos.x, prop.pos.y, prop.pos.z,
        prop.rot.x, prop.rot.y, prop.rot.z,
        true, true, false, true, prop.rotOrder or 0, true
    )

    SetModelAsNoLongerNeeded(prop.model)
    return object
end

local function ShouldInterruptProgress(data)
    local ped = PlayerPedId()
    if not data.useWhileDead   and IsEntityDead(ped)   then return true end
    if not data.allowRagdoll   and IsPedRagdoll(ped)   then return true end
    if not data.allowCuffed    and IsPedCuffed(ped)    then return true end
    if not data.allowFalling   and IsPedFalling(ped)   then return true end
    if not data.allowSwimming  and IsPedSwimming(ped)  then return true end
    return false
end

local function ApplyProgressDisables(disable, playerId)
    if disable.mouse then
        DisableControlAction(0, controls.INPUT_LOOK_LR, true)
        DisableControlAction(0, controls.INPUT_LOOK_UD, true)
        DisableControlAction(0, controls.INPUT_VEH_MOUSE_CONTROL_OVERRIDE, true)
    end

    if disable.move then
        DisableControlAction(0, controls.INPUT_SPRINT, true)
        DisableControlAction(0, controls.INPUT_MOVE_LR, true)
        DisableControlAction(0, controls.INPUT_MOVE_UD, true)
        DisableControlAction(0, controls.INPUT_DUCK, true)
    elseif disable.sprint then
        DisableControlAction(0, controls.INPUT_SPRINT, true)
    end

    if disable.car then
        DisableControlAction(0, controls.INPUT_VEH_MOVE_LEFT_ONLY, true)
        DisableControlAction(0, controls.INPUT_VEH_MOVE_RIGHT_ONLY, true)
        DisableControlAction(0, controls.INPUT_VEH_ACCELERATE, true)
        DisableControlAction(0, controls.INPUT_VEH_BRAKE, true)
        DisableControlAction(0, controls.INPUT_VEH_EXIT, true)
    end

    if disable.combat then
        DisableControlAction(0, controls.INPUT_AIM, true)
        DisablePlayerFiring(playerId, true)
    end
end

local function StartProgressAnim(anim)
    if not anim then return end

    if anim.dict then
        Utils.requestAnimDict(anim.dict)
        TaskPlayAnim(
            PlayerPedId(), anim.dict, anim.clip,
            anim.blendIn or 3.0, anim.blendOut or 1.0, anim.duration or -1,
            anim.flag or 49, anim.playbackRate or 0,
            anim.lockX, anim.lockY, anim.lockZ
        )
        RemoveAnimDict(anim.dict)
    elseif anim.scenario then
        TaskStartScenarioInPlace(
            PlayerPedId(), anim.scenario, 0,
            anim.playEnter == nil or anim.playEnter --[[@as boolean]]
        )
    end
end

local function StopProgressAnim(anim)
    if not anim then return end

    if anim.dict then
        StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 1.0)
        Wait(0) -- Required: prevents StopAnimTask from being cancelled immediately
    else
        ClearPedTasks(PlayerPedId())
    end
end

---@param data ProgressProps
local function RunProgress(data)
    playerState.invBusy = true
    activeProgress = data

    StartProgressAnim(data.anim)

    if data.prop then
        TriggerServerEvent('prism:progressProps', data.prop)
    end

    local disable   = data.disable
    local startTime = GetGameTimer()
    local playerId  = PlayerId()

    while activeProgress do
        if disable then
            ApplyProgressDisables(disable, playerId)
        end

        if ShouldInterruptProgress(activeProgress) then
            activeProgress = false
        end

        Wait(0)
    end

    if data.prop then
        TriggerServerEvent('prism:progressProps', nil)
    end

    StopProgressAnim(data.anim)

    playerState.invBusy = false

    -- false = cancelled by interrupt/CancelProgress, nil = completed via NUI callback
    local cancelled = activeProgress == false
    local elapsed   = not cancelled and (GetGameTimer() - startTime + 100) -- slight leeway

    if cancelled or elapsed <= data.duration then
        SendNUIMessage({ action = 'progressCancel' })
        return false
    end

    return true
end

---@param data ProgressProps
---@return boolean?
function ProgressBar(data)
    while activeProgress ~= nil do Wait(0) end

    if ShouldInterruptProgress(data) then return end

    SendNUIMessage({
        action = 'progress',
        data = {
            label     = data.label,
            duration  = data.duration,
            position  = data.position,
            variant   = data.variant,
            canCancel = data.canCancel
        }
    })

    return RunProgress(data)
end

-- Compat alias
---@param data ProgressProps
---@return boolean?
function ProgressCircle(data)
    return ProgressBar(data)
end

function CancelProgress()
    if not activeProgress then
        error('No progress bar is active')
    end

    activeProgress = false
end

---@return boolean
function ProgressActive()
    return activeProgress and true or false
end

RegisterNUICallback('progressComplete', function(data, cb)
    cb(1)
    activeProgress = nil
end)

RegisterCommand('cancelprogress_prism', function()
    if activeProgress and activeProgress.canCancel then
        activeProgress = false
    end
end, false)

RegisterKeyMapping('cancelprogress_prism', 'Cancel Progressbar', 'keyboard', GetConvar('prism:progressCancelKey', 'X'))

local function DeleteProgressProps(serverId)
    local playerProps = createdProps[serverId]
    if not playerProps then return end

    createdProps[serverId] = nil

    for i = 1, #playerProps do
        if DoesEntityExist(playerProps[i]) then
            DeleteEntity(playerProps[i])
        end
    end
end

RegisterNetEvent('onPlayerDropped', function(serverId)
    DeleteProgressProps(serverId)
end)

AddStateBagChangeHandler('prism:progressProps', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end

    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end

    local ped      = GetPlayerPed(ply)
    local serverId = GetPlayerServerId(ply)

    if not value or createdProps[serverId] then
        return DeleteProgressProps(serverId)
    end

    local playerProps = {}

    if value.model then
        local prop = CreateProgressProp(ped, value)
        if prop then playerProps[#playerProps + 1] = prop end
    else
        local propCount = math.min(maxProps, #value)
        for i = 1, propCount do
            local prop = CreateProgressProp(ped, value[i])
            if prop then playerProps[#playerProps + 1] = prop end
        end
    end

    createdProps[serverId] = playerProps
end)
