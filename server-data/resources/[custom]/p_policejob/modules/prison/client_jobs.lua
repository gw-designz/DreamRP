if not (Config and Config.Prison and Config.Prison.Enabled) then return end
if not (Config.Prison.PrisonJobs and Config.Prison.PrisonJobs.enabled) then return end

-- ─── Module State ────────────────────────────────────────────────────────────

-- [jobId] = game timer timestamp when the cooldown expires
local jobCooldowns     = {}
-- The last completed job id (prevents immediate repeat)
local lastCompletedJobId = nil
-- Current active job state (or nil when no job is running)
local activeJob        = nil
-- Promise resolver for the built-in NUI minigame
local minigameResolver = nil

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

local function RemoveZone(zone)
    if not zone then return end
    if Bridge.Target and Bridge.Target.removeSphereZone then
        pcall(Bridge.Target.removeSphereZone, zone)
    else
        local ok, tgt = pcall(function() return exports.ox_target end)
        if ok and tgt then pcall(tgt.removeZone, tgt, zone) end
    end
end

local function DeleteDirtProps()
    if not (activeJob and activeJob.dirtProps) then return end
    for _, ent in ipairs(activeJob.dirtProps) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    activeJob.dirtProps = nil
end

-- Scatters random dirt/stain props around coords for the current job stop
local function SpawnDirtProps(jobId, coords)
    local dirtCfg = Config.Prison.PrisonJobs.dirtProps
    if not (dirtCfg and dirtCfg.enabled ~= false) then return end
    if dirtCfg.jobs and not dirtCfg.jobs[jobId] then return end

    local models = dirtCfg.models or {}
    if #models == 0 then return end

    local count  = math.max(0, tonumber(dirtCfg.count) or 0)
    local radius = tonumber(dirtCfg.radius) or 1.5
    local props  = {}

    for _ = 1, count do
        local model = models[math.random(#models)]
        local hash  = type(model) == "number" and model or joaat(model)
        if IsModelValid(hash) then
            lib.requestModel(hash, 5000)
            if HasModelLoaded(hash) then
                local angle = math.random() * 2 * math.pi
                local dist  = math.sqrt(math.random()) * radius
                local px    = coords.x + math.cos(angle) * dist
                local py    = coords.y + math.sin(angle) * dist
                local found, gz = GetGroundZFor_3dCoord(px, py, coords.z + 1.0, false)
                local pz    = (found and gz) or coords.z

                local ent = CreateObject(hash, px, py, pz, false, false, false)
                PlaceObjectOnGroundProperly(ent)
                SetEntityHeading(ent, math.random(0, 359) + 0.0)
                FreezeEntityPosition(ent, true)
                SetModelAsNoLongerNeeded(hash)
                props[#props + 1] = ent
            end
        end
    end

    activeJob.dirtProps = props
end

-- Cleans up the current stop's blip, zone, and dirt props
local function CleanupCurrentStop()
    if not activeJob then return end

    if activeJob.blip and DoesBlipExist(activeJob.blip) then
        RemoveBlip(activeJob.blip)
    end
    activeJob.blip = nil

    RemoveZone(activeJob.zoneId)
    activeJob.zoneId = nil

    DeleteDirtProps()
end

-- Returns a random location for the job from Prison.Map.jobLocations[jobId],
-- avoiding coords too close to avoidCoords (up to 8 tries)
local function GetRandomJobLocation(jobId, avoidCoords)
    local locations = Prison.Map and Prison.Map.jobLocations and Prison.Map.jobLocations[jobId]
    if not (locations and #locations > 0) then return nil end

    if #locations == 1 or not avoidCoords then
        return locations[math.random(#locations)]
    end

    local picked
    for _ = 1, 8 do
        local candidate = locations[math.random(#locations)]
        picked = candidate
        if #(vector3(candidate.x, candidate.y, candidate.z) - avoidCoords) > 0.5 then
            return candidate
        end
    end

    return picked
end

-- Builds the job list table for the NUI (with cooldown + locked state)
local function BuildJobListForUI()
    local now  = GetGameTimer()
    local list = {}

    local iconMap = { cleaning = "bubbles", laundry = "shirt", kitchen = "chef" }

    for _, jobDef in ipairs(Config.Prison.PrisonJobs.defaultJobs or {}) do
        local cooldownEnd = jobCooldowns[jobDef.id] or 0
        local onCooldown  = now < cooldownEnd

        list[#list + 1] = {
            id           = jobDef.id,
            label        = jobDef.label,
            description  = jobDef.description,
            payment      = jobDef.payment,
            duration     = jobDef.duration,
            timeReduction = jobDef.timeReduction,
            icon         = iconMap[jobDef.id],
            onCooldown   = onCooldown,
            cooldownLeft = onCooldown and math.ceil((cooldownEnd - now) / 1000) or 0,
            locked       = jobDef.id == lastCompletedJobId,
        }
    end

    return list
end

-- ─── Minigame ────────────────────────────────────────────────────────────────

-- Runs whichever minigame variant is configured; returns bool success
local function RunMinigame(jobDef)
    local mgCfg = Config.Prison.Minigames

    -- External export (from another resource)
    if mgCfg and mgCfg.useExternal and type(mgCfg.externalExport) == "function" then
        local ok, result = pcall(mgCfg.externalExport)
        if ok then return result == true end
    end

    local prisonMgCfg = Config.Prison.PrisonJobs.minigame or {}

    -- Custom Lua function
    if prisonMgCfg.useCustom and type(prisonMgCfg.customRun) == "function" then
        local ok, result = pcall(prisonMgCfg.customRun, jobDef)
        if ok then return result == true end
    end

    -- Per-job or default variant
    local variant = (prisonMgCfg.perJob and prisonMgCfg.perJob[jobDef.id])
        or prisonMgCfg.default
        or "scrub"

    -- Built-in NUI minigame
    local p = promise.new()
    minigameResolver = function(success)
        if p then
            local res = p
            p = nil
            res:resolve(success == true)
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "setVisiblePrisonMinigame",
        data   = {
            variant = variant,
            label   = jobDef.label or "Prison Task",
        },
    })

    local result = Citizen.Await(p)

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisiblePrisonMinigame", data = false })

    return result
end

-- ─── Animation Helper ────────────────────────────────────────────────────────

local function PlayAnimAndWait(animDef, durationMs)
    if not (animDef and animDef.dict and animDef.clip) then
        Wait(durationMs)
        return
    end

    lib.requestAnimDict(animDef.dict)
    TaskPlayAnim(cache.ped, animDef.dict, animDef.clip,
        4.0, -4.0, durationMs, 1, 0, false, false, false)
    Wait(durationMs)
    ClearPedTasks(cache.ped)
end

-- ─── Stop Advance ────────────────────────────────────────────────────────────

-- Forward declaration
local AdvanceToNextStop

-- onSelect handler for a job stop zone:
-- plays anim → minigame → on success increments done count
local function OnStopSelected()
    if not (activeJob and not activeJob.busy) then return end
    if not Prison.isInPrison then return end

    activeJob.busy = true

    -- Short starter animation
    PlayAnimAndWait(activeJob.jobDef.animation, 200)

    -- Pre-warm anim dict
    lib.requestAnimDict(
        (activeJob.jobDef.animation and activeJob.jobDef.animation.dict) or ""
    )

    -- Loop animation
    if activeJob.jobDef.animation then
        TaskPlayAnim(cache.ped,
            activeJob.jobDef.animation.dict,
            activeJob.jobDef.animation.clip,
            4.0, -4.0, -1, 1, 0, false, false, false)
    end

    -- Run the minigame
    local passed = RunMinigame(activeJob.jobDef)
    ClearPedTasks(cache.ped)

    if not passed then
        Bridge.Notify.showNotify(locale("prison_job_failed"), "error")
        activeJob.busy = false
        return
    end

    activeJob.stopsDone = activeJob.stopsDone + 1
    Bridge.Notify.showNotify(
        locale("prison_job_task_progress", activeJob.stopsDone, activeJob.stopsTotal),
        "success"
    )

    CleanupCurrentStop()

    if activeJob.stopsDone >= activeJob.stopsTotal then
        -- Job complete
        local jobDef      = activeJob.jobDef
        local stopsCompleted = activeJob.stopsDone
        local duration    = (jobDef.duration or 30) * 1000

        jobCooldowns[jobDef.id] = GetGameTimer() + duration
        lastCompletedJobId = jobDef.id
        activeJob          = nil

        TriggerServerEvent("p_policejob/server/prison/jobComplete", {
            jobId          = jobDef.id,
            stopsCompleted = stopsCompleted,
        })

        local pay = (jobDef.payment or 0) * stopsCompleted
        local red = (jobDef.timeReduction or 0) * stopsCompleted
        Bridge.Notify.showNotify(
            string.format("Shift complete! +$%d, -%d min off your sentence", pay, red),
            "success"
        )
        Bridge.Notify.showNotify(locale("prison_job_talk_to_guard"), "info")
        return
    end

    activeJob.busy = false
    AdvanceToNextStop()
end

-- Advances to the next stop: picks a new location, spawns dirt props, adds blip + zone
AdvanceToNextStop = function()
    if not activeJob then return end

    local jobDef    = activeJob.jobDef
    local nextCoords = GetRandomJobLocation(jobDef.id, activeJob.currentCoords)

    if not nextCoords then
        Bridge.Notify.showNotify(locale("prison_job_no_locations"), "error")
        CleanupCurrentStop()
        activeJob = nil
        return
    end

    activeJob.currentCoords = vector3(nextCoords.x, nextCoords.y, nextCoords.z)

    SpawnDirtProps(jobDef.id, activeJob.currentCoords)

    -- Blip
    local blipCfg = Config.Prison.PrisonJobs.stopBlip or {}
    local blip    = AddBlipForCoord(nextCoords.x, nextCoords.y, nextCoords.z)
    SetBlipSprite(blip, blipCfg.sprite or 280)
    SetBlipColour(blip, blipCfg.color  or 5)
    SetBlipScale(blip,  blipCfg.scale  or 0.9)
    SetBlipAsShortRange(blip, true)
    SetBlipRoute(blip, true)

    local blipLabel = string.format("%s (%d/%d)",
        blipCfg.label or "Prison Task",
        activeJob.stopsDone + 1,
        activeJob.stopsTotal)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(blipLabel)
    EndTextCommandSetBlipName(blip)
    activeJob.blip = blip

    -- Target zone
    local zoneName = string.format("p_policejob_prison_job_stop_%d", GetGameTimer())
    local zone = Bridge.Target.addSphereZone({
        coords    = activeJob.currentCoords,
        radius    = 1.2,
        debug     = Bridge.Config and Bridge.Config.Debug,
        drawSprite = true,
        options   = {
            {
                name     = zoneName,
                label    = jobDef.label or "Work",
                icon     = "fa-solid fa-broom",
                distance = 1.8,
                onSelect = OnStopSelected,
            },
        },
    })
    activeJob.zoneId = zone
end

-- Marker draw thread for the current stop
local function StartStopMarkerThread()
    CreateThread(function()
        local markerCfg  = Config.Prison.PrisonJobs.stopMarker or {}
        if markerCfg.enabled == false then return end

        local color     = markerCfg.color or { r = 255, g = 170, b = 40, a = 200 }
        local size      = markerCfg.size  or 0.35
        local drawDist  = markerCfg.drawDistance or 60.0
        local height    = markerCfg.height       or 1.4

        while activeJob do
            if activeJob.currentCoords then
                local dist = #(GetEntityCoords(cache.ped) - activeJob.currentCoords)

                if dist <= drawDist then
                    DrawMarker(markerCfg.type or 2,
                        activeJob.currentCoords.x,
                        activeJob.currentCoords.y,
                        activeJob.currentCoords.z + height,
                        0, 0, 0, 180, 0, 0,
                        size, size, size,
                        color.r, color.g, color.b, color.a,
                        true, false, 2, true, nil, nil, false)
                    Wait(0)
                else
                    Wait(400)
                end
            else
                Wait(200)
            end
        end
    end)
end

-- ─── Start / Open UI ─────────────────────────────────────────────────────────

-- Validates and starts the given job definition
local function StartJob(jobDef)
    if activeJob then
        return Bridge.Notify.showNotify(locale("prison_job_already_active"), "error")
    end

    if jobDef.id == lastCompletedJobId then
        return Bridge.Notify.showNotify(locale("prison_job_repeat"), "error")
    end

    local cooldownEnd = jobCooldowns[jobDef.id]
    if cooldownEnd and GetGameTimer() < cooldownEnd then
        return Bridge.Notify.showNotify(locale("prison_job_cooldown"), "error")
    end

    local stopsTotal = math.max(1, tonumber(Config.Prison.PrisonJobs.stopsPerJob) or 5)

    activeJob = {
        jobDef       = jobDef,
        stopsTotal   = stopsTotal,
        stopsDone    = 0,
        currentCoords = nil,
        blip         = nil,
        zoneId       = nil,
        busy         = false,
    }

    Bridge.Notify.showNotify(
        string.format("Shift started: %s. Complete %d tasks marked on your map.",
            jobDef.label, stopsTotal),
        "info"
    )

    AdvanceToNextStop()
    StartStopMarkerThread()
end

-- Opens the prison jobs NUI
function openPrisonJobsUI()
    if not Prison.isInPrison then
        return Bridge.Notify.showNotify(locale("prison_job_not_in_prison"), "error")
    end
    if activeJob then
        return Bridge.Notify.showNotify(locale("prison_job_already_active"), "error")
    end

    SendNUIMessage({ action = "setVisiblePrisonJobs",  data = true })
    SendNUIMessage({ action = "setPrisonJobsData",      data = { jobs = BuildJobListForUI() } })
    SetNuiFocus(true, true)
end

-- Cancels the active job and clears NUI / minigame state
local function CancelActiveJob(message)
    if not activeJob then return end

    CleanupCurrentStop()
    activeJob = nil
    ClearPedTasks(cache.ped)

    if minigameResolver then
        local r = minigameResolver
        minigameResolver = nil
        r(false)
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisiblePrisonMinigame", data = false })

    if message then
        Bridge.Notify.showNotify(message, "error")
    end
end

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("prison/jobs/close", function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisiblePrisonJobs", data = false })
    cb({})
end)

RegisterNUICallback("prison/minigame/result", function(payload, cb)
    cb({})
    local resolver = minigameResolver
    minigameResolver = nil
    if resolver then
        resolver(payload and payload.success == true)
    end
end)

-- NUI: player selected a job from the jobs screen
RegisterNUICallback("prison/jobs/complete", function(payload, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisiblePrisonJobs", data = false })
    cb({})

    if not (payload and payload.jobId) then return end
    if not Prison.isInPrison then return end

    -- Find the job definition
    local jobDef = nil
    for _, def in ipairs(Config.Prison.PrisonJobs.defaultJobs or {}) do
        if def.id == payload.jobId then
            jobDef = def
            break
        end
    end

    if jobDef then StartJob(jobDef) end
end)

-- ─── Net Events ──────────────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/client/prison/openJobs", function()
    openPrisonJobsUI()
end)

-- Cancel job on release
RegisterNetEvent("p_policejob/client/prison/release", function()
    CancelActiveJob()
end)

-- ─── Events & Exports ────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupCurrentStop()
    end
end)

exports("openPrisonJobs", function()
    openPrisonJobsUI()
end)
