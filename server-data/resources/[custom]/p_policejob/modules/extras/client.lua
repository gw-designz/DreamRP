while true do
    if Config and Config.Extras then break end
    Citizen.Wait(1)
end

if not Config.Extras.enabled then return end

local Extras = {}
Extras.inZone        = false
Extras.currentVehicle = nil
Extras.cameraUnlocked = false
Extras.antiSpam      = GetGameTimer()

-- ============================================================
--  Access check
-- ============================================================

function Extras.hasAccess(self)
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end
    return Config.Jobs[job.name] ~= nil
end

-- ============================================================
--  Vehicle data fetchers
-- ============================================================

function Extras.getVehicleExtras(self, vehicle)
    local result = {}
    for id = 0, 20 do
        if DoesExtraExist(vehicle, id) then
            result[#result + 1] = { id = id, enabled = IsVehicleExtraTurnedOn(vehicle, id) }
        end
    end
    return result
end

function Extras.getVehicleLiveries(self, vehicle)
    local result = {}
    local count  = GetVehicleLiveryCount(vehicle)
    if count <= 0 then return result end

    local current = GetVehicleLivery(vehicle)
    for id = 0, count - 1 do
        local rawName  = GetLiveryName(vehicle, id)
        local label    = nil
        if rawName and rawName ~= "" and rawName ~= "NULL" then
            local text = GetLabelText(rawName)
            if text and text ~= "" and text ~= "NULL" then label = text end
        end
        result[#result + 1] = {
            id     = id,
            label  = label or ("Livery #" .. (id + 1)),
            active = current == id,
        }
    end
    return result
end

function Extras.getVehicleModLiveries(self, vehicle)
    local result  = {}
    local count   = GetNumVehicleMods(vehicle, 48)
    if count <= 0 then return result end

    local current = GetVehicleMod(vehicle, 48)
    for id = 0, count - 1 do
        local rawName = GetModTextLabel(vehicle, 48, id)
        local label   = nil
        if rawName and rawName ~= "" and rawName ~= "NULL" then
            local text = GetLabelText(rawName)
            if text and text ~= "" and text ~= "NULL" then label = text end
        end
        result[#result + 1] = {
            id     = id,
            label  = label or ("Livery #" .. (id + 1)),
            active = current == id,
        }
    end
    return result
end

function Extras.getVehicleMods(self, vehicle)
    local result = {}
    for _, modDef in ipairs(Config.Extras.mods) do
        local modType = modDef.modType
        local count   = GetNumVehicleMods(vehicle, modType)
        if count > 0 then
            local current = GetVehicleMod(vehicle, modType)
            local options = {{ index = -1, label = "Stock", active = current == -1 }}
            for idx = 0, count - 1 do
                local rawName = GetModTextLabel(vehicle, modType, idx)
                local label   = (rawName and rawName ~= "" and rawName ~= "NULL") and rawName or nil
                options[#options + 1] = {
                    index  = idx,
                    label  = label or (modDef.label .. " #" .. (idx + 1)),
                    active = current == idx,
                }
            end
            result[#result + 1] = {
                modType = modType,
                label   = modDef.label,
                current = current,
                options = options,
            }
        end
    end
    return result
end

function Extras.fetchVehicleData(self, vehicle)
    SetVehicleModKit(vehicle, 0)
    return {
        extras      = self:getVehicleExtras(vehicle),
        liveries    = self:getVehicleLiveries(vehicle),
        modLiveries = self:getVehicleModLiveries(vehicle),
        mods        = self:getVehicleMods(vehicle),
    }
end

-- ============================================================
--  Open menu
-- ============================================================

function Extras.openMenu(self)
    if self.antiSpam > GetGameTimer() then return end
    if not self:hasAccess() then return end

    local vehicle = cache.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        Bridge.Notify.showNotify("No vehicle nearby", "error")
        return
    end

    self.currentVehicle  = vehicle
    self.cameraUnlocked  = false

    local vehicleData = self:fetchVehicleData(vehicle)

    SetNuiFocus(true, true)
    SendNUIMessage({ action = "setExtrasCameraKeybind", data = Config.Extras.CameraKeybind })
    SendNUIMessage({ action = "setVisibleExtras",       data = true })
    SendNUIMessage({ action = "setExtrasData",          data = vehicleData })
end

-- ============================================================
--  Camera toggle (shared by keybind and NUI callback)
-- ============================================================

local function toggleCamera()
    if Extras.antiSpam > GetGameTimer() then return end
    if not Extras.currentVehicle then return end

    Extras.antiSpam      = GetGameTimer() + 100
    Extras.cameraUnlocked = not Extras.cameraUnlocked

    SetNuiFocus(not Extras.cameraUnlocked, not Extras.cameraUnlocked)
    SendNUIMessage({ action = "setExtrasCameraState", data = Extras.cameraUnlocked })
end

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("extras/toggleExtra", function(data, cb)
    local vehicle = Extras.currentVehicle
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleExtra(vehicle, data.id, not data.enabled)
        cb(Extras:fetchVehicleData(vehicle))
    else
        cb({})
    end
end)

RegisterNUICallback("extras/setLivery", function(data, cb)
    local vehicle = Extras.currentVehicle
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleLivery(vehicle, data.id)
        cb(Extras:fetchVehicleData(vehicle))
    else
        cb({})
    end
end)

RegisterNUICallback("extras/setModLivery", function(data, cb)
    local vehicle = Extras.currentVehicle
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleMod(vehicle, 48, data.id, false)
        cb(Extras:fetchVehicleData(vehicle))
    else
        cb({})
    end
end)

RegisterNUICallback("extras/setMod", function(data, cb)
    local vehicle = Extras.currentVehicle
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleMod(vehicle, data.modType, data.index, false)
        cb(Extras:fetchVehicleData(vehicle))
    else
        cb({})
    end
end)

RegisterNUICallback("extras/toggleCamera", function(data, cb)
    if not Extras.currentVehicle or Extras.antiSpam > GetGameTimer() then
        cb("ok")
        return
    end
    toggleCamera()
    cb("ok")
end)

-- ============================================================
--  Keybind
-- ============================================================

lib.addKeybind({
    name          = "extras_camera_toggle",
    description   = "Toggle camera movement in extras menu",
    defaultKey    = Config.Extras.CameraKeybind,
    defaultMapper = "keyboard",
    onPressed     = toggleCamera,
})

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if data.name ~= "setVisibleExtras" then return end

    SendNUIMessage({ action = "setVisibleExtras",     data = false })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    Extras.cameraUnlocked = false
    Extras.currentVehicle = nil
    Extras.antiSpam       = GetGameTimer() + 1000
end)

-- ============================================================
--  lib.points zones from DepartmentData.extras
-- ============================================================

for _, zoneDef in ipairs(Config.DepartmentData.extras or {}) do
    local point = lib.points.new({ coords = zoneDef.coords, distance = zoneDef.size })
    point.textShown = false

    function point:onEnter()
        Extras.inZone = true
    end

    function point:onExit()
        Extras.inZone = false
        if self.textShown then
            lib.hideTextUI()
            self.textShown = false
        end
    end

    function point:nearby()
        local inVehicle   = cache.vehicle ~= nil
        local hasAccess   = inVehicle and Extras:hasAccess()

        if hasAccess then
            if not self.textShown then
                lib.showTextUI("[E] " .. (zoneDef.label or "Vehicle Extras"))
                self.textShown = true
            end
            if IsControlJustPressed(0, 38) then  -- E key
                Extras:openMenu()
            end
        else
            if self.textShown then
                lib.hideTextUI()
                self.textShown = false
            end
        end
    end
end
