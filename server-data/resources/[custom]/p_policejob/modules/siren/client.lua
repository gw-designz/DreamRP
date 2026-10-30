while true do
    if Config and Config.Siren then break end
    Citizen.Wait(50)
end

if not Config.Siren.enabled then return end

Siren = {}
Siren.menuOpen      = false
Siren.editing       = false
Siren.currentVehicle = nil
Siren.state = {
    lights = false,
    audio  = false,
    muted  = false,
    tone   = 1,
    horn   = false,
}

-- ============================================================
--  File-local helpers
-- ============================================================

-- Returns the "code" integer from the current state:
--   0 = off, 1 = lights only (code 2), 2/3 = lights+audio (code 3)
local function getCode(state)
    if not state.lights then return 0 end
    if not state.audio  then return 1 end
    return state.tone > 2 and 3 or 2
end

-- Active sound handle
local activeSoundId = nil

-- Stops and releases the current siren sound.
local function stopSirenSound()
    if activeSoundId then
        StopSound(activeSoundId)
        ReleaseSoundId(activeSoundId)
        activeSoundId = nil
    end
end

-- Plays a siren sound looped from the vehicle entity.
local function playSirenSound(vehicle, soundName)
    stopSirenSound()
    if not soundName or not vehicle or not DoesEntityExist(vehicle) then return end
    activeSoundId = GetSoundId()
    PlaySoundFromEntity(activeSoundId, soundName, vehicle, 0, false, 0)
end

-- True if vehicle exists and is a networked entity (has a player in it).
local function isValidVehicle(vehicle)
    return vehicle and vehicle ~= 0
end

-- True if vehicle's class is in the allowed list.
local function isEmergencyVehicle(vehicle)
    if not isValidVehicle(vehicle) then return false end
    return Config.Siren.allowedClasses[GetVehicleClass(vehicle)] == true
end

-- True if the vehicle is in the allowed list AND has the police flag set.
local function hasPoliceFlag(vehicle)
    if not isValidVehicle(vehicle) then return false end
    return Entity(vehicle).state.isPoliceVehicle == true or isEmergencyVehicle(vehicle)
end

-- ============================================================
--  Access check
-- ============================================================

function Siren.hasAccess(self)
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end
    return Config.Jobs[job.name] ~= nil
end

-- ============================================================
--  Apply current state to the vehicle
-- ============================================================

function Siren.applyState(self)
    local vehicle = self.currentVehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end

    if self.state.lights then
        SetVehicleSiren(vehicle, true)
        SetVehicleHasMutedSirens(vehicle, true)
    else
        SetVehicleSiren(vehicle, false)
        SetVehicleHasMutedSirens(vehicle, false)
    end

    local shouldPlayAudio = self.state.lights and self.state.audio and not self.state.muted

    if not shouldPlayAudio then
        stopSirenSound()
    else
        local toneDef  = Config.Siren.tones[self.state.tone]
        local soundName = toneDef and toneDef.sound
        playSirenSound(vehicle, soundName)
    end
end

-- ============================================================
--  NUI data push
-- ============================================================

local staticSentOnce = false

-- Builds the static config payload (tones + locales) — only built once per session.
local function buildStaticData()
    local tones = {}
    for i, toneDef in ipairs(Config.Siren.tones) do
        local label = (toneDef.localeKey and locale(toneDef.localeKey)) or toneDef.label
        tones[i] = { label = label }
    end

    return {
        tones    = tones,
        keybinds = Config.Siren.keybinds,
        locales  = {
            title            = locale("siren_title"),
            status_off       = locale("siren_status_off"),
            status_code2     = locale("siren_status_code2"),
            status_code3     = locale("siren_status_code3"),
            label_lights     = locale("siren_label_lights"),
            label_siren      = locale("siren_label_siren"),
            label_mute       = locale("siren_label_mute"),
            value_on         = locale("siren_value_on"),
            value_off        = locale("siren_value_off"),
            value_muted      = locale("siren_value_muted"),
            value_audible    = locale("siren_value_audible"),
            section_tones    = locale("siren_section_tones"),
            section_keybinds = locale("siren_section_keybinds"),
            section_layout   = locale("siren_section_layout"),
            active           = locale("siren_active"),
            edit             = locale("siren_edit"),
            btn_reset        = locale("siren_btn_reset"),
            btn_save         = locale("siren_btn_save"),
            layout_hint      = locale("siren_layout_hint"),
        },
    }
end

function Siren.pushNui(self)
    if not staticSentOnce then
        SendNUIMessage({ action = "setSirenStatic", data = buildStaticData() })
        staticSentOnce = true
    end

    SendNUIMessage({ action = "setSirenData", data = {
        lights = self.state.lights,
        audio  = self.state.audio,
        muted  = self.state.muted,
        tone   = self.state.tone,
        code   = getCode(self.state),
        horn   = self.state.horn,
    }})
end

-- ============================================================
--  Menu open / close / edit mode
-- ============================================================

function Siren.openMenu(self)
    if not self:hasAccess() then return end

    local vehicle = cache.vehicle
    if not isEmergencyVehicle(vehicle) or not hasPoliceFlag(vehicle) then
        return Bridge.Notify.showNotify(locale("siren_not_in_emergency_vehicle"), "error")
    end

    self.currentVehicle = vehicle
    self.menuOpen       = true
    SendNUIMessage({ action = "setVisibleSiren", data = true })
    self:pushNui()
    Bridge.Debug("[Siren] HUD opened")
end

function Siren.closeMenu(self)
    if not self.menuOpen then return end
    self.menuOpen = false
    if self.editing then self:setEditing(false) end
    stopSirenSound()
    SendNUIMessage({ action = "setVisibleSiren", data = false })
end

function Siren.setEditing(self, enabled)
    self.editing = enabled and true or false
    SetNuiFocus(self.editing, self.editing)
    SendNUIMessage({ action = "setSirenEditing", data = self.editing })
end

-- ============================================================
--  State mutators
-- ============================================================

function Siren.toggleLights(self)
    self.state.lights = not self.state.lights
    if not self.state.lights then
        self.state.audio = false
        self.state.muted = false
    end
    self:applyState()
    self:pushNui()
end

function Siren.toggleAudio(self)
    if not self.state.lights then self.state.lights = true end
    self.state.audio = not self.state.audio
    if self.state.audio then self.state.muted = false end
    self:applyState()
    self:pushNui()
end

function Siren.toggleMute(self)
    if not self.state.audio then return end
    self.state.muted = not self.state.muted
    self:applyState()
    self:pushNui()
end

function Siren.cycleTone(self)
    local count = #Config.Siren.tones
    if count == 0 then return end
    self.state.tone = (self.state.tone % count) + 1
    self:applyState()
    self:pushNui()
end

function Siren.setTone(self, toneIndex)
    if not Config.Siren.tones[toneIndex] then return end
    self.state.tone = toneIndex
    self:applyState()
    self:pushNui()
end

function Siren.reset(self)
    self.state.lights = false
    self.state.audio  = false
    self.state.muted  = false
    self.state.horn   = false
    self.state.tone   = 1
    stopSirenSound()
    local vehicle = self.currentVehicle
    if vehicle and DoesEntityExist(vehicle) then
        SetVehicleSiren(vehicle, false)
        SetVehicleHasMutedSirens(vehicle, false)
    end
end

-- ============================================================
--  Horn
-- ============================================================

local hornActive = false

local function startHorn()
    local vehicle = cache.vehicle
    if not isEmergencyVehicle(vehicle) or not hasPoliceFlag(vehicle) then return end
    if hornActive then return end

    hornActive           = true
    Siren.state.horn     = true
    if Siren.menuOpen then Siren:pushNui() end

    CreateThread(function()
        while hornActive and cache.vehicle and cache.vehicle ~= 0 do
            Wait(0)
            SoundVehicleHornThisFrame(cache.vehicle)
        end
        hornActive = false
    end)
end

local function stopHorn()
    if not hornActive and not Siren.state.horn then return end
    hornActive        = false
    Siren.state.horn  = false
    if Siren.menuOpen then Siren:pushNui() end
end

-- ============================================================
--  Keybinds
-- ============================================================

lib.addKeybind({
    name        = "p_policejob_siren_menu",
    description = locale("siren_kb_toggle_menu"),
    defaultKey  = Config.Siren.keybinds.toggleMenu.key,
    onPressed   = function()
        if Siren.menuOpen then Siren:closeMenu() else Siren:openMenu() end
    end,
})

lib.addKeybind({
    name        = "p_policejob_siren_lights",
    description = locale("siren_kb_toggle_lights"),
    defaultKey  = Config.Siren.keybinds.toggleLights.key,
    onPressed   = function()
        if not Siren:hasAccess() then return end
        local vehicle = cache.vehicle
        if not isEmergencyVehicle(vehicle) or not hasPoliceFlag(vehicle) then return end
        Siren.currentVehicle = vehicle
        Siren:toggleLights()
    end,
})

lib.addKeybind({
    name        = "p_policejob_siren_cycle",
    description = locale("siren_kb_cycle_siren"),
    defaultKey  = Config.Siren.keybinds.cycleSiren.key,
    onPressed   = function()
        if not Siren:hasAccess() then return end
        local vehicle = cache.vehicle
        if not isEmergencyVehicle(vehicle) or not hasPoliceFlag(vehicle) then return end
        Siren.currentVehicle = vehicle
        if not Siren.state.audio then
            Siren:toggleAudio()
        else
            Siren:cycleTone()
        end
    end,
})

lib.addKeybind({
    name        = "p_policejob_siren_mute",
    description = locale("siren_kb_mute_toggle"),
    defaultKey  = Config.Siren.keybinds.muteToggle.key,
    onPressed   = function()
        local vehicle = cache.vehicle
        if not isEmergencyVehicle(vehicle) or not hasPoliceFlag(vehicle) then return end
        Siren.currentVehicle = vehicle
        Siren:toggleMute()
    end,
})

lib.addKeybind({
    name        = "p_policejob_siren_horn",
    description = locale("siren_kb_manual_horn"),
    defaultKey  = Config.Siren.keybinds.manualHorn.key,
    onPressed   = startHorn,
    onReleased  = stopHorn,
})

-- ============================================================
--  NUI callback
-- ============================================================

RegisterNUICallback("siren/closeEdit", function(_, cb)
    Siren:setEditing(false)
    cb(1)
end)

-- ============================================================
--  Vehicle departure / change monitor (every 500ms)
-- ============================================================

CreateThread(function()
    while true do
        Wait(500)
        local tracked = Siren.currentVehicle
        if tracked then
            local inSameVehicle = cache.vehicle == tracked and hasPoliceFlag(tracked)
            if not inSameVehicle then
                Siren:reset()
                Siren.currentVehicle = nil
                if Siren.menuOpen then Siren:closeMenu() end
            end
        end
    end
end)

-- ============================================================
--  Sound loop maintenance (every 250ms) — restarts sound if it ended
-- ============================================================

CreateThread(function()
    while true do
        Wait(250)
        local vehicle        = Siren.currentVehicle
        local shouldPlay     = vehicle
            and DoesEntityExist(vehicle)
            and Siren.state.lights
            and Siren.state.audio
            and not Siren.state.muted

        if shouldPlay then
            if activeSoundId and HasSoundFinished(activeSoundId) then
                local toneDef   = Config.Siren.tones[Siren.state.tone]
                local soundName = toneDef and toneDef.sound
                playSirenSound(vehicle, soundName)
            end
        else
            if activeSoundId then stopSirenSound() end
        end
    end
end)

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    local name = data and data.name or nil
    if name == "setVisibleSiren" and Siren.editing then
        Siren:setEditing(false)
    end
end)

-- ============================================================
--  /sirenconfig command
-- ============================================================

RegisterCommand("sirenconfig", function()
    if not Siren.menuOpen then Siren:openMenu() end
    if Siren.menuOpen then
        Siren:setEditing(not Siren.editing)
    end
end, false)

TriggerEvent("chat:addSuggestion", "/sirenconfig", locale("siren_command_suggestion"))

-- ============================================================
--  Default siren key block (disables native Q key siren)
-- ============================================================

CreateThread(function()
    if Config.Siren.disableDefaultSiren == false then return end
    while true do
        local vehicle = cache.vehicle
        if vehicle and vehicle ~= 0 then
            if cache.seat == -1 and isEmergencyVehicle(vehicle) then
                DisableControlAction(0, 86, true)  -- control 86 = VehicleHorn (siren toggle)
                if IsVehicleSirenOn(vehicle) then
                    SetVehicleHasMutedSirens(vehicle, true)
                end
                Wait(0)
            else
                Wait(500)
            end
        else
            Wait(500)
        end
    end
end)

-- ============================================================
--  Exports
-- ============================================================

exports("isSirenMenuOpen", function() return Siren.menuOpen end)
exports("openSirenMenu",   function() Siren:openMenu() end)
