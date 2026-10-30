-- Wait for Config.Evidences to be available
while not (Config and Config.Evidences) do Citizen.Wait(500) end

if not Config.Evidences.enabled then return end

local evidencesConfig = Config.Evidences

-- Global Evidences object shared across the resource
Evidences = {}
Evidences.list              = {}   -- [id] = evidenceData
Evidences.spatial           = {}   -- ["x:y"] = { [id] = true }
Evidences.serialCache       = {}   -- [uniqueId] = { fingerprint, dna, bloodType }
Evidences.registeredStashes = {}   -- [stashId] = true
Evidences.vehicles          = {}   -- [plate] = [ evidenceEntry, ... ]
Evidences.nextId            = 1

-- vehicleEventCooldown[source] = unix timestamp when they may next trigger vehicle evidence
local vehicleEventCooldown = {}

local SPATIAL_CELL_SIZE = 50.0

-- ─── Spatial Hashing ─────────────────────────────────────────────────────────

-- Returns the cell key string for a world X/Y position
function GetSpatialKey(x, y)
    return string.format("%d:%d",
        math.floor(x / SPATIAL_CELL_SIZE),
        math.floor(y / SPATIAL_CELL_SIZE)
    )
end

-- Returns a list of all cell key strings within `radius` of (x, y)
function GetNearbySpatialKeys(x, y, radius)
    local cellRadius = math.ceil(radius / SPATIAL_CELL_SIZE)
    local cx         = math.floor(x / SPATIAL_CELL_SIZE)
    local cy         = math.floor(y / SPATIAL_CELL_SIZE)
    local keys       = {}

    for dx = -cellRadius, cellRadius do
        for dy = -cellRadius, cellRadius do
            keys[#keys + 1] = string.format("%d:%d", cx + dx, cy + dy)
        end
    end

    return keys
end

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Simple polynomial hash over a string; used to derive deterministic forensic IDs
local function StringHash(str)
    if not str then return 0 end
    local h = 0
    for i = 1, #str do
        h = (h * 31 + string.byte(str, i)) % 2147483647
    end
    return h
end

-- Returns (or generates) the forensic identifiers for a given uniqueId.
-- Optionally overrides fingerprint/bloodType from framework forensics data.
function GetForensicData(uniqueId, playerSource)
    if not uniqueId then return nil end

    local cached = Evidences.serialCache[uniqueId]
    if cached then return cached end

    local hash         = StringHash(uniqueId)
    local fingerprint  = string.format("FP-%04X-%04X", hash % 65535, math.floor(hash / 65535) % 65535)
    local dna          = string.format("DNA-%05X-%05X-%05X",
        hash % 1048575,
        math.floor(hash / 1048575) % 1048575,
        (hash * 17) % 1048575
    )
    local bloodTypes   = evidencesConfig.BloodTypes
    local bloodType    = bloodTypes[hash % #bloodTypes + 1] or "O+"

    -- Allow the framework to override with character-specific values
    if playerSource and Bridge.Framework.getForensics then
        local forensics = Bridge.Framework.getForensics(playerSource)
        if forensics then
            if forensics.fingerprint and forensics.fingerprint ~= "" then fingerprint = forensics.fingerprint end
            if forensics.bloodType   and forensics.bloodType   ~= "" then bloodType   = forensics.bloodType end
        end
    end

    local result = { fingerprint = fingerprint, dna = dna, bloodType = bloodType }
    Evidences.serialCache[uniqueId] = result
    return result
end

-- Returns true if the player's job meets the evidence access threshold
function PlayerHasEvidenceAccess(playerSource)
    if not Config.Jobs then return true end

    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end

    local threshold = Config.Jobs[job.name]
    if threshold == nil then return false end

    return threshold <= job.grade
end

-- Checks required items; if all present removes them and returns true.
-- Returns false + missingItemName on failure.
-- If requiredItems is nil/empty, returns true without consuming anything.
function ConsumeRequiredItems(playerSource, requiredItems)
    if not requiredItems then return true end

    for itemName, count in pairs(requiredItems) do
        if count > Bridge.Inventory.getItemCount(playerSource, itemName) then
            return false, itemName
        end
    end

    for itemName, count in pairs(requiredItems) do
        Bridge.Inventory.removeItem(playerSource, itemName, count)
    end

    return true
end

-- ─── Evidence Lifecycle ───────────────────────────────────────────────────────

-- Removes an evidence from the list and spatial index, broadcasts removal to all clients
function RemoveEvidence(evidenceId)
    local entry = Evidences.list[evidenceId]
    if not entry then return end

    Evidences.list[evidenceId] = nil

    local cellKey = GetSpatialKey(entry.coords.x, entry.coords.y)
    if Evidences.spatial[cellKey] then
        Evidences.spatial[cellKey][evidenceId] = nil
    end

    TriggerClientEvent("p_policejob/client/evidences/remove", -1, evidenceId)
end

-- Serialises an evidence entry to a plain table safe for network transmission
function SerialiseEvidence(entry)
    return {
        id        = entry.id,
        type      = entry.type,
        coords    = { x = entry.coords.x, y = entry.coords.y, z = entry.coords.z },
        rotation  = { x = entry.rotation.x, y = entry.rotation.y, z = entry.rotation.z },
        metadata  = entry.metadata,
        createdAt = entry.createdAt,
        expiresAt = entry.expiresAt,
    }
end

-- Enforces per-area and world-wide evidence caps, removing the oldest entries first
function EnforceEvidenceLimits(newEntry)
    -- Per-area cap
    local nearbyKeys = GetNearbySpatialKeys(newEntry.coords.x, newEntry.coords.y, evidencesConfig.AreaRadius)
    local areaEntries = {}

    for _, cellKey in ipairs(nearbyKeys) do
        if Evidences.spatial[cellKey] then
            for id in pairs(Evidences.spatial[cellKey]) do
                local e = Evidences.list[id]
                if e and #(newEntry.coords - e.coords) <= evidencesConfig.AreaRadius then
                    areaEntries[#areaEntries + 1] = e
                end
            end
        end
    end

    if #areaEntries > evidencesConfig.MaxPerArea then
        table.sort(areaEntries, function(a, b) return a.createdAt < b.createdAt end)
        for i = 1, #areaEntries - evidencesConfig.MaxPerArea do
            RemoveEvidence(areaEntries[i].id)
        end
    end

    -- World-wide cap
    local totalCount = 0
    for _ in pairs(Evidences.list) do totalCount = totalCount + 1 end

    if totalCount > evidencesConfig.MaxWorldEvidences then
        local allEntries = {}
        for _, e in pairs(Evidences.list) do allEntries[#allEntries + 1] = e end
        table.sort(allEntries, function(a, b) return a.createdAt < b.createdAt end)

        for i = 1, totalCount - evidencesConfig.MaxWorldEvidences do
            RemoveEvidence(allEntries[i].id)
        end
    end
end

-- Creates a new evidence entry, registers it in the list and spatial index,
-- enforces limits, and returns the new entry.
function Evidences:Create(evidenceData)
    local typeDef = evidencesConfig.Types[evidenceData.type]
    if not typeDef then return nil end
    if not evidenceData.coords then return nil end

    local id       = self.nextId
    self.nextId    = id + 1
    local now      = os.time()

    -- Resolve rotation (default: random Z)
    local rotation
    if evidenceData.rotation then
        rotation = vec3(
            evidenceData.rotation.x or 0,
            evidenceData.rotation.y or 0,
            evidenceData.rotation.z or 0
        )
    else
        rotation = vec3(0, 0, math.random() * 360.0)
    end

    local entry = {
        id        = id,
        type      = evidenceData.type,
        coords    = vec3(evidenceData.coords.x, evidenceData.coords.y, evidenceData.coords.z),
        rotation  = rotation,
        owner     = evidenceData.owner,
        metadata  = evidenceData.metadata or {},
        createdAt = now,
        expiresAt = now + (typeDef.expire or 3600),
    }

    -- Embed type display info into metadata for client rendering
    entry.metadata.label = typeDef.label
    entry.metadata.color = typeDef.color
    entry.metadata.prop  = typeDef.prop

    self.list[id] = entry

    -- Register in spatial index
    local cellKey = GetSpatialKey(entry.coords.x, entry.coords.y)
    if not self.spatial[cellKey] then self.spatial[cellKey] = {} end
    self.spatial[cellKey][id] = true

    EnforceEvidenceLimits(entry)

    return entry
end

-- Returns all evidences within `radius` of `coords` as serialised plain tables
function Evidences:Nearby(coords, radius)
    radius = radius or evidencesConfig.StreamDistance
    local result   = {}
    local cellKeys = GetNearbySpatialKeys(coords.x, coords.y, radius)

    for _, cellKey in ipairs(cellKeys) do
        local cell = self.spatial[cellKey]
        if cell then
            for id in pairs(cell) do
                local entry = self.list[id]
                if entry and #(coords - entry.coords) <= radius then
                    result[#result + 1] = SerialiseEvidence(entry)
                end
            end
        end
    end

    return result
end

-- ─── Stream Thread ────────────────────────────────────────────────────────────

-- Every StreamInterval ms, send each online player the evidences near them
CreateThread(function()
    while true do
        Citizen.Wait(evidencesConfig.StreamInterval)

        for _, rawId in ipairs(GetPlayers()) do
            local playerSource = tonumber(rawId)
            local ped          = playerSource and GetPlayerPed(playerSource)

            if ped and ped ~= 0 then
                local nearby = Evidences:Nearby(GetEntityCoords(ped), evidencesConfig.StreamDistance)
                TriggerClientEvent("p_policejob/client/evidences/sync", playerSource, nearby)
            end
        end
    end
end)

-- ─── Expiry Thread ────────────────────────────────────────────────────────────

-- Every 30 seconds, remove expired world evidences and vehicle evidence entries
CreateThread(function()
    while true do
        Citizen.Wait(30000)
        local now = os.time()

        -- Expire world evidences
        local expired = {}
        for id, entry in pairs(Evidences.list) do
            if now >= entry.expiresAt then expired[#expired + 1] = id end
        end
        for _, id in ipairs(expired) do RemoveEvidence(id) end

        -- Expire vehicle evidence entries
        for plate, vehicleList in pairs(Evidences.vehicles) do
            for i = #vehicleList, 1, -1 do
                if now >= vehicleList[i].expiresAt then
                    table.remove(vehicleList, i)
                end
            end
            if #vehicleList == 0 then
                Evidences.vehicles[plate] = nil
            end
        end
    end
end)

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Client → server: player fired a gun; create bullet casing + optional fingerprint
RegisterNetEvent("p_policejob/server/evidences/gunshot", function(payload)
    local playerSource = source

    if not evidencesConfig.AutoCreate.gunshot.enabled then return end
    if not (type(payload) == "table" and payload.coords) then return end

    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return end

    -- Sanity: shooter must be within 12m of the reported coords
    local pedPos      = GetEntityCoords(ped)
    local reportedPos = vec3(payload.coords.x, payload.coords.y, payload.coords.z)
    if #(pedPos - reportedPos) > 12.0 then return end

    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    local weaponHash   = tonumber(payload.weaponHash) or 0
    local caliber      = evidencesConfig.WeaponCalibers[weaponHash] or "Unknown"

    Evidences:Create({
        type     = "bullet_casing",
        coords   = payload.coords,
        rotation = payload.rotation,
        owner    = uniqueId,
        metadata = {
            weaponHash = weaponHash,
            weaponName = payload.weaponName,
            serial     = payload.serial,
            caliber    = caliber,
            tracerFrom = payload.tracerFrom,
            tracerTo   = payload.tracerTo,
        },
    })

    -- Chance to also leave a fingerprint at the casing location
    local fingerprintChance = evidencesConfig.AutoCreate.gunshot.fingerprintChance or 0
    if math.random() < fingerprintChance then
        local forensics = GetForensicData(uniqueId, playerSource)
        Evidences:Create({
            type     = "fingerprint",
            coords   = payload.coords,
            owner    = uniqueId,
            metadata = { fingerprintId = forensics and forensics.fingerprint or nil },
        })
    end
end)

-- Client → server: player took damage; create blood evidence
RegisterNetEvent("p_policejob/server/evidences/blood", function(payload)
    local playerSource = source

    if not evidencesConfig.AutoCreate.bloodOnDamage.enabled then return end
    if not (type(payload) == "table" and payload.coords) then return end

    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return end

    local pedPos      = GetEntityCoords(ped)
    local reportedPos = vec3(payload.coords.x, payload.coords.y, payload.coords.z)
    if #(pedPos - reportedPos) > 5.0 then return end

    local uniqueId  = Bridge.Framework.getUniqueId(playerSource)
    local forensics = GetForensicData(uniqueId, playerSource)

    Evidences:Create({
        type     = "blood",
        coords   = payload.coords,
        owner    = uniqueId,
        metadata = {
            dna       = forensics and forensics.dna       or nil,
            bloodType = forensics and forensics.bloodType or nil,
        },
    })
end)

-- Client → server: officer collected an evidence marker from the ground
RegisterNetEvent("p_policejob/server/evidences/collect", function(rawId)
    local playerSource = source
    local evidenceId   = tonumber(rawId) or 0
    local entry        = Evidences.list[evidenceId]

    if not entry then
        return Bridge.Notify.showNotify(playerSource, locale("evidence_not_found"), "error")
    end

    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return end

    local distance = #(GetEntityCoords(ped) - entry.coords)
    if distance > evidencesConfig.InteractDistance + 1.5 then
        return Bridge.Notify.showNotify(playerSource, locale("evidence_too_far"), "error")
    end

    local typeDef = evidencesConfig.Types[entry.type]
    if not typeDef then return end

    local isOfficer = PlayerHasEvidenceAccess(playerSource)

    -- Determine which required-items list applies and consume them
    local requiredItems = isOfficer and typeDef.requiredItems.police or typeDef.requiredItems.civilian
    local hasItems, missingItem = ConsumeRequiredItems(playerSource, requiredItems)
    if not hasItems then
        return Bridge.Notify.showNotify(playerSource,
            locale("evidence_missing_item"):format(missingItem), "error")
    end

    if isOfficer then
        -- Build the evidence bag metadata
        local collectedBy   = Bridge.Framework.getPlayerName(playerSource)
        local collectedAt   = os.time()
        local dateStr       = os.date("%Y-%m-%d %H:%M", collectedAt)

        local bagMeta = {
            evidenceId    = entry.id,
            evidenceType  = entry.type,
            label         = typeDef.label,
            coords        = { x = entry.coords.x, y = entry.coords.y, z = entry.coords.z },
            collectedBy   = collectedBy,
            collectedAt   = collectedAt,
            analyzed      = false,
            metadata      = entry.metadata,
        }

        local description = string.format("%s\nCollected: %s", typeDef.label, dateStr)

        Bridge.Inventory.addItem(playerSource, typeDef.item, 1, bagMeta, nil, description)
        Bridge.Notify.showNotify(playerSource, locale("evidence_collected"):format(typeDef.label), "success")

        if Config.Webhooks and Config.Webhooks.evidences and Config.Webhooks.evidences ~= "" then
            Bridge.Logs.Send(playerSource, "Evidences",
                string.format("%s collected %s (#%d)", collectedBy, typeDef.label, entry.id),
                Config.Webhooks.evidences)
        end
    else
        Bridge.Notify.showNotify(playerSource, locale("evidence_cleaned"), "success")

        if Config.Webhooks and Config.Webhooks.evidences and Config.Webhooks.evidences ~= "" then
            local name = Bridge.Framework.getPlayerName(playerSource)
            Bridge.Logs.Send(playerSource, "Evidences",
                string.format("%s cleaned %s (#%d)", name, typeDef.label, entry.id),
                Config.Webhooks.evidences)
        end
    end

    RemoveEvidence(entry.id)
end)

-- ─── Interactions: Body Sample Collection ────────────────────────────────────

-- Shared handler for taking a biological sample from a living player
local function TakeSampleFromPlayer(officerSource, targetSource, sampleType, requiredItems)
    if not PlayerHasEvidenceAccess(officerSource) then
        return Bridge.Notify.showNotify(officerSource, locale("locker_no_access"), "error")
    end

    local officerPed = GetPlayerPed(officerSource)
    local targetPed  = GetPlayerPed(targetSource)
    if not (officerPed and officerPed ~= 0) then return end
    if not (targetPed  and targetPed  ~= 0) then return end

    if #(GetEntityCoords(officerPed) - GetEntityCoords(targetPed)) > 3.5 then
        return Bridge.Notify.showNotify(officerSource, locale("evidence_too_far"), "error")
    end

    local typeDef = evidencesConfig.Types[sampleType]
    if not typeDef then return end

    local hasItems, missingItem = ConsumeRequiredItems(officerSource, requiredItems)
    if not hasItems then
        return Bridge.Notify.showNotify(officerSource,
            locale("evidence_missing_item"):format(missingItem), "error")
    end

    local targetUniqueId = Bridge.Framework.getUniqueId(targetSource)
    local forensics      = GetForensicData(targetUniqueId, targetSource)

    local sampleMeta = {}
    if sampleType == "blood" then
        sampleMeta.dna       = forensics and forensics.dna       or nil
        sampleMeta.bloodType = forensics and forensics.bloodType or nil
    elseif sampleType == "fingerprint" then
        sampleMeta.fingerprintId = forensics and forensics.fingerprint or nil
    end

    local collectedBy = Bridge.Framework.getPlayerName(officerSource)
    local collectedAt = os.time()
    local dateStr     = os.date("%Y-%m-%d %H:%M", collectedAt)

    local bagMeta = {
        evidenceType = sampleType,
        label        = typeDef.label,
        coords       = nil,
        collectedBy  = collectedBy,
        collectedAt  = collectedAt,
        analyzed     = false,
        metadata     = sampleMeta,
    }

    local description = string.format("%s\nSuspect ID: %s\nCollected: %s",
        typeDef.label, tostring(targetSource), dateStr)

    Bridge.Inventory.addItem(officerSource, typeDef.item, 1, bagMeta, nil, description)
    Bridge.Notify.showNotify(officerSource, locale("evidence_collected"):format(typeDef.label), "success")

    if Config.Webhooks and Config.Webhooks.evidences and Config.Webhooks.evidences ~= "" then
        Bridge.Logs.Send(officerSource, "Evidences",
            string.format("%s took a %s sample from player %s",
                collectedBy, typeDef.label, tostring(targetSource)),
            Config.Webhooks.evidences)
    end
end

RegisterNetEvent("p_policejob/server/interactions/TakeBloodSample", function(targetId)
    TakeSampleFromPlayer(source, tonumber(targetId), "blood",
        { evidence_kit = 1, swab_kit = 1 })
end)

RegisterNetEvent("p_policejob/server/interactions/TakeFingerprintSample", function(targetId)
    TakeSampleFromPlayer(source, tonumber(targetId), "fingerprint",
        { evidence_kit = 1, fingerprint_kit = 1 })
end)

-- ─── Evidence Lab Callbacks ───────────────────────────────────────────────────

-- Build a reverse lookup: item name → evidence type key
local itemToEvidenceType = {}
for typeName, typeDef in pairs(evidencesConfig.Types) do
    if typeDef.item then
        itemToEvidenceType[typeDef.item] = typeName
    end
end

-- Normalises an inventory item to a structured evidence bag, or returns nil
local function ParseEvidenceBag(itemData)
    if type(itemData) ~= "table" then return nil end

    local meta = itemData.metadata or itemData.info or {}

    local evidenceType = meta.evidenceType
    if not evidenceType then
        evidenceType = itemToEvidenceType[itemData.name]
    end

    local typeDef = evidenceType and evidencesConfig.Types[evidenceType]
    if not typeDef then return nil end

    return {
        slot        = itemData.slot,
        itemName    = itemData.name,
        type        = evidenceType,
        label       = meta.label or typeDef.label,
        coords      = meta.coords,
        collectedBy = meta.collectedBy,
        collectedAt = meta.collectedAt,
        analyzed    = meta.analyzed or false,
        metadata    = meta.metadata or {},
        results     = meta.results,
    }
end

-- Returns the player's collected evidence bags, sorted newest first
local function GetPlayerEvidenceBags(playerSource)
    local items = Bridge.Inventory.getPlayerItems and Bridge.Inventory.getPlayerItems(playerSource)
    local bags  = {}

    if items then
        for _, item in pairs(items) do
            local bag = ParseEvidenceBag(item)
            if bag then bags[#bags + 1] = bag end
        end
    end

    table.sort(bags, function(a, b)
        return (a.collectedAt or 0) > (b.collectedAt or 0)
    end)

    return bags
end

-- Generates analysis result fields for a given evidence type and raw metadata
local function GenerateAnalysisResults(evidenceType, rawMeta)
    local results = {}

    if evidenceType == "bullet_casing" then
        results.weapon   = rawMeta.weaponName or "Unknown"
        results.serial   = rawMeta.serial     or "Unknown"
        results.caliber  = rawMeta.caliber    or "Unknown"
        results.residue  = string.format("GSR-%04X", math.random(0, 65535))
        results.rifling  = string.format("R-%04X", (rawMeta.weaponHash or 0) % 65535)

    elseif evidenceType == "blood" then
        results.dna       = rawMeta.dna       or "Unknown"
        results.bloodType = rawMeta.bloodType or "Unknown"
        results.dnaSample = string.format("SMP-%04X", math.random(0, 65535))

    elseif evidenceType == "fingerprint" then
        results.fingerprintId  = rawMeta.fingerprintId or "Unknown"
        results.matchConfidence = string.format("%d%%", 85 + math.random(0, 14))
        results.pattern = ({ "Loop", "Whorl", "Arch", "Tented Arch" })[math.random(1, 4)]

    elseif evidenceType == "drug_residue" then
        results.substanceId = string.format("SUB-%04X", math.random(0, 65535))
        results.substance   = rawMeta.substance or
            ({ "Cocaine", "Methamphetamine", "Heroin", "MDMA" })[math.random(1, 4)]
        results.purity      = string.format("%d%%", 40 + math.random(0, 59))

    elseif evidenceType == "weapon_fragment" then
        results.fragmentId = string.format("FRG-%04X", math.random(0, 65535))
        results.material   = ({ "Steel", "Polymer", "Aluminum", "Brass" })[math.random(1, 4)]
        results.origin     = ({ "Slide", "Grip", "Magazine", "Barrel" })[math.random(1, 4)]
    end

    return results
end

-- Returns the evidence bags from a stash inventory, sorted newest first
local function GetStashEvidenceBags(stashId)
    local inv   = Bridge.Inventory.getInventory and Bridge.Inventory.getInventory(stashId)
    local items = inv and inv.items
    local bags  = {}

    if not items then return bags end

    for _, item in pairs(items) do
        local bag = ParseEvidenceBag(item)
        if bag then bags[#bags + 1] = bag end
    end

    table.sort(bags, function(a, b)
        return (a.collectedAt or 0) > (b.collectedAt or 0)
    end)

    return bags
end

lib.callback.register("p_policejob/server/evidences/getInventory", function(playerSource)
    if not PlayerHasEvidenceAccess(playerSource) then return {} end
    return GetPlayerEvidenceBags(playerSource)
end)

lib.callback.register("p_policejob/server/evidences/analyze", function(playerSource, slotArg)
    if not PlayerHasEvidenceAccess(playerSource) then
        return { success = false }
    end

    local slot    = tonumber(slotArg) or 0
    local invItem = Bridge.Inventory.getItemSlot and Bridge.Inventory.getItemSlot(playerSource, slot)
    if not invItem then return { success = false } end

    local meta         = invItem.metadata or {}
    local evidenceType = meta.evidenceType or itemToEvidenceType[invItem.name]
    local typeDef      = evidenceType and evidencesConfig.Types[evidenceType]

    if not typeDef then return { success = false } end
    if meta.analyzed   then return { success = false } end

    local results        = GenerateAnalysisResults(evidenceType, meta.metadata or {})
    meta.evidenceType    = evidenceType
    meta.label           = meta.label or typeDef.label
    meta.analyzed        = true
    meta.results         = results

    if not Bridge.Inventory.setMetadata then return { success = false } end
    Bridge.Inventory.setMetadata(playerSource, slot, meta)

    if Config.Webhooks and Config.Webhooks.evidences and Config.Webhooks.evidences ~= "" then
        local name = Bridge.Framework.getPlayerName(playerSource)
        Bridge.Logs.Send(playerSource, "Evidences",
            string.format("%s analyzed %s", name, meta.label or "evidence"),
            Config.Webhooks.evidences)
    end

    return { success = true, results = results, type = evidenceType }
end)

lib.callback.register("p_policejob/server/evidences/destroyBag", function(playerSource, slotArg)
    if not PlayerHasEvidenceAccess(playerSource) then
        return { success = false }
    end

    local slot    = tonumber(slotArg) or 0
    local invItem = Bridge.Inventory.getItemSlot and Bridge.Inventory.getItemSlot(playerSource, slot)
    if not invItem then return { success = false } end

    local count = invItem.count or invItem.amount or 1
    Bridge.Inventory.removeItem(playerSource, invItem.name, count, nil, slot)
    return { success = true }
end)

-- ─── Storage ─────────────────────────────────────────────────────────────────

-- Registers a stash with the inventory bridge (once per stash id)
local function EnsureStashRegistered(stashId, label, slots, weight)
    if Evidences.registeredStashes[stashId] then return end
    Evidences.registeredStashes[stashId] = true

    if Bridge.Inventory.registerStash then
        Bridge.Inventory.registerStash(stashId, label, slots, weight)
    end
end

RegisterNetEvent("p_policejob/server/evidences/openStorage", function(rawLockerId)
    local playerSource = source

    if not PlayerHasEvidenceAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("locker_no_access"), "error")
    end

    local lockerId = tostring(rawLockerId or "main"):sub(1, 64)
    local stashId  = evidencesConfig.StorageStashPrefix .. "_" .. lockerId

    EnsureStashRegistered(stashId, lockerId,
        evidencesConfig.StorageStashSlots,
        evidencesConfig.StorageStashWeight)
end)

lib.callback.register("p_policejob/server/evidences/getStorageBags", function(playerSource, rawLockerId)
    if not PlayerHasEvidenceAccess(playerSource) then return {} end

    local lockerId = tostring(rawLockerId or "main"):sub(1, 64)
    local stashId  = evidencesConfig.StorageStashPrefix .. "_" .. lockerId
    return GetStashEvidenceBags(stashId)
end)

-- ─── Reconstruction Callback ──────────────────────────────────────────────────

lib.callback.register("p_policejob/server/evidences/reconstruction", function(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return {} end

    if Bridge.Inventory.getItemCount(playerSource, evidencesConfig.ReconstructionItem) < 1 then
        return {}
    end

    return Evidences:Nearby(GetEntityCoords(ped), evidencesConfig.ReconstructionRadius)
end)

-- ─── Vehicle Evidence ─────────────────────────────────────────────────────────

local vehicleConfig = evidencesConfig.Vehicle or {}

-- Strips trailing whitespace and uppercases a plate string; returns nil on empty
local function NormalisePlate(rawPlate)
    if type(rawPlate) ~= "string" then return nil end
    local plate = rawPlate:gsub("%s+$", ""):upper()
    return (plate ~= "") and plate or nil
end

-- Creates a vehicle evidence entry (fingerprint, blood, or bullet_casing on a plate)
function AddVehicleEvidence(rawPlate, evidenceType, extraData)
    if not vehicleConfig.enabled then return nil end

    local plate   = NormalisePlate(rawPlate)
    if not plate  then return nil end

    local typeDef = evidencesConfig.Types[evidenceType]
    if not typeDef then return nil end

    extraData = extraData or {}

    local id  = Evidences.nextId
    Evidences.nextId = id + 1
    local now = os.time()

    local expiry = extraData.expire
        or vehicleConfig.expire
        or typeDef.expire
        or 3600

    local entry = {
        id        = id,
        type      = evidenceType,
        plate     = plate,
        model     = extraData.model,
        owner     = extraData.owner,
        metadata  = extraData.metadata or {},
        createdAt = now,
        expiresAt = now + expiry,
    }

    entry.metadata.plate = entry.metadata.plate or plate
    if entry.model and not entry.metadata.model then
        entry.metadata.model = entry.model
    end

    if not Evidences.vehicles[plate] then
        Evidences.vehicles[plate] = {}
    end

    local vehicleList = Evidences.vehicles[plate]
    vehicleList[#vehicleList + 1] = entry

    local maxPerVehicle = vehicleConfig.maxPerVehicle or 20
    while #vehicleList > maxPerVehicle do
        table.remove(vehicleList, 1)
    end

    return entry
end

exports("addVehicleEvidence", function(plate, evidenceType, extraData)
    return AddVehicleEvidence(plate, evidenceType, extraData)
end)

-- Client → server: player left evidence on or in a vehicle (enter fingerprint, blood, casing)
RegisterNetEvent("p_policejob/server/evidences/vehicle", function(payload)
    local playerSource = source

    if not vehicleConfig.enabled then return end
    if type(payload) ~= "table" then return end

    local evidenceType = payload.evidenceType
    if not evidencesConfig.Types[evidenceType] then return end

    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return end

    local plate = NormalisePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return end

    -- Per-player cooldown: one vehicle evidence event per second
    local now = os.time()
    if vehicleEventCooldown[playerSource] and now < vehicleEventCooldown[playerSource] then return end
    vehicleEventCooldown[playerSource] = now + 1

    local uniqueId  = Bridge.Framework.getUniqueId(playerSource)
    local forensics = GetForensicData(uniqueId, playerSource)

    local extraMeta = {
        plate  = plate,
        model  = payload.model,
        player = Bridge.Framework.getPlayerName(playerSource),
    }

    if evidenceType == "fingerprint" then
        if not vehicleConfig.fingerprintOnEnter then return end
        extraMeta.fingerprintId = forensics and forensics.fingerprint or nil

    elseif evidenceType == "blood" then
        if not vehicleConfig.bloodInVehicle then return end
        extraMeta.dna       = forensics and forensics.dna       or nil
        extraMeta.bloodType = forensics and forensics.bloodType or nil

    elseif evidenceType == "bullet_casing" then
        if not vehicleConfig.casingInVehicle then return end
        local weaponHash     = tonumber(payload.weaponHash) or 0
        extraMeta.weaponHash = weaponHash
        extraMeta.weaponName = payload.weaponName
        extraMeta.serial     = payload.serial
        extraMeta.caliber    = evidencesConfig.WeaponCalibers[weaponHash] or "Unknown"
    else
        return
    end

    AddVehicleEvidence(plate, evidenceType, {
        owner    = uniqueId,
        model    = payload.model,
        metadata = extraMeta,
    })
end)

AddEventHandler("playerDropped", function()
    vehicleEventCooldown[source] = nil
end)

lib.callback.register("p_policejob/server/evidences/getVehicleEvidence", function(playerSource, rawPlate)
    if not PlayerHasEvidenceAccess(playerSource) then return {} end

    local plate = NormalisePlate(rawPlate)
    if not plate then return {} end

    local vehicleList = Evidences.vehicles[plate]
    if not vehicleList then return {} end

    local results = {}
    for _, entry in ipairs(vehicleList) do
        local typeDef = evidencesConfig.Types[entry.type]
        results[#results + 1] = {
            id        = entry.id,
            type      = entry.type,
            plate     = entry.plate,
            model     = entry.model,
            label     = (typeDef and typeDef.label) or entry.type,
            metadata  = entry.metadata,
            createdAt = entry.createdAt,
            date      = os.date("%Y-%m-%d %H:%M", entry.createdAt),
        }
    end

    return results
end)

RegisterNetEvent("p_policejob/server/evidences/collectVehicle", function(rawPlate, rawEvidenceId)
    local playerSource = source

    if not PlayerHasEvidenceAccess(playerSource) then
        return Bridge.Notify.showNotify(playerSource, locale("locker_no_access"), "error")
    end

    local plate = NormalisePlate(rawPlate)
    if not plate then return end

    local vehicleList = Evidences.vehicles[plate]
    if not vehicleList then
        return Bridge.Notify.showNotify(playerSource, locale("evidence_not_found"), "error")
    end

    local evidenceId = tonumber(rawEvidenceId) or 0

    -- Find the specific entry in the vehicle list
    local foundEntry, foundIndex = nil, nil
    for i, entry in ipairs(vehicleList) do
        if entry.id == evidenceId then
            foundEntry = entry
            foundIndex = i
            break
        end
    end

    if not foundEntry then
        return Bridge.Notify.showNotify(playerSource, locale("evidence_not_found"), "error")
    end

    local typeDef = evidencesConfig.Types[foundEntry.type]
    if not typeDef then return end

    local hasItems, missingItem = ConsumeRequiredItems(playerSource, typeDef.requiredItems.police)
    if not hasItems then
        return Bridge.Notify.showNotify(playerSource,
            locale("evidence_missing_item"):format(missingItem), "error")
    end

    local collectedBy = Bridge.Framework.getPlayerName(playerSource)
    local collectedAt = os.time()
    local dateStr     = os.date("%Y-%m-%d %H:%M", collectedAt)

    local bagMeta = {
        evidenceType = foundEntry.type,
        label        = typeDef.label,
        coords       = nil,
        collectedBy  = collectedBy,
        collectedAt  = collectedAt,
        analyzed     = false,
        metadata     = foundEntry.metadata,
        source       = "vehicle",
        plate        = foundEntry.plate,
    }

    local description = string.format("%s\nVehicle: %s\nCollected: %s",
        typeDef.label, foundEntry.plate, dateStr)

    Bridge.Inventory.addItem(playerSource, typeDef.item, 1, bagMeta, nil, description)
    Bridge.Notify.showNotify(playerSource, locale("evidence_collected"):format(typeDef.label), "success")

    table.remove(vehicleList, foundIndex)
    if #vehicleList == 0 then
        Evidences.vehicles[plate] = nil
    end

    if Config.Webhooks and Config.Webhooks.evidences and Config.Webhooks.evidences ~= "" then
        Bridge.Logs.Send(playerSource, "Evidences",
            string.format("%s collected %s from vehicle %s (#%d)",
                collectedBy, typeDef.label, foundEntry.plate, foundEntry.id),
            Config.Webhooks.evidences)
    end
end)

-- ─── Public Exports ───────────────────────────────────────────────────────────

exports("createEvidence", function(evidenceData)
    return Evidences:Create(evidenceData)
end)

exports("getNearbyEvidences", function(coords, radius)
    return Evidences:Nearby(coords, radius)
end)

-- ─── Forensic Lookup Utilities ────────────────────────────────────────────────

-- Ensures all online players have their forensic data pre-cached
local function PrimeForensicCache()
    for _, rawId in ipairs(GetPlayers()) do
        local playerSource = tonumber(rawId) or rawId
        local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
        if uniqueId then
            GetForensicData(uniqueId, playerSource)
        end
    end
end

-- Resolves a server source and unique-id from a server-id (number) or unique-id (string)
local function ResolveIdentifier(idOrUniqueId)
    if idOrUniqueId == nil then return nil, nil end

    if type(idOrUniqueId) == "number" then
        local uniqueId = Bridge.Framework.getUniqueId(idOrUniqueId)
        return uniqueId, idOrUniqueId
    end

    local strId = tostring(idOrUniqueId)
    local found = Bridge.Framework.getPlayerByUniqueId(strId)

    -- Try uppercase variant if not found
    if not found and strId:upper() ~= strId then
        local upperStr = strId:upper()
        found = Bridge.Framework.getPlayerByUniqueId(upperStr)
        if found then strId = upperStr end
    end

    local playerSource = found and (found.source or (found.PlayerData and found.PlayerData.source)) or nil
    return strId, playerSource
end

exports("GetEvidenceForCid", function(idOrUniqueId)
    local uniqueId, playerSource = ResolveIdentifier(idOrUniqueId)
    if not uniqueId then return nil end

    local forensics = GetForensicData(uniqueId, playerSource)

    local result = {
        blood        = {},
        fingerprints = {},
        casings      = {},
    }

    -- Reverse map for iteration
    local typeToList = {
        blood         = result.blood,
        fingerprint   = result.fingerprints,
        bullet_casing = result.casings,
    }

    local function TryAddEntry(evidenceEntry, source, plate)
        local list = typeToList[evidenceEntry.type]
        if not list then return end

        local meta = evidenceEntry.metadata or {}

        -- Check ownership: either direct owner match or fingerprint match
        local isOwner = evidenceEntry.owner == uniqueId
        if not isOwner and forensics and meta.fingerprintId ~= nil then
            isOwner = meta.fingerprintId == forensics.fingerprint
        end
        if not isOwner then return end

        local coordsCopy = nil
        if evidenceEntry.coords then
            coordsCopy = { x = evidenceEntry.coords.x, y = evidenceEntry.coords.y, z = evidenceEntry.coords.z }
        end

        list[#list + 1] = {
            id        = evidenceEntry.id,
            type      = evidenceEntry.type,
            coords    = coordsCopy,
            plate     = plate,
            metadata  = meta,
            createdAt = evidenceEntry.createdAt,
            expiresAt = evidenceEntry.expiresAt,
            source    = source,
        }
    end

    for _, entry in pairs(Evidences.list) do
        TryAddEntry(entry, "world", nil)
    end

    for plate, vehicleList in pairs(Evidences.vehicles) do
        for _, entry in ipairs(vehicleList) do
            TryAddEntry(entry, "vehicle", plate)
        end
    end

    return result
end)

exports("GetEvidenceList", function(sinceTimestamp)
    local since  = tonumber(sinceTimestamp)
    local result = {}

    for _, entry in pairs(Evidences.list) do
        if not since or entry.createdAt >= since then
            result[#result + 1] = {
                id        = entry.id,
                type      = entry.type,
                coords    = { x = entry.coords.x, y = entry.coords.y, z = entry.coords.z },
                metadata  = entry.metadata,
                createdAt = entry.createdAt,
                expiresAt = entry.expiresAt,
                source    = "world",
            }
        end
    end

    for plate, vehicleList in pairs(Evidences.vehicles) do
        for _, entry in ipairs(vehicleList) do
            if not since or entry.createdAt >= since then
                result[#result + 1] = {
                    id        = entry.id,
                    type      = entry.type,
                    plate     = plate,
                    metadata  = entry.metadata,
                    createdAt = entry.createdAt,
                    expiresAt = entry.expiresAt,
                    source    = "vehicle",
                }
            end
        end
    end

    return result
end)

exports("GetIdentifierFromFinger", function(fingerprintId)
    if not fingerprintId then return nil end
    PrimeForensicCache()
    for uniqueId, forensics in pairs(Evidences.serialCache) do
        if forensics.fingerprint == fingerprintId then return uniqueId end
    end
    return nil
end)

exports("GetIdentifierFromBlood", function(dnaId)
    if not dnaId then return nil end
    PrimeForensicCache()
    for uniqueId, forensics in pairs(Evidences.serialCache) do
        if forensics.dna == dnaId then return uniqueId end
    end
    return nil
end)

exports("GenerateFinger", function(idOrUniqueId)
    local uniqueId, playerSource = ResolveIdentifier(idOrUniqueId)
    if not uniqueId then return nil end
    local forensics = GetForensicData(uniqueId, playerSource)
    return forensics and forensics.fingerprint or nil
end)

exports("GenerateBlood", function(idOrUniqueId)
    local uniqueId, playerSource = ResolveIdentifier(idOrUniqueId)
    if not uniqueId then return nil end
    local forensics = GetForensicData(uniqueId, playerSource)
    if not forensics then return nil end
    return { dna = forensics.dna, bloodType = forensics.bloodType }
end)
