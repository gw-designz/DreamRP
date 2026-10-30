while true do
    if Config and Config.GPS then break end
    Citizen.Wait(500)
end

if not Config.GPS.enabled then return end

GPS = {}
GPS.state      = false
GPS.blips      = {}
GPS.panicBlips = {}

-- ============================================================
--  Blip management
-- ============================================================

function GPS.clear(self)
    for _, blip in pairs(self.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    self.blips = {}
end

function GPS.init(self, gpsData)
    self:clear()
    AddTextEntryByHash(1248374007, "GPS~w~")

    for serverId, playerData in pairs(gpsData) do
        local typeCfg = Config.GPS.types[playerData.type]
        if not typeCfg then goto continue end
        if typeCfg.enabled == false then goto continue end

        -- Per-job color/scale override
        local jobOverride = Config.GPS.jobs and Config.GPS.jobs[playerData.job]

        -- Try to attach blip to a live ped, fall back to coords
        local playerHandle = GetPlayerFromServerId(serverId)
        local blip = nil

        if playerHandle and playerHandle ~= 0 then
            local ped = GetPlayerPed(playerHandle)
            -- Don't blip ourselves (unless our server ID matches, but only show once)
            if ped == cache.ped and cache.serverId == serverId then
                goto continue
            end
            blip = AddBlipForEntity(ped)
        else
            blip = AddBlipForCoord(playerData.coords.x, playerData.coords.y, playerData.coords.z)
        end

        SetBlipSprite(blip,              typeCfg.sprite)
        SetBlipColour(blip,              jobOverride and jobOverride.color or typeCfg.color)
        SetBlipScale(blip,               jobOverride and jobOverride.scale or typeCfg.scale)
        SetBlipShrink(blip,              true)
        SetBlipPriority(blip,            10)
        ShowHeightOnBlip(blip,           false)
        SetBlipHiddenOnLegend(blip,      false)
        SetBlipCategory(blip,            7)
        SetBlipAsShortRange(blip,        false)
        ShowNumberOnBlip(blip,           "10")
        ShowHeadingIndicatorOnBlip(blip, Config.GPS.showHeading)
        SetBlipRotation(blip,            math.ceil(playerData.heading))

        local label = playerData.label
        if jobOverride and jobOverride.prefix then
            label = ("%s %s"):format(jobOverride.prefix, label)
        end
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(label)
        EndTextCommandSetBlipName(blip)

        self.blips[serverId] = blip

        if playerData.sirens then
            SetBlipColour(blip, jobOverride and jobOverride.sirenColor or typeCfg.sirenColor)
        end

        ::continue::
    end
end

-- ============================================================
--  Toggle GPS tracking on/off
-- ============================================================

function GPS.toggle(self)
    local job = Bridge.Framework.fetchPlayerJob()
    if not job or not Config.Jobs[job.name] then
        Bridge.Notify.showNotify(locale("no_access"), "error")
        return
    end

    self.state = not self.state

    -- Hide/show local player blip
    SetBlipScale(GetMainPlayerBlipId(), self.state and 0.0 or 0.9)

    TriggerServerEvent("p_policejob/gps/server/toggle")

    if not self.state then self:clear() end
end

-- ============================================================
--  Panic button
-- ============================================================

function GPS.panic(self)
    local job = Bridge.Framework.fetchPlayerJob()
    if not job or not Config.Jobs[job.name] then return end
    TriggerServerEvent("p_policejob/gps/server/panic")
end

-- ============================================================
--  Panic alert display (received from server)
-- ============================================================

function GPS.showPanicAlert(self, alertData)
    if not self.state then return end

    -- Remove any previous panic blip for this source
    local existingBlip = self.panicBlips[alertData.source]
    if existingBlip and DoesBlipExist(existingBlip) then
        RemoveBlip(existingBlip)
    end

    local panicCfg = Config.GPS.panic
    local blip     = AddBlipForCoord(alertData.coords.x, alertData.coords.y, alertData.coords.z)
    SetBlipSprite(blip,       panicCfg.blip.sprite)
    SetBlipColour(blip,       panicCfg.blip.color)
    SetBlipScale(blip,        panicCfg.blip.scale)
    SetBlipFlashes(blip,      panicCfg.blip.flash)
    SetBlipAsShortRange(blip, false)
    SetBlipPriority(blip,     10)
    SetBlipCategory(blip,     7)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(("~r~PANIC~w~ - %s"):format(alertData.name))
    EndTextCommandSetBlipName(blip)

    self.panicBlips[alertData.source] = blip

    if panicCfg.sound then
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", true)
    end

    Bridge.Notify.showNotify(("PANIC ALERT: %s"):format(alertData.name), "error")

    -- Auto-remove after configured duration
    Citizen.SetTimeout(panicCfg.duration * 1000, function()
        local b = self.panicBlips[alertData.source]
        if b and DoesBlipExist(b) then
            RemoveBlip(b)
            self.panicBlips[alertData.source] = nil
        end
    end)
end

-- ============================================================
--  Closest officer utility
-- ============================================================

function GPS.getClosestOfficer(self)
    local myCoords  = GetEntityCoords(cache.ped)
    local gpsData   = GlobalState["p_policejob/gpsData"]
    if not gpsData then return nil end

    local minDist  = math.huge
    local closestId, closestData = nil, nil

    for serverId, playerData in pairs(gpsData) do
        if serverId ~= cache.serverId then
            local dist = #(myCoords - vector3(playerData.coords.x, playerData.coords.y, playerData.coords.z))
            if dist < minDist then
                minDist     = dist
                closestId   = serverId
                closestData = playerData
            end
        end
    end

    if closestId then
        return { id = closestId, distance = minDist, data = closestData }
    end
    return nil
end

-- ============================================================
--  Exports
-- ============================================================

exports("isGpsActive",       function() return GPS.state end)
exports("triggerPanic",      function() GPS:panic() end)
exports("getClosestOfficer", function() return GPS:getClosestOfficer() end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/client/gps/toggle", function()
    GPS:toggle()
end)

RegisterNetEvent("p_policejob/client/gps/panic", function(alertData)
    if not Config.GPS.panic.enabled then return end
    GPS:showPanicAlert(alertData)
end)

-- ============================================================
--  State bag — re-render blips whenever GPS data updates
-- ============================================================

AddStateBagChangeHandler("p_policejob/gpsData", "global", function(_, _, newValue)
    if not GPS.state then return end

    local job = Bridge.Framework.fetchPlayerJob()
    if not job or not Config.Jobs[job.name] then
        GPS:clear()
        return
    end

    GPS:init(newValue)
end)
