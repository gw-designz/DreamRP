if not (Config and Config.Prison and Config.Prison.Enabled) then return end
if not (Config.Prison.OfficerTasks and Config.Prison.OfficerTasks.enabled) then return end

-- ─── Module State ────────────────────────────────────────────────────────────

local activeTaskDef   = nil    -- current OfficerTasks task definition or nil
local activeBlip      = nil    -- blip for the current waypoint
local activeZone      = nil    -- target zone for the current waypoint
local activeTaskCoords = nil   -- vec3 of the current waypoint
local waypointIndex   = 0      -- current index along a patrol route / cell list

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function RemoveZone(zone)
    if not zone then return end
    if Bridge.Target and Bridge.Target.removeSphereZone then
        pcall(Bridge.Target.removeSphereZone, zone)
    end
end

-- Removes blip, zone, and resets waypoint state (does NOT clear activeTaskDef)
local function CleanupCurrentWaypoint()
    if activeBlip and DoesBlipExist(activeBlip) then RemoveBlip(activeBlip) end
    activeBlip = nil

    RemoveZone(activeZone)
    activeZone = nil

    activeTaskCoords = nil
end

-- Fully cancels the active officer task
local function CancelOfficerTask(silent)
    CleanupCurrentWaypoint()
    activeTaskDef    = nil
    waypointIndex    = 0
    ClearPedTasks(cache.ped)

    if not silent then
        Bridge.Notify.showNotify(locale("prison_officer_task_cancel"), "info")
    end
end

-- Creates a route blip at coords with the given label string
local function CreateWaypointBlip(coords, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, true)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ─── Marker Draw Thread ───────────────────────────────────────────────────────

local function StartMarkerThread()
    CreateThread(function()
        while activeTaskDef do
            if activeTaskCoords then
                local dist = #(GetEntityCoords(cache.ped) - activeTaskCoords)

                if dist <= 60.0 then
                    local isCellInspection = activeTaskDef.id == "cell_inspection"

                    -- Chevron above the point
                    DrawMarker(2,
                        activeTaskCoords.x, activeTaskCoords.y,
                        activeTaskCoords.z + (isCellInspection and 1.0 or 1.4),
                        0, 0, 0, 180, 0, 0,
                        0.35, 0.35, 0.35,
                        59, 130, 246, 200,
                        true, false, 2, true, nil, nil, false)

                    -- Flat circle on the ground (not for cell inspection)
                    if not isCellInspection then
                        DrawMarker(1,
                            activeTaskCoords.x, activeTaskCoords.y,
                            activeTaskCoords.z - 0.98,
                            0, 0, 0, 0, 0, 0,
                            2.0, 2.0, 0.5,
                            59, 130, 246, 90,
                            false, false, 2, false, nil, nil, false)
                    end

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

-- ─── Animation Helper ────────────────────────────────────────────────────────

local function PlayAnimAndWait(animDef, durationMs)
    if not (animDef and animDef.dict and animDef.clip) then
        Wait(durationMs or 0)
        return
    end

    lib.requestAnimDict(animDef.dict)
    TaskPlayAnim(cache.ped, animDef.dict, animDef.clip,
        4.0, -4.0, durationMs or -1, 1, 0, false, false, false)
    if durationMs then
        Wait(durationMs)
        ClearPedTasks(cache.ped)
    end
end

-- ─── Task Complete ────────────────────────────────────────────────────────────

-- Marks the task complete: cleans up, resets state, notifies
local function CompleteTask()
    CleanupCurrentWaypoint()
    local finishedDef = activeTaskDef
    activeTaskDef = nil
    waypointIndex = 0

    Bridge.Notify.showNotify(locale("prison_officer_task_done"), "success")
    return finishedDef
end

-- ─── Patrol Route ─────────────────────────────────────────────────────────────

-- Forward declaration
local AdvancePatrolWaypoint

-- onSelect handler for a patrol waypoint zone
local function OnPatrolWaypointReached()
    if not activeTaskDef then return end

    local waypoints = Prison.Map and Prison.Map.officerPatrolWaypoints
    if not (waypoints and #waypoints > 0) then return end

    -- Verify the player is close enough (≤ 3m) and this waypoint is still the active one
    if #(GetEntityCoords(cache.ped) - activeTaskCoords) > 3.0 then return end

    CleanupCurrentWaypoint()
    AdvancePatrolWaypoint(activeTaskDef)
end

-- Advances to the next patrol waypoint, or completes the route
AdvancePatrolWaypoint = function(taskDef)
    local waypoints = Prison.Map and Prison.Map.officerPatrolWaypoints
    if not (waypoints and #waypoints > 0) then
        Bridge.Notify.showNotify(locale("prison_officer_no_waypoints"), "error")
        CancelOfficerTask(true)
        return
    end

    waypointIndex = waypointIndex + 1

    if waypointIndex > #waypoints then
        CompleteTask()
        return
    end

    local wp      = waypoints[waypointIndex]
    local wpCoords = vector3(wp.x, wp.y, wp.z)
    activeTaskCoords = wpCoords

    activeBlip = CreateWaypointBlip(wpCoords,
        string.format("Patrol %d/%d", waypointIndex, #waypoints))

    Bridge.Notify.showNotify(
        locale("prison_officer_patrol_next", waypointIndex, #waypoints), "info")

    local zoneName = "p_policejob_prison_patrol_" .. GetGameTimer()
    local capturedIndex = waypointIndex

    activeZone = Bridge.Target.addSphereZone({
        coords     = wpCoords,
        radius     = 2.0,
        debug      = false,
        drawSprite = true,
        options    = {
            {
                name     = zoneName,
                label    = string.format("Reach point %d/%d", waypointIndex, #waypoints),
                icon     = "fa-solid fa-person-walking",
                distance = 2.0,
                onSelect = function()
                    if not activeTaskDef then return end
                    if capturedIndex ~= waypointIndex then return end

                    local dist = #(GetEntityCoords(cache.ped) - wpCoords)
                    if dist > 3.0 then return end

                    CleanupCurrentWaypoint()
                    AdvancePatrolWaypoint(taskDef)
                end,
            },
        },
    })
end

-- ─── Cell Inspection ──────────────────────────────────────────────────────────

-- Runs a cell inspection task: visits up to 3 cells, using a progress bar at each
local function StartCellInspection(taskDef)
    local cells = Prison.Map and Prison.Map.cells
    if not (cells and #cells > 0) then
        Bridge.Notify.showNotify(locale("prison_officer_no_cells"), "error")
        CancelOfficerTask(true)
        return
    end

    local totalCells   = math.min(3, #cells)
    local inspectedCount = 0
    local inspecting   = false

    -- Recursive function to set up the next cell zone
    local function NextCell()
        if not activeTaskDef then return end

        if inspectedCount >= totalCells then
            CompleteTask()
            return
        end

        local cell       = cells[inspectedCount + 1]
        local cellCoords = vector3(cell.coords.x, cell.coords.y, cell.coords.z)
        activeTaskCoords = cellCoords

        activeBlip = CreateWaypointBlip(cellCoords,
            string.format("%s %d/%d", taskDef.label, inspectedCount + 1, totalCells))

        Bridge.Notify.showNotify(
            locale("prison_officer_goto_cell", inspectedCount + 1, totalCells), "info")

        local capturedCount = inspectedCount

        activeZone = Bridge.Target.addSphereZone({
            coords     = cellCoords,
            radius     = 1.5,
            debug      = false,
            drawSprite = true,
            options    = {
                {
                    name     = string.format("p_policejob_prison_inspect_%d", cell.id),
                    label    = locale("prison_officer_inspect_cell")
                        .. " " .. (cell.label or tostring(cell.id)),
                    icon     = "fa-solid fa-magnifying-glass",
                    distance = 1.8,
                    onSelect = function()
                        if not activeTaskDef then return end
                        if inspecting then return end

                        inspecting = true

                        local completed = Bridge.Progress.Start({
                            duration     = taskDef.duration or 8000,
                            label        = locale("prison_officer_inspecting"),
                            useWhileDead = false,
                            canCancel    = true,
                            disable      = { move = true, car = true, combat = true },
                            anim         = taskDef.animation,
                        })

                        inspecting = false

                        if not (completed and activeTaskDef) then return end

                        inspectedCount = inspectedCount + 1
                        RemoveZone(activeZone)
                        activeZone = nil

                        Bridge.Notify.showNotify(
                            locale("prison_officer_cell_inspected", inspectedCount, totalCells),
                            "success")

                        NextCell()
                    end,
                },
            },
        })
    end

    NextCell()
end

-- ─── Start Task ───────────────────────────────────────────────────────────────

local function StartOfficerTask(taskDef)
    if activeTaskDef then
        return Bridge.Notify.showNotify(locale("prison_officer_active_task"), "error")
    end

    if not Prison:hasJobAccess() then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    activeTaskDef = taskDef
    waypointIndex = 0
    StartMarkerThread()

    Bridge.Notify.showNotify(locale("prison_officer_task_started", taskDef.label), "info")

    if taskDef.id == "patrol_route" then
        AdvancePatrolWaypoint(taskDef)

    elseif taskDef.id == "cell_inspection" then
        StartCellInspection(taskDef)

    else
        -- Generic task: play animation then complete
        PlayAnimAndWait(taskDef.animation, taskDef.duration or 5000)
        CompleteTask()
    end
end

-- ─── Prison Methods ───────────────────────────────────────────────────────────

-- Returns a list of task definitions formatted for the management NUI
function Prison:getOfficerTasksForUI()
    local list = {}
    for _, taskDef in ipairs(Config.Prison.OfficerTasks.tasks or {}) do
        list[#list + 1] = {
            id          = taskDef.id,
            label       = taskDef.label,
            description = taskDef.description,
        }
    end
    return list
end

-- Returns the currently active task id, or nil
function Prison:getActiveOfficerTaskId()
    return activeTaskDef and activeTaskDef.id or nil
end

-- Starts a task by its id string; returns true on success
function Prison:startOfficerTaskById(taskId)
    for _, taskDef in ipairs(Config.Prison.OfficerTasks.tasks or {}) do
        if taskDef.id == taskId then
            StartOfficerTask(taskDef)
            return true
        end
    end
    return false
end

-- Cancels the active officer task
function Prison:cancelOfficerTask()
    if activeTaskDef then CancelOfficerTask() end
end

-- Opens the prison management NUI directly on the tasks tab
function Prison:openOfficerTasks()
    if not self:hasJobAccess() then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    self:openManagement()
    SendNUIMessage({ action = "setPrisonManagementTab", data = "tasks" })
end

-- ─── Commands / Events / Exports ─────────────────────────────────────────────

RegisterCommand("prisontasks", function()
    Prison:openOfficerTasks()
end, false)

RegisterNetEvent("p_policejob/client/prison/openOfficerTasks", function()
    Prison:openOfficerTasks()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupCurrentWaypoint()
    end
end)

exports("openPrisonOfficerTasks", function()
    Prison:openOfficerTasks()
end)
