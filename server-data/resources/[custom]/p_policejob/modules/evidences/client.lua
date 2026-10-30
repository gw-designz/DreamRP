-- Wait for Config.Evidences to be available
while not (Config and Config.Evidences) do Citizen.Wait(500) end

if not Config.Evidences.enabled then return end

local evidencesConfig = Config.Evidences

-- Global Evidences object shared across the resource
Evidences = {}
Evidences.list    = {}   -- [id] = evidenceData
Evidences.props   = {}   -- [id] = entity handle
Evidences.targets = {}   -- [id] = target zone handle or name
Evidences.recon   = {
    active    = false,
    expiresAt = 0,
    items     = {},
}

-- true when the local player is holding the flashlight weapon
local isHoldingFlashlight = false

-- ─── Glove Detection ─────────────────────────────────────────────────────────

-- Drawable variations considered "gloves on" for the torso component (component 3)
local GLOVED_DRAWABLES = {
    [-1] = true, [0] = true, [1] = true, [2] = true, [3] = true,
    [4]  = true, [5] = true, [6] = true, [7] = true, [8] = true,
    [9]  = true, [10] = true, [11] = true, [12] = true, [13] = true,
    [14] = true, [15] = true, [16] = true,
    [113] = true, [114] = true, [115] = true,
    [199] = true,
}

-- Returns true when the ped is a known MP model but is NOT wearing gloves
function IsNotWearingGloves()
    local ped       = cache.ped or PlayerPedId()
    local model     = GetEntityModel(ped)
    local isMpMale  = model == 1885233650
    local isMpFemale = model == -1667301416

    if not (isMpMale or isMpFemale) then return false end

    local torsoDrawable = GetPedDrawableVariation(ped, 3)
    return not GLOVED_DRAWABLES[torsoDrawable]
end

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Returns the evidence type definition for the given type key, or nil
function GetEvidenceTypeDef(evidenceType)
    return evidencesConfig.Types[evidenceType]
end

-- Resolves the street name and zone label for a world coords table
function GetLocationInfo(coords)
    if not (coords and coords.x and coords.y and coords.z) then return nil end

    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    local zoneLabel  = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    if zoneLabel == "NULL" then zoneLabel = nil end

    return {
        street = (streetName ~= "" and streetName) or nil,
        zone   = zoneLabel,
    }
end

-- Enriches each evidence entry in a list with its .street and .zone fields
function EnrichEvidenceLocations(evidenceList)
    for _, entry in ipairs(evidenceList or {}) do
        if entry.coords then
            local location = GetLocationInfo(entry.coords)
            if location then
                entry.street = location.street
                entry.zone   = location.zone
            end
        end
    end
    return evidenceList
end

-- Returns the display name of the vehicle model (label text or model name fallback)
function GetVehicleDisplayName(vehicleEntity)
    local modelName  = GetDisplayNameFromVehicleModel(GetEntityModel(vehicleEntity))
    local labelText  = GetLabelText(modelName)
    if labelText and labelText ~= "NULL" and labelText ~= "" then
        return labelText
    end
    return modelName
end

-- Returns true if the local player's job meets the evidence access threshold
function LocalPlayerHasEvidenceAccess()
    if not Config.Jobs then return true end

    local job = Bridge.Framework.fetchPlayerJob and Bridge.Framework.fetchPlayerJob()
    if not job then return false end

    local threshold = Config.Jobs[job.name]
    if threshold == nil then return false end

    return threshold <= job.grade
end

-- ─── Prop Management ─────────────────────────────────────────────────────────

-- Deletes the spawned prop for the given evidence id and removes it from the table
function DeleteEvidenceProp(evidenceId)
    local entity = Evidences.props[evidenceId]
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    Evidences.props[evidenceId] = nil
end

-- Removes the target zone for the given evidence id
function RemoveEvidenceTarget(evidenceId)
    local zone = Evidences.targets[evidenceId]
    if zone and Bridge.Target.removeSphereZone then
        pcall(Bridge.Target.removeSphereZone, zone)
    end
    Evidences.targets[evidenceId] = nil
end

-- Deletes all spawned props and removes all target zones
function CleanupAllEvidences()
    for id in pairs(Evidences.props)   do DeleteEvidenceProp(id) end
    for id in pairs(Evidences.targets) do RemoveEvidenceTarget(id) end
end

-- Spawns the 3D prop for an evidence entry (skips if already spawned and valid)
function SpawnEvidenceProp(evidenceData)
    local existing = Evidences.props[evidenceData.id]
    if existing and DoesEntityExist(existing) then return end

    local typeDef = GetEvidenceTypeDef(evidenceData.type)
    if not (typeDef and typeDef.prop) then return end

    local modelHash
    if type(typeDef.prop) == "number" then
        modelHash = typeDef.prop
    else
        modelHash = joaat(typeDef.prop)
    end

    if not (IsModelInCdimage(modelHash) and IsModelValid(modelHash)) then return end
    if not lib.requestModel(modelHash, 5000) then return end

    local zOffset = (typeDef.offset and typeDef.offset.z) or 0
    local entity  = CreateObject(
        modelHash,
        evidenceData.coords.x, evidenceData.coords.y, evidenceData.coords.z + zOffset,
        false, false, false
    )

    SetModelAsNoLongerNeeded(modelHash)
    if not entity or entity == 0 then return end

    SetEntityAsMissionEntity(entity, true, true)
    SetEntityCollision(entity, false, false)
    FreezeEntityPosition(entity, true)

    SetEntityRotation(entity,
        evidenceData.rotation.x or 0.0,
        evidenceData.rotation.y or 0.0,
        evidenceData.rotation.z or 0.0,
        2, true
    )

    PlaceObjectOnGroundProperly(entity)
    SetEntityAlpha(entity, 220, false)

    if typeDef.scale and typeDef.scale ~= 1.0 then
        SetEntityScale(entity, typeDef.scale, typeDef.scale, typeDef.scale)
    end

    Evidences.props[evidenceData.id] = entity
end

-- Registers a target sphere zone for an evidence entry (skips if already registered)
function RegisterEvidenceTarget(evidenceData)
    if Evidences.targets[evidenceData.id] then return end

    local typeDef = GetEvidenceTypeDef(evidenceData.type)
    if not typeDef then return end
    if not Bridge.Target.addSphereZone then return end

    local zoneName = "p_policejob/evidence/" .. evidenceData.id

    local zone = Bridge.Target.addSphereZone({
        name   = zoneName,
        coords = vec3(evidenceData.coords.x, evidenceData.coords.y, evidenceData.coords.z),
        radius = 0.5,
        debug  = false,
        options = {
            {
                name     = zoneName .. ":collect",
                label    = locale("evidence_collect_target"):format(typeDef.label),
                icon     = "fa-solid fa-vial",
                distance = 2.5,
                onSelect = function()
                    Evidences:collect(evidenceData.id)
                end,
                canInteract = function()
                    return LocalPlayerHasEvidenceAccess()
                end,
            },
            {
                name     = zoneName .. ":clean",
                label    = locale("evidence_clean_target"):format(typeDef.label),
                icon     = "fa-solid fa-broom",
                distance = 2.5,
                onSelect = function()
                    Evidences:collect(evidenceData.id)
                end,
                canInteract = function()
                    return not LocalPlayerHasEvidenceAccess()
                end,
            },
        },
    })

    Evidences.targets[evidenceData.id] = zone or zoneName
end

-- ─── Evidences Methods ───────────────────────────────────────────────────────

-- Plays the collection progress bar and fires the server collect event
function Evidences:collect(evidenceId)
    local evidenceData = self.list[evidenceId]
    if not evidenceData then return end

    local typeDef  = GetEvidenceTypeDef(evidenceData.type)
    if not typeDef then return end

    local isOfficer = LocalPlayerHasEvidenceAccess()

    local label    = isOfficer
        and locale("evidence_collecting"):format(typeDef.label)
        or  locale("evidence_cleaning"):format(typeDef.label)

    local duration = isOfficer and 4000 or 6000

    local completed = lib.progressBar({
        duration     = duration,
        label        = label,
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = { dict = "amb@medic@standing@kneel@base", clip = "base", flag = 1 },
    })

    if not completed then return end

    RemoveEvidenceTarget(evidenceId)
    TriggerServerEvent("p_policejob/server/evidences/collect", evidenceId)
end

-- ─── Rendering Helpers ────────────────────────────────────────────────────────

-- Draws a flat circle marker beneath an evidence entity, fading with distance
function DrawEvidenceMarker(evidenceData, distance)
    local typeDef = GetEvidenceTypeDef(evidenceData.type)
    if not typeDef then return end

    local color    = typeDef.color or { r = 255, g = 255, b = 255 }
    local alpha    = math.floor(math.max(0, math.min(255, 220 * (1 - distance / evidencesConfig.RenderDistance))))

    DrawMarker(
        25,
        evidenceData.coords.x, evidenceData.coords.y, evidenceData.coords.z - 0.94,
        0, 0, 0, 0, 0, 0,
        0.22, 0.22, 0.22,
        color.r, color.g, color.b, alpha,
        false, false, 2, false, nil, nil, false
    )
end

-- Draws a bullet tracer line for bullet_casing evidence that has tracerFrom/To metadata
function DrawBulletTracer(evidenceData)
    local meta = evidenceData.metadata
    if not (meta and meta.tracerTo and meta.tracerFrom) then return end

    local typeDef = GetEvidenceTypeDef(evidenceData.type)
    local color   = (typeDef and typeDef.color) or { r = 255, g = 200, b = 80 }

    DrawLine(
        meta.tracerFrom.x, meta.tracerFrom.y, meta.tracerFrom.z,
        meta.tracerTo.x,   meta.tracerTo.y,   meta.tracerTo.z,
        color.r, color.g, color.b, 200
    )
end

-- Draws a floating diamond marker for each active recon item
function DrawReconMarker(reconItem)
    local typeDef = GetEvidenceTypeDef(reconItem.type)
    if not typeDef then return end

    local color = typeDef.color or { r = 200, g = 200, b = 255 }

    DrawMarker(
        21,
        reconItem.coords.x, reconItem.coords.y, reconItem.coords.z + 0.4,
        0, 0, 0, 0, 0, 0,
        0.35, 0.35, 0.35,
        color.r, color.g, color.b, 120,
        true, true, 2, true, nil, nil, false
    )
end

-- ─── Main Render Thread ───────────────────────────────────────────────────────

CreateThread(function()
    while true do
        local hasEvidences = next(Evidences.list)
        local reconActive  = Evidences.recon.active

        -- Sleep longer when nothing to render
        if not hasEvidences and not reconActive then
            Wait(500)
            goto continue
        end

        -- No flashlight and not in recon: clear props/targets if present, sleep
        if not isHoldingFlashlight and not reconActive then
            if next(Evidences.props) or next(Evidences.targets) then
                CleanupAllEvidences()
            end
            Wait(500)
            goto continue
        end

        Wait(0)

        local playerPos = GetEntityCoords(PlayerPedId())

        for evidenceId, evidenceData in pairs(Evidences.list) do
            local distance = #(playerPos - evidenceData.coords)

            if isHoldingFlashlight then
                if distance <= evidencesConfig.RenderDistance then
                    if not Evidences.props[evidenceId]   then SpawnEvidenceProp(evidenceData) end
                    if not Evidences.targets[evidenceId] then RegisterEvidenceTarget(evidenceData) end
                    DrawEvidenceMarker(evidenceData, distance)
                    if evidenceData.type == "bullet_casing" then DrawBulletTracer(evidenceData) end
                else
                    if Evidences.props[evidenceId]   then DeleteEvidenceProp(evidenceId) end
                    if Evidences.targets[evidenceId] then RemoveEvidenceTarget(evidenceId) end
                end
            end
        end

        -- Recon markers and expiry check
        if reconActive then
            if GetGameTimer() > Evidences.recon.expiresAt then
                Evidences.recon.active = false
                Evidences.recon.items  = {}
            else
                for _, reconItem in ipairs(Evidences.recon.items) do
                    DrawReconMarker(reconItem)
                end
            end
        end

        ::continue::
    end
end)

-- ─── Weapon Cache Handler ─────────────────────────────────────────────────────

-- Track whether the player is holding the flashlight (weapon hash -1951375401)
lib.onCache("weapon", function(weaponHash)
    isHoldingFlashlight = (weaponHash == -1951375401)
    if not isHoldingFlashlight then
        CleanupAllEvidences()
    end
end)

-- ─── Vehicle Cache Handler ────────────────────────────────────────────────────

-- When entering a networked vehicle, maybe leave a fingerprint after a random delay
lib.onCache("vehicle", function(vehicleEntity)
    local vehicleConfig = evidencesConfig.Vehicle
    if not (vehicleConfig and vehicleConfig.enabled and vehicleConfig.fingerprintOnEnter) then return end
    if not vehicleEntity or vehicleEntity == 0 then return end
    if not NetworkGetEntityIsNetworked(vehicleEntity) then return end

    if vehicleConfig.checkGloves and IsNotWearingGloves() then return end

    CreateThread(function()
        Wait(math.random(500, 3000))

        if cache.vehicle ~= vehicleEntity then return end  -- left the vehicle already

        local chance = vehicleConfig.fingerprintChance or 100
        if math.random(1, 100) > chance then return end

        TriggerServerEvent("p_policejob/server/evidences/vehicle", {
            evidenceType = "fingerprint",
            model        = GetVehicleDisplayName(vehicleEntity),
        })
    end)
end)

-- ─── Gunshot Event Handler ────────────────────────────────────────────────────

local lastGunshotTime = 0

AddEventHandler("CEventGunShot", function()
    if not evidencesConfig.AutoCreate.gunshot.enabled then return end

    local ped = cache.ped or PlayerPedId()
    if not IsPedShooting(ped) then return end

    local now = GetGameTimer()
    if now < lastGunshotTime then return end
    lastGunshotTime = now + 250

    local _, weaponHash  = GetCurrentPedWeapon(ped, true)
    local weaponLabel    = nil
    local weaponSerial   = nil

    local currentWeapon = Bridge.Inventory.getCurrentWeapon and Bridge.Inventory.getCurrentWeapon()
    if currentWeapon then
        if currentWeapon.metadata and currentWeapon.metadata.serial then
            weaponSerial = currentWeapon.metadata.serial
        end
        weaponLabel = currentWeapon.label or currentWeapon.name
    end

    -- If inside a networked vehicle, record bullet casing to vehicle evidence
    local vehicle = cache.vehicle
    local vehicleConfig = evidencesConfig.Vehicle
    if vehicleConfig and vehicleConfig.enabled and vehicleConfig.casingInVehicle
    and vehicle and vehicle ~= 0 and NetworkGetEntityIsNetworked(vehicle)
    then
        TriggerServerEvent("p_policejob/server/evidences/vehicle", {
            evidenceType = "bullet_casing",
            model        = GetVehicleDisplayName(vehicle),
            weaponHash   = weaponHash,
            weaponName   = weaponLabel,
            serial       = weaponSerial,
        })
        return
    end

    -- Ground-level shell casing at the shooter's feet
    local pedCoords    = GetEntityCoords(ped)
    local casingCoords = { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z - 0.95 }

    -- Compute tracer vectors from impact point back toward the muzzle
    local tracerFrom, tracerTo = nil, nil
    local hasImpact, impactCoords = GetPedLastWeaponImpactCoord(ped)

    if hasImpact then
        local direction = pedCoords - impactCoords
        local length    = #direction

        if length > 0.001 then
            direction = direction / length
            local tracerLength = (evidencesConfig.AutoCreate.gunshot.tracerLength or 2.5)

            tracerFrom = { x = impactCoords.x, y = impactCoords.y, z = impactCoords.z }
            tracerTo   = {
                x = impactCoords.x + direction.x * tracerLength,
                y = impactCoords.y + direction.y * tracerLength,
                z = impactCoords.z + direction.z * tracerLength,
            }
        end
    end

    TriggerServerEvent("p_policejob/server/evidences/gunshot", {
        coords     = casingCoords,
        rotation   = { x = 0.0, y = 0.0, z = math.random() * 360.0 },
        weaponHash = weaponHash,
        weaponName = weaponLabel,
        serial     = weaponSerial,
        tracerFrom = tracerFrom,
        tracerTo   = tracerTo,
    })
end)

-- ─── Blood / Damage Handler ───────────────────────────────────────────────────

local lastKnownHealth = 0
local lastKnownArmour = 0
local lastBloodTime   = 0

-- Track health/armour every 500ms for damage delta calculation
CreateThread(function()
    while true do
        local ped     = cache.ped or PlayerPedId()
        lastKnownHealth = GetEntityHealth(ped)
        lastKnownArmour = GetPedArmour(ped)
        Wait(500)
    end
end)

AddEventHandler("gameEventTriggered", function(eventName, eventData)
    if eventName ~= "CEventNetworkEntityDamage" then return end
    if not evidencesConfig.AutoCreate.bloodOnDamage.enabled then return end

    local damagedEntity = eventData[1]
    local weaponHash    = eventData[7] or 0

    if not IsPedAPlayer(damagedEntity) then return end
    if NetworkGetPlayerIndexFromPed(damagedEntity) ~= PlayerId() then return end
    if weaponHash == -1569615261 then return end  -- ignore suppressed weapons

    local currentHealth = GetEntityHealth(damagedEntity)
    local currentArmour = GetPedArmour(damagedEntity)
    local totalDamage   = (lastKnownHealth - currentHealth) + (lastKnownArmour - currentArmour)

    lastKnownHealth = currentHealth
    lastKnownArmour = currentArmour

    local minDamage = evidencesConfig.AutoCreate.bloodOnDamage.minDamage or 15.0
    if totalDamage < minDamage then return end

    local now      = GetGameTimer()
    local cooldown = evidencesConfig.AutoCreate.bloodOnDamage.cooldown or 2500
    if now - lastBloodTime < cooldown then return end
    lastBloodTime = now

    -- Vehicle blood evidence
    local vehicle       = cache.vehicle
    local vehicleConfig = evidencesConfig.Vehicle
    if vehicleConfig and vehicleConfig.enabled and vehicleConfig.bloodInVehicle
    and vehicle and vehicle ~= 0 and NetworkGetEntityIsNetworked(vehicle)
    then
        TriggerServerEvent("p_policejob/server/evidences/vehicle", {
            evidenceType = "blood",
            model        = GetVehicleDisplayName(vehicle),
        })
        return
    end

    local pedCoords = GetEntityCoords(damagedEntity)
    TriggerServerEvent("p_policejob/server/evidences/blood", {
        coords = { x = pedCoords.x, y = pedCoords.y, z = pedCoords.z - 0.95 },
    })
end)

-- ─── Evidence Sync Net Events ─────────────────────────────────────────────────

-- Server → client: authoritative evidence list for this player's stream range
RegisterNetEvent("p_policejob/client/evidences/sync", function(evidenceList)
    if type(evidenceList) ~= "table" then return end

    local receivedIds = {}

    for i = 1, #evidenceList do
        local entry = evidenceList[i]

        entry.coords = vec3(entry.coords.x, entry.coords.y, entry.coords.z)
        entry.rotation = vec3(
            entry.rotation.x or 0,
            entry.rotation.y or 0,
            entry.rotation.z or 0
        )

        receivedIds[entry.id]    = true
        Evidences.list[entry.id] = entry
    end

    -- Remove any evidences no longer in range
    for id in pairs(Evidences.list) do
        if not receivedIds[id] then
            Evidences.list[id] = nil
            DeleteEvidenceProp(id)
            RemoveEvidenceTarget(id)
        end
    end
end)

-- Server → client: a specific evidence was collected/removed
RegisterNetEvent("p_policejob/client/evidences/remove", function(evidenceId)
    Evidences.list[evidenceId] = nil
    DeleteEvidenceProp(evidenceId)
    RemoveEvidenceTarget(evidenceId)
end)

-- ─── Reconstruction ───────────────────────────────────────────────────────────

-- Fetches nearby evidences from the server and activates the recon overlay
function UseEvidenceReconstructor()
    local items = lib.callback.await("p_policejob/server/evidences/reconstruction", false)

    if not (items and #items > 0) then
        return Bridge.Notify.showNotify(locale("evidence_recon_empty"), "error")
    end

    for _, item in ipairs(items) do
        item.coords = vec3(item.coords.x, item.coords.y, item.coords.z)
    end

    Evidences.recon.active    = true
    Evidences.recon.expiresAt = GetGameTimer() + evidencesConfig.ReconstructionDuration
    Evidences.recon.items     = items

    Bridge.Notify.showNotify(
        locale("evidence_recon_started"):format(#items),
        "success"
    )
end

exports("useEvidenceReconstructor", UseEvidenceReconstructor)

if Bridge.Inventory.registerUsableItem then
    Bridge.Inventory.registerUsableItem(evidencesConfig.ReconstructionItem, function()
        UseEvidenceReconstructor()
    end)
end

-- ─── Evidence Laboratory (NUI) ────────────────────────────────────────────────

local Laboratory = { isOpen = false }

function Laboratory:open()
    if self.isOpen then return end

    if not LocalPlayerHasEvidenceAccess() then
        return Bridge.Notify.showNotify(locale("locker_no_access"), "error")
    end

    local bags = lib.callback.await("p_policejob/server/evidences/getInventory", false) or {}
    bags = EnrichEvidenceLocations(bags)

    self.isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "setVisibleLaboratory", data = true })
    SendNUIMessage({ action = "setLaboratoryData",    data = { bags = bags } })
end

function Laboratory:close()
    if not self.isOpen then return end
    self.isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibleLaboratory", data = false })
end

-- ─── Evidence Storage (NUI) ───────────────────────────────────────────────────

Storage = { isOpen = false, lockerId = "main" }

function Storage:open(rawLockerId)
    if self.isOpen then return end

    if not LocalPlayerHasEvidenceAccess() then
        return Bridge.Notify.showNotify(locale("locker_no_access"), "error")
    end

    local lockerId = tostring(rawLockerId or "main"):sub(1, 64)
    self.lockerId  = lockerId

    TriggerServerEvent("p_policejob/server/evidences/openStorage", lockerId)
    Wait(100)

    local bags = lib.callback.await("p_policejob/server/evidences/getStorageBags", false, lockerId) or {}
    bags = EnrichEvidenceLocations(bags)

    self.isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "setVisibleEvidenceStorage", data = true })
    SendNUIMessage({
        action = "setEvidenceStorageData",
        data   = { bags = bags, lockerId = lockerId },
    })
end

function Storage:close()
    if not self.isOpen then return end
    self.isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibleEvidenceStorage", data = false })
end

-- ─── NUI Frame Hide Handler ───────────────────────────────────────────────────

AddEventHandler("p_policejob:client:hideFrame", function(frameData)
    if not frameData then return end
    if frameData.name == "setVisibleLaboratory"    then Laboratory:close() end
    if frameData.name == "setVisibleEvidenceStorage" then Storage:close()  end
end)

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("evidence/refreshBags", function(_, cb)
    local bags = lib.callback.await("p_policejob/server/evidences/getInventory", false) or {}
    cb(EnrichEvidenceLocations(bags))
end)

RegisterNUICallback("evidence/analyze", function(payload, cb)
    local slot   = payload and payload.slot
    local result = lib.callback.await("p_policejob/server/evidences/analyze", false, slot)
    cb(result or { success = false })
end)

RegisterNUICallback("evidence/destroy", function(payload, cb)
    local slot   = payload and payload.slot
    local result = lib.callback.await("p_policejob/server/evidences/destroyBag", false, slot)
    cb(result or { success = false })
end)

RegisterNUICallback("evidence/setWaypoint", function(payload, cb)
    local coords = payload and payload.coords
    if coords and coords.x and coords.y then
        SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)
        Bridge.Notify.showNotify(locale("evidence_waypoint_set"), "success")
    end
    cb({})
end)

RegisterNUICallback("evidence/copy", function(payload, cb)
    local value = payload and payload.value
    if value ~= nil then
        lib.setClipboard(tostring(value))
        Bridge.Notify.showNotify(locale("copied_evidence_info"), "success")
    end
    cb({})
end)

-- Storage NUI: switch to a different locker by id
RegisterNUICallback("evidence/storageOpenLocker", function(payload, cb)
    local rawId  = (payload and payload.lockerId) or "main"
    local lockerId = tostring(rawId):sub(1, 64)

    Storage.lockerId = lockerId
    TriggerServerEvent("p_policejob/server/evidences/openStorage", lockerId)
    Wait(100)

    local bags = lib.callback.await("p_policejob/server/evidences/getStorageBags", false, lockerId) or {}
    cb({ bags = EnrichEvidenceLocations(bags), lockerId = lockerId })
end)

-- Storage NUI: open the inventory stash for the current locker
RegisterNUICallback("evidence/storageOpenInventory", function(payload, cb)
    local rawId    = (payload and payload.lockerId) or Storage.lockerId or "main"
    local lockerId = tostring(rawId):sub(1, 64)

    TriggerServerEvent("p_policejob/server/evidences/openStorage", lockerId)
    Wait(100)

    Bridge.Inventory.openInventory("stash", {
        id = evidencesConfig.StorageStashPrefix .. "_" .. lockerId,
    })
    cb({})
end)

-- Storage NUI: prompt the player for a locker id then open it
RegisterNUICallback("evidence/storagePromptLocker", function(_, cb)
    cb({})

    local currentId = Storage.lockerId or "main"
    Storage:close()

    local input = lib.inputDialog(locale("evidence_storage_prompt_title"), {
        { type = "input", label = locale("evidence_storage_prompt_label"), required = true, default = currentId },
    })

    Storage:open(input and input[1] or currentId)
end)

-- ─── Laboratory Target Zones ──────────────────────────────────────────────────

CreateThread(function()
    Citizen.Wait(2000)

    if not Bridge.Target.addSphereZone then return end

    for i, labData in ipairs(Config.DepartmentData.laboratories or {}) do
        if labData.coords then
            Bridge.Target.addSphereZone({
                name   = "p_policejob/evidence/lab_" .. i,
                coords = vec3(labData.coords.x, labData.coords.y, labData.coords.z),
                radius = 1.2,
                debug  = false,
                options = {
                    {
                        name     = "p_policejob/evidence/lab_open_" .. i,
                        label    = locale("evidence_open_lab"),
                        icon     = "fa-solid fa-microscope",
                        distance = 1.8,
                        groups   = Config.Jobs,
                        onSelect = function() Laboratory:open() end,
                    },
                    {
                        name     = "p_policejob/evidence/lab_storage_" .. i,
                        label    = locale("evidence_open_storage"),
                        icon     = "fa-solid fa-boxes-stacked",
                        distance = 1.8,
                        groups   = Config.Jobs,
                        onSelect = function()
                            local input = lib.inputDialog(locale("evidence_storage_prompt_title"), {
                                { type = "input", label = locale("evidence_storage_prompt_label"), required = true, default = "main" },
                            })
                            if input and input[1] then Storage:open(input[1]) end
                        end,
                    },
                },
            })

            if labData.blip then
                local blip = AddBlipForCoord(labData.coords.x, labData.coords.y, labData.coords.z)
                SetBlipSprite(blip,        labData.blip.sprite or 458)
                SetBlipColour(blip,        labData.blip.color  or 38)
                SetBlipScale(blip,         labData.blip.scale  or 0.7)
                SetBlipAsShortRange(blip,  true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentSubstringPlayerName(labData.blip.label or labData.label or "Crime Lab")
                EndTextCommandSetBlipName(blip)
            end
        end
    end
end)

-- ─── Vehicle Evidence Analysis ────────────────────────────────────────────────

local COLLECTION_ANIM = { dict = "amb@medic@standing@kneel@base", clip = "base", flag = 1 }
local isAnalyzingVehicle = false

-- Collects a specific evidence entry from a vehicle
local function CollectVehicleEvidence(plate, evidenceEntry)
    local completed = lib.progressBar({
        duration     = 4000,
        label        = locale("evidence_collecting"):format(evidenceEntry.label),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = COLLECTION_ANIM,
    })
    if not completed then return end
    TriggerServerEvent("p_policejob/server/evidences/collectVehicle", plate, evidenceEntry.id)
end

-- Builds and shows the vehicle evidence context menu
local function ShowVehicleEvidenceMenu(plate, evidenceList)
    local options = {}
    for _, entry in ipairs(evidenceList) do
        options[#options + 1] = {
            title       = string.format("%s - #%s", entry.label, entry.id),
            description = locale("vehicle_evidence_desc", plate, entry.date or "-"),
            icon        = "fa-solid fa-vial",
            onSelect    = function()
                CollectVehicleEvidence(plate, entry)
            end,
        }
    end

    lib.registerContext({ id = "p_policejob_vehicle_evidence", title = locale("vehicle_analysis_title"), options = options })
    lib.showContext("p_policejob_vehicle_evidence")
end

-- Entry point for vehicle evidence analysis
function AnalyzeVehicle(vehicleEntity)
    if isAnalyzingVehicle then return end

    if not LocalPlayerHasEvidenceAccess() then
        return Bridge.Notify.showNotify(locale("locker_no_access"), "error")
    end

    -- Resolve the vehicle: argument → current vehicle → closest vehicle
    if not vehicleEntity or vehicleEntity == 0 then
        vehicleEntity = cache.vehicle
        if not vehicleEntity or vehicleEntity == 0 then
            vehicleEntity = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
        end
    end

    if not (vehicleEntity and vehicleEntity ~= 0 and NetworkGetEntityIsNetworked(vehicleEntity)) then
        return Bridge.Notify.showNotify(locale("no_closest_vehicle"), "error")
    end

    local plate = GetVehicleNumberPlateText(vehicleEntity)
    isAnalyzingVehicle = true

    local completed = lib.progressBar({
        duration     = 3500,
        label        = locale("analyzing_vehicle"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = COLLECTION_ANIM,
    })

    if not completed then
        isAnalyzingVehicle = false
        return
    end

    local evidenceList = lib.callback.await("p_policejob/server/evidences/getVehicleEvidence", false, plate) or {}
    isAnalyzingVehicle = false

    if #evidenceList == 0 then
        return Bridge.Notify.showNotify(locale("vehicle_evidence_none"), "info")
    end

    ShowVehicleEvidenceMenu(plate, evidenceList)
end

exports("analyzeVehicle", function(vehicleEntity)
    AnalyzeVehicle(vehicleEntity)
end)

AddEventHandler("p_policejob/analyzeVehicle", function()
    AnalyzeVehicle()
end)

-- ─── Cleanup on Resource Stop ─────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CleanupAllEvidences()
end)
