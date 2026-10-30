if not Config.VehicleTracker.Enabled then return end

VehicleTracker = {}
VehicleTracker.blips      = {}   -- [plate] = { first = blipHandle, second = blipHandle? }
VehicleTracker.isTracking = false

-- ============================================================
--  Plate normalisation (trim whitespace, collapse spaces, uppercase)
-- ============================================================

local function normalisePlate(raw)
    if not raw then return nil end
    local s = tostring(raw):gsub("^%s*(.-)%s*$", "%1"):gsub("%s+", ""):upper()
    return s ~= "" and s or nil
end

-- ============================================================
--  Access checks
-- ============================================================

function VehicleTracker.hasPoliceAccess(self)
    if not Bridge.Framework.isPlayerLoaded() then return false end
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end
    return Config.Jobs[job.name] ~= nil
end

-- ============================================================
--  Tracker state queries (reads GlobalState)
-- ============================================================

-- Returns true if the vehicle has a tracker installed.
function VehicleTracker.isTrackedVehicle(self, vehicle)
    if not vehicle or vehicle == 0 then return false end
    local plate   = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return false end
    local trackers = GlobalState.p_policejob_vehicleTrackers
    return trackers ~= nil and trackers[plate] ~= nil
end

-- Returns plate (string), trackerData (table) for the vehicle, or nil, nil.
function VehicleTracker.getVehicleData(self, vehicle)
    if not vehicle or vehicle == 0 then return nil end
    local plate   = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return nil end
    local trackers = GlobalState.p_policejob_vehicleTrackers
    local data     = trackers and trackers[plate]
    return plate, data or nil
end

-- ============================================================
--  Blip management
-- ============================================================

function VehicleTracker.createBlip(self, plate, trackerData)
    if not trackerData.coords then return end

    -- Remove any existing blip for this plate before creating a new one
    self:removeBlip(plate)
    self.blips[plate] = {}

    local BlipCfg = Config.VehicleTracker.Blip
    local coords  = trackerData.coords
    local label   = (BlipCfg.namePrefix or "Tracker | ") .. (trackerData.plate or plate)

    -- Primary blip
    local primary = AddBlipForCoord(coords.x, coords.y, coords.z)
    self.blips[plate].first = primary

    SetBlipScale(primary,    BlipCfg.scale    or 0.9)
    SetBlipSprite(primary,   BlipCfg.sprite   or 225)
    SetBlipCategory(primary, BlipCfg.category or 3)
    SetBlipShrink(primary,   BlipCfg.shrink   ~= false)
    SetBlipPriority(primary, BlipCfg.priority or 3)
    ShowHeightOnBlip(primary, BlipCfg.height  or false)
    SetBlipColour(primary,   BlipCfg.color    or 5)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(primary)

    -- Optional pulse blip
    if BlipCfg.pulse then
        local pulse = AddBlipForCoord(coords.x, coords.y, coords.z)
        self.blips[plate].second = pulse
        SetBlipSprite(pulse, 161)
        SetBlipScale(pulse, 1.0)
        SetBlipColour(pulse, BlipCfg.color or 5)
        PulseBlip(pulse)
    end

    -- Optional heading indicator
    if BlipCfg.heading and trackerData.heading then
        ShowHeadingIndicatorOnBlip(primary, true)
        SetBlipRotation(primary, trackerData.heading)
    end
end

function VehicleTracker.removeBlip(self, plate)
    local entry = self.blips[plate]
    if not entry then return end
    if entry.first  then RemoveBlip(entry.first) end
    if entry.second then RemoveBlip(entry.second) end
    self.blips[plate] = nil
end

function VehicleTracker.removeAllBlips(self)
    for plate in pairs(self.blips) do
        self:removeBlip(plate)
    end
end

-- Syncs the blip map to the current GlobalState tracker list.
function VehicleTracker.updateBlips(self)
    local trackers = GlobalState.p_policejob_vehicleTrackers or {}
    local active   = {}

    for plate, data in pairs(trackers) do
        if data and data.coords and data.exists ~= false then
            self:createBlip(plate, data)
            active[plate] = true
        end
    end

    -- Remove blips for plates no longer in the tracker list
    for plate in pairs(self.blips) do
        if not active[plate] then self:removeBlip(plate) end
    end
end

-- ============================================================
--  Tracking loop
-- ============================================================

function VehicleTracker.startTracking(self)
    if self.isTracking then return end
    self.isTracking = true
    CreateThread(function()
        while self.isTracking do
            self:updateBlips()
            Wait(Config.VehicleTracker.LoopRate)
        end
    end)
end

function VehicleTracker.stopTracking(self)
    if not self.isTracking then return end
    self.isTracking = false
    self:removeAllBlips()
end

-- ============================================================
--  Item use (triggered by keybind / server event)
-- ============================================================

function VehicleTracker.useItem(self)
    if not self:hasPoliceAccess() then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), Config.VehicleTracker.InstallDistance, false)
    self:installOnVehicle(vehicle)
end

-- ============================================================
--  Install tracker on a nearby vehicle
-- ============================================================

function VehicleTracker.installOnVehicle(self, vehicle)
    if not vehicle or vehicle == 0 then
        return Bridge.Notify.showNotify(locale("vehicle_tracker_not_found"), "error")
    end
    if not NetworkGetEntityIsNetworked(vehicle) then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end
    if self:isTrackedVehicle(vehicle) then
        return Bridge.Notify.showNotify(locale("vehicle_tracker_already_on_vehicle"), "error")
    end

    local InstallCfg = Config.VehicleTracker.Install
    local ok = Bridge.Progress.Start({
        duration     = InstallCfg.duration,
        label        = locale("setting_vehicle_tracker"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = { dict = InstallCfg.animation.dict, clip = InstallCfg.animation.clip },
    })
    if not ok then return end

    local plate = normalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then
        return Bridge.Notify.showNotify(locale("vehicle_tracker_not_found"), "error")
    end

    TriggerServerEvent("p_policejob:vehicleTracker:install", {
        netId = NetworkGetNetworkIdFromEntity(vehicle),
        plate = plate,
    })
    Config.VehicleTracker.onInstall(vehicle, plate)
end

-- ============================================================
--  Remove tracker (police)
-- ============================================================

function VehicleTracker.removeByPolice(self, vehicle)
    if not self:hasPoliceAccess() then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end
    local plate, data = self:getVehicleData(vehicle)
    if not plate then
        return Bridge.Notify.showNotify(locale("vehicle_tracker_not_found"), "error")
    end

    local RemoveCfg = Config.VehicleTracker.Remove
    local ok = Bridge.Progress.Start({
        duration     = RemoveCfg.duration,
        label        = locale("removing_vehicle_tracker"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = { dict = RemoveCfg.animation.dict, clip = RemoveCfg.animation.clip },
    })
    if not ok then return end

    TriggerServerEvent("p_policejob:vehicleTracker:remove", {
        netId  = NetworkGetNetworkIdFromEntity(vehicle),
        plate  = plate,
        reason = "police",
    })
    Config.VehicleTracker.onRemove(vehicle, plate, "police")
end

-- ============================================================
--  Remove tracker (hack — criminal action)
-- ============================================================

function VehicleTracker.removeByHack(self, vehicle)
    -- Criminals cannot have police access; police use removeByPolice instead
    if self:hasPoliceAccess() then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end
    if not Config.VehicleTracker.Hack.enabled then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end
    local plate, _ = self:getVehicleData(vehicle)
    if not plate then
        return Bridge.Notify.showNotify(locale("vehicle_tracker_not_found"), "error")
    end

    local HackCfg = Config.VehicleTracker.Hack
    local ok = Bridge.Progress.Start({
        duration     = HackCfg.duration,
        label        = locale("hacking_vehicle_tracker"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = { dict = HackCfg.animation.dict, clip = HackCfg.animation.clip },
    })
    if not ok then return end

    if not HackCfg.miniGame() then
        return Bridge.Notify.showNotify(locale("vehicle_tracker_hack_failed"), "error")
    end

    TriggerServerEvent("p_policejob:vehicleTracker:remove", {
        netId  = NetworkGetNetworkIdFromEntity(vehicle),
        plate  = plate,
        reason = "hack",
    })
    Config.VehicleTracker.onRemove(vehicle, plate, "hack")
end

-- ============================================================
--  ox_target vehicle options (install / remove / hack)
-- ============================================================

CreateThread(function()
    local function resolveEntity(raw)
        -- ox_target may pass either a number entity handle or a table with .entity
        if type(raw) == "number" then return raw end
        return raw and raw.entity
    end

    Bridge.Target.addVehicle({
        {
            name     = "vehicle_tracker_install",
            label    = locale("install_vehicle_tracker"),
            icon     = "fa-solid fa-satellite-dish",
            distance = Config.VehicleTracker.InstallDistance,
            canInteract = function(vehicle)
                if not VehicleTracker:hasPoliceAccess() then return false end
                if not vehicle or vehicle == 0 then return false end
                if not NetworkGetEntityIsNetworked(vehicle) then return false end
                if VehicleTracker:isTrackedVehicle(vehicle) then return false end
                return Bridge.Inventory.getItemCount(Config.VehicleTracker.ItemName) >= 1
            end,
            onSelect = function(raw)
                VehicleTracker:installOnVehicle(resolveEntity(raw))
            end,
        },
        {
            name     = "vehicle_tracker_remove",
            label    = locale("remove_vehicle_tracker"),
            icon     = "fa-solid fa-circle-minus",
            distance = Config.VehicleTracker.RemoveDistance,
            canInteract = function(vehicle)
                if not VehicleTracker:hasPoliceAccess() then return false end
                if not vehicle or vehicle == 0 then return false end
                return VehicleTracker:isTrackedVehicle(vehicle)
            end,
            onSelect = function(raw)
                VehicleTracker:removeByPolice(resolveEntity(raw))
            end,
        },
        {
            name     = "vehicle_tracker_hack_remove",
            label    = locale("hack_vehicle_tracker"),
            icon     = "fa-solid fa-laptop-code",
            distance = Config.VehicleTracker.RemoveDistance,
            canInteract = function(vehicle)
                if VehicleTracker:hasPoliceAccess() then return false end  -- police use the remove option
                if not Config.VehicleTracker.Hack.enabled then return false end
                if not vehicle or vehicle == 0 then return false end
                return VehicleTracker:isTrackedVehicle(vehicle)
            end,
            onSelect = function(raw)
                VehicleTracker:removeByHack(resolveEntity(raw))
            end,
        },
    })
end)

-- ============================================================
--  Access-gated tracking loop manager (polls every 2.5s)
-- ============================================================

CreateThread(function()
    while true do
        Wait(2500)
        if VehicleTracker:hasPoliceAccess() then
            if not VehicleTracker.isTracking then
                VehicleTracker:startTracking()
            end
        else
            if VehicleTracker.isTracking then
                VehicleTracker:stopTracking()
            end
        end
    end
end)

-- ============================================================
--  Net events from server
-- ============================================================

RegisterNetEvent("p_policejob:vehicleTracker:useItem", function()
    VehicleTracker:useItem()
end)

RegisterNetEvent("p_policejob:vehicleTracker:removeBlip", function(data)
    local plate = data and data.plate and normalisePlate(data.plate)
    if plate then VehicleTracker:removeBlip(plate) end
end)
