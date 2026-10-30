-- ============================================================
-- main.lua  –  bablo-billing  (client)
-- ============================================================

local jobAccessGranted = false   -- shared across OpenJob / CanAccessJobAccount

-- Debug startup info
if Config.DEBUG then
    if not Framework then
        print("^1[FRAMEWORK] Framework object not found. Ensure framework files are loaded.^7")
    else
        print("^2[FRAMEWORK] Using framework: " .. Config.Framework .. "^7")
    end
end

-- Register open command + optional key mapping
Citizen.CreateThread(function()
    RegisterCommand(Config.OpenCommand, function()
        Open()
    end, false)

    if Config.OpenMenu then
        RegisterKeyMapping(Config.OpenCommand, "Open Billing Menu", "keyboard", Config.OpenMenu)
    end
end)

-- Opens billing menu after validating job access
function OpenJob()
    if not Framework then
        print("^1[BILLING] Framework not loaded yet^7")
        return
    end

    local playerData = Framework.GetPlayerData and Framework.GetPlayerData() or nil

    if not playerData or not playerData.job then
        if Framework.Notify then
            Framework.Notify("You don't have a job", "error")
        end
        return
    end

    local jobName = playerData.job.name
    local blockedJobs = Config.JobAccount.blockedJobs

    if blockedJobs and #blockedJobs > 0 then
        for _, blocked in ipairs(blockedJobs) do
            if jobName == blocked then
                if Framework.Notify then
                    Framework.Notify("Your job is not authorized to use billing system", "error")
                end
                return
            end
        end
    end

    jobAccessGranted = true

    SendNUIMessage({ type = "SET_JOB_ACCESS", data = { hasAccess = true } })
    Open()
end

-- Returns whether the player currently has job account access
function CanAccessJobAccount()
    local result

    if not Config.JobAccount.requireJobOpen then
        result = true
    else
        result = jobAccessGranted
    end

    if Config.DEBUG then
        print(string.format(
            "[BILLING] CanAccessJobAccount: requireJobOpen=%s, jobAccessGranted=%s, result=%s",
            tostring(Config.JobAccount.requireJobOpen),
            tostring(jobAccessGranted),
            tostring(result)
        ))
    end

    return result
end

-- Reset job access when resource stops or player drops
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        jobAccessGranted = false
    end
end)

AddEventHandler("playerDropped", function()
    jobAccessGranted = false
end)

-- ============================================================
-- DEBUG-ONLY commands
-- ============================================================
if Config.DEBUG then

    -- Finds the nearest vehicle within a given radius
    function getCloseVehicle(coords, radius)
        if not coords then
            coords = GetEntityCoords(PlayerPedId())
        end
        radius = radius or 5.0

        local closest, closestDist = nil, radius

        for _, vehicle in ipairs(GetGamePool("CVehicle")) do
            local dist = #(coords - GetEntityCoords(vehicle))
            if dist < closestDist then
                closest = vehicle
                closestDist = dist
            end
        end

        return closest
    end

    -- Plays an animation on a ped and waits until it finishes
    function playAnimationOnPed(ped, animData)
        if not ped or not animData.dict or not animData.name then
            Debug.error(Debug, "Invalid parameters for playAnimationOnPed")
            return
        end

        RequestAnimDict(animData.dict)
        while not HasAnimDictLoaded(animData.dict) do
            Wait(100)
        end

        TaskPlayAnim(ped, animData.dict, animData.name, 8.0, -8.0, -1, 1, 0, false, false, false)

        while IsEntityPlayingAnim(ped, animData.dict, animData.name, 3) do
            Wait(0)
        end

        ClearPedTasks(ped)
        Debug.info(Debug, "Animation played on ped:", ped, "Animation:", animData.name)
    end

    -- /rip – repairs the nearest vehicle engine
    RegisterCommand("rip", function()
        local vehicle = getCloseVehicle()
        if not vehicle then return end

        local animData = { dict = "mini@repair", name = "fixing_a_player" }

        if GetVehicleEngineHealth(vehicle) >= 1000 then
            if Framework.Notify then Framework.Notify("Vehicle engine is already repaired", "success") end
            TriggerServerEvent("closeBonnet", VehToNet(vehicle))
            return
        end

        TriggerServerEvent("openBonnet", VehToNet(vehicle))
        playAnimationOnPed(PlayerPedId(), animData)
        Citizen.Wait(5000)
        SetVehicleEngineHealth(vehicle, 1000.0)
        ClearPedTasks(PlayerPedId())
        if Framework.Notify then Framework.Notify("Repaired vehicle", "success") end
        TriggerServerEvent("closeBonnet", VehToNet(vehicle))
    end, false)

    -- /destroyengine – destroys the nearest vehicle engine
    RegisterCommand("destroyengine", function()
        local vehicle = getCloseVehicle()
        if not vehicle then return end

        local animData = { dict = "mini@repair", name = "fixing_a_player" }

        if GetVehicleEngineHealth(vehicle) <= 0 then
            if Framework.Notify then Framework.Notify("Vehicle engine is already destroyed") end
            return
        end

        TriggerServerEvent("openBonnet", VehToNet(vehicle))
        playAnimationOnPed(PlayerPedId(), animData)
        Citizen.Wait(5000)
        SetVehicleEngineHealth(vehicle, 0.0)
        ClearPedTasks(PlayerPedId())
        if Framework.Notify then Framework.Notify("Destroyed vehicle engine") end
    end, false)

    -- Network events for bonnet open/close (debug helpers)
    RegisterNetEvent("openBonnet")
    AddEventHandler("openBonnet", function(netVehicle)
        SetVehicleDoorOpen(NetToVeh(netVehicle), 4, false, false)
    end)

    RegisterNetEvent("closeBonnet")
    AddEventHandler("closeBonnet", function(netVehicle)
        local vehicle = NetToVeh(netVehicle)
        print("Closing bonnet")
        print(vehicle)
        SetVehicleDoorShut(vehicle, 4, false)
    end)
end
