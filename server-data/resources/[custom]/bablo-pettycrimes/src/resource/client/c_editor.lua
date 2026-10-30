-- Wait for eventName to be initialized by c_main.lua
while not eventName do
    Wait(0)
end

ConfigSyncReady = false

local configSyncReceived = false
local editorIsOpen = false

local function applyConfigOverrides(overrides)
    if not overrides then return end

    local configSections = {
        modules       = Config.Modules,
        minigames     = Config.Minigames,
        mugging       = Config.Mugging,
        mailboxes     = Config.Mailboxes,
        parkingMeters = Config.ParkingMeters,
        parcels       = Config.Parcels,
        pickPocketing = Config.PickPocketing,
        smashnGrab    = Config.SmashnGrab,
        vendingMachines = Config.VendingMachines,
        tireSlash     = Config.TireSlash,
        pedalBrick    = Config.PedalBrick,
        cashRegisters = Config.CashRegisters,
        atmRobbery    = Config.AtmRobbery,
        storeShelves  = Config.StoreShelves,
    }

    for key, section in pairs(configSections) do
        if overrides[key] and type(overrides[key]) == "table" then
            for k, v in pairs(overrides[key]) do
                section[k] = v
            end
        end
    end

    configSyncReceived = true
end

local function markConfigSyncReady()
    if ConfigSyncReady then return end
    ConfigSyncReady = true
    TriggerEvent(eventName .. "client:configSyncReady")
end

function WaitForConfigSync()
    if ConfigSyncReady then return end

    local elapsed = 0
    while not configSyncReceived and elapsed < 5000 do
        Citizen.Wait(100)
        elapsed = elapsed + 100
    end

    if not configSyncReceived then
        Trace("Config sync not received passively, requesting from server...")
        TriggerLatentServerEvent(eventName .. "server:requestConfigSync", 128000)

        elapsed = 0
        while not configSyncReceived and elapsed < 10000 do
            Citizen.Wait(100)
            elapsed = elapsed + 100
        end

        if not configSyncReceived then
            Trace("Config sync still not received after retry, proceeding with defaults")
        end
    end

    markConfigSyncReady()
end

local function serverCallback(callName, args, timeout, onTimeout)
    return TriggerServerCallback({
        eventName = eventName .. callName,
        args      = args or {},
        timeout   = timeout or 10,
        timedout  = onTimeout or function()
            Trace("Server callback timed out: " .. callName)
        end
    })
end

local function sendEditorNUI(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function pollRequirementsDelayed()
    Citizen.CreateThread(function()
        for _, delay in ipairs({ 500, 1500, 3000 }) do
            Citizen.Wait(delay)
            if not editorIsOpen then return end

            local result = serverCallback("editor:checkRequirements", {}, 15, function()
                Trace("Editor delayed requirements check timed out")
            end)

            if result and result.status and type(result.issues) == "table" then
                sendEditorNUI("EDITOR_REQUIREMENTS_UPDATED", { issues = result.issues })
            end
        end
    end)
end

RegisterCommand("pettycrimeseditor", function()
    if editorIsOpen then return end

    local configResult = serverCallback("editor:getConfig", {}, 10, function()
        Trace("Editor config request timed out")
    end)

    if not configResult or not configResult.status then
        Trace("Failed to open editor: " .. (configResult and configResult.message or "unknown"))
        return
    end

    local requirementsResult = serverCallback("editor:checkRequirements", {}, 15, function()
        Trace("Editor requirements precheck timed out")
    end)

    local requirements = {}
    if requirementsResult and requirementsResult.status and type(requirementsResult.issues) == "table" then
        requirements = requirementsResult.issues
    end

    editorIsOpen = true
    SetNuiFocus(true, true)

    sendEditorNUI("EDITOR_OPEN", {
        config       = configResult.config,
        items        = configResult.items,
        requirements = requirements,
    })

    pollRequirementsDelayed()
end, false)

RegisterNUICallback("editor:close", function(data, cb)
    editorIsOpen = false
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback("editor:reloadConfig", function(data, cb)
    local result = serverCallback("editor:getConfig", {}, 10, function()
        Trace("Editor reload config request timed out")
    end)

    if not result or not result.status then
        cb({ ok = false })
        return
    end

    sendEditorNUI("EDITOR_CONFIG_UPDATED", { config = result.config })
    cb({ ok = true })
end)

RegisterNUICallback("editor:save", function(data, cb)
    local result = serverCallback("editor:saveConfig", { data }, 10, function()
        Trace("Editor save request timed out")
    end)

    if not result or not result.status then
        cb({ ok = false, message = (result and result.message) or "Save failed" })
        return
    end

    cb({ ok = true })
end)

RegisterNUICallback("editor:getActiveVehicles", function(data, cb)
    local result = serverCallback("editor:getActiveVehicles", {
        {
            page     = data.page     or 1,
            pageSize = data.pageSize or 20,
        }
    }, 10, function()
        Trace("Editor get active vehicles timed out")
    end)

    if not result or not result.status then
        cb({ ok = false, vehicles = {}, total = 0, page = 1, pageSize = 20 })
        return
    end

    cb({
        ok       = true,
        vehicles = result.vehicles,
        total    = result.total,
        page     = result.page,
        pageSize = result.pageSize,
    })
end)

RegisterNUICallback("editor:getCooldowns", function(data, cb)
    local result = serverCallback("editor:getCooldowns", {
        { module = data.module }
    }, 10, function()
        Trace("Editor get cooldowns timed out")
    end)

    if not result or not result.status then
        cb({ ok = false, cooldowns = {} })
        return
    end

    cb({ ok = true, cooldowns = result.cooldowns })
end)

RegisterNUICallback("editor:clearCooldown", function(data, cb)
    local result = serverCallback("editor:clearCooldown", {
        { module = data.module, key = data.key }
    }, 10, function()
        Trace("Editor clear cooldown timed out")
    end)

    cb({ ok = (result and result.status) or false })
end)

RegisterNUICallback("editor:clearAllCooldowns", function(data, cb)
    local result = serverCallback("editor:clearAllCooldowns", {
        { module = data.module }
    }, 10, function()
        Trace("Editor clear all cooldowns timed out")
    end)

    cb({ ok = (result and result.status) or false })
end)

RegisterNUICallback("editor:teleportToVehicle", function(data, cb)
    if not data.coords then
        cb({ ok = false })
        return
    end

    local heading = data.heading or 0.0
    local angleRad = math.rad(heading + 90.0)
    local teleportX = data.coords.x + math.cos(angleRad) * 5.0
    local teleportY = data.coords.y + math.sin(angleRad) * 5.0
    local teleportZ = data.coords.z + 0.5

    local ped = PlayerPedId()
    RequestCollisionAtCoord(teleportX, teleportY, teleportZ)
    SetEntityCoords(ped, teleportX, teleportY, teleportZ, false, false, false, true)
    SetEntityHeading(ped, heading)

    cb({ ok = true })
end)

RegisterNUICallback("editor:removeVehicle", function(data, cb)
    local result = serverCallback("editor:removeVehicle", { data }, 10, function()
        Trace("Editor remove vehicle timed out")
    end)

    if not result or not result.status then
        cb({ ok = false, message = (result and result.message) or "Remove failed" })
        return
    end

    cb({ ok = true })
end)

RegisterNUICallback("editor:getSmashnGrabStats", function(data, cb)
    local result = serverCallback("editor:getSmashnGrabStats", {}, 10, function()
        Trace("Editor get smashngrab stats timed out")
    end)

    if not result or not result.status then
        cb({ ok = false })
        return
    end

    cb({
        ok             = true,
        debugEnabled   = result.debugEnabled,
        stats          = result.stats,
        activeVehicles = result.activeVehicles,
        vehicleLimit   = result.vehicleLimit,
        queueReady     = result.queueReady,
        queueWaiting   = result.queueWaiting,
        gameTime       = result.gameTime,
    })
end)

RegisterNUICallback("editor:toggleSmashnGrabDebug", function(data, cb)
    local result = serverCallback("editor:toggleSmashnGrabDebug", {}, 10, function()
        Trace("Editor toggle smashngrab debug timed out")
    end)

    cb({
        ok      = (result and result.status)  or false,
        enabled = (result and result.enabled) or false,
    })
end)

RegisterNUICallback("editor:resetSmashnGrabStats", function(data, cb)
    local result = serverCallback("editor:resetSmashnGrabStats", {}, 10, function()
        Trace("Editor reset smashngrab stats timed out")
    end)

    cb({ ok = (result and result.status) or false })
end)

RegisterNUICallback("editor:checkRequirements", function(data, cb)
    local result = serverCallback("editor:checkRequirements", {}, 15, function()
        Trace("Editor requirements check timed out")
    end)

    if not result or not result.status then
        cb({ ok = false, issues = {} })
        return
    end

    cb({ ok = true, issues = result.issues })
end)

RegisterNUICallback("editor:testDispatch", function(data, cb)
    local result = serverCallback("editor:testDispatch", { data.crimeType }, 10, function()
        Trace("Editor dispatch test timed out")
    end)

    if not result or not result.status then
        cb({ ok = false, message = (result and result.message) or "Dispatch test failed" })
        return
    end

    cb({ ok = true })
end)

RegisterNetEvent(eventName .. "editor:triggerTestDispatch")
AddEventHandler(eventName .. "editor:triggerTestDispatch", function(dispatchData)
    if not Dispatch or not Dispatch.Send then
        Trace("Dispatch system not available for test")
        return
    end

    Dispatch:Send({
        coords = vector3(dispatchData.coords.x, dispatchData.coords.y, dispatchData.coords.z),
        jobs   = { "police", "lspd", "bcso" },
        message     = dispatchData.message,
        description = dispatchData.description,
        blip = {
            sprite = 161,
            scale  = 1.0,
            colour = 1,
            text   = "[TEST] " .. dispatchData.message,
            time   = 30,
        }
    })
end)

RegisterNetEvent(eventName .. "editor:configUpdated")
AddEventHandler(eventName .. "editor:configUpdated", function(updatedConfig)
    if not updatedConfig then return end

    applyConfigOverrides(updatedConfig)
    markConfigSyncReady()

    sendEditorNUI("EDITOR_CONFIG_UPDATED", { config = updatedConfig })
end)
