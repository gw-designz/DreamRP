-- Wait for Config.BatteringRam to be available before proceeding
while true do
    if Config and Config.BatteringRam then
        break
    end
    Citizen.Wait(500)
end

local batteringRamConfig = Config.BatteringRam

if not batteringRamConfig.enabled then
    return
end

local nextUseTime = 0

-- Returns true if the local player's job is authorized to use the battering ram
function HasBatteringRamAccess()
    local playerJob = Bridge.Framework.fetchPlayerJob()
    local allowedJobs = batteringRamConfig.jobs or Config.Jobs

    if playerJob and allowedJobs then
        return nil ~= allowedJobs[playerJob.name]
    end

    return playerJob or allowedJobs
end

-- Spawns and attaches the battering ram prop to the player ped
-- Returns the prop entity, or nil if the model is invalid/unavailable
function SpawnBatteringRamProp()
    local propConfig = batteringRamConfig.prop

    if not (propConfig and propConfig.model) then
        return nil
    end

    local playerPed = cache.ped

    local modelHash
    if type(propConfig.model) == "number" then
        modelHash = propConfig.model
    else
        modelHash = joaat(propConfig.model)
    end

    if not IsModelValid(modelHash) then
        return nil
    end

    lib.requestModel(modelHash, 3000)

    if not HasModelLoaded(modelHash) then
        return nil
    end

    local spawnCoords = GetEntityCoords(playerPed)
    local propEntity = CreateObject(modelHash, spawnCoords, true, true, false)

    local boneIndex = GetPedBoneIndex(playerPed, propConfig.bone or 28422)

    local attachPos = propConfig.pos or vector3(0, 0, 0)
    local attachRot = propConfig.rot or vector3(0, 0, 0)

    AttachEntityToEntity(
        propEntity, playerPed, boneIndex,
        attachPos.x, attachPos.y, attachPos.z,
        attachRot.x, attachRot.y, attachRot.z,
        true, true, false, false, 1, true
    )

    SetModelAsNoLongerNeeded(modelHash)

    return propEntity
end

-- Deletes the prop entity if it exists
function CleanupProp(propEntity)
    if propEntity and DoesEntityExist(propEntity) then
        DeleteEntity(propEntity)
    end
end

-- Builds the progress bar options table for the battering ram animation
function BuildProgressOptions(animConfig)
    local options = {
        duration    = batteringRamConfig.duration or 2500,
        label       = locale("battering_ram_forcing"),
        useWhileDead = false,
        canCancel   = true,
        disable     = { move = true, car = true, combat = true },
    }

    if animConfig then
        options.anim = {
            dict  = animConfig.dict,
            clip  = animConfig.clip,
            flag  = animConfig.flag,
        }
    end

    return options
end

-- Core battering ram logic: job check → cooldown → prop → progress → force door
function UseBatteringRam()
    if not HasBatteringRamAccess() then
        Bridge.Notify.showNotify(locale("battering_ram_no_access"), "error")
        return
    end

    local currentTime = GetGameTimer()
    if currentTime < nextUseTime then
        return
    end

    local targetDoor = batteringRamConfig.getTargetDoor and batteringRamConfig.getTargetDoor()
    if not targetDoor then
        Bridge.Notify.showNotify(locale("battering_ram_no_door"), "error")
        return
    end

    -- Set cooldown before the progress bar so spam-clicking is blocked immediately
    nextUseTime = GetGameTimer() + (batteringRamConfig.cooldown or 6000)

    local propEntity = SpawnBatteringRamProp()
    local progressOptions = BuildProgressOptions(batteringRamConfig.anim)
    local completed = Bridge.Progress.Start(progressOptions)

    CleanupProp(propEntity)
    ClearPedTasks(cache.ped)

    if not completed then
        return
    end

    -- Re-fetch the door in case it changed during the progress bar
    local doorToForce = (batteringRamConfig.getTargetDoor and batteringRamConfig.getTargetDoor()) or targetDoor

    local success = batteringRamConfig.forceDoor and batteringRamConfig.forceDoor(doorToForce)

    if success then
        Bridge.Notify.showNotify(locale("battering_ram_success"), "success")
    else
        Bridge.Notify.showNotify(locale("battering_ram_failed"), "error")
    end
end

-- Net event: triggered from the server or other resources
RegisterNetEvent("p_policejob/client/batteringram/use", function()
    UseBatteringRam()
end)

-- Export for use by other resources
exports("useBatteringRam", UseBatteringRam)

-- Debug command: plays the battering ram hit animation on the local ped
RegisterCommand("play_ram", function()
    local animDict = lib.requestAnimDict("battering_ram")
    TaskPlayAnim(cache.ped, animDict, "hit", 8.0, 1.0, -1, 1, 0, false, false, false)
    RemoveAnimDict(animDict)
end)
