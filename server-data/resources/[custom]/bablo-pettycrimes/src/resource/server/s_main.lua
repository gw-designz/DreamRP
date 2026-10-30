-- ─── Resource Guard ───────────────────────────────────────────────────────────

eventName = "bablo-pettycrimes:"

Locales = Locales or {}

if GetCurrentResourceName() ~= "bablo-pettycrimes" then
    error("Resource name must be 'bablo-pettycrimes'")
    return
end

-- ─── Init Thread ──────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    Main:Init()
end)

-- ─── Employee Count Cache ─────────────────────────────────────────────────────
-- Caches online employee counts per job for 60 seconds to reduce Framework calls.

local employeeCountCache = {}

local function getCachedEmployeeCount(jobName)
    local now   = GetGameTimer()
    local entry = employeeCountCache[jobName]

    if entry and (now - entry.time) < 60000 then
        return entry.count
    end

    local employees = Framework:getEmployees(jobName)
    local count     = (employees and #employees) or 0

    employeeCountCache[jobName] = { count = count, time = now }
    return count
end

-- ─── Particle Sync Throttle ───────────────────────────────────────────────────
-- Tracks last syncParticles timestamp per source to throttle to 100ms.

local lastParticleSyncTime = {}

-- ─── Server Callbacks ─────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName     = eventName .. "server:hasItem",
    eventCallback = function(source, itemName)
        local player = Framework:fetchPlayer(source)
        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        local counts = Inventory:getPlayerItemsCount(source)
        local count  = counts and counts[itemName]

        -- ⚠️ Original code fetches counts twice and OR's: `count > 0 or count`.
        -- The second fetch is redundant — result is identical. Simplified to one fetch.
        if not count or count <= 0 then
            return { status = false, message = "NO_ITEM" }
        end

        return { status = true }
    end,
})

RegisterServerCallback({
    eventName     = eventName .. "server:getEmployees",
    eventCallback = function(source, jobName)
        if not Framework:fetchPlayer(source) then
            return { status = false, message = "NO_CHARACTER" }
        end
        if not jobName then
            return { status = false, message = "NO_JOB" }
        end

        local employees = Framework:getEmployees(jobName)
        if not employees then
            return { status = false, message = "NO_EMPLOYEES" }
        end

        return { status = true, employees = employees }
    end,
})

RegisterServerCallback({
    eventName     = eventName .. "server:getEmployeesCount",
    eventCallback = function(source, jobName)
        if not Framework:fetchPlayer(source) then
            return { status = false, message = "NO_CHARACTER" }
        end
        if not jobName then
            return { status = false, message = "NO_JOB" }
        end

        return { status = true, count = getCachedEmployeeCount(jobName) }
    end,
})

RegisterServerCallback({
    eventName     = eventName .. "server:playSound",
    eventCallback = function(source, data)
        if not Framework:fetchPlayer(source) then
            return { status = false, message = "NO_CHARACTER" }
        end
        if not data then
            return { status = false, message = "NO_DATA" }
        end
        if not data.sound then
            return { status = false, message = "NO_SOUND" }
        end
        if not data.coords then
            return { status = false, message = "NO_COORDS" }
        end

        local uniqueId = Main:generateUniqueId()
        local target   = data.synced and -1 or source

        exports.xsound:PlayUrlPos(target, uniqueId, data.sound, data.volume or 1.0, data.coords, data.loop and 1 or 0)
        exports.xsound:Distance(target, uniqueId, data.distance or 5.0)

        Main.activeSounds[uniqueId] = { owner = source, synced = target }

        return { status = true, uniqueId = uniqueId }
    end,
})

-- ─── Stop Sound ───────────────────────────────────────────────────────────────

RegisterServerEvent(eventName .. "server:stopSound")
AddEventHandler(eventName .. "server:stopSound", function(uniqueId)
    local sound = Main.activeSounds[uniqueId]
    if not sound then
        Trace("Sound not found", uniqueId)
        return
    end
    exports.xsound:Destroy(sound.synced, uniqueId)
end)

-- ─── Sync Particles ───────────────────────────────────────────────────────────

RegisterServerEvent(eventName .. "server:syncParticles")
AddEventHandler(eventName .. "server:syncParticles", function(...)
    local now       = GetGameTimer()
    local senderId  = source
    local lastTime  = lastParticleSyncTime[senderId]

    -- Throttle: ignore if called within 100ms
    if lastTime and (now - lastTime) < 100 then return end
    lastParticleSyncTime[senderId] = now

    local senderPed = GetPlayerPed(senderId)
    if not DoesEntityExist(senderPed) then return end

    local senderCoords  = GetEntityCoords(senderPed)
    local radiusSq      = 30.0 * 30.0

    for _, playerId in pairs(GetPlayers()) do
        if playerId ~= tostring(senderId) then
            local playerPed = GetPlayerPed(playerId)
            if DoesEntityExist(playerPed) then
                local playerCoords = GetEntityCoords(playerPed)
                local dx = senderCoords.x - playerCoords.x
                local dy = senderCoords.y - playerCoords.y
                local dz = senderCoords.z - playerCoords.z
                if (dx * dx + dy * dy + dz * dz) <= radiusSq then
                    TriggerClientEvent(eventName .. "client:syncParticles", playerId, ...)
                end
            end
        end
    end

    -- Also echo back to sender
    TriggerClientEvent(eventName .. "client:syncParticles", senderId, ...)
end)

-- ─── Set Entity State Bag ─────────────────────────────────────────────────────

RegisterServerEvent(eventName .. "server:setEntityStateBag")
AddEventHandler(eventName .. "server:setEntityStateBag", function(netId, stateData)
    local entity = NetworkGetEntityFromNetworkId(netId)

    if not entity or not DoesEntityExist(entity) then
        Trace(("Invalid entity from %s (netId: %s)"):format(source, netId))
        return
    end

    local entityState = Entity(entity).state
    for key, value in pairs(stateData) do
        entityState:set(key, value, true)
    end

    Trace(("State bag updated for entity %s by player %s"):format(netId, source))
end)

-- ─── Send Alert Broadcast ─────────────────────────────────────────────────────

RegisterNetEvent(eventName .. "server:sendAlert")
AddEventHandler(eventName .. "server:sendAlert", function(alertData)
    TriggerClientEvent(eventName .. "client:sendAlert", -1, alertData)
end)

-- ─── Cleanup on Resource Stop ─────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for uniqueId, _ in pairs(Main.activeSounds) do
        exports.xsound:Destroy(uniqueId)
    end
end)

-- ─── Cleanup on Player Drop ───────────────────────────────────────────────────

AddEventHandler("onPlayerDropped", function()
    local droppedSource = source

    for uniqueId, sound in pairs(Main.activeSounds) do
        if sound.owner == droppedSource then
            exports.xsound:Destroy(sound.synced, uniqueId)
        end
    end
end)
