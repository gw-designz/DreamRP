if not (Config and Config.Prison and Config.Prison.Enabled) then return end

-- Global Prison object shared across the resource
Prison = {
    isInPrison  = false,
    sentenceData = nil,
    cellId      = nil,
    prisonZone  = nil,
    savedOutfit = nil,
    Map         = nil,
    inHospital  = false,
    hudHidden   = false,
}

-- ─── Map Loading Thread ───────────────────────────────────────────────────────

CreateThread(function()
    while not Config.PrisonMap do Wait(100) end

    local mapType = type(Config.PrisonMap)

    if mapType == "string" then
        Prison.Map = lib.load(string.format("maps.prisons.%s", Config.PrisonMap))
    elseif mapType == "table" then
        Prison.Map = lib.load(string.format("maps.prisons.%s", Config.PrisonMap[1]))
    end

    if type(Prison.Map) ~= "table" then
        lib.print.error("Failed to load prison map. Check Config.PrisonMap in config/shared.lua")
        return
    end

    if Bridge and type(Bridge.Debug) == "function" then
        Bridge.Debug("[Prison] Loaded prison map: " .. tostring(Config.PrisonMap))
    else
        lib.print.debug("[Prison] Loaded prison map: " .. tostring(Config.PrisonMap))
    end
end)

-- ─── Job Helpers ─────────────────────────────────────────────────────────────

-- Returns true if the local player's job is in Config.Jobs
function Prison:hasJobAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end
    return Config.Jobs[job.name] ~= nil
end

-- Returns the player's numeric job grade, or -1 if not in an authorised job
function Prison:getJobGrade()
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return -1 end
    if Config.Jobs[job.name] == nil then return -1 end
    return tonumber(job.grade) or 0
end

-- ─── Outfit Management ────────────────────────────────────────────────────────

-- Component slot index lookup for outfit save/restore
local COMPONENT_SLOTS = {
    tshirt  = 8,
    torso   = 11,
    decals  = 10,
    arms    = 3,
    pants   = 4,
    shoes   = 6,
    bags    = 5,
}

-- Saves current outfit then applies prison outfit for MP male/female peds
function Prison:applyPrisonOutfit()
    local ped        = cache.ped
    local isMpMale   = GetEntityModel(ped) == 1885233650
    local outfitCfg  = isMpMale and Config.Prison.PrisonOutfit.male or Config.Prison.PrisonOutfit.female
    if not outfitCfg then return end

    self.savedOutfit = {}

    for key, value in pairs(outfitCfg) do
        -- Keys with suffix "_1" are drawable component entries
        local compName = key:match("^(.-)_(%d+)$")
        if compName then
            local suffixNum = tonumber(key:match("_(%d+)$"))
            if suffixNum == 1 then
                local slot = COMPONENT_SLOTS[compName]
                if slot then
                    self.savedOutfit[key]                    = GetPedDrawableVariation(ped, slot)
                    self.savedOutfit[compName .. "_2"]       = GetPedTextureVariation(ped, slot)
                end
            end
        end
    end

    -- Map from config key → component slot
    local slotMap = {
        tshirt_1 = { 8,  true },
        torso_1  = { 11, true },
        decals_1 = { 10, true },
        arms     = { 3,  true },
        pants_1  = { 4,  true },
        shoes_1  = { 6,  true },
    }

    for key, slotData in pairs(slotMap) do
        if outfitCfg[key] then
            local textureKey = key:gsub("_1$", "_2")
            local texture    = outfitCfg[textureKey] or 0
            SetPedComponentVariation(ped, slotData[1], outfitCfg[key], texture, 2)
        end
    end
end

-- Restores the outfit saved by applyPrisonOutfit
function Prison:restoreOutfit()
    if not self.savedOutfit then return end

    local ped = cache.ped
    local slotMap = {
        tshirt_1 = 8,
        torso_1  = 11,
        decals_1 = 10,
        arms     = 3,
        pants_1  = 4,
        shoes_1  = 6,
    }

    for key, slot in pairs(slotMap) do
        local drawable   = self.savedOutfit[key]
        local textureKey = key:gsub("_1$", "_2")
        local texture    = self.savedOutfit[textureKey] or 0
        if drawable then
            SetPedComponentVariation(ped, slot, drawable, texture, 2)
        end
    end

    self.savedOutfit = nil
end

-- ─── Teleport ────────────────────────────────────────────────────────────────

-- Fades out, teleports to coords (defaults to map spawn), then fades in
function Prison:teleportToPrison(coords)
    local dest = coords
    if not dest and self.Map and self.Map.location then
        dest = self.Map.location.spawn
    end

    DoScreenFadeOut(500)
    Wait(500)
    SetEntityCoords(cache.ped, dest.x, dest.y, dest.z, false, false, false, true)
    SetEntityHeading(cache.ped, dest.w or 0.0)
    Wait(700)
    DoScreenFadeIn(500)
end

-- ─── Jail HUD ────────────────────────────────────────────────────────────────

-- Sets the inJail/injail state bags (accepts remaining seconds; -1 = life)
local function SetJailStateBags(remaining)
    local value = false

    if remaining then
        if remaining == -1 then
            value = 99999
        else
            value = math.ceil(math.max(remaining, 1) / 60)
        end
    end

    LocalPlayer.state:set("inJail",  value, true)
    LocalPlayer.state:set("injail",  value, true)
end

-- Pushes current sentence data to the NUI jail HUD
function Prison:pushJailHud()
    if not self.isInPrison or not self.sentenceData then
        SendNUIMessage({ action = "setVisibleJailHud", data = false })
        return
    end

    if self.hudHidden then
        SendNUIMessage({ action = "setVisibleJailHud", data = false })
        return
    end

    -- Find the cell label for the current cell
    local cellLabel = "General Population"
    if self.cellId and self.Map and self.Map.cells then
        for _, cell in ipairs(self.Map.cells) do
            if cell.id == self.cellId then
                cellLabel = cell.label or cellLabel
                break
            end
        end
    end

    local remaining = self.sentenceData.remaining or 0
    local isLife    = remaining == -1
    local isCS      = self.sentenceData.isCommunityService == true

    local sentenceType = isLife and "life" or (isCS and "community" or "prison")

    SendNUIMessage({ action = "setVisibleJailHud", data = true })
    SendNUIMessage({
        action = "setJailHudData",
        data   = {
            prisonerName = self.sentenceData.playerName,
            officerName  = self.sentenceData.officerName,
            reason       = self.sentenceData.reason,
            cellLabel    = cellLabel,
            sentenceType = sentenceType,
            totalSeconds = self.sentenceData.sentenceTime or 0,
            remainingSeconds = isLife and -1 or math.max(0, remaining),
        },
    })
end

-- ─── Prison Entry / Exit ─────────────────────────────────────────────────────

-- Runs the full entry sequence: state, outfit, teleport, HUD, uncuff, hooks
function Prison:enter(sentenceData)
    if self.isInPrison then return end

    self.isInPrison   = true
    self.sentenceData = sentenceData
    self.cellId       = sentenceData.cellId

    LocalPlayer.state:set("isInPrison",    true,                    true)
    LocalPlayer.state:set("prisonSentence", sentenceData.remaining, true)

    SetJailStateBags(sentenceData.remaining)
    RemoveAllPedWeapons(cache.ped, true)
    self:applyPrisonOutfit()

    -- Resolve teleport destination
    local destCoords, cellLabel
    if self.cellId and self.Map and self.Map.cells then
        for _, cell in ipairs(self.Map.cells) do
            if cell.id == self.cellId then
                destCoords = sentenceData.solitaryCoords or cell.coords
                cellLabel  = cell.label
                break
            end
        end
    end

    self:teleportToPrison(destCoords)

    -- Build sentence duration string
    local isLife        = sentenceData.remaining == -1
    local sentenceMins  = math.ceil((sentenceData.remaining or sentenceData.sentenceTime or 0) / 60)
    local durationStr   = isLife and locale("prison_life_sentence_label")
        or locale("prison_minutes", sentenceMins)

    local cellStr   = cellLabel or locale("prison_general_population")
    local officerStr = sentenceData.officerName or locale("prison_unknown")

    lib.alertDialog({
        header  = locale("prison_alert_jailed_header"),
        content = locale("prison_alert_jailed_body",
            sentenceData.reason or locale("prison_no_reason"),
            durationStr,
            cellStr,
            officerStr),
        centered = true,
        cancel   = false,
    })

    self:pushJailHud()

    -- Uncuff if needed
    if LocalPlayer.state.isCuffed then
        Wait(1000)
        if Interactions then
            Interactions.isCuffed = false
            Interactions:destroyCuffProp()
        end
        LocalPlayer.state:set("isCuffed",  false, true)
        LocalPlayer.state:set("cuffType",  "none", true)
        ClearPedTasks(cache.ped)
    end

    if type(Config.Prison.onPlayerJailed) == "function" then
        Config.Prison.onPlayerJailed(cache.serverId, sentenceData)
    end

    Bridge.Debug("[Prison] Player entered prison, sentence: " .. tostring(sentenceData.remaining) .. "s")
end

-- Runs the full release sequence: clears state, restores outfit, teleports, hides HUD
function Prison:release()
    if not self.isInPrison then return end

    self.isInPrison   = false
    self.sentenceData = nil
    self.cellId       = nil

    LocalPlayer.state:set("isInPrison",    false, true)
    LocalPlayer.state:set("prisonSentence", 0,    true)

    SetJailStateBags(nil)
    self:restoreOutfit()

    local releaseCoords = self.Map and self.Map.location and self.Map.location.release
    self:teleportToPrison(releaseCoords)

    SendNUIMessage({ action = "setPrisonTime",       data = { remaining = 0 } })
    SendNUIMessage({ action = "setVisibleJailHud",   data = false })

    Bridge.Notify.showNotify(locale("prison_released"), "success")

    if type(Config.Prison.onPlayerReleased) == "function" then
        Config.Prison.onPlayerReleased(cache.serverId)
    end

    Bridge.Debug("[Prison] Player released from prison")
end

-- ─── Net Events ──────────────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/client/prison/enter", function(sentenceData)
    if type(sentenceData) ~= "table" then return end
    Prison:enter(sentenceData)
end)

RegisterNetEvent("p_policejob/client/prison/release", function()
    Prison:release()
end)

RegisterNetEvent("p_policejob/client/prison/escaped", function()
    if not Prison.isInPrison then return end

    Prison.isInPrison   = false
    Prison.sentenceData = nil
    Prison.cellId       = nil

    LocalPlayer.state:set("isInPrison",    false, true)
    LocalPlayer.state:set("prisonSentence", 0,    true)

    SetJailStateBags(nil)

    SendNUIMessage({ action = "setPrisonTime",     data = { remaining = 0 } })
    SendNUIMessage({ action = "setVisibleJailHud", data = false })

    Bridge.Debug("[Prison] Player escaped from prison")
end)

RegisterNetEvent("p_policejob/client/prison/updateSentence", function(remaining, newSentenceTime)
    if not Prison.isInPrison then return end

    if Prison.sentenceData then
        Prison.sentenceData.remaining = remaining
        if newSentenceTime then
            Prison.sentenceData.sentenceTime = newSentenceTime
        end
    end

    LocalPlayer.state:set("prisonSentence", remaining, true)
    SetJailStateBags(remaining)

    SendNUIMessage({ action = "setPrisonTime", data = { remaining = remaining } })
    Prison:pushJailHud()
end)

RegisterNetEvent("p_policejob/client/prison/moveToCell", function(cellId)
    if not Prison.isInPrison then return end

    Prison.cellId = cellId
    if not (Prison.Map and Prison.Map.cells) then return end

    for _, cell in ipairs(Prison.Map.cells) do
        if cell.id == cellId then
            Prison:teleportToPrison(cell.coords)
            Bridge.Notify.showNotify(locale("prison_moved_to_cell", cell.label), "info")
            Prison:pushJailHud()
            break
        end
    end
end)

RegisterNetEvent("p_policejob/client/prison/moveToSolitary", function(coordsArg)
    if not Prison.isInPrison then return end

    -- Resolve solitary coords: argument → map.solitary → map.solitary[1]
    local dest = coordsArg
    if not dest and Prison.Map and Prison.Map.solitary then
        local sol = Prison.Map.solitary
        dest = sol.x and sol or sol[1]
    end

    if not dest then return end

    Prison:teleportToPrison(dest)
    Bridge.Notify.showNotify(locale("prison_sent_to_solitary"), "error")
end)

RegisterNetEvent("p_policejob/client/prison/restoreState", function(sentenceData)
    if not (sentenceData and sentenceData.remaining) then return end
    if sentenceData.remaining > 0 or sentenceData.remaining == -1 then
        Prison:enter(sentenceData)
    end
end)

RegisterNetEvent("p_policejob/client/prison/releaseSpawn", function()
    if Prison.isInPrison then return end

    while not Prison.Map do Wait(100) end

    Prison:teleportToPrison(Prison.Map.location.release)
    Bridge.Notify.showNotify(locale("prison_released"), "success")
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("isInPrison",       function() return Prison.isInPrison  end)
exports("getPrisonSentence", function() return Prison.sentenceData end)

-- ─── HUD Toggle Command ───────────────────────────────────────────────────────

RegisterCommand("jailhud", function()
    if not Prison.isInPrison then return end
    Prison.hudHidden = not Prison.hudHidden
    Prison:pushJailHud()
end, false)

RegisterKeyMapping("jailhud", "Toggle Jail HUD", "keyboard", "F10")

-- ─── Hospital System ─────────────────────────────────────────────────────────

-- Returns a free hospital bed coords table, or the first bed if all occupied
local function FindFreeHospitalBed()
    local beds = Prison.Map and Prison.Map.hospital and Prison.Map.hospital.beds
    if not (beds and #beds > 0) then return nil end

    for _, bed in ipairs(beds) do
        local nearby = lib.getNearbyPlayers(vector3(bed.x, bed.y, bed.z), 1.0, false)
        if #nearby == 0 then return bed end
    end

    return beds[1]
end

-- Teleports to a hospital bed, runs treatment countdown, then revives the ped
function Prison:sendToHospital()
    if self.inHospital then return end

    local bed = FindFreeHospitalBed()
    if not bed then return end

    self.inHospital = true

    DoScreenFadeOut(500)
    Wait(500)
    SetEntityCoords(cache.ped, bed.x, bed.y, bed.z, false, false, false, true)
    SetEntityHeading(cache.ped, bed.w or 0.0)
    Wait(500)
    DoScreenFadeIn(500)

    local treatTime = Config.Prison.Hospital.treatTime or 30
    while treatTime > 0 do
        if not self.isInPrison then break end
        lib.showTextUI(locale("prison_hospital_treating", treatTime), {
            position = "top-center",
            icon     = "truck-medical",
        })
        Wait(1000)
        treatTime = treatTime - 1
    end

    lib.hideTextUI()

    if self.isInPrison then
        Editable:revivePlayer()
        Bridge.Notify.showNotify(locale("prison_hospital_treated"), "success")
    end

    self.inHospital = false
end

-- Hospital check thread: every 5s, if dead and not already hospitalised, send to hospital
CreateThread(function()
    while true do
        Wait(5000)

        if Config.Prison.Hospital and Config.Prison.Hospital.enabled
        and Prison.isInPrison and not Prison.inHospital
        and Prison.Map and Prison.Map.hospital
        then
            local dead = Editable.isPlayerDead and Editable:isPlayerDead(cache.serverId)
                or IsEntityDead(cache.ped)

            if dead then
                Prison:sendToHospital()
            end
        end
    end
end)

-- ─── Prison Zone ─────────────────────────────────────────────────────────────

CreateThread(function()
    local zoneCfg = Config.Prison.Zone
    if not (zoneCfg and zoneCfg.enabled) then return end

    while not (Prison.Map and Prison.Map.location) do Wait(500) end

    local center = zoneCfg.center
        or (Prison.Map.location.spawn)

    lib.zones.sphere({
        coords = vec3(center.x, center.y, center.z),
        radius = zoneCfg.radius or 200.0,
        debug  = Bridge.Config and Bridge.Config.Debug,
        onExit = function()
            if not Prison.isInPrison then return end
            if Prison.sentenceData and Prison.sentenceData.isCommunityService then return end

            CreateThread(function()
                Prison:teleportToPrison(Prison.Map.location.spawn)
                Bridge.Notify.showNotify(locale("prison_zone_return"), "error")
            end)
        end,
    })
end)

-- ─── Jail Locker ─────────────────────────────────────────────────────────────

-- Officer opens another prisoner's locker by their citizen ID
local function OpenJailLockerById()
    local input = lib.inputDialog(locale("jail_locker"), {
        { type = "input", label = locale("jail_locker_citizen_id"), required = true },
    })
    if not (input and input[1]) then return end

    local stashId = lib.callback.await("p_policejob/server/prison/jailLocker/getById", false, input[1])
    if not stashId then
        return Bridge.Notify.showNotify(locale("jail_locker_not_found"), "error")
    end

    Bridge.Inventory.openInventory("stash", { id = stashId })
end

-- Prisoner opens their own jail locker
local function OpenOwnJailLocker()
    local stashId = lib.callback.await("p_policejob/server/prison/jailLocker/getOwn", false)
    if not stashId then
        return Bridge.Notify.showNotify(locale("jail_locker_cant_open"), "error")
    end

    Bridge.Inventory.openInventory("stash", { id = stashId })
end

CreateThread(function()
    local lockerCfg = Config.Prison.JailLocker
    if not (lockerCfg and lockerCfg.enabled) then return end

    -- Police point: officers look up prisoner lockers by ID
    if lockerCfg.policePoint and lockerCfg.policePoint.coords then
        Bridge.Target.addSphereZone({
            coords = lockerCfg.policePoint.coords,
            radius = lockerCfg.policePoint.radius or 0.75,
            debug  = Bridge.Config and Bridge.Config.Debug,
            options = {
                {
                    name     = "p_policejob_jail_locker_police",
                    label    = locale("jail_locker_open_by_id"),
                    icon     = lockerCfg.policePoint.icon     or "fa-solid fa-id-card",
                    distance = lockerCfg.policePoint.distance or 2.0,
                    groups   = Config.Jobs,
                    onSelect = OpenJailLockerById,
                },
            },
        })
    end

    -- Prison point: prisoners open their own locker
    if lockerCfg.prisonPoint and lockerCfg.prisonPoint.coords then
        Bridge.Target.addSphereZone({
            coords = lockerCfg.prisonPoint.coords,
            radius = lockerCfg.prisonPoint.radius or 0.75,
            debug  = Bridge.Config and Bridge.Config.Debug,
            options = {
                {
                    name     = "p_policejob_jail_locker_personal",
                    label    = locale("jail_locker"),
                    icon     = lockerCfg.prisonPoint.icon     or "fa-solid fa-id-card",
                    distance = lockerCfg.prisonPoint.distance or 2.0,
                    onSelect = OpenOwnJailLocker,
                },
            },
        })
    end
end)
