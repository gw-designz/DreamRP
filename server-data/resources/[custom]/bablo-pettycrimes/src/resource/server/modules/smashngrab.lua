-- Module guard
if not (Config and Config.Modules and Config.Modules.SMASH_N_GRAB) then
    Trace("SMASH_N_GRAB module disabled, skipping all initialization and event handlers")
    return
end

-- ─── Vehicle Hash Lookup Table ────────────────────────────────────────────────
-- Loaded from vehicleHashes.json for fast O(1) model validation.

local vehicleHashLookup = {}
do
    local raw = LoadResourceFile(GetCurrentResourceName(), "vehicleHashes.json")
    if raw then
        local decoded = json.decode(raw)
        if decoded then
            for _, entry in ipairs(decoded) do
                vehicleHashLookup[entry.hash] = true
            end
            Trace("Loaded " .. #decoded .. " vehicle hashes for performance optimization")
        else
            Trace("Failed to decode vehicleHashes.json")
        end
    else
        Trace("Failed to load vehicleHashes.json")
    end
end

-- ─── Stats Tables ─────────────────────────────────────────────────────────────
-- nullStatsMeta: a metatable that makes any unset stat read as 0 and silently
-- drops writes — used when debug tracking is off to avoid nil errors cheaply.

local nullStatsMeta = {
    __index    = function() return 0 end,
    __newindex = function() end,
}

local function createNullStats()
    return setmetatable({}, nullStatsMeta)
end

local function createFullStats()
    return {
        candidatesReceived      = 0,
        attempted               = 0,
        notYetReady             = 0,
        successfullyRobbed      = 0,
        playerDroppedLosses     = 0,
        failedNotExist          = 0,
        failedPopType           = 0,
        failedHash              = 0,
        failedVehicleType       = 0,
        failedEngineRunning     = 0,
        failedPlayerOwned       = 0,
        failedNoOwner           = 0,
        failedLimit             = 0,
        failedChance            = 0,
        failedPersistent        = 0,
        failedLootedState       = 0,
        failedFrameworkCheck    = 0,
        failedTooClose          = 0,
        clientVerifyAttempted   = 0,
        clientVerifyPassed      = 0,
        failedClientVerify      = 0,
        clientFailedNetIdInvalid = 0,
        clientFailedNotExist    = 0,
        clientFailedWrongClass  = 0,
        clientFailedNotEmpty    = 0,
        clientFailedBadModel    = 0,
        clientFailedBlacklisted = 0,
        clientFailedTooFewSeats = 0,
        clientFailedBoneNotFound = 0,
        lastVehicleAddedAt      = 0,
        lastTickAt              = 0,
        lastTickProcessed       = 0,
        lastTickPassed          = 0,
    }
end

-- ─── SmashnGrab State ────────────────────────────────────────────────────────

SmashnGrab = {
    persistentVehicles     = {},
    persistentVehicleCount = 0,
    vehiclesToRemove       = {},
    vehicleHashes          = vehicleHashLookup,
    candidateVehicles      = {},
    queueBatchSize         = (Config.SmashnGrab and Config.SmashnGrab.QueueBatchSize) or 8,
    debugEnabled           = false,
    stats                  = createNullStats(),
}

-- ─── Player List Cache ────────────────────────────────────────────────────────
-- Refreshes the player list at most every 5 seconds.

local cachedPlayerList    = {}
local playerListCacheTime = 0
local PLAYER_CACHE_TTL    = 5000

local function getCachedPlayers()
    local now = GetGameTimer()
    if now - playerListCacheTime >= PLAYER_CACHE_TTL then
        cachedPlayerList    = GetPlayers()
        playerListCacheTime = now
    end
    return cachedPlayerList
end

-- ─── Wait for eventName ───────────────────────────────────────────────────────

while not eventName do
    Citizen.Wait(0)
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function getEntityStateBag(entity)
    local state = Entity(entity).state
    if state and type(state.get) == "function" then
        return state
    end
    return nil
end

local function isVehicleLooted(stateBag)
    if not stateBag then return false end
    return stateBag:get("looted") or stateBag:get("looting") or false
end

local function isTooCloseToExisting(coords, minDist)
    for _, data in pairs(SmashnGrab.persistentVehicles) do
        if #(coords - data.coords) < minDist then
            return true
        end
    end
    return false
end

local function buildLootEntry(lootItem)
    if not (Config.SmashnGrab.UseBag and lootItem) then
        return lootItem
    end
    return {
        name  = lootItem.name,
        chance = lootItem.chance,
        count = lootItem.count,
        prop  = Config.SmashnGrab.BagProp or "prop_poly_bag_01",
        rot   = lootItem.rot,
    }
end

local function decrPersistentCount()
    SmashnGrab.persistentVehicleCount = math.max(0, SmashnGrab.persistentVehicleCount - 1)
end

-- ─── Entity Created ───────────────────────────────────────────────────────────

AddEventHandler("entityCreated", function(entity)
    if not entity or not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 2 then return end  -- 2 = vehicle

    SmashnGrab.stats.candidatesReceived = SmashnGrab.stats.candidatesReceived + 1

    if not SmashnGrab.candidateVehicles[entity] then
        SmashnGrab.candidateVehicles[entity] = GetGameTimer() + 10000
    end
end)

-- ─── Entity Removed ───────────────────────────────────────────────────────────

AddEventHandler("entityRemoved", function(entity)
    if not entity then return end

    SmashnGrab.candidateVehicles[entity] = nil

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 then
        local data = SmashnGrab.persistentVehicles[netId]
        if data then
            local uniqueId = data.uniqueId
            SmashnGrab.persistentVehicles[netId] = nil
            decrPersistentCount()
            TriggerClientEvent(eventName .. "client:removePersistentVehicle", -1, { uniqueId })
        end
    end
end)

-- ─── Candidate Processing Thread ─────────────────────────────────────────────
-- Runs every 20s, filters candidates through server-side checks, then hands
-- passing vehicles to prepareVehicle for client verification.

Citizen.CreateThread(function()
    SmashnGrab.vehiclesToPrepare = {}

    while true do
        Citizen.Wait(20000)

        local candidateCount = 0
        for _ in pairs(SmashnGrab.candidateVehicles) do
            candidateCount = candidateCount + 1
        end

        Trace(
            "SmashnGrab tick | candidates:", candidateCount,
            "| persistent:", SmashnGrab.persistentVehicleCount,
            "/", Config.SmashnGrab.Limit
        )

        local processed = 0
        local passed    = 0
        local now       = GetGameTimer()
        local minDist   = Config.SmashnGrab.MinVehicleDistance

        for entity, readyAt in pairs(SmashnGrab.candidateVehicles) do
            if processed >= SmashnGrab.queueBatchSize then break end

            if readyAt > now then
                SmashnGrab.stats.notYetReady = SmashnGrab.stats.notYetReady + 1
                goto nextCandidate
            end

            SmashnGrab.candidateVehicles[entity] = nil
            processed = processed + 1
            SmashnGrab.stats.attempted = SmashnGrab.stats.attempted + 1

            if not entity or not DoesEntityExist(entity) then
                SmashnGrab.stats.failedNotExist = SmashnGrab.stats.failedNotExist + 1
                goto nextCandidate
            end

            if not SmashnGrab.vehicleHashes[GetEntityModel(entity)] then
                SmashnGrab.stats.failedHash = SmashnGrab.stats.failedHash + 1
                goto nextCandidate
            end

            if GetVehicleType(entity) ~= "automobile" then
                SmashnGrab.stats.failedVehicleType = SmashnGrab.stats.failedVehicleType + 1
                goto nextCandidate
            end

            if GetIsVehicleEngineRunning(entity) then
                SmashnGrab.stats.failedEngineRunning = SmashnGrab.stats.failedEngineRunning + 1
                goto nextCandidate
            end

            if HasVehicleBeenOwnedByPlayer(entity) then
                SmashnGrab.stats.failedPlayerOwned = SmashnGrab.stats.failedPlayerOwned + 1
                goto nextCandidate
            end

            local owner = NetworkGetEntityOwner(entity)
            if not owner or owner <= 0 then
                SmashnGrab.stats.failedNoOwner = SmashnGrab.stats.failedNoOwner + 1
                goto nextCandidate
            end

            if SmashnGrab.persistentVehicleCount >= Config.SmashnGrab.Limit then
                SmashnGrab.stats.failedLimit = SmashnGrab.stats.failedLimit + 1
                goto nextCandidate
            end

            if math.random(1, 100) > Config.SmashnGrab.ChanceToSpawn then
                SmashnGrab.stats.failedChance = SmashnGrab.stats.failedChance + 1
                goto nextCandidate
            end

            do
                local stateBag = getEntityStateBag(entity)
                if stateBag and stateBag:get("persistent") then
                    SmashnGrab.stats.failedPersistent = SmashnGrab.stats.failedPersistent + 1
                    goto nextCandidate
                end

                if isVehicleLooted(stateBag) then
                    SmashnGrab.stats.failedLootedState = SmashnGrab.stats.failedLootedState + 1
                    goto nextCandidate
                end

                local netId = NetworkGetNetworkIdFromEntity(entity)
                if Framework:vehicleChecks(netId, entity) then
                    SmashnGrab.stats.failedFrameworkCheck = SmashnGrab.stats.failedFrameworkCheck + 1
                    goto nextCandidate
                end

                local coords = GetEntityCoords(entity)
                if isTooCloseToExisting(coords, minDist) then
                    SmashnGrab.stats.failedTooClose = SmashnGrab.stats.failedTooClose + 1
                    goto nextCandidate
                end

                SmashnGrab.vehiclesToPrepare[entity] = true
                passed = passed + 1
            end

            ::nextCandidate::
        end

        if processed > 0 then
            Trace("SmashnGrab processed:", processed, "| passed filters:", passed)
        end

        SmashnGrab.stats.lastTickAt        = GetGameTimer()
        SmashnGrab.stats.lastTickProcessed = processed
        SmashnGrab.stats.lastTickPassed    = passed

        SmashnGrab:prepareVehicle(SmashnGrab.vehiclesToPrepare)
        SmashnGrab.vehiclesToPrepare = {}
    end
end)

-- ─── Stale Persistent Vehicle Cleanup Thread ─────────────────────────────────
-- Every 10s, remove persistent vehicle entries whose entity no longer exists,
-- and flush the vehiclesToRemove queue to all clients.

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)

        local toRemove = {}

        for netId, data in pairs(SmashnGrab.persistentVehicles) do
            local entity = NetworkGetEntityFromNetworkId(netId)
            if not entity or entity == 0 or not DoesEntityExist(entity) then
                toRemove[#toRemove + 1] = data.uniqueId
                SmashnGrab.persistentVehicles[netId] = nil
                decrPersistentCount()
            end
        end

        for _, uniqueId in ipairs(SmashnGrab.vehiclesToRemove) do
            toRemove[#toRemove + 1] = uniqueId
        end
        SmashnGrab.vehiclesToRemove = {}

        if #toRemove > 0 then
            TriggerClientEvent(eventName .. "client:removePersistentVehicle", -1, toRemove)
        end
    end
end)

-- ─── Prepare Vehicle (Client Verify Path) ────────────────────────────────────
-- Groups candidates by their network owner, then asks each owner to verify
-- their vehicles via a client callback. Confirmed vehicles are marked persistent.

function SmashnGrab:prepareVehicle(candidates)
    local count = 0
    for _ in pairs(candidates) do count = count + 1 end
    if count == 0 then return end

    -- Build netId map grouped by owner (source string)
    local byOwner = {}
    for entity in pairs(candidates) do
        if entity and DoesEntityExist(entity) then
            local netId = NetworkGetNetworkIdFromEntity(entity)
            if netId and netId ~= 0 then
                local owner = NetworkGetEntityOwner(entity)
                if owner and owner > 0 then
                    local ownerKey = tostring(owner)
                    byOwner[ownerKey] = byOwner[ownerKey] or {}
                    byOwner[ownerKey][netId] = netId
                end
            end
        end
    end

    local minDist     = Config.SmashnGrab.MinVehicleDistance
    local anyAdded    = false
    local slotsLeft   = Config.SmashnGrab.Limit - SmashnGrab.persistentVehicleCount

    for ownerKey, netIds in pairs(byOwner) do
        if SmashnGrab.persistentVehicleCount >= Config.SmashnGrab.Limit then break end

        self.stats.clientVerifyAttempted = self.stats.clientVerifyAttempted + 1

        local ownerSource = tonumber(ownerKey)
        if not GetPlayerName(ownerSource) then
            self.stats.failedClientVerify = self.stats.failedClientVerify + 1
            goto nextOwner
        end

        do
            -- Promise-based client callback with timeout
            local p        = promise.new()
            local resolved = false
            local function resolve(result)
                if resolved then return end
                resolved = true
                p:resolve(result)
            end

            TriggerClientCallback({
                source    = ownerKey,
                eventName = eventName .. "client:verifyVehicles",
                args      = { netIds },
                timeout   = Config.SmashnGrab.VerifyTimeoutSeconds or 5,
                timedout  = function() resolve(nil) end,
                callback  = function(result) resolve(result) end,
            })

            local response = Citizen.Await(p)

            if not response or type(response) ~= "table" then
                self.stats.failedClientVerify = self.stats.failedClientVerify + 1
                goto nextOwner
            end

            -- Accumulate client-side failure counts
            if response.failures then
                local f = response.failures
                self.stats.clientFailedNetIdInvalid  = self.stats.clientFailedNetIdInvalid  + (f.netIdInvalid  or 0)
                self.stats.clientFailedNotExist      = self.stats.clientFailedNotExist      + (f.notExist      or 0)
                self.stats.clientFailedWrongClass    = self.stats.clientFailedWrongClass    + (f.wrongClass    or 0)
                self.stats.clientFailedNotEmpty      = self.stats.clientFailedNotEmpty      + (f.notEmpty      or 0)
                self.stats.clientFailedBadModel      = self.stats.clientFailedBadModel      + (f.badModel      or 0)
                self.stats.clientFailedBlacklisted   = self.stats.clientFailedBlacklisted   + (f.blacklisted   or 0)
                self.stats.clientFailedTooFewSeats   = self.stats.clientFailedTooFewSeats   + (f.tooFewSeats   or 0)
                self.stats.clientFailedBoneNotFound  = self.stats.clientFailedBoneNotFound  + (f.boneNotFound  or 0)
            end

            if not response.status then
                self.stats.failedClientVerify = self.stats.failedClientVerify + 1
                goto nextOwner
            end

            local added = 0
            for _, vehicleData in pairs(response.vehicles) do
                if slotsLeft <= added then break end

                local netId = vehicleData.netId
                if self.persistentVehicles[netId] then goto nextVehicle end

                local entity = NetworkGetEntityFromNetworkId(netId)
                if not entity or not DoesEntityExist(entity) then goto nextVehicle end

                local coords = GetEntityCoords(entity)
                if isTooCloseToExisting(coords, minDist) then
                    self.stats.failedTooClose = self.stats.failedTooClose + 1
                    goto nextVehicle
                end

                do
                    Trace("Adding persistent vehicle: " .. tostring(coords))

                    local uniqueId   = Main:generateUniqueId()
                    local entityState = Entity(entity).state

                    entityState:set("persistent", true, true)
                    entityState:set("uniqueId",   uniqueId, true)

                    if GetVehicleDoorLockStatus(entity) ~= 2 then
                        SetVehicleDoorsLocked(entity, 2)
                    end

                    local loot = buildLootEntry(SelectRandomItem(Config.SmashnGrab.LootTables))

                    self.persistentVehicles[netId] = {
                        model   = vehicleData.model,
                        netId   = netId,
                        coords  = coords,
                        heading = GetEntityHeading(entity),
                        uniqueId = uniqueId,
                        seat    = vehicleData.seat,
                        loot    = loot,
                        owner   = ownerKey,
                    }
                    self.persistentVehicleCount = self.persistentVehicleCount + 1
                    self.stats.clientVerifyPassed = self.stats.clientVerifyPassed + 1
                    self.stats.lastVehicleAddedAt = GetGameTimer()
                    added    = added + 1
                    anyAdded = true
                end

                ::nextVehicle::
            end
        end

        ::nextOwner::
    end

    if anyAdded then
        TriggerLatentClientEvent(eventName .. "client:updatePersistentVehicles", -1, -1, SmashnGrab.persistentVehicles)
    end
end

-- ─── Get Vehicles (Legacy / Fallback Scan) ───────────────────────────────────
-- Scans all server-side vehicles directly (no candidate queue) and registers
-- robbable ones. Used as an alternative or supplemental path.
-- ⚠️ This function has significant code duplication with prepareVehicle's
-- inner loop. The two paths exist because one uses the candidate queue with
-- per-owner client callbacks, while this one picks a single random source
-- to verify all candidates at once.

function SmashnGrab:getVehicles(source)
    local slotsLeft = Config.SmashnGrab.Limit - self.persistentVehicleCount
    if slotsLeft <= 0 then return end

    local minDist    = Config.SmashnGrab.MinVehicleDistance
    local candidates = {}  -- netId → netId, deduped per-vehicle
    local dedupe     = {}  -- netId → bool, prevents double-registering
    local found      = 0

    for _, entity in ipairs(GetAllVehicles()) do
        if slotsLeft <= found then break end
        if not DoesEntityExist(entity) then goto nextVehicle end
        if GetIsVehicleEngineRunning(entity) then goto nextVehicle end

        local stateBag = getEntityStateBag(entity)
        local netId    = NetworkGetNetworkIdFromEntity(entity)

        if self.persistentVehicles[netId] then goto nextVehicle end

        local owner = NetworkGetEntityOwner(entity)
        -- ⚠️ Condition: owner ~= -1 then check HasVehicleBeenOwnedByPlayer.
        -- If owner IS -1, skip that check. Both paths are "valid" for selection.
        if owner ~= -1 then
            if HasVehicleBeenOwnedByPlayer(entity) then goto nextVehicle end
        end

        if stateBag and (stateBag:get("persistent") or isVehicleLooted(stateBag)) then
            goto nextVehicle
        end

        if Framework:vehicleChecks(netId, entity) then goto nextVehicle end

        do
            local coords = GetEntityCoords(entity)
            if isTooCloseToExisting(coords, minDist) then
                Trace("Vehicle too close to another persistent vehicle")
                goto nextVehicle
            end

            -- Also check against candidates already queued this pass
            for _, candidateNetId in pairs(candidates) do
                local candidateEntity = NetworkGetEntityFromNetworkId(candidateNetId)
                if candidateEntity then
                    local candidateCoords = GetEntityCoords(candidateEntity)
                    if #(coords - candidateCoords) < minDist then
                        goto nextVehicle
                    end
                end
            end

            if not dedupe[netId] then
                dedupe[netId]      = true
                candidates[netId]  = netId
                found = found + 1
            end
        end

        ::nextVehicle::
    end

    if Config.Debug then
        Trace("Vehicles found: " .. found)
    end
    if found < 1 then return end

    local randomSource = self:getRandomSource()
    if not randomSource then return end

    local response = TriggerClientCallback({
        source    = randomSource,
        eventName = eventName .. "client:verifyVehicles",
        args      = { candidates },
    })

    if not response or not response.status then
        Trace(response and response.message or "No response from client verify")
        return
    end

    local added   = 0
    for _, vehicleData in pairs(response.vehicles) do
        if slotsLeft <= added then break end

        local netId  = vehicleData.netId
        if self.persistentVehicles[netId] then goto nextResult end

        local entity = NetworkGetEntityFromNetworkId(netId)
        if not entity then goto nextResult end

        local coords = GetEntityCoords(entity)
        if isTooCloseToExisting(coords, minDist) then
            Trace("Skipping vehicle: too close to another persistent vehicle")
            goto nextResult
        end

        do
            Trace("Adding persistent vehicle: " .. tostring(GetEntityCoords(entity)))

            local assignedSource = self:getRandomSource()
            TriggerClientEvent(eventName .. "client:registerNetworkedEntity", assignedSource, netId, true)

            local uniqueId    = Main:generateUniqueId()
            local entityState = Entity(entity).state
            entityState:set("persistent", true, true)
            entityState:set("uniqueId",   uniqueId, true)

            if GetVehicleDoorLockStatus(entity) ~= 2 then
                SetVehicleDoorsLocked(entity, 2)
            end

            local loot = buildLootEntry(SelectRandomItem(Config.SmashnGrab.LootTables))

            self.persistentVehicles[netId] = {
                model    = vehicleData.model,
                coords   = GetEntityCoords(entity),
                heading  = GetEntityHeading(entity),
                uniqueId = uniqueId,
                seat     = vehicleData.seat,
                loot     = loot,
                owner    = assignedSource,
            }
            self.persistentVehicleCount = self.persistentVehicleCount + 1
            added = added + 1
        end

        ::nextResult::
    end

    Trace("persistentVehicles:", json.encode(self.persistentVehicles, { indent = true }))
    TriggerClientEvent(eventName .. "client:updatePersistentVehicles", -1, self.persistentVehicles)
    Trace("DATA SENT")
end

-- ─── Remove Persistent Vehicle ────────────────────────────────────────────────

function SmashnGrab:removePersistentVehicle(netId, uniqueId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then
        if self.persistentVehicles[netId] then
            self.persistentVehicles[netId] = nil
            decrPersistentCount()
        end
        Trace("Vehicle does not exist")
        return
    end

    table.insert(self.vehiclesToRemove, uniqueId)

    if self.persistentVehicles[netId] then
        self.persistentVehicles[netId] = nil
        decrPersistentCount()
    end
end

-- ─── Give Vehicle Loot ────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName     = eventName .. "server:giveVehicleLoot",
    eventCallback = function(source, data)
        local lootName = data.loot.name

        if not Framework:fetchPlayer(source) then
            return { success = false, message = "NO_CHARACTER" }
        end

        if Main:isJobBlacklisted(source, "SMASH_N_GRAB") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        SmashnGrab:removePersistentVehicle(data.netId, data.uniqueId)
        SmashnGrab.stats.successfullyRobbed = SmashnGrab.stats.successfullyRobbed + 1

        -- Bag mode: give the bag item and let the player open it later
        if Config.SmashnGrab.UseBag then
            local bagItem = Config.SmashnGrab.BagItem or "bbag"
            local added   = Inventory:addPlayerItem(source, bagItem, 1)
            sendWebhook(source, "SMASH_N_GRAB", "Received " .. bagItem)
            if not added then
                return { success = false, message = "ITEM_FAILED_TO_GIVE" }
            end
            return { success = true, message = Translate("SMASHNGRAB_GOT_BAG") }
        end

        -- Direct loot mode
        local count = 1
        if data.loot.count then
            count = math.random(data.loot.count[1], data.loot.count[2])
        end

        if lootName == "money" then
            Framework:addMoney(source, count)
            sendWebhook(source, "SMASH_N_GRAB", "Money x" .. count)
            return { success = true, message = Translate("GIVE_MONEY", { count }) }
        else
            local added = Inventory:addPlayerItem(source, lootName, count)
            sendWebhook(source, "SMASH_N_GRAB", lootName .. " x" .. count)
            if not added then
                return { success = false, message = "ITEM_FAILED_TO_GIVE" }
            end
            return { success = true }
        end
    end,
})

-- ─── Open Bag Loot ────────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName     = eventName .. "server:openBagLoot",
    eventCallback = function(source, data)
        if not Framework:fetchPlayer(source) then
            return { success = false, message = "NO_CHARACTER" }
        end

        if Main:isJobBlacklisted(source, "SMASH_N_GRAB") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        local bagItem   = Config.SmashnGrab.BagItem or "bbag"
        local usedItem  = data.usedItem or bagItem
        local removed   = Inventory:removePlayerItem(source, usedItem, 1)
        if not removed then
            return { success = false, message = "NO_ITEM" }
        end

        local lootTables = Config.SmashnGrab.LootTables
        if not lootTables or #lootTables == 0 then
            return { success = false, message = "NO_LOOT" }
        end

        local loot = SelectRandomItem(lootTables)
        if not loot then
            return { success = false, message = "NO_LOOT" }
        end

        -- Resolve count: can be a {min, max} table or a plain number
        local count = 1
        if loot.count then
            if type(loot.count) == "table" then
                count = math.random(loot.count[1], loot.count[2])
            elseif type(loot.count) == "number" then
                count = loot.count
            end
        end

        if loot.name == "money" then
            Framework:addMoney(source, count)
            sendWebhook(source, "SMASH_N_GRAB_BAG", "Money x" .. count)
            return { success = true, message = Translate("GIVE_MONEY", { count }) }
        else
            local added = Inventory:addPlayerItem(source, loot.name, count)
            sendWebhook(source, "SMASH_N_GRAB_BAG", loot.name .. " x" .. count)
            if not added then
                return { success = false, message = "ITEM_FAILED_TO_GIVE" }
            end
            return { success = true, message = Translate("SMASHNGRAB_BAG_OPENED") }
        end
    end,
})

-- ─── Request Persistent Vehicles ─────────────────────────────────────────────

RegisterNetEvent(eventName .. "server:requestPersistentVehicles")
AddEventHandler(eventName .. "server:requestPersistentVehicles", function()
    TriggerClientEvent(eventName .. "client:updatePersistentVehicles", source, SmashnGrab.persistentVehicles)
    Trace("Data sent to client", source)
end)

-- ─── Smash Vehicle Window (Proximity Broadcast) ───────────────────────────────

RegisterNetEvent(eventName .. "server:smashVehicleWindow")
AddEventHandler(eventName .. "server:smashVehicleWindow", function(netId, windowIndex)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then
        Trace(("Invalid entity from %s (netId: %s)"):format(source, netId))
        return
    end

    local vehicleCoords = GetEntityCoords(entity)
    for _, playerId in pairs(getCachedPlayers()) do
        if playerId ~= tostring(source) then
            local playerPed = GetPlayerPed(playerId)
            if DoesEntityExist(playerPed) then
                if #(vehicleCoords - GetEntityCoords(playerPed)) <= 30.0 then
                    TriggerClientEvent(eventName .. "client:smashVehicleWindow", playerId, netId, windowIndex)
                end
            end
        end
    end
end)

-- ─── Utility Methods ──────────────────────────────────────────────────────────

function SmashnGrab:getRandomSource()
    local players = getCachedPlayers()
    if #players == 0 then return nil end
    return players[math.random(1, #players)]
end

function SmashnGrab:getClosestPlayer(coords, radius)
    for _, playerId in pairs(getCachedPlayers()) do
        local playerCoords = GetEntityCoords(GetPlayerPed(playerId))
        if #(coords - playerCoords) < radius then
            return true
        end
    end
    return false
end

-- ─── Resource Cleanup ─────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for netId in pairs(SmashnGrab.persistentVehicles) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    SmashnGrab.persistentVehicles     = {}
    SmashnGrab.persistentVehicleCount = 0
end)

-- ─── Player Dropped ───────────────────────────────────────────────────────────

AddEventHandler("playerDropped", function()
    local droppedSource  = source
    local newOwner       = SmashnGrab:getRandomSource()

    for netId, data in pairs(SmashnGrab.persistentVehicles) do
        if data.owner == droppedSource then
            SmashnGrab.persistentVehicles[netId] = nil
            decrPersistentCount()
            SmashnGrab.stats.playerDroppedLosses = SmashnGrab.stats.playerDroppedLosses + 1

            if newOwner then
                TriggerClientEvent(eventName .. "client:registerNetworkedEntity", newOwner, netId, false)
            end
        end
    end
end)

-- ─── Exports ──────────────────────────────────────────────────────────────────

exports("getRobbableVehicles", function()
    return SmashnGrab.persistentVehicles
end)

exports("getRobbableVehicle", function(netId)
    return SmashnGrab.persistentVehicles[netId]
end)

exports("isVehicleRobbable", function(netId)
    return SmashnGrab.persistentVehicles[netId] ~= nil
end)

-- ─── Editor / Admin Callbacks ─────────────────────────────────────────────────

RegisterServerCallback({
    eventName     = eventName .. "editor:getSmashnGrabStats",
    eventCallback = function(source)
        if not Framework:isAdmin(source) then
            return { status = false }
        end

        local now     = GetGameTimer()
        local ready   = 0
        local waiting = 0
        for _, readyAt in pairs(SmashnGrab.candidateVehicles) do
            if readyAt <= now then
                ready   = ready + 1
            else
                waiting = waiting + 1
            end
        end

        return {
            status        = true,
            debugEnabled  = SmashnGrab.debugEnabled,
            stats         = SmashnGrab.stats,
            activeVehicles = SmashnGrab.persistentVehicleCount,
            vehicleLimit  = Config.SmashnGrab.Limit,
            queueReady    = ready,
            queueWaiting  = waiting,
            gameTime      = now,
        }
    end,
})

RegisterServerCallback({
    eventName     = eventName .. "editor:toggleSmashnGrabDebug",
    eventCallback = function(source)
        if not Framework:isAdmin(source) then
            return { status = false }
        end

        SmashnGrab.debugEnabled = not SmashnGrab.debugEnabled
        SmashnGrab.stats = SmashnGrab.debugEnabled
            and createFullStats()
            or  createNullStats()

        local state = SmashnGrab.debugEnabled and "enabled" or "disabled"
        Trace("SmashnGrab debug tracking " .. state .. " by player " .. source)

        return { status = true, enabled = SmashnGrab.debugEnabled }
    end,
})

RegisterServerCallback({
    eventName     = eventName .. "editor:resetSmashnGrabStats",
    eventCallback = function(source)
        if not Framework:isAdmin(source) then
            return { status = false }
        end
        SmashnGrab.stats = createFullStats()
        return { status = true }
    end,
})