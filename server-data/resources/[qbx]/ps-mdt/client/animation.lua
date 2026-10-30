local tabletProp = nil
local isPlayingTabletAnim = false
local animDict = Config.Animation and Config.Animation.Dict or 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a'
local animName = Config.Animation and Config.Animation.Name or 'idle_a'
local propConfig = Config.TabletProp or {}
local propModel = propConfig.model or 'police_tablet'
local propBone = propConfig.bone or 28422
local propPos = propConfig.pos or vec3(-0.05, 0.0, 0.0)
local propRot = propConfig.rot or vec3(0.0, -90.0, 0.0)

-- Helper to always get current ped (never stale)
local function getPed()
    return PlayerPedId()
end

-- Options ----------------------------------

local propOptions = {
    xPos = propPos.x, -- X-axis offset from the center of entity2
    yPos = propPos.y, -- Y-axis offset from the center of entity2
    zPos = propPos.z, -- Z-axis offset from the center of entity2
    xRot = propRot.x, -- X-axis rotation
    yRot = propRot.y, -- Y-axis rotation
    zRot = propRot.z, -- Z-axis rotation
    p9 = true, -- Unknown
    useSoftPinning = true, -- If set to false attached entity will not detach when fixed
    collision = false, -- Controls collision between the two entities
    isPed = true, -- Pitch doesnt work when false and roll will only work on negative numbers (only peds)
    rotationOrder = 1, -- The order in which the rotation is applied
    syncRot = true -- If false it ignores entity rotation
}

local animOptions = {
        animDict = animDict, -- The animation dictionary
        animName = animName, -- The animation name
        blendInSpeed = 3.0, -- The speed at which the animation blends in
        blendOutSpeed = 2.0, -- The speed at which the animation blends out
        duration = -1, -- The duration of the animation in milliseconds (-1 = loop)
        flag = 49, -- Animation flags (49 = loop with upper body, allow movement)
        playbackRate = 0, -- The playback rate (between 0.0 and 1.0)
        lockX = false, -- Lock X rotation
        lockY = false, -- Lock Y rotation
        lockZ = false -- Lock Z rotation
}

-- Animation Monitoring ---------------------------------

local monitoringThread = nil

-- Start animation monitoring
local function StartAnimationMonitoring()
    if monitoringThread then return end -- Already monitoring

    monitoringThread = CreateThread(function()
        while MDTOpen and isPlayingTabletAnim do
            if not IsEntityPlayingAnim(getPed(), animDict, animName, 3) then
                RestartTabletAnimation()
            end
            Wait(2000)
        end
        monitoringThread = nil
    end)
end

-- Stop animation monitoring
local function StopAnimationMonitoring()
    if monitoringThread then
        monitoringThread = nil
    end
end

-- Prop Handling ---------------------------------

-- Create and attach tablet prop
local function CreateTabletProp()
    local ped = getPed()
    local coords = GetEntityCoords(ped)
    local propHash = GetHashKey(propModel)

    if not ps.requestModel(propModel) then
        ps.warn('Failed to load tablet prop model')
        return false
    end

    tabletProp = CreateObject(propHash, coords.x, coords.y, coords.z + 0.2, true, true, true)

    if not DoesEntityExist(tabletProp) then
        ps.warn('Failed to create tablet prop')
        SetModelAsNoLongerNeeded(propHash)
        return false
    end

    -- Attach prop to player
    local boneIndex = GetPedBoneIndex(ped, propBone)
    AttachEntityToEntity(
        tabletProp,
        ped,
        boneIndex,
        propOptions.xPos,
        propOptions.yPos,
        propOptions.zPos,
        propOptions.xRot,
        propOptions.yRot,
        propOptions.zRot,
        propOptions.p9,
        propOptions.useSoftPinning,
        propOptions.collision,
        propOptions.isPed,
        propOptions.rotationOrder,
        propOptions.syncRot
    )

    -- Clean up model from memory
    SetModelAsNoLongerNeeded(propHash)

    ps.debug('Tablet prop created and attached')
    return true
end

-- Function to destroy tablet prop
local function DestroyTabletProp()
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
        tabletProp = nil
        ps.debug('Tablet prop destroyed')
    end
end

-- /mdtprop x y z rx ry rz: re-grips the held tablet live, for fitting the prop to the
-- hand. /mdtprop <x|y|z|rx|ry|rz> <amount> nudges one value by that much instead
-- (e.g. /mdtprop rx 10, /mdtprop y -0.02). With no arguments it prints the current
-- values. Copy the result into Config.TabletProp.pos / rot to keep it.
local nudgeKeys = { x = 'xPos', y = 'yPos', z = 'zPos', rx = 'xRot', ry = 'yRot', rz = 'zRot' }

RegisterCommand('mdtprop', function(_, args)
    local n = {}
    for i = 1, 6 do n[i] = tonumber(args[i]) end
    local nudge = args[1] and nudgeKeys[args[1]:lower()]
    if nudge and tonumber(args[2]) then
        propOptions[nudge] = propOptions[nudge] + tonumber(args[2])
    elseif n[1] then
        propOptions.xPos = n[1] or propOptions.xPos
        propOptions.yPos = n[2] or propOptions.yPos
        propOptions.zPos = n[3] or propOptions.zPos
        propOptions.xRot = n[4] or propOptions.xRot
        propOptions.yRot = n[5] or propOptions.yRot
        propOptions.zRot = n[6] or propOptions.zRot
    end
    if nudge or n[1] then
        if tabletProp and DoesEntityExist(tabletProp) then
            local ped = getPed()
            DetachEntity(tabletProp, true, false)
            AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, propBone),
                propOptions.xPos, propOptions.yPos, propOptions.zPos,
                propOptions.xRot, propOptions.yRot, propOptions.zRot,
                propOptions.p9, propOptions.useSoftPinning, propOptions.collision,
                propOptions.isPed, propOptions.rotationOrder, propOptions.syncRot)
        end
    end
    print(('[ps-mdt] Config.TabletProp  pos = vec3(%.3f, %.3f, %.3f),  rot = vec3(%.1f, %.1f, %.1f)'):format(
        propOptions.xPos, propOptions.yPos, propOptions.zPos, propOptions.xRot, propOptions.yRot, propOptions.zRot))
end, false)

-- Animation Handling ---------------------------------

-- Function to play tablet animation
function PlayTabletAnimation()
    if isPlayingTabletAnim then
        return
    end

    local ped = getPed()

    if not ps.requestAnim(animDict) then
        ps.debug('Failed to load tablet animation dictionary')
        return
    end

    if IsPedUsingAnyScenario(ped) or IsPedActiveInScenario(ped) then
        ClearPedTasksImmediately(ped)
    end

    if not CreateTabletProp() then
        RemoveAnimDict(animDict)
        return
    end

    -- Yield once so the expensive entity work (CreateObject/AttachEntity above)
    -- and TaskPlayAnim below don't land on the same frame. Bail if the MDT was
    -- closed during the wait so we don't animate after close.
    Wait(0)
    if not MDTOpen then
        RemoveAnimDict(animDict)
        DestroyTabletProp()
        return
    end

    TaskPlayAnim(
        ped,
        animOptions.animDict,
        animOptions.animName,
        animOptions.blendInSpeed,
        animOptions.blendOutSpeed,
        animOptions.duration,
        animOptions.flag,
        animOptions.playbackRate,
        animOptions.lockX,
        animOptions.lockY,
        animOptions.lockZ
    )

    RemoveAnimDict(animDict)
    isPlayingTabletAnim = true
    ps.debug('Tablet animation started')
    StartAnimationMonitoring()
end

-- Stop tablet animation
function StopTabletAnimation()
    if not isPlayingTabletAnim then return end

    StopAnimationMonitoring()
    ClearPedTasks(getPed())
    DestroyTabletProp()

    isPlayingTabletAnim = false
    ps.debug('Tablet animation stopped')
end

-- Check if tablet animation is playing
function IsPlayingTabletAnimation()
    return isPlayingTabletAnim
end

-- Restart tablet animation
function RestartTabletAnimation()
    if not isPlayingTabletAnim then return end

    local ped = getPed()

    if not ps.requestAnim(animDict) then
        ps.debug('Failed to load tablet animation dictionary for restart')
        return
    end

    TaskPlayAnim(
        ped,
        animOptions.animDict,
        animOptions.animName,
        animOptions.blendInSpeed,
        animOptions.blendOutSpeed,
        animOptions.duration,
        animOptions.flag,
        animOptions.playbackRate,
        animOptions.lockX,
        animOptions.lockY,
        animOptions.lockZ
    )

    RemoveAnimDict(animDict)
end

-- Event Handlers ---------------------------------

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isPlayingTabletAnim then
        StopTabletAnimation()
    end
end)