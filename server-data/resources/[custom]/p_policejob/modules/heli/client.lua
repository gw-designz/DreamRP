-- Wait for Config.Helicam to be available
while not (Config and Config.Helicam) do Citizen.Wait(500) end

if not Config.Helicam.Enabled then return end

local heliConfig = Config.Helicam

-- Vision mode numeric constants
local VISION_NORMAL  = 0
local VISION_NIGHT   = 1
local VISION_THERMAL = 2

-- Vision mode → string label (sent to NUI)
local VISION_LABELS = {
    [VISION_NORMAL]  = "normal",
    [VISION_NIGHT]   = "night",
    [VISION_THERMAL] = "thermal",
}

-- Global Helicam object shared across the resource
Helicam = {
    active          = false,
    cam             = nil,
    fov             = heliConfig.FovDefault,
    vision          = VISION_NORMAL,
    spotlight       = false,
    spotlightRadius = (heliConfig.Spotlight and heliConfig.Spotlight.Radius) or 13.0,
    lockedEntity    = nil,
    heli            = nil,
}

-- ─── Spotlight Config ─────────────────────────────────────────────────────────

local spotlightCfg   = heliConfig.Spotlight or {}
local SPOT_COLOR     = spotlightCfg.Color      or { 245, 245, 220 }
local SPOT_DISTANCE  = spotlightCfg.Distance   or 250.0
local SPOT_BRIGHT    = spotlightCfg.Brightness or 25.0
local SPOT_HARDNESS  = spotlightCfg.Hardness   or 0.0
local SPOT_RADIUS    = spotlightCfg.Radius     or 13.0
local SPOT_FALLOFF   = spotlightCfg.Falloff    or 28.0
local SPOT_RADIUS_MIN  = spotlightCfg.RadiusMin  or 4.0
local SPOT_RADIUS_MAX  = spotlightCfg.RadiusMax  or 40.0
local SPOT_RADIUS_STEP = spotlightCfg.RadiusStep or 1.5
local SPOT_SMOOTHING   = spotlightCfg.Smoothing  or 12.0

-- ─── Synced Spotlight Table ───────────────────────────────────────────────────
-- spotlights[networkId] = { dir = {x,y,z}, radius = number, cur = {x,y,z} }
local spotlights        = {}
local spotlightThreadActive = false

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Returns true if the local player's job allows helicam use
function PlayerHasHelicamAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    if not (job and job.name) then return false end

    local threshold = Config.Jobs[job.name]
    if threshold == nil then return false end

    return threshold <= (job.grade or 0)
end

-- Returns the vehicle the local ped is currently in (if valid and allowed)
function GetCurrentHelicamVehicle()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if not (vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)) then return nil end

    if heliConfig.RestrictToHelicopter and GetVehicleClass(vehicle) ~= 15 then
        return nil
    end

    if not heliConfig.AllowPilot then
        if GetPedInVehicleSeat(vehicle, -1) == cache.ped then
            return nil
        end
    end

    return vehicle
end

-- Applies the current vision mode (nightvision / thermal / normal)
function ApplyVisionMode(visionMode)
    if visionMode == VISION_NIGHT then
        SetSeethrough(false)
        SetNightvision(true)
    elseif visionMode == VISION_THERMAL then
        SetNightvision(false)
        SetSeethrough(true)
        local maxThickness = math.max(0.0, math.min(10000.0, heliConfig.ThermalMaxThickness or 10000.0))
        SeethroughSetMaxThickness(maxThickness)
    else
        SetNightvision(false)
        SetSeethrough(false)
    end
end

-- Returns the forward direction vector from the given scripted camera's rotation
function GetCameraForwardVector(camHandle)
    if not camHandle then
        return { x = 0.0, y = 0.0, z = -1.0 }
    end

    local rot = GetCamRot(camHandle, 2)
    local sinZ = math.sin(math.rad(rot.z))
    local cosX = math.cos(math.rad(rot.x))

    return {
        x = -sinZ * cosX,
        y =  math.cos(math.rad(rot.z)) * cosX,
        z =  math.sin(math.rad(rot.x)),
    }
end

-- Returns info about the locked entity for the NUI (type + label), or false
function GetLockedEntityInfo(entity)
    if not (entity and DoesEntityExist(entity)) then return nil end

    if IsEntityAVehicle(entity) then
        local plate = (GetVehicleNumberPlateText(entity) or ""):gsub("%s+$", ""):gsub("^%s+", "")
        return {
            type  = "vehicle",
            label = (plate == "") and "----" or plate,
        }
    elseif IsEntityAPed(entity) then
        return { type = "ped", label = "" }
    end

    return nil
end

-- ─── Spotlight Radius ─────────────────────────────────────────────────────────

-- Sets the spotlight radius clamped to [RadiusMin, RadiusMax], syncs to server
function SetSpotlightRadius(newRadius)
    local clamped = math.max(SPOT_RADIUS_MIN, math.min(SPOT_RADIUS_MAX, newRadius))
    if clamped == Helicam.spotlightRadius then return end

    Helicam.spotlightRadius = clamped

    if not Helicam.spotlight then return end
    if not (Helicam.heli and DoesEntityExist(Helicam.heli)) then return end

    local netId = NetworkGetNetworkIdFromEntity(Helicam.heli)
    if netId and netId ~= 0 then
        TriggerServerEvent("p_policejob:heli:updateSpotlightRadius", netId, clamped)
    end
end

-- ─── Spotlight Toggle ─────────────────────────────────────────────────────────

-- Toggles the spotlight on/off for the current heli; syncs to server
function SetSpotlightActive(enable)
    if not heliConfig.EnableSpotlight then return end
    if not (Helicam.heli and DoesEntityExist(Helicam.heli)) then return end

    Helicam.spotlight = enable

    local netId = NetworkGetNetworkIdFromEntity(Helicam.heli)
    if not (netId and netId ~= 0) then return end

    local dir    = enable and GetCameraForwardVector(Helicam.cam) or nil
    local radius = enable and Helicam.spotlightRadius or nil

    TriggerServerEvent("p_policejob:heli:setSpotlight", netId, enable, dir, radius)
end

-- ─── Synced Spotlight Draw Thread ────────────────────────────────────────────

-- Starts the cooperative spotlight rendering thread (one shared thread for all spotlights)
function EnsureSpotlightThread()
    if spotlightThreadActive then return end
    spotlightThreadActive = true

    CreateThread(function()
        while next(spotlights) do
            local smoothFactor = math.min(1.0, GetFrameTime() * SPOT_SMOOTHING)

            for netId, spotData in pairs(spotlights) do
                if NetworkDoesNetworkIdExist(netId) then
                    local entity = NetworkGetEntityFromNetworkId(netId)

                    if entity and entity ~= 0 and DoesEntityExist(entity) then
                        local entityPos = GetEntityCoords(entity)
                        local dir

                        -- If this heli is the local one with an active spotlight, use live cam dir
                        if Helicam.active and Helicam.spotlight and Helicam.heli == entity then
                            dir = GetCameraForwardVector(Helicam.cam)
                            spotData.cur = dir
                        else
                            -- Lerp toward the target direction
                            local cur = spotData.cur
                            if not cur then
                                cur = { x = spotData.dir.x, y = spotData.dir.y, z = spotData.dir.z }
                                spotData.cur = cur
                            end

                            cur.x = cur.x + (spotData.dir.x - cur.x) * smoothFactor
                            cur.y = cur.y + (spotData.dir.y - cur.y) * smoothFactor
                            cur.z = cur.z + (spotData.dir.z - cur.z) * smoothFactor

                            -- Normalise
                            local len = math.sqrt(cur.x * cur.x + cur.y * cur.y + cur.z * cur.z)
                            if len > 1e-4 then
                                cur.x = cur.x / len
                                cur.y = cur.y / len
                                cur.z = cur.z / len
                            end

                            dir = cur
                        end

                        DrawSpotLight(
                            entityPos.x, entityPos.y, entityPos.z,
                            dir.x, dir.y, dir.z,
                            SPOT_COLOR[1], SPOT_COLOR[2], SPOT_COLOR[3],
                            SPOT_DISTANCE,
                            SPOT_BRIGHT,
                            SPOT_HARDNESS,
                            spotData.radius or SPOT_RADIUS,
                            SPOT_FALLOFF
                        )
                    end
                end
            end

            Wait(0)
        end

        spotlightThreadActive = false
    end)
end

-- ─── NUI Data Push ────────────────────────────────────────────────────────────

-- Sends the current helicam state to the NUI overlay
function UpdateHelicamNUI()
    if not (Helicam.heli and DoesEntityExist(Helicam.heli)) then return end

    -- Zoom percentage (0 = min zoom / wide, 100 = max zoom / narrow)
    local zoomPct = math.floor(
        ((heliConfig.FovMax - Helicam.fov) / (heliConfig.FovMax - heliConfig.FovMin)) * 100 + 0.5
    )

    local altitude  = GetEntityHeightAboveGround(Helicam.heli)
    local speed     = GetEntitySpeed(Helicam.heli)

    -- Altitude unit
    local altValue, altUnit
    if heliConfig.AltitudeUnit == "ft" then
        altValue = math.floor(altitude * 3.28084 + 0.5)
        altUnit  = "ft"
    else
        altValue = math.floor(altitude + 0.5)
        altUnit  = "m"
    end

    -- Speed unit
    local spdValue, spdUnit
    if heliConfig.SpeedUnit == "mph" then
        spdValue = math.floor(speed * 2.236936 + 0.5)
        spdUnit  = "mph"
    else
        spdValue = math.floor(speed * 3.6 + 0.5)
        spdUnit  = "km/h"
    end

    SendNUIMessage({
        action = "setHelicamData",
        data   = {
            vision          = VISION_LABELS[Helicam.vision],
            zoom            = zoomPct,
            alt             = altValue,
            altUnit         = altUnit,
            spd             = spdValue,
            spdUnit         = spdUnit,
            fov             = Helicam.fov,
            spotlight       = Helicam.spotlight,
            spotlightRadius = math.floor(Helicam.spotlightRadius + 0.5),
            target          = GetLockedEntityInfo(Helicam.lockedEntity) or false,
        },
    })
end

-- ─── Entity Lock ─────────────────────────────────────────────────────────────

-- Finds the best ped or vehicle in the camera's aim cone to lock onto.
-- Returns the entity handle and distance, or nil.
function FindLockTarget(camHandle)
    local camPos  = GetCamCoord(camHandle)
    local camFwd  = GetCameraForwardVector(camHandle)
    local maxDist = heliConfig.LockMaxDistance or 250.0

    local bestEntity = nil
    local bestDot    = nil
    local bestDist   = nil

    local function TryEntity(entity)
        if not DoesEntityExist(entity) then return end
        if entity == Helicam.heli    then return end
        if entity == cache.ped       then return end

        local entityPos = GetEntityCoords(entity)
        local dx = entityPos.x - camPos.x
        local dy = entityPos.y - camPos.y
        local dz = entityPos.z - camPos.z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

        if dist < 5.0 or dist > maxDist then return end

        local dot = (dx * camFwd.x + dy * camFwd.y + dz * camFwd.z) / dist

        if dot < 0.985 then return end

        -- Optional line-of-sight check
        if heliConfig.LockRequireLos ~= false then
            if not HasEntityClearLosToEntity(Helicam.heli, entity, 17) then return end
        end

        if not bestDot or dot > bestDot then
            bestEntity = entity
            bestDot    = dot
            bestDist   = dist
        end
    end

    for _, ped     in ipairs(GetGamePool("CPed"))     do TryEntity(ped) end
    for _, vehicle in ipairs(GetGamePool("CVehicle")) do TryEntity(vehicle) end

    return bestEntity, bestDist
end

-- ─── Helicam Methods ─────────────────────────────────────────────────────────

-- Starts the helicam: creates scripted camera, attaches to heli, opens NUI overlay
function Helicam:start()
    if self.active then return end

    local vehicle = GetCurrentHelicamVehicle()
    if not vehicle then return end

    if not PlayerHasHelicamAccess() then
        Bridge.Notify.showNotify(locale("no_access"), "error")
        return
    end

    self.active          = true
    self.heli            = vehicle
    self.fov             = heliConfig.FovDefault
    self.vision          = VISION_NORMAL
    self.spotlight       = false
    self.spotlightRadius = SPOT_RADIUS
    self.lockedEntity    = nil

    -- Create scripted camera attached 1.5 units below the heli
    local cam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    AttachCamToEntity(cam, vehicle, 0.0, 0.0, -1.5, true)
    SetCamRot(cam, -45.0, 0.0, GetEntityHeading(vehicle), 2)
    SetCamFov(cam, self.fov)
    RenderScriptCams(true, false, 0, true, false)
    self.cam = cam

    ApplyVisionMode(self.vision)
    heliConfig.onStart()

    SendNUIMessage({ action = "setVisibleHelicam", data = true })
    UpdateHelicamNUI()

    -- Main input & camera control thread
    CreateThread(function()
        local lastNuiUpdate    = 0
        local lastSpotSyncTime = 0
        local lastSpotSyncDir  = nil

        while self.active do
            Wait(0)

            -- Validate heli is still the right vehicle
            local currentVehicle = GetCurrentHelicamVehicle()
            if not currentVehicle or currentVehicle ~= self.heli or not DoesEntityExist(self.heli) then
                self:stop()
                break
            end

            HideHudAndRadarThisFrame()

            -- Disable standard controls during helicam
            for _, ctrl in ipairs({ 1, 2, 14, 15, 16, 17, 24, 25, 257, 263, 36 }) do
                DisableControlAction(0, ctrl, true)
            end

            local inputX = GetDisabledControlNormal(0, 1) * heliConfig.RotateSpeed
            local inputY = GetDisabledControlNormal(0, 2) * heliConfig.RotateSpeed

            -- Handle locked entity or free camera rotation
            if self.lockedEntity then
                if DoesEntityExist(self.lockedEntity) then
                    local camPos    = GetCamCoord(self.cam)
                    local targetPos = GetEntityCoords(self.lockedEntity)
                    PointCamAtCoord(self.cam, targetPos.x, targetPos.y, targetPos.z)

                    -- Auto-unlock if target gets too far away
                    if #(camPos - targetPos) > 600.0 then
                        self.lockedEntity = nil
                        StopCamPointing(self.cam)
                        UpdateHelicamNUI()
                    end
                else
                    self.lockedEntity = nil
                    StopCamPointing(self.cam)
                    UpdateHelicamNUI()
                end
            else
                local rot    = GetCamRot(self.cam, 2)
                local newPitch = math.max(heliConfig.PitchMin, math.min(heliConfig.PitchMax, rot.x - inputY))
                SetCamRot(self.cam, newPitch, 0.0, rot.z - inputX, 2)
            end

            -- Spotlight or FOV zoom controls (dpad up/down)
            if self.spotlight then
                if IsDisabledControlPressed(0, 36) then  -- Left Ctrl held
                    if IsDisabledControlPressed(0, 14) then
                        SetSpotlightRadius(self.spotlightRadius - SPOT_RADIUS_STEP)
                    elseif IsDisabledControlPressed(0, 15) then
                        SetSpotlightRadius(self.spotlightRadius + SPOT_RADIUS_STEP)
                    end
                end
            else
                if IsDisabledControlPressed(0, 14) then
                    self.fov = math.min(heliConfig.FovMax, self.fov + heliConfig.FovStep)
                    SetCamFov(self.cam, self.fov)
                elseif IsDisabledControlPressed(0, 15) then
                    self.fov = math.max(heliConfig.FovMin, self.fov - heliConfig.FovStep)
                    SetCamFov(self.cam, self.fov)
                end
            end

            local now = GetGameTimer()

            -- Sync spotlight direction every 120ms
            if self.spotlight then
                local spotDir = GetCameraForwardVector(self.cam)
                local needSync = not lastSpotSyncDir
                    or now - lastSpotSyncTime >= 120

                if needSync then
                    lastSpotSyncTime = now
                    lastSpotSyncDir  = spotDir
                    local netId = NetworkGetNetworkIdFromEntity(self.heli)
                    if netId and netId ~= 0 then
                        TriggerServerEvent("p_policejob:heli:updateSpotlightDir", netId, spotDir)
                    end
                end
            end

            -- Refresh NUI every 100ms
            if now - lastNuiUpdate >= 100 then
                lastNuiUpdate = now
                UpdateHelicamNUI()
            end
        end
    end)
end

-- Stops the helicam: destroys camera, resets vision, hides NUI, turns off spotlight
function Helicam:stop()
    if not self.active then return end

    self.active = false

    if self.cam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(self.cam, false)
        self.cam = nil
    end

    ApplyVisionMode(VISION_NORMAL)
    SetSpotlightActive(false)

    self.lockedEntity = nil
    self.heli         = nil

    SendNUIMessage({ action = "setVisibleHelicam", data = false })
    heliConfig.onStop()
end

-- Toggles the helicam on or off
function Helicam:toggle()
    if self.active then self:stop() else self:start() end
end

-- Cycles to the next vision mode and applies it
function Helicam:cycleVision()
    if not self.active then return end
    self.vision = (self.vision + 1) % 3
    ApplyVisionMode(self.vision)
    UpdateHelicamNUI()
end

-- Toggles the spotlight on/off
function Helicam:toggleSpotlight()
    if not self.active then return end
    SetSpotlightActive(not self.spotlight)
    UpdateHelicamNUI()
end

-- Attempts to lock onto an entity in the camera's aim cone.
-- If already locked onto a valid entity, unlocks instead.
function Helicam:tryLock()
    if not (self.active and self.cam) then return end

    if self.lockedEntity and DoesEntityExist(self.lockedEntity) then
        self.lockedEntity = nil
        StopCamPointing(self.cam)
        UpdateHelicamNUI()
        return
    end

    local foundEntity = FindLockTarget(self.cam)
    if foundEntity then
        self.lockedEntity = foundEntity
        UpdateHelicamNUI()
    end
end

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Server → client: add or remove a spotlight for a networked heli
RegisterNetEvent("p_policejob:heli:syncSpotlight", function(netId, isActive, dir, radius)
    if isActive then
        spotlights[netId] = {
            dir    = dir or { x = 0.0, y = 0.0, z = -1.0 },
            radius = radius or SPOT_RADIUS,
        }
        EnsureSpotlightThread()
    else
        spotlights[netId] = nil
    end
end)

-- Server → client: update spotlight direction for a networked heli
RegisterNetEvent("p_policejob:heli:syncSpotlightDir", function(netId, dir)
    local spot = spotlights[netId]
    if spot and dir then
        spot.dir = dir
    end
end)

-- Server → client: update spotlight radius for a networked heli
RegisterNetEvent("p_policejob:heli:syncSpotlightRadius", function(netId, radius)
    local spot = spotlights[netId]
    if spot and radius then
        spot.radius = radius
    end
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("isHelicamActive", function()
    return Helicam.active
end)

exports("toggleHelicam", function()
    Helicam:toggle()
end)

-- ─── Keybinds ────────────────────────────────────────────────────────────────

lib.addKeybind({
    name        = "helicam_toggle",
    description = locale("helicam_toggle"),
    defaultKey  = heliConfig.Keys.toggle,
    onPressed   = function() Helicam:toggle() end,
})

lib.addKeybind({
    name        = "helicam_vision",
    description = locale("helicam_cycle_vision"),
    defaultKey  = heliConfig.Keys.cycleVision,
    onPressed   = function() Helicam:cycleVision() end,
})

lib.addKeybind({
    name        = "helicam_light",
    description = locale("helicam_toggle_light"),
    defaultKey  = heliConfig.Keys.toggleLight,
    onPressed   = function() Helicam:toggleSpotlight() end,
})

lib.addKeybind({
    name        = "helicam_lock",
    description = locale("helicam_lock_target"),
    defaultKey  = heliConfig.Keys.lockTarget,
    onPressed   = function() Helicam:tryLock() end,
})

-- ─── Event Handlers ──────────────────────────────────────────────────────────

AddEventHandler("baseevents:leftVehicle", function()
    if Helicam.active then Helicam:stop() end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() and Helicam.active then
        Helicam:stop()
    end
end)

-- On join, request the current spotlight state from the server
CreateThread(function()
    Wait(1000)
    TriggerServerEvent("p_policejob:heli:requestSpotlights")
end)
