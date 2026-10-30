-- ============================================================
-- functions.lua  –  bablo-billing  (client)
-- ============================================================

Displaying = false
Tablet    = nil

local resourceName = GetCurrentResourceName()

-- ── Open ─────────────────────────────────────────────────────
function Open()
    SetNuiFocus(true, true)

    SendNUIMessage({ event = "SET_THEME_CONFIG", data = Config.Theme or {} })
    SendNUIMessage({ event = "SET_OPEN",         data = true })
    SendNUIMessage({
        event = "SET_JOB_CONFIG",
        data  = {
            requireJobOpen                 = Config.JobAccount.requireJobOpen,
            hasAccess                      = CanAccessJobAccount(),
            allowPrivatePersonToSendInvoice = Config.Invoice.allowPrivatePersonToSendInvoice,
            useDefaultTemplates            = (false ~= Config.Invoice.showDefaultTemplates),
        }
    })

    setUser()
    Displaying = true
    CreateTablet()

    if not Tablet then return end

    local ped      = PlayerPedId()
    local boneIdx  = GetPedBoneIndex(ped, 28422)
    local animDict = "amb@code_human_in_bus_passenger_idles@female@tablet@idle_a"
    local animName = "idle_a"

    AttachEntityToEntity(Tablet, ped, boneIdx, -0.05, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    PlayAnimation(ped, { dict = animDict, name = animName }, {
        blendIn      = 8.0,
        blendOut     = 8.0,
        duration     = -1,
        flag         = 49,
        playbackRate = 1.0,
        lockX        = 0,
        lockY        = 0,
        lockZ        = 0,
    })
end

-- ── Close ────────────────────────────────────────────────────
function Close()
    SetNuiFocus(false, false)
    SendNUIMessage({ event = "SET_OPEN", data = false })

    if Tablet then
        if DoesEntityExist(Tablet) then
            DeleteEntity(Tablet)
        end
        Tablet = nil
    end

    Displaying = false
    ClearPedTasks(PlayerPedId())
end

-- ── setUser ──────────────────────────────────────────────────
-- Fetches user data from server and pushes it to NUI.
function setUser()
    local response = TriggerServerCallback({ eventName = "bablo-billing:GET_USER", args = {} })

    if not response or not response.success then
        Debug.error(Debug, "Failed to get user data:", response and response.error)
        return
    end

    SendNUIMessage({ event = "SET_USER", data = response })
    Debug.info(Debug, "User data set in NUI:", response)
end

-- ── CreateTablet ─────────────────────────────────────────────
function CreateTablet()
    AddEventHandler("onResourceStop", function(stoppedResource)
        if stoppedResource ~= resourceName then return end

        if Displaying then Close() end

        if Tablet and DoesEntityExist(Tablet) then
            DeleteEntity(Tablet)
            Tablet = nil
        end
    end)

    local playerCoords = table.unpack(GetEntityCoords(PlayerPedId()))
    local modelHash    = -1585232418  -- prop_cs_tablet_01 (⚠️ confirm hash if model changes)

    while not HasModelLoaded(modelHash) do
        RequestModel(modelHash)
        Wait(0)
    end

    local obj = CreateObject(modelHash, playerCoords, true, true, false)
    if obj == 0 then return end

    Tablet = obj
    return obj
end

-- ── PlayAnimation ────────────────────────────────────────────
function PlayAnimation(ped, animData, options)
    local dict = animData.dict
    local name = animData.name

    assert(DoesAnimDictExist(dict), "Animation dictionary does not exist")
    RequestAnimDict(dict)

    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(0)
    end

    local seqTask = OpenSequenceTask()
    TaskPlayAnim(0, dict, name,
        options.blendIn, options.blendOut, options.duration,
        options.flag, options.playbackRate,
        options.lockX, options.lockY, options.lockZ)
    CloseSequenceTask(seqTask)
    TaskPerformSequence(ped, seqTask)
    ClearSequenceTask(seqTask)
    RemoveAnimDict(dict)

    return true
end
