while true do
    if Config and Config.VehicleRadar then break end
    Citizen.Wait(500)
end

if not Config.VehicleRadar.enabled then return end

VehicleRadar = {}
VehicleRadar.active     = false
VehicleRadar.editing    = false
VehicleRadar.previewing = false
VehicleRadar.mode       = Config.VehicleRadar.DefaultMode or "BOTH"
VehicleRadar.locked     = { front = nil, rear = nil }
VehicleRadar.targets    = { front = nil, rear = nil, patrol = 0 }
VehicleRadar.lastDist   = { front = nil, rear = nil }
VehicleRadar.peaks      = { front = nil, rear = nil }

-- ============================================================
--  Mode cycle list (wraps around)
-- ============================================================

local MODE_LIST = { "BOTH", "SAME", "OPP" }

local function nextMode(current)
    for i, mode in ipairs(MODE_LIST) do
        if mode == current then
            local nextIdx = i % #MODE_LIST + 1
            return MODE_LIST[nextIdx]
        end
    end
    return "BOTH"
end

-- ============================================================
--  Helpers
-- ============================================================

-- Sends a sound name to the NUI to play.
local function playRadarSound(soundName)
    if not soundName or soundName == "" then return end
    SendNUIMessage({ action = "playRadarSound", data = soundName })
end

-- Returns true when the local player's job grants radar access.
local function hasJobAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    if not job or not job.name then return false end
    local minGrade = Config.Jobs[job.name]
    if minGrade == nil then return false end
    return minGrade <= (job.grade or 0)
end

-- Returns true when the given vehicle is in the allowed vehicle list
-- (or when the list is empty / restriction is off).
local function isAllowedVehicle(vehicle)
    if not Config.VehicleRadar.restrictToAllowedVehicles then return true end
    local allowed = Config.VehicleRadar.AllowedVehicles
    if not next(allowed) then return true end

    local archetype = GetEntityArchetypeName(vehicle)
    if archetype then
        return allowed[string.lower(archetype)] == true
    end

    -- Fall back to model hash comparison
    local modelHash = GetEntityModel(vehicle)
    for modelName in pairs(allowed) do
        if GetHashKey(modelName) == modelHash then return true end
    end
    return false
end

-- Converts m/s to the configured unit (kmh or mph).
local function toDisplaySpeed(mps)
    return Config.VehicleRadar.Unit == "kmh" and mps * 3.6 or mps * 2.236936
end

-- Trims leading/trailing whitespace from a string.
local function trimPlate(plate)
    if not plate then return "" end
    return plate:gsub("%s+$", ""):gsub("^%s+", "")
end

-- ============================================================
--  findTargetInCone
--  Scans the vehicle pool for the closest (tgt) and fastest (fast)
--  targets within the radar cone.
--  isFront = true  → forward cone; false → rear cone
--  mode    = "BOTH" | "SAME" | "OPP"
--  Returns: closestVehicle, closestDist, fastestVehicle, fastestDist
-- ============================================================

local function findTargetInCone(radarVehicle, isFront, mode)
    local radarCoords  = GetEntityCoords(radarVehicle)
    local fwdVec       = GetEntityForwardVector(radarVehicle)
    local dirX, dirY   = fwdVec.x, fwdVec.y

    if not isFront then
        dirX, dirY = -dirX, -dirY
    end

    local maxDist  = Config.VehicleRadar.MaxDistance
    local coneDot  = Config.VehicleRadar.ConeDot
    local minFast  = Config.VehicleRadar.MinFastSpeed or 0

    local closestVehicle, closestDist = nil, nil
    local fastestVehicle, fastestDist, fastestSpeed = nil, nil, nil

    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if vehicle ~= radarVehicle and DoesEntityExist(vehicle) then
            local vCoords = GetEntityCoords(vehicle)
            local dx = vCoords.x - radarCoords.x
            local dy = vCoords.y - radarCoords.y
            local dz = vCoords.z - radarCoords.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)

            if dist > 0.1 and dist <= maxDist then
                -- Cone check (dot product of normalised direction and bearing)
                local dot = (dx/dist) * dirX + (dy/dist) * dirY
                if dot >= coneDot then
                    -- Direction filter
                    local inCone = true
                    if mode == "SAME" or mode == "OPP" then
                        local vFwd     = GetEntityForwardVector(vehicle)
                        local alignment = vFwd.x * fwdVec.x + vFwd.y * fwdVec.y
                        if mode == "SAME" and alignment <= 0 then inCone = false end
                        if mode == "OPP"  and alignment >= 0 then inCone = false end
                    end

                    if inCone then
                        -- Closest target
                        if not closestDist or dist < closestDist then
                            closestDist    = dist
                            closestVehicle = vehicle
                        end

                        -- Fastest target (must exceed MinFastSpeed)
                        local speed = toDisplaySpeed(GetEntitySpeed(vehicle))
                        if speed >= minFast and (not fastestSpeed or speed > fastestSpeed) then
                            fastestSpeed   = speed
                            fastestDist    = dist
                            fastestVehicle = vehicle
                        end
                    end
                end
            end
        end
    end

    return closestVehicle, closestDist, fastestVehicle, fastestDist
end

-- ============================================================
--  buildTargetData: turns an entity + optional dist into a display table
--  Returns nil if the entity is invalid or below MinTargetSpeed.
-- ============================================================

local function buildTargetData(vehicle, dist)
    if not vehicle or vehicle == 0 then return nil end
    if not DoesEntityExist(vehicle) then return nil end

    local speed = toDisplaySpeed(GetEntitySpeed(vehicle))
    if speed < Config.VehicleRadar.MinTargetSpeed then return nil end

    return {
        plate    = trimPlate(GetVehicleNumberPlateText(vehicle)),
        speed    = math.floor(speed + 0.5),
        distance = math.floor((dist or 0) + 0.5),
    }
end

-- ============================================================
--  buildSide: computes front/rear side data for one radar scan tick
--  Returns a table { tgt, fast } or nil.
-- ============================================================

function VehicleRadar.buildSide(self, side, closestVehicle, closestDist, fastestVehicle, fastestDist)
    local tgtData = buildTargetData(closestVehicle, closestDist)

    if not tgtData then
        self.lastDist[side] = nil
        self.peaks[side]    = nil
    else
        -- Peak speed tracking
        local peak = self.peaks[side]
        if not peak or peak.plate ~= tgtData.plate then
            peak = { plate = tgtData.plate, speed = tgtData.speed }
        else
            if tgtData.speed > peak.speed then peak.speed = tgtData.speed end
        end
        self.peaks[side] = peak
        tgtData.peak     = peak.speed

        -- Closing / receding
        local prevDist = self.lastDist[side]
        local closing  = "steady"
        if prevDist and closestDist then
            local delta = closestDist - prevDist
            if delta < -0.4 then closing = "closing"
            elseif delta > 0.4 then closing = "receding"
            end
        end
        tgtData.closing     = closing
        self.lastDist[side] = closestDist
    end

    -- Fast-target data
    local fastData = buildTargetData(fastestVehicle, fastestDist)
    if fastData then
        local minFast = Config.VehicleRadar.MinFastSpeed or 0
        if fastData.speed < minFast then fastData = nil end

        -- Only keep fastData if it's different from (or faster than) tgtData
        if fastData and tgtData then
            if fastData.plate == tgtData.plate and fastData.speed <= tgtData.speed then
                fastData = nil
            end
        end
    end

    if not tgtData and not fastData then return nil end
    return { tgt = tgtData, fast = fastData }
end

-- ============================================================
--  NUI push helpers
-- ============================================================

-- Sends live preview data with dummy values for the editor.
function VehicleRadar.sendPreview(self)
    SendNUIMessage({ action = "setVehicleRadarData", data = {
        unit        = Config.VehicleRadar.Unit,
        maxDistance = Config.VehicleRadar.MaxDistance,
        mode        = self.mode,
        patrol      = 38,
        front = {
            tgt  = { plate = "ABC1234", speed = 67, distance = 22, closing = "closing", peak = 71 },
            fast = { plate = "ZRX9911", speed = 88, distance = 64 },
        },
        rear = {
            tgt  = { plate = "XYZ9876", speed = 31, distance = 48, closing = "receding", peak = 44 },
            fast = nil,
        },
        locked = {
            front = {
                tgt  = { plate = "ABC1234", speed = 67 },
                fast = { plate = "ZRX9911", speed = 88 },
            },
            rear = nil,
        },
    }})
end

-- Sends the live radar state.
function VehicleRadar.sendState(self)
    SendNUIMessage({ action = "setVehicleRadarData", data = {
        unit        = Config.VehicleRadar.Unit,
        maxDistance = Config.VehicleRadar.MaxDistance,
        mode        = self.mode,
        patrol      = self.targets.patrol,
        front       = self.targets.front,
        rear        = self.targets.rear,
        locked      = self.locked,
    }})
end

-- ============================================================
--  open / close
-- ============================================================

function VehicleRadar.open(self)
    self.active     = true
    self.locked     = { front = nil, rear = nil }
    self.targets    = { front = nil, rear = nil, patrol = 0 }
    self.lastDist   = { front = nil, rear = nil }
    self.peaks      = { front = nil, rear = nil }

    SendNUIMessage({ action = "setVisibleVehicleRadar", data = true })
    self:sendState()

    local soundCfg = Config.VehicleRadar.Sounds
    playRadarSound(soundCfg and soundCfg.powerOn)
    Config.VehicleRadar.onToggleOn()
    self:startThread()
end

function VehicleRadar.close(self)
    if not self.active then return end
    self.active     = false
    self.previewing = false
    self.locked     = { front = nil, rear = nil }
    self.targets    = { front = nil, rear = nil, patrol = 0 }
    self.lastDist   = { front = nil, rear = nil }
    self.peaks      = { front = nil, rear = nil }
    SendNUIMessage({ action = "setVisibleVehicleRadar", data = false })
    Config.VehicleRadar.onToggleOff()
end

-- ============================================================
--  Edit mode
-- ============================================================

function VehicleRadar.enterEdit(self)
    if self.editing then return end
    self.editing = true

    if not self.active then
        self.active     = true
        self.previewing = true
        SendNUIMessage({ action = "setVisibleVehicleRadar", data = true })
        self:sendPreview()
    end

    SendNUIMessage({ action = "setVehicleRadarEdit", data = true })
    SetNuiFocus(true, true)
end

function VehicleRadar.exitEdit(self)
    if not self.editing then return end
    self.editing = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVehicleRadarEdit", data = false })
    if self.previewing then self:close() end
end

function VehicleRadar.toggleEdit(self)
    if self.editing then self:exitEdit() else self:enterEdit() end
end

-- ============================================================
--  toggle (power on/off)
-- ============================================================

function VehicleRadar.toggle(self)
    if self.editing then return end

    if self.active then
        self:close()
        return
    end

    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("no_access"), "error")
        return
    end

    -- Must be in a vehicle, in the driver seat
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if not vehicle or vehicle == 0
        or GetPedInVehicleSeat(vehicle, -1) ~= cache.ped then
        Bridge.Notify.showNotify(locale("vehicle_radar_not_in_vehicle"), "error")
        return
    end

    if not isAllowedVehicle(vehicle) then
        Bridge.Notify.showNotify(locale("vehicle_radar_not_in_vehicle"), "error")
        return
    end

    self:open()
end

-- ============================================================
--  lock
-- ============================================================

function VehicleRadar.lock(self, side)
    if self.editing or not self.active then return end
    if side ~= "front" and side ~= "rear" then return end

    -- Unlock if already locked on this side
    if self.locked[side] then
        self.locked[side] = nil
        Config.VehicleRadar.onUnlock(side)
        self:sendState()
        return
    end

    local sideData = self.targets[side]
    if not sideData then return end

    -- Snapshot only plate + speed (no transient data like distance/closing)
    local locked = {}
    if sideData.tgt then
        locked.tgt = { plate = sideData.tgt.plate, speed = sideData.tgt.speed }
    end
    if sideData.fast then
        locked.fast = { plate = sideData.fast.plate, speed = sideData.fast.speed }
    end

    if not locked.tgt and not locked.fast then return end

    self.locked[side] = locked
    playRadarSound(Config.VehicleRadar.Sounds and Config.VehicleRadar.Sounds.lock)
    Config.VehicleRadar.onLock(side, locked)
    self:sendState()
end

-- ============================================================
--  cycleMode
-- ============================================================

function VehicleRadar.cycleMode(self)
    if not self.active then return end
    self.mode = nextMode(self.mode)
    playRadarSound(Config.VehicleRadar.Sounds and Config.VehicleRadar.Sounds.mode)
    self:sendState()
end

-- ============================================================
--  startThread: main scan loop
-- ============================================================

function VehicleRadar.startThread(self)
    CreateThread(function()
        while true do
            if not self.active then break end

            Wait(Config.VehicleRadar.UpdateInterval)

            if self.previewing then
                -- No scanning while in preview/edit mode
            else
                local vehicle = GetVehiclePedIsIn(cache.ped, false)
                local validVehicle = vehicle and vehicle ~= 0
                    and GetPedInVehicleSeat(vehicle, -1) == cache.ped
                    and isAllowedVehicle(vehicle)

                if not validVehicle and not self.editing then
                    self:close()
                    break
                end

                if validVehicle then
                    -- Patrol speed (own vehicle)
                    self.targets.patrol = math.floor(toDisplaySpeed(GetEntitySpeed(vehicle)) + 0.5)

                    -- Scan front cone
                    local fClosest, fClosestDist, fFastest, fFastestDist =
                        findTargetInCone(vehicle, true,  self.mode)
                    -- Scan rear cone
                    local rClosest, rClosestDist, rFastest, rFastestDist =
                        findTargetInCone(vehicle, false, self.mode)

                    self.targets.front = self:buildSide(
                        "front", fClosest, fClosestDist, fFastest, fFastestDist)
                    self.targets.rear  = self:buildSide(
                        "rear",  rClosest, rClosestDist, rFastest, rFastestDist)

                    self:sendState()
                end
            end
        end
    end)
end

-- ============================================================
--  Wanted-alert helpers
-- ============================================================

local function showWantedAlert(data)
    if not (type(data) == "table" and data.plate and data.plate ~= "") then return end
    SendNUIMessage({ action = "setVehicleRadarWanted", data = {
        plate    = tostring(data.plate),
        reason   = tostring(data.reason or ""),
        severity = data.severity or "danger",
        title    = data.title,
        duration = data.duration,
    }})
end

local function hideWantedAlert()
    SendNUIMessage({ action = "setVehicleRadarWanted", data = nil })
end

-- ============================================================
--  Exports
-- ============================================================

exports("isVehicleRadarActive",  function() return VehicleRadar.active end)
exports("toggleVehicleRadar",    function() VehicleRadar:toggle() end)
exports("lockVehicleRadar",      function(side) VehicleRadar:lock(side) end)
exports("cycleVehicleRadarMode", function() VehicleRadar:cycleMode() end)
exports("openVehicleRadarConfig",function() VehicleRadar:toggleEdit() end)
exports("showVehicleRadarWanted",showWantedAlert)
exports("hideVehicleRadarWanted",hideWantedAlert)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob:vehicle_radar:wanted",       showWantedAlert)
RegisterNetEvent("p_policejob:vehicle_radar:wanted:clear", hideWantedAlert)

-- ============================================================
--  Keybinds
-- ============================================================

local Keys = Config.VehicleRadar.Keys

lib.addKeybind({
    name        = "vehicle_radar_toggle",
    description = locale("toggle_police_radar"),
    defaultKey  = Keys.toggle,
    onPressed   = function() VehicleRadar:toggle() end,
})

lib.addKeybind({
    name        = "vehicle_radar_lock_front",
    description = locale("lock_front_radar"),
    defaultKey  = Keys.lockFront,
    onPressed   = function() VehicleRadar:lock("front") end,
})

lib.addKeybind({
    name        = "vehicle_radar_lock_rear",
    description = locale("lock_rear_radar"),
    defaultKey  = Keys.lockRear,
    onPressed   = function() VehicleRadar:lock("rear") end,
})

lib.addKeybind({
    name        = "vehicle_radar_cycle_mode",
    description = locale("cycle_radar_mode"),
    defaultKey  = Keys.cycleMode,
    onPressed   = function() VehicleRadar:cycleMode() end,
})

-- Optional edit command
local editCmd = Config.VehicleRadar.EditCommand
if editCmd and editCmd ~= "" then
    RegisterCommand(editCmd, function() VehicleRadar:toggleEdit() end, false)
end

-- ============================================================
--  NUI callbacks / events
-- ============================================================

RegisterNUICallback("VehicleRadarExitEdit", function(_, cb)
    VehicleRadar:exitEdit()
    cb("ok")
end)

AddEventHandler("baseevents:leftVehicle", function()
    if VehicleRadar.active and not VehicleRadar.editing then
        VehicleRadar:close()
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if VehicleRadar.editing then SetNuiFocus(false, false) end
    if VehicleRadar.active then
        SendNUIMessage({ action = "setVisibleVehicleRadar", data = false })
    end
end)

-- Dev command for testing the wanted alert
RegisterCommand("test_wanted", function()
    showWantedAlert({
        plate    = "TEST123",
        reason   = "Test wanted alert",
        severity = "warning",
        title    = "TEST ALERT",
        duration = 10000,
    })
end)
