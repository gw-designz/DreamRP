if not (Config and Config.Prison and Config.Prison.Enabled) then return end

-- Global Prison object shared across the resource
Prison = {
    sentences            = {},   -- [uniqueId] = sentenceData
    cellAssignments      = {},   -- [cellId]   = uniqueId
    solitaryAssignments  = {},   -- [slotIndex] = uniqueId
    pendingOfflineRelease = {},  -- [uniqueId] = true
    Map                  = nil,
}

-- ─── Map Loading ─────────────────────────────────────────────────────────────

local mapType = type(Config.PrisonMap)
if mapType == "string" then
    Prison.Map = lib.load(string.format("maps.prisons.%s", Config.PrisonMap))
elseif mapType == "table" then
    Prison.Map = lib.load(string.format("maps.prisons.%s", Config.PrisonMap[1]))
end

if type(Prison.Map) ~= "table" then
    lib.print.error("Failed to load prison map on server. Check Config.PrisonMap in config/shared.lua")
    return
end

-- ─── Database Init ────────────────────────────────────────────────────────────

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `p_policejob_prison_sentences` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `identifier` VARCHAR(60) NOT NULL,
            `player_name` VARCHAR(100) NOT NULL,
            `officer_name` VARCHAR(100) DEFAULT NULL,
            `officer_id` INT DEFAULT NULL,
            `reason` TEXT,
            `sentence_time` INT NOT NULL DEFAULT 0,
            `remaining_time` INT NOT NULL DEFAULT 0,
            `cell_id` INT DEFAULT NULL,
            `is_community_service` TINYINT(1) DEFAULT 0,
            `is_solitary` TINYINT(1) DEFAULT 0,
            `solitary_until` INT DEFAULT 0,
            `status` ENUM('active','released','escaped') DEFAULT 'active',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `released_at` TIMESTAMP NULL DEFAULT NULL,
            INDEX `idx_identifier` (`identifier`),
            INDEX `idx_status` (`status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `p_policejob_prison_jobs` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `job_id` VARCHAR(50) NOT NULL,
            `label` VARCHAR(100) NOT NULL,
            `description` TEXT,
            `payment` INT DEFAULT 0,
            `duration` INT DEFAULT 30,
            `time_reduction` INT DEFAULT 0,
            `locations` LONGTEXT,
            `animation_dict` VARCHAR(100),
            `animation_clip` VARCHAR(100),
            `created_by` VARCHAR(60),
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    Wait(1000)
    Prison:loadActiveSentences()
    Wait(2000)
    Prison:restoreOnlinePlayers()
end)

-- ─── Community Service Routing Bucket ────────────────────────────────────────

-- Isolates CS players into their own routing bucket (or releases back to 0)
function Prison:setCommunityServiceBucket(playerSource, shouldIsolate)
    local csCfg = Config.Prison.CommunityService
    if not (csCfg and csCfg.isolatePlayer) then return end

    if shouldIsolate then
        SetPlayerRoutingBucket(playerSource, (csCfg.bucketBase or 10000) + playerSource)
    else
        SetPlayerRoutingBucket(playerSource, 0)
    end
end

-- ─── Sentence Pausing / Resuming ─────────────────────────────────────────────

-- Pauses a sentence's countdown (called on playerDropped)
function Prison:pauseSentence(sentence)
    if sentence.pausedAt then return end
    sentence.pausedAt = os.time()
end

-- Resumes a paused sentence, shifting releaseAt by the paused duration
function Prison:resumeSentence(sentence)
    if not sentence.pausedAt then return end

    if sentence.releaseAt > 0 then
        local elapsed     = os.time() - sentence.pausedAt
        sentence.releaseAt = sentence.releaseAt + elapsed
    end

    sentence.pausedAt = nil
end

-- Returns remaining seconds, or -1 for life sentences
function Prison:sentenceRemaining(sentence)
    if sentence.releaseAt == 0 then return -1 end

    local reference = sentence.pausedAt or os.time()
    return math.max(0, sentence.releaseAt - reference)
end

-- ─── Restore Online Players ───────────────────────────────────────────────────

-- After resource restart: resumes sentences and re-triggers prison entry for all online prisoners
function Prison:restoreOnlinePlayers()
    for uniqueId, sentence in pairs(self.sentences) do
        if sentence.status == "active" then
            local playerObj = Bridge.Framework.getPlayerByUniqueId(uniqueId)
            local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))

            if playerSource then
                self:resumeSentence(sentence)
                local remaining = self:sentenceRemaining(sentence)

                local sentencePacket = {
                    id              = sentence.id,
                    identifier      = sentence.identifier,
                    playerName      = sentence.playerName,
                    officerName     = sentence.officerName,
                    reason          = sentence.reason,
                    sentenceTime    = sentence.sentenceTime,
                    remaining       = remaining,
                    cellId          = sentence.cellId,
                    isCommunityService = sentence.isCommunityService,
                    solitaryCoords  = nil,
                }

                -- Resolve solitary coords
                if sentence.isSolitary and sentence.solitarySlot then
                    local slots = self:getSolitarySlots()
                    sentencePacket.solitaryCoords = slots[sentence.solitarySlot]
                end

                if remaining == -1 or remaining > 0 then
                    if sentence.isCommunityService then
                        self:setCommunityServiceBucket(playerSource, true)
                        TriggerClientEvent("p_policejob/client/prison/communityService/enter", playerSource, sentencePacket)
                    else
                        TriggerClientEvent("p_policejob/client/prison/restoreState", playerSource, sentencePacket)
                    end
                    Bridge.Debug(string.format("[Prison] Restored prison state for player %d on resource restart", playerSource))
                end
            end
        end
    end
end

-- ─── Job Access ──────────────────────────────────────────────────────────────

function Prison:hasJobAccess(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end
    return Config.Jobs[job.name] ~= nil
end

-- ─── Cell Management ─────────────────────────────────────────────────────────

-- Returns the first unassigned cell id, or nil
function Prison:findAvailableCell()
    if not Config.Prison.Cells.assignAutomatically then return nil end
    if not (self.Map and self.Map.cells) then return nil end

    for _, cell in ipairs(self.Map.cells) do
        if not self.cellAssignments[cell.id] then
            return cell.id
        end
    end

    return nil
end

function Prison:assignCell(cellId, uniqueId)
    self.cellAssignments[cellId] = uniqueId
end

function Prison:freeCell(cellId)
    self.cellAssignments[cellId] = nil
end

-- ─── Solitary Management ─────────────────────────────────────────────────────

-- Returns all solitary coord entries as a table (normalises single coord or array)
function Prison:getSolitarySlots()
    local sol = self.Map and self.Map.solitary
    if not sol then return {} end
    if sol.x then return { sol } end
    return sol
end

-- Returns (slotIndex, coords) for the first free solitary slot, or nil
function Prison:findFreeSolitarySlot()
    local slots = self:getSolitarySlots()
    for i = 1, #slots do
        if not self.solitaryAssignments[i] then
            return i, slots[i]
        end
    end
    return nil
end

-- Frees the solitary slot occupied by a sentence record
function Prison:freeSolitarySlot(sentence)
    if sentence.solitarySlot then
        self.solitaryAssignments[sentence.solitarySlot] = nil
        sentence.solitarySlot = nil
    end
end

-- ─── Load Active Sentences ────────────────────────────────────────────────────

function Prison:loadActiveSentences()
    local rows = MySQL.query.await(
        "SELECT * FROM `p_policejob_prison_sentences` WHERE `status` = ?",
        { "active" }
    )
    if not rows then return end

    local now = os.time()

    for _, row in ipairs(rows) do
        local releaseAt = row.remaining_time > 0 and (now + row.remaining_time) or 0

        local sentence = {
            id                = row.id,
            identifier        = row.identifier,
            playerName        = row.player_name,
            officerName       = row.officer_name,
            reason            = row.reason,
            sentenceTime      = row.sentence_time,
            releaseAt         = releaseAt,
            cellId            = row.cell_id,
            isCommunityService = row.is_community_service == 1,
            isSolitary        = row.is_solitary == 1,
            solitaryUntil     = row.solitary_until,
            status            = row.status,
            pausedAt          = now,   -- starts paused until player reconnects
        }

        self.sentences[row.identifier] = sentence

        if row.cell_id then
            self.cellAssignments[row.cell_id] = row.identifier
        end

        if sentence.isSolitary then
            local slotIndex = self:findFreeSolitarySlot()
            if slotIndex then
                sentence.solitarySlot = slotIndex
                self.solitaryAssignments[slotIndex] = row.identifier
            end
        end
    end

    Bridge.Debug(string.format("[Prison] Loaded %d active sentences", #rows))
end

-- ─── Send to Jail ────────────────────────────────────────────────────────────

-- Jails a player. Parameters:
--   officerSource  - server id of the arresting officer
--   targetSource   - server id of the player being jailed
--   sentenceMinutes - sentence length in minutes (0 for life)
--   reason         - string reason
--   isCommunityService - bool
--   options        - { lifeSentence=bool, cellId=number }
function Prison:sendToJail(officerSource, targetSource, sentenceMinutes, reason, isCommunityService, options)
    local uniqueId = Bridge.Framework.getUniqueId(targetSource)
    if not uniqueId then return false end

    -- Already jailed
    local existing = self.sentences[uniqueId]
    if existing and existing.status == "active" then
        Bridge.Notify.showNotify(targetSource, locale("prison_already_jailed"), "error")
        return false
    end

    options = options or {}

    local isLife         = options.lifeSentence == true
    local sentenceSeconds = isLife and 0 or (sentenceMinutes * 60)
    local playerName     = Bridge.Framework.getPlayerName(targetSource)
    local officerName    = Bridge.Framework.getPlayerName(officerSource)

    -- Resolve cell
    local cellId = nil
    if options.cellId then
        local parsed = tonumber(options.cellId)
        if parsed and not self.cellAssignments[parsed] then
            cellId = parsed
        end
    end
    if not cellId then
        cellId = self:findAvailableCell()
    end

    -- Insert DB record
    local insertId = MySQL.insert.await(
        "INSERT INTO `p_policejob_prison_sentences` "
        .. "(`identifier`, `player_name`, `officer_name`, `officer_id`, `reason`, "
        .. "`sentence_time`, `remaining_time`, `cell_id`, `is_community_service`) "
        .. "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        {
            uniqueId, playerName, officerName, officerSource, reason,
            sentenceSeconds, sentenceSeconds, cellId,
            isCommunityService and 1 or 0,
        }
    )

    if not insertId then return false end

    local sentencePacket = {
        id                 = insertId,
        identifier         = uniqueId,
        playerName         = playerName,
        officerName        = officerName,
        reason             = reason,
        sentenceTime       = sentenceSeconds,
        remaining          = isLife and -1 or sentenceSeconds,
        releaseAt          = isLife and 0 or (os.time() + sentenceSeconds),
        cellId             = cellId,
        isCommunityService = isCommunityService,
        isLife             = isLife,
        isSolitary         = false,
        solitaryUntil      = 0,
        status             = "active",
    }

    self.sentences[uniqueId] = sentencePacket

    if cellId then
        self:assignCell(cellId, uniqueId)
    end

    self:processJailItems(targetSource, uniqueId)

    -- Trigger client entry
    if isCommunityService then
        self:setCommunityServiceBucket(targetSource, true)
        TriggerClientEvent("p_policejob/client/prison/communityService/enter", targetSource, sentencePacket)
    elseif Config.Prison.Mugshot.enabled then
        TriggerClientEvent("p_policejob/client/prison/mugshot", targetSource, sentencePacket)
    else
        TriggerClientEvent("p_policejob/client/prison/enter", targetSource, sentencePacket)
    end

    -- Clear cuffs / drag state
    local playerState = Player(targetSource).state
    if playerState.isCuffed then
        playerState:set("isCuffed",  false, true)
        playerState:set("cuffType",  "none", true)
    end
    if playerState.draggedBy then
        playerState:set("draggedBy", nil, true)
    end

    if type(Config.Prison.onPlayerJailed_Server) == "function" then
        Config.Prison.onPlayerJailed_Server(officerSource, targetSource, sentencePacket)
    end

    Bridge.Logs.Send(officerSource, "Prison",
        string.format("Sent %s (ID: %d) to %s for %d minutes. Reason: %s",
            playerName, targetSource,
            isCommunityService and "community service" or "prison",
            sentenceMinutes, reason),
        Config.Webhooks.prison)

    Bridge.Notify.showNotify(officerSource,
        locale("prison_player_sent", playerName), "success")

    return true
end

-- ─── Release Prisoner ─────────────────────────────────────────────────────────

-- Releases a prisoner by unique id; officerSource is optional (for logging)
function Prison:releasePrisoner(uniqueId, officerSource)
    local sentence = self.sentences[uniqueId]
    if not sentence then return false end

    MySQL.update(
        "UPDATE `p_policejob_prison_sentences` SET `status` = ?, `remaining_time` = 0, `released_at` = NOW() WHERE `id` = ?",
        { "released", sentence.id }
    )

    if sentence.cellId then
        self:freeCell(sentence.cellId)
    end

    self:freeSolitarySlot(sentence)

    -- Notify the online player
    local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
    local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))

    if playerSource then
        if sentence.isCommunityService then
            self:setCommunityServiceBucket(playerSource, false)
            TriggerClientEvent("p_policejob/client/prison/communityService/release", playerSource)
        else
            TriggerClientEvent("p_policejob/client/prison/release", playerSource)
        end
    elseif not sentence.isCommunityService then
        self.pendingOfflineRelease[uniqueId] = true
    end

    self.sentences[uniqueId] = nil

    if officerSource then
        Bridge.Logs.Send(officerSource, "Prison",
            string.format("Released prisoner %s (ID: %s)", sentence.playerName, uniqueId),
            Config.Webhooks.prison)
    end

    if type(Config.Prison.onPlayerReleased_Server) == "function" then
        Config.Prison.onPlayerReleased_Server(uniqueId)
    end

    return true
end

-- ─── Escape Jail ─────────────────────────────────────────────────────────────

function Prison:escapeJail(uniqueId)
    local sentence = self.sentences[uniqueId]
    if not (sentence and sentence.status == "active") then return false end

    MySQL.update(
        "UPDATE `p_policejob_prison_sentences` SET `status` = ?, `remaining_time` = 0, `released_at` = NOW() WHERE `id` = ?",
        { "escaped", sentence.id }
    )

    if sentence.cellId then self:freeCell(sentence.cellId) end
    self:freeSolitarySlot(sentence)
    self.sentences[uniqueId] = nil

    local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
    local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))

    if playerSource then
        if sentence.isCommunityService then
            self:setCommunityServiceBucket(playerSource, false)
        end
        TriggerClientEvent("p_policejob/client/prison/escaped", playerSource)
    end

    -- Dispatch escape alert
    if playerSource and Bridge.Dispatch and Bridge.Dispatch.SendAlert then
        local jobList = {}
        for jobName in pairs(Config.Jobs) do jobList[#jobList + 1] = jobName end

        Bridge.Dispatch.SendAlert(playerSource, {
            title    = locale("prison_escape_alert", sentence.playerName),
            code     = "10-98",
            icon     = "fa-solid fa-person-running",
            priority = "high",
            blip     = { sprite = 188, scale = 1.2, color = 1 },
            job      = jobList,
        })
    end

    if type(Config.Prison.onPlayerEscaped_Server) == "function" then
        Config.Prison.onPlayerEscaped_Server(playerSource, sentence)
    end

    if playerSource then
        Bridge.Logs.Send(playerSource, "Prison",
            string.format("Prisoner %s (%s) escaped from prison", sentence.playerName, uniqueId),
            Config.Webhooks.prison)
    end

    return true
end

-- ─── Sentence Adjustment ─────────────────────────────────────────────────────

-- Reduces a sentence by deltaSeconds. Releases automatically if it hits 0.
function Prison:reduceSentence(uniqueId, deltaSeconds)
    local sentence = self.sentences[uniqueId]
    if not sentence then return false end
    if sentence.releaseAt == 0 then return false end  -- life sentence

    sentence.releaseAt   = sentence.releaseAt - deltaSeconds
    local remaining      = math.max(0, self:sentenceRemaining(sentence))
    sentence.sentenceTime = math.max(remaining, (sentence.sentenceTime or 0) - deltaSeconds)

    MySQL.update(
        "UPDATE `p_policejob_prison_sentences` SET `remaining_time` = ?, `sentence_time` = ? WHERE `id` = ?",
        { remaining, sentence.sentenceTime, sentence.id }
    )

    if remaining <= 0 then
        self:releasePrisoner(uniqueId)
        return true
    end

    local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
    local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))

    if playerSource then
        TriggerClientEvent("p_policejob/client/prison/updateSentence",
            playerSource, remaining, sentence.sentenceTime)
    end

    return true
end

-- Increases a sentence by deltaSeconds
function Prison:increaseSentence(uniqueId, deltaSeconds)
    local sentence = self.sentences[uniqueId]
    if not sentence then return false end
    if sentence.releaseAt == 0 then return false end

    sentence.releaseAt    = sentence.releaseAt + deltaSeconds
    local remaining       = math.max(0, self:sentenceRemaining(sentence))
    sentence.sentenceTime = (sentence.sentenceTime or 0) + deltaSeconds

    MySQL.update(
        "UPDATE `p_policejob_prison_sentences` SET `remaining_time` = ?, `sentence_time` = ? WHERE `id` = ?",
        { remaining, sentence.sentenceTime, sentence.id }
    )

    local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
    local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))

    if playerSource then
        TriggerClientEvent("p_policejob/client/prison/updateSentence",
            playerSource, remaining, sentence.sentenceTime)
        Bridge.Notify.showNotify(playerSource, locale("prison_sentence_increased"), "error")
    end

    return true
end

-- ─── Solitary ────────────────────────────────────────────────────────────────

function Prison:sendToSolitary(uniqueId, minutes)
    local sentence = self.sentences[uniqueId]
    if not sentence then return false end
    if sentence.isSolitary then return false end

    local slotIndex, slotCoords = self:findFreeSolitarySlot()
    if not slotIndex then return false, "full" end

    local until_ = os.time() + minutes * 60

    sentence.isSolitary    = true
    sentence.solitaryUntil = until_
    sentence.solitarySlot  = slotIndex
    self.solitaryAssignments[slotIndex] = uniqueId

    MySQL.update(
        "UPDATE `p_policejob_prison_sentences` SET `is_solitary` = 1, `solitary_until` = ? WHERE `id` = ?",
        { until_, sentence.id }
    )

    local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
    local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))

    if playerSource then
        TriggerClientEvent("p_policejob/client/prison/moveToSolitary", playerSource, slotCoords)
    end

    return true
end

function Prison:releaseFromSolitary(uniqueId)
    local sentence = self.sentences[uniqueId]
    if not (sentence and sentence.isSolitary) then return false end

    sentence.isSolitary    = false
    sentence.solitaryUntil = 0
    self:freeSolitarySlot(sentence)

    MySQL.update(
        "UPDATE `p_policejob_prison_sentences` SET `is_solitary` = 0, `solitary_until` = 0 WHERE `id` = ?",
        { sentence.id }
    )

    local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
    local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))

    if playerSource and sentence.cellId then
        TriggerClientEvent("p_policejob/client/prison/moveToCell", playerSource, sentence.cellId)
    end

    return true
end

-- ─── Callbacks ────────────────────────────────────────────────────────────────

lib.callback.register("p_policejob/server/prison/getRemainingTime", function(playerSource)
    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return 0 end

    local sentence = Prison.sentences[uniqueId]
    if not sentence then return 0 end

    return Prison:sentenceRemaining(sentence)
end)

lib.callback.register("p_policejob/server/prison/getAllPrisoners", function(playerSource)
    if not Prison:hasJobAccess(playerSource) then return {} end

    local list = {}

    for uniqueId, sentence in pairs(Prison.sentences) do
        local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
        local playerSource2 = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))
        local isOnline     = playerSource2 ~= nil

        list[#list + 1] = {
            id                 = sentence.id,
            identifier         = uniqueId,
            playerName         = sentence.playerName,
            officerName        = sentence.officerName,
            reason             = sentence.reason,
            sentenceTime       = sentence.sentenceTime,
            remaining          = Prison:sentenceRemaining(sentence),
            cellId             = sentence.cellId,
            isCommunityService = sentence.isCommunityService,
            isSolitary         = sentence.isSolitary,
            solitaryUntil      = sentence.solitaryUntil,
            status             = sentence.status,
            isOnline           = isOnline,
            playerId           = playerSource2,
        }
    end

    return list
end)

-- ─── Management Net Events ────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/server/prison/management/release", function(payload)
    local playerSource = source
    if not Prison:hasJobAccess(playerSource) then return end
    if not (payload and payload.identifier) then return end

    Prison:releasePrisoner(payload.identifier, playerSource)
    Bridge.Notify.showNotify(playerSource, locale("prison_prisoner_released"), "success")
end)

RegisterNetEvent("p_policejob/server/prison/management/reduceSentence", function(payload)
    local playerSource = source
    if not Prison:hasJobAccess(playerSource) then return end
    if not (payload and payload.identifier and payload.minutes) then return end

    local delta = math.max(0, tonumber(payload.minutes) or 0) * 60
    Prison:reduceSentence(payload.identifier, delta)

    Bridge.Notify.showNotify(playerSource, locale("prison_sentence_reduced"), "success")
    Bridge.Logs.Send(playerSource, "Prison",
        string.format("Reduced sentence for %s by %d minutes", payload.identifier, payload.minutes),
        Config.Webhooks.prison)
end)

RegisterNetEvent("p_policejob/server/prison/management/increaseSentence", function(payload)
    local playerSource = source
    if not Prison:hasJobAccess(playerSource) then return end
    if not (payload and payload.identifier and payload.minutes) then return end

    local delta = math.max(0, tonumber(payload.minutes) or 0) * 60
    Prison:increaseSentence(payload.identifier, delta)

    Bridge.Notify.showNotify(playerSource, locale("prison_sentence_increased_by"), "success")
    Bridge.Logs.Send(playerSource, "Prison",
        string.format("Increased sentence for %s by %d minutes", payload.identifier, payload.minutes),
        Config.Webhooks.prison)
end)

RegisterNetEvent("p_policejob/server/prison/management/solitary", function(payload)
    local playerSource = source
    if not Prison:hasJobAccess(playerSource) then return end
    if not (payload and payload.identifier) then return end

    if payload.release then
        Prison:releaseFromSolitary(payload.identifier)
        Bridge.Notify.showNotify(playerSource, locale("prison_solitary_released"), "success")
    else
        local minutes = math.max(1,
            math.min(Config.Prison.Solitary.maxTime, tonumber(payload.minutes) or 15))
        local ok, reason = Prison:sendToSolitary(payload.identifier, minutes)

        if ok then
            Bridge.Notify.showNotify(playerSource, locale("prison_sent_to_solitary"), "success")
        elseif reason == "full" then
            Bridge.Notify.showNotify(playerSource, locale("prison_solitary_full"), "error")
            return
        else
            return
        end
    end

    Bridge.Logs.Send(playerSource, "Prison",
        string.format("%s solitary for %s",
            payload.release and "Released from" or "Sent to",
            payload.identifier),
        Config.Webhooks.prison)
end)

RegisterNetEvent("p_policejob/server/prison/management/moveToCell", function(payload)
    local playerSource = source
    if not Prison:hasJobAccess(playerSource) then return end
    if not (payload and payload.identifier and payload.cellId) then return end

    local sentence = Prison.sentences[payload.identifier]
    if not sentence then return end

    if sentence.cellId then
        Prison:freeCell(sentence.cellId)
    end

    sentence.cellId = payload.cellId
    Prison:assignCell(payload.cellId, payload.identifier)

    MySQL.update(
        "UPDATE `p_policejob_prison_sentences` SET `cell_id` = ? WHERE `id` = ?",
        { payload.cellId, sentence.id }
    )

    local playerObj    = Bridge.Framework.getPlayerByUniqueId(payload.identifier)
    local targetSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))

    if targetSource then
        TriggerClientEvent("p_policejob/client/prison/moveToCell", targetSource, payload.cellId)
    end
end)

-- ─── Prison Jobs Net Event ────────────────────────────────────────────────────

-- [source] → cooldown table: identifier .. ":" .. jobId = os.time() expiry
local jobServerCooldowns = {}

RegisterNetEvent("p_policejob/server/prison/jobComplete", function(payload)
    local playerSource = source
    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end

    local sentence = Prison.sentences[uniqueId]
    if not sentence then return end

    if not (payload and payload.jobId) then return end

    -- Find job definition
    local jobDef = nil
    for _, def in ipairs((Config.Prison.PrisonJobs and Config.Prison.PrisonJobs.defaultJobs) or {}) do
        if def.id == payload.jobId then jobDef = def break end
    end
    if not jobDef then return end

    -- Server-side cooldown check
    local cooldownKey = uniqueId .. ":" .. jobDef.id
    local now         = os.time()
    local existing    = jobServerCooldowns[cooldownKey]
    if existing and now < existing then
        Bridge.Notify.showNotify(playerSource, "This job is on cooldown.", "error")
        return
    end

    jobServerCooldowns[cooldownKey] = now + (jobDef.duration or 30)

    local stopsTotal     = math.max(1, tonumber(Config.Prison.PrisonJobs.stopsPerJob) or 5)
    local stopsCompleted = math.max(0, math.min(stopsTotal, tonumber(payload.stopsCompleted) or 0))
    if stopsCompleted <= 0 then return end

    local timeReduction = (tonumber(jobDef.timeReduction) or 0) * stopsCompleted * 60
    local payment       = (tonumber(jobDef.payment)       or 0) * stopsCompleted

    if timeReduction > 0 then
        Prison:reduceSentence(uniqueId, timeReduction)
    end

    if payment > 0 then
        Bridge.Framework.addMoney(playerSource, "cash", payment)
    end
end)

-- ─── Cell Stash Net Event ─────────────────────────────────────────────────────

local registeredCellStashes = {}

RegisterNetEvent("p_policejob/server/prison/cellStash/open", function(rawCellId)
    local playerSource = source
    if not (Config.Prison.CellStash and Config.Prison.CellStash.enabled) then return end

    local cellId = tonumber(rawCellId)
    if not cellId then return end

    -- Validate the cell exists in the map
    local cellValid = false
    if Prison.Map and Prison.Map.cells then
        for _, cell in ipairs(Prison.Map.cells) do
            if cell.id == cellId then cellValid = true break end
        end
    end
    if not cellValid then return end

    -- Validate the player is sentenced to this cell
    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    local sentence = uniqueId and Prison.sentences[uniqueId]
    if not (sentence and sentence.status == "active" and sentence.cellId == cellId) then return end

    local stashId = string.format("p_policejob_cell_%d", cellId)
    if registeredCellStashes[stashId] then return end

    registeredCellStashes[stashId] = true

    if Bridge.Inventory.registerStash then
        Bridge.Inventory.registerStash(stashId, stashId,
            Config.Prison.CellStash.slots     or 2,
            Config.Prison.CellStash.maxWeight or 8000)
    end
end)

-- ─── Community Task Complete ──────────────────────────────────────────────────

RegisterNetEvent("p_policejob/server/prison/communityTaskComplete", function()
    local playerSource = source
    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end

    local sentence = Prison.sentences[uniqueId]
    if not (sentence and sentence.isCommunityService) then return end

    Prison:reduceSentence(uniqueId, Config.Prison.Sentence.tickRate)
end)

-- ─── Release All Expired ─────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/server/prison/management/releaseAllExpired", function()
    local playerSource = source
    if not Prison:hasJobAccess(playerSource) then return end

    local now     = os.time()
    local expired = {}

    for uniqueId, sentence in pairs(Prison.sentences) do
        if not sentence.pausedAt and sentence.releaseAt > 0
        and (sentence.releaseAt - now) <= 0
        then
            expired[#expired + 1] = uniqueId
        end
    end

    for _, uniqueId in ipairs(expired) do
        Prison:releasePrisoner(uniqueId, playerSource)
    end

    Bridge.Notify.showNotify(playerSource,
        string.format("Released %d expired sentence(s).", #expired),
        "success")
end)

-- ─── Player Load Event ────────────────────────────────────────────────────────

AddEventHandler("p_bridge/server/playerLoaded", function(playerSource)
    Wait(3000)

    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end

    local sentence = Prison.sentences[uniqueId]

    if sentence and sentence.status == "active" then
        Prison:resumeSentence(sentence)
        local remaining = Prison:sentenceRemaining(sentence)

        local sentencePacket = {
            id                 = sentence.id,
            identifier         = sentence.identifier,
            playerName         = sentence.playerName,
            officerName        = sentence.officerName,
            reason             = sentence.reason,
            sentenceTime       = sentence.sentenceTime,
            remaining          = remaining,
            cellId             = sentence.cellId,
            isCommunityService = sentence.isCommunityService,
            solitaryCoords     = nil,
        }

        if sentence.isSolitary and sentence.solitarySlot then
            local slots = Prison:getSolitarySlots()
            sentencePacket.solitaryCoords = slots[sentence.solitarySlot]
        end

        if remaining == -1 or remaining > 0 then
            if sentence.isCommunityService then
                Prison:setCommunityServiceBucket(playerSource, true)
                TriggerClientEvent("p_policejob/client/prison/communityService/enter", playerSource, sentencePacket)
            else
                TriggerClientEvent("p_policejob/client/prison/restoreState", playerSource, sentencePacket)
            end
            Bridge.Debug(string.format("[Prison] Restored prison state for player %d", playerSource))
        end

    elseif Prison.pendingOfflineRelease[uniqueId] then
        Prison.pendingOfflineRelease[uniqueId] = nil
        TriggerClientEvent("p_policejob/client/prison/releaseSpawn", playerSource)
        Bridge.Debug(string.format("[Prison] Player %d was released while offline, moving to release point", playerSource))
    end
end)

-- ─── Resource Stop: Restore CS Buckets ───────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for uniqueId, sentence in pairs(Prison.sentences) do
        if sentence.isCommunityService then
            local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
            local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))
            if playerSource then
                SetPlayerRoutingBucket(playerSource, 0)
            end
        end
    end
end)

-- ─── Player Dropped ───────────────────────────────────────────────────────────

AddEventHandler("playerDropped", function()
    local playerSource = source
    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end

    local sentence = Prison.sentences[uniqueId]
    if not sentence then return end

    Prison:pauseSentence(sentence)

    -- Save remaining time to DB
    local remaining = sentence.releaseAt == 0 and 0
        or math.max(0, sentence.releaseAt - (sentence.pausedAt or os.time()))

    MySQL.update(
        "UPDATE `p_policejob_prison_sentences` SET `remaining_time` = ? WHERE `id` = ?",
        { remaining, sentence.id }
    )
end)

-- ─── Sentence Tick Thread ─────────────────────────────────────────────────────

-- Waits until there are active sentences, then ticks every 30s:
-- auto-releases expired sentences, updates remaining time in DB, releases solitary, syncs clients
CreateThread(function()
    -- Wait until at least one sentence is active
    while true do
        if next(Prison.sentences) then break end
        Wait(5000)

        local count = MySQL.scalar.await(
            "SELECT COUNT(*) as cnt FROM `p_policejob_prison_sentences` WHERE `status` = ?",
            { "active" }
        )
        if count and count == 0 then break end
    end

    while true do
        Wait(30000)

        local now     = os.time()
        local toRelease = {}
        local toUpdate  = {}

        for uniqueId, sentence in pairs(Prison.sentences) do
            if not sentence.pausedAt then
                if sentence.releaseAt > 0 then
                    local remaining = sentence.releaseAt - now

                    if remaining <= 0 then
                        toRelease[#toRelease + 1] = uniqueId
                    else
                        -- Sync remaining time to online player
                        local playerObj    = Bridge.Framework.getPlayerByUniqueId(uniqueId)
                        local playerSource = playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))
                        if playerSource then
                            TriggerClientEvent("p_policejob/client/prison/updateSentence",
                                playerSource, remaining)
                        end

                        toUpdate[#toUpdate + 1] = { remaining = remaining, id = sentence.id }
                    end
                end

                -- Auto-release from solitary
                if sentence.isSolitary and sentence.solitaryUntil > 0 and now >= sentence.solitaryUntil then
                    Prison:releaseFromSolitary(uniqueId)
                end
            end
        end

        for _, uniqueId in ipairs(toRelease) do
            Prison:releasePrisoner(uniqueId)
        end

        for _, entry in ipairs(toUpdate) do
            MySQL.update(
                "UPDATE `p_policejob_prison_sentences` SET `remaining_time` = ? WHERE `id` = ?",
                { entry.remaining, entry.id }
            )
        end
    end
end)

-- ─── Shop Purchase Handler ────────────────────────────────────────────────────

-- Shared purchase flow: validates funds → removes cash → adds item → checks it was added
local function ProcessShopPurchase(playerSource, itemName, quantity, totalPrice, shopLabel)
    local money = Bridge.Framework.getMoney(playerSource)
    local cash  = (money and money.money) or 0

    if totalPrice > cash then
        Bridge.Notify.showNotify(playerSource,
            locale("prison_shop_not_enough_money", totalPrice), "error")
        return
    end

    local countBefore = Bridge.Inventory.getItemCount(playerSource, itemName) or 0

    Bridge.Framework.removeMoney(playerSource, "cash", totalPrice)
    Bridge.Inventory.addItem(playerSource, itemName, quantity)

    local countAfter = Bridge.Inventory.getItemCount(playerSource, itemName) or 0

    if countAfter <= countBefore then
        -- Item wasn't added — refund and report
        Bridge.Framework.addMoney(playerSource, "cash", totalPrice)
        Bridge.Notify.showNotify(playerSource,
            locale("prison_shop_purchase_failed", itemName), "error")
        print(string.format(
            "[^1ERROR^7] [Prison] %s purchase failed: item '%s' was not added to player %s's inventory.",
            shopLabel, itemName, playerSource))
        return
    end

    Bridge.Notify.showNotify(playerSource,
        locale("prison_shop_purchased", quantity, itemName), "success")
end

-- Validates an item exists in a shop config list with the correct price
local function ValidateShopItem(shopItems, itemName, requestedPrice)
    for _, item in ipairs(shopItems) do
        if item.name == itemName and item.price == tonumber(requestedPrice) then
            return true
        end
    end
    return false
end

RegisterNetEvent("p_policejob/server/prison/commissary/buy", function(payload)
    local playerSource = source
    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end
    if not Prison.sentences[uniqueId] then return end
    if not (payload and payload.item and payload.price) then return end

    local quantity   = math.max(1, math.min(10, tonumber(payload.quantity) or 1))
    local totalPrice = tonumber(payload.price) * quantity

    if not ValidateShopItem(Config.Prison.Commissary.items, payload.item, payload.price) then return end

    ProcessShopPurchase(playerSource, payload.item, quantity, totalPrice, "Commissary")
end)

RegisterNetEvent("p_policejob/server/prison/illegalshop/buy", function(payload)
    local playerSource = source
    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end
    if not Prison.sentences[uniqueId] then return end
    if not (payload and payload.item and payload.price) then return end

    local quantity   = math.max(1, math.min(10, tonumber(payload.quantity) or 1))
    local totalPrice = tonumber(payload.price) * quantity

    if not ValidateShopItem(Config.Prison.IllegalShop.items, payload.item, payload.price) then return end

    ProcessShopPurchase(playerSource, payload.item, quantity, totalPrice, "Illegal shop")
end)

-- ─── NPC Trade (buy from NPC) ─────────────────────────────────────────────────

RegisterNetEvent("p_policejob/server/prison/npc_trade/buy", function(payload)
    local playerSource = source
    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end
    if not Prison.sentences[uniqueId] then return end
    if not (payload and payload.item and payload.price and payload.npcIndex) then return end

    -- Validate item exists in the NPC's tradeItems list
    local npcData  = Prison.Map and Prison.Map.npcs and Prison.Map.npcs[payload.npcIndex]
    if not (npcData and npcData.tradeItems) then return end

    local quantity   = math.max(1, math.min(10, tonumber(payload.quantity) or 1))
    local totalPrice = tonumber(payload.price) * quantity

    if not ValidateShopItem(npcData.tradeItems, payload.item, payload.price) then return end

    ProcessShopPurchase(playerSource, payload.item, quantity, totalPrice, "NPC trade")
end)

-- ─── NPC Barter Trade ────────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/server/prison/npc_trade/execute", function(payload)
    local playerSource = source
    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end
    if not Prison.sentences[uniqueId] then return end

    if not (payload and payload.npcIndex and payload.offeredItems and payload.requestedItem) then return end

    local npcData = Prison.Map and Prison.Map.npcs
        and Prison.Map.npcs[payload.npcIndex]
    if not (npcData and npcData.tradeItems) then return end

    -- Find the requested item in the NPC's list
    local requestedDef = nil
    for _, item in ipairs(npcData.tradeItems) do
        if item.name == payload.requestedItem then
            requestedDef = item
            break
        end
    end
    if not requestedDef then return end

    -- Calculate offered value and check quantities
    local offeredValue = 0
    for _, offered in ipairs(payload.offeredItems) do
        local count = Bridge.Inventory.getItemCount(playerSource, offered.name)
        if count < offered.quantity then
            Bridge.Notify.showNotify(playerSource, "You don't have enough items", "error")
            return
        end
        offeredValue = offeredValue + 5 * offered.quantity
    end

    if offeredValue < requestedDef.price then
        Bridge.Notify.showNotify(playerSource, "Your offer is not valuable enough", "error")
        return
    end

    -- Consume offered items and give the requested one
    for _, offered in ipairs(payload.offeredItems) do
        Bridge.Inventory.removeItem(playerSource, offered.name, offered.quantity)
    end
    Bridge.Inventory.addItem(playerSource, requestedDef.name, 1)

    Bridge.Notify.showNotify(playerSource,
        "Trade successful! You received " .. (requestedDef.label or requestedDef.name),
        "success")
end)

-- ─── Player-to-Player Trade ───────────────────────────────────────────────────

lib.callback.register("p_policejob/server/prison/getTradeItems", function(playerSource)
    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return {} end
    if not Prison.sentences[uniqueId] then return {} end

    local items    = Bridge.Inventory.getPlayerItems and Bridge.Inventory.getPlayerItems(playerSource)
    if not items then return {} end

    local result = {}
    for _, item in ipairs(items) do
        local count = item.count or item.amount or 0
        if count > 0 then
            result[#result + 1] = {
                name  = item.name,
                label = item.label or item.name,
                count = count,
                value = 5,
            }
        end
    end

    return result
end)

RegisterNetEvent("p_policejob/server/prison/trade/send", function(payload)
    local playerSource = source
    local uniqueId     = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end
    if not Prison.sentences[uniqueId] then return end

    if not (payload and payload.targetId and payload.items) then return end

    local targetId = tonumber(payload.targetId)
    if not (targetId and targetId >= 1) then return end

    local targetUniqueId = Bridge.Framework.getUniqueId(targetId)
    if not targetUniqueId then return end
    if not Prison.sentences[targetUniqueId] then
        Bridge.Notify.showNotify(playerSource, "That player is not in prison", "error")
        return
    end

    for _, item in ipairs(payload.items) do
        local name     = tostring(item.name)
        local quantity = math.max(1, math.min(100, tonumber(item.quantity) or 0))
        local have     = Bridge.Inventory.getItemCount(playerSource, name) or 0

        if quantity > 0 and quantity <= have then
            Bridge.Inventory.removeItem(playerSource, name, quantity)
            Bridge.Inventory.addItem(targetId, name, quantity)
        end
    end

    Bridge.Notify.showNotify(playerSource, "Trade sent!", "success")
    Bridge.Notify.showNotify(targetId,     "You received items from a trade", "info")
end)

-- ─── Jail Locker ─────────────────────────────────────────────────────────────

local registeredJailLockers = {}

-- Returns the stash id for a citizen's jail locker, registering it if needed
local function GetOrRegisterJailLockerStash(citizenId)
    local lockerCfg = Config.Prison.JailLocker
    local prefix    = lockerCfg.stashPrefix or "p_policejob_jail_locker"
    local stashId   = string.format("%s_%s", prefix, citizenId)

    if not registeredJailLockers[stashId] then
        registeredJailLockers[stashId] = true
        if Bridge.Inventory.registerStash then
            Bridge.Inventory.registerStash(stashId, locale("jail_locker"),
                lockerCfg.slots     or 50,
                lockerCfg.maxWeight or 500000)
        end
    end

    return stashId
end

local function PlayerHasLockerAccess(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job or not job.name then return false end
    local threshold = Config.Jobs[job.name]
    if threshold == nil then return false end
    return (job.grade or 0) >= threshold
end

lib.callback.register("p_policejob/server/prison/jailLocker/getById", function(playerSource, citizenId)
    local lockerCfg = Config.Prison.JailLocker
    if not (lockerCfg and lockerCfg.enabled) then return nil end
    if not PlayerHasLockerAccess(playerSource) then return nil end

    citizenId = tostring(citizenId or ""):gsub("%s+", ""):sub(1, 64)
    if citizenId == "" then return nil end

    -- Verify the citizen exists
    if not (Bridge.Framework.getPlayerByUniqueId and Bridge.Framework.getPlayerByUniqueId(citizenId)) then
        return nil
    end

    if Config.Webhooks and Config.Webhooks.locker and Config.Webhooks.locker ~= "" then
        Bridge.Logs.Send(playerSource, "Jail Locker",
            string.format("Opened jail locker of citizen %s", citizenId),
            Config.Webhooks.locker)
    end

    return GetOrRegisterJailLockerStash(citizenId)
end)

lib.callback.register("p_policejob/server/prison/jailLocker/getOwn", function(playerSource)
    local lockerCfg = Config.Prison.JailLocker
    if not (lockerCfg and lockerCfg.enabled) then return nil end

    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return nil end

    return GetOrRegisterJailLockerStash(uniqueId)
end)

-- ─── processJailItems ────────────────────────────────────────────────────────

-- Handles item confiscation on jail entry (locker / wipe based on config)
function Prison:processJailItems(playerSource, uniqueId)
    local lockerCfg = Config.Prison.JailLocker
    if not (lockerCfg and lockerCfg.enabled) then return end
    if lockerCfg.onJail ~= "locker" and lockerCfg.onJail ~= "wipe" then return end

    local items = Bridge.Inventory.getPlayerItems and Bridge.Inventory.getPlayerItems(playerSource)
    if not items then return end

    local keepItems  = lockerCfg.keepItems or {}
    local lockerStash = lockerCfg.onJail == "locker"
        and GetOrRegisterJailLockerStash(uniqueId)
        or nil

    for _, item in pairs(items) do
        local count = tonumber(item.count or item.amount) or 0
        if item.name and count > 0 and not keepItems[item.name] then
            if lockerStash then
                Bridge.Inventory.addItem(lockerStash,  item.name, count, item.metadata or item.info)
            end
            Bridge.Inventory.removeItem(playerSource, item.name, count, nil, item.slot)
        end
    end

    if lockerStash then
        Bridge.Notify.showNotify(playerSource, locale("jail_locker_items_moved"), "inform")
    end
end

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("sendToJail", function(officerSource, targetSource, minutes, reason, isCommunityService)
    return Prison:sendToJail(officerSource, targetSource, minutes, reason, isCommunityService)
end)

exports("releasePrisoner", function(uniqueId)
    return Prison:releasePrisoner(uniqueId)
end)

exports("EscapeJail", function(sourceOrUniqueId)
    local id = sourceOrUniqueId
    if type(id) == "number" then
        id = Bridge.Framework.getUniqueId(sourceOrUniqueId) or id
    end
    if not id then return false end
    return Prison:escapeJail(id)
end)

exports("reduceSentence", function(uniqueId, minutes)
    return Prison:reduceSentence(uniqueId, minutes * 60)
end)

exports("increaseSentence", function(uniqueId, minutes)
    return Prison:increaseSentence(uniqueId, minutes * 60)
end)

exports("isPlayerInPrison", function(playerSource)
    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return false end
    return Prison.sentences[uniqueId] ~= nil
end)

exports("getAllPrisoners", function()
    return Prison.sentences
end)

exports("getPrisonerInfo", function(sourceOrUniqueId)
    local id = sourceOrUniqueId
    if type(id) == "number" then
        id = Bridge.Framework.getUniqueId(id) or id
    end
    if not id then return nil end
    return Prison.sentences[id]
end)

-- Returns remaining minutes; 99999 for life; 0 if not jailed
local function GetRemainingMinutes(sourceOrUniqueId)
    local id = sourceOrUniqueId
    if type(id) == "number" then
        id = Bridge.Framework.getUniqueId(id) or id
    end
    if not id then return 0 end

    local sentence = Prison.sentences[id]
    if not (sentence and sentence.status == "active") then return 0 end
    if sentence.isLife then return 99999 end

    return math.ceil(math.max(0, Prison:sentenceRemaining(sentence)) / 60)
end

exports("getRemainingTime", function(sourceOrUniqueId)
    local id = sourceOrUniqueId
    if type(id) == "number" then
        id = Bridge.Framework.getUniqueId(id) or id
    end
    if not id then return 0 end

    local sentence = Prison.sentences[id]
    if not (sentence and sentence.status == "active") then return 0 end
    if sentence.isLife then return -1 end

    return math.max(0, Prison:sentenceRemaining(sentence))
end)

exports("GetJailedPlayers", function()
    local result = {}
    for uniqueId, sentence in pairs(Prison.sentences) do
        if sentence.status == "active" then
            local mins = -1
            if not sentence.isLife then
                local releaseAt = sentence.releaseAt or 0
                if releaseAt > 0 then
                    mins = math.ceil(math.max(0, Prison:sentenceRemaining(sentence)) / 60)
                end
            end

            local jailedAt = nil
            if sentence.releaseAt and sentence.releaseAt > 0 then
                local st = sentence.sentenceTime or 0
                if st > 0 then jailedAt = sentence.releaseAt - st end
            end

            result[#result + 1] = {
                cid             = uniqueId,
                name            = sentence.playerName,
                reason          = sentence.reason,
                offenses        = { sentence.reason },
                minutesLeft     = mins,
                isLife          = sentence.isLife or false,
                isCommunityService = sentence.isCommunityService or false,
                cellId          = sentence.cellId,
                jailedBy        = sentence.officerName,
                jailedAt        = jailedAt,
            }
        end
    end
    return result
end)

exports("getPlayerJudgment",  GetRemainingMinutes)
exports("IsPlayerInJail",     GetRemainingMinutes)

AddEventHandler("__cfx_export_wasabi_police_IsPlayerInJail", function(cb)
    cb(GetRemainingMinutes)
end)

-- ─── JailPlayer / JailPlayers / UnJailPlayer / ShortenJailPlayer ─────────────

-- Resolves a player identifier (server id, unique id string, or table) to a source number
local function ResolvePlayerSource(idOrUniqueId)
    if type(idOrUniqueId) == "table" then
        idOrUniqueId = idOrUniqueId.identifier or idOrUniqueId.player
    end

    if type(idOrUniqueId) == "number" then return idOrUniqueId end

    if type(idOrUniqueId) == "string" then
        local num = tonumber(idOrUniqueId)
        if num then return num end

        local playerObj = Bridge.Framework.getPlayerByUniqueId(idOrUniqueId)
        return playerObj and (playerObj.source or (playerObj.PlayerData and playerObj.PlayerData.source))
    end

    return nil
end

-- Internal: jails one player given the officer source, a player id, and a data table
local function JailOnePlayer(officerSource, playerId, data)
    local playerSource = ResolvePlayerSource(playerId)
    if not playerSource then return false, "invalid_target" end

    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return false, "player_not_found" end

    local existing = Prison.sentences[uniqueId]
    if existing and existing.status == "active" then return false, "already_jailed" end

    local minutes    = tonumber(data.jail) or 0
    local isLife     = data.lifeSentence == true
    local isCS       = data.communityService == true
    local reason     = data.reason or "Unknown"

    if minutes <= 0 and not isLife then return false, "invalid_sentence" end

    local ok = Prison:sendToJail(officerSource, playerSource,
        isLife and 0 or minutes, reason, isCS, { lifeSentence = isLife })

    if not ok then return false, "failed" end

    local fine = tonumber(data.fine) or 0
    if fine > 0 then
        Bridge.Framework.removeMoney(playerSource, "bank", fine)
    end

    return true, "jailed"
end

exports("JailPlayer", function(officerSource, data)
    if type(data) ~= "table" or not data.player then return false, "invalid_data" end
    return JailOnePlayer(officerSource, data.player, data)
end)

exports("JailPlayers", function(officerSource, data)
    if type(data) ~= "table" or type(data.players) ~= "table" then
        return false, "invalid_data"
    end

    local succeeded = 0
    local lastError = "invalid_data"

    for _, playerId in ipairs(data.players) do
        local ok, err = JailOnePlayer(officerSource, playerId, data)
        if ok then succeeded = succeeded + 1 else lastError = err end
    end

    if succeeded == 0 then return false, lastError end
    return true, string.format("jailed_%d", succeeded)
end)

exports("UnJailPlayer", function(officerSource, targetIdOrUniqueId)
    targetIdOrUniqueId = tonumber(targetIdOrUniqueId) or targetIdOrUniqueId

    local uniqueId = targetIdOrUniqueId
    if type(uniqueId) == "number" then
        uniqueId = Bridge.Framework.getUniqueId(uniqueId)
    end

    if not uniqueId then return false, "player_not_found" end

    local sentence = Prison.sentences[uniqueId]
    if not (sentence and sentence.status == "active") then return false, "not_jailed" end

    local ok = Prison:releasePrisoner(uniqueId, officerSource)
    return ok and true or false, ok and "released" or "failed"
end)

exports("ShortenJailPlayer", function(officerSource, targetIdOrUniqueId, minutes)
    minutes = tonumber(minutes)
    if not minutes or minutes <= 0 then return false, "invalid_amount" end

    targetIdOrUniqueId = tonumber(targetIdOrUniqueId) or targetIdOrUniqueId

    local uniqueId = targetIdOrUniqueId
    if type(uniqueId) == "number" then
        uniqueId = Bridge.Framework.getUniqueId(uniqueId)
    end

    if not uniqueId then return false, "player_not_found" end

    local sentence = Prison.sentences[uniqueId]
    if not (sentence and sentence.status == "active") then return false, "not_jailed" end
    if sentence.isLife then return false, "life_sentence" end

    local ok = Prison:reduceSentence(uniqueId, minutes * 60)
    return ok and true or false, ok and "shortened" or "failed"
end)

-- ─── Admin Commands ───────────────────────────────────────────────────────────

-- Sentence time formatter for the /prisoners and /jailtime commands
local function FormatSentenceTime(sentence)
    if sentence.isLife then return "LIFE" end
    local remaining = math.max(0, Prison:sentenceRemaining(sentence))
    return string.format("%dm", math.ceil(remaining / 60))
end

local commandsCfg = Config.Prison.Commands
if commandsCfg and commandsCfg.enabled then
    local restricted = commandsCfg.restricted
    if restricted == nil then restricted = "group.admin" end

    if commandsCfg.jail and commandsCfg.jail.enabled then
        lib.addCommand(commandsCfg.jail.name or "jail", {
            help       = "Send a player to jail",
            params     = {
                { name = "id",     type = "number", help = "Player server ID" },
                { name = "type",   type = "string", help = "Sentence type: 'prison', 'community' or 'life'", optional = true },
                { name = "length", type = "number", help = "Sentence length in minutes (ignored for life)", optional = true },
                { name = "reason", type = "string", help = "Reason for jailing", optional = true },
            },
            restricted = restricted,
        }, function(playerSource, args)
            local sentenceType = tostring(args.type or "prison"):lower()
            local reason       = args.reason or "Admin action"

            if sentenceType ~= "prison" and sentenceType ~= "community" and sentenceType ~= "life" then
                return Bridge.Notify.showNotify(playerSource,
                    "Invalid type. Use 'prison', 'community' or 'life'.", "error")
            end

            local isLife = sentenceType == "life"
            local isCS   = sentenceType == "community"

            if not isLife and (not args.length or args.length <= 0) then
                return Bridge.Notify.showNotify(playerSource,
                    "You must provide a sentence length (minutes).", "error")
            end

            local uniqueId = Bridge.Framework.getUniqueId(args.id)
            if not uniqueId then
                return Bridge.Notify.showNotify(playerSource, locale("player_not_found"), "error")
            end

            Prison:sendToJail(playerSource, args.id,
                isLife and 0 or args.length,
                reason, isCS, { lifeSentence = isLife })
        end)
    end

    if commandsCfg.unjail and commandsCfg.unjail.enabled then
        lib.addCommand(commandsCfg.unjail.name or "unjail", {
            help       = "Release a prisoner by their server ID",
            params     = { { name = "id", type = "number", help = "Player server ID" } },
            restricted = restricted,
        }, function(playerSource, args)
            local uniqueId = Bridge.Framework.getUniqueId(args.id)
            if not uniqueId then
                return Bridge.Notify.showNotify(playerSource, locale("player_not_found"), "error")
            end

            local ok = Prison:releasePrisoner(uniqueId, playerSource)
            if ok then
                Bridge.Notify.showNotify(playerSource, locale("prison_prisoner_released"), "success")
            else
                Bridge.Notify.showNotify(playerSource, locale("prison_inmate_not_found"), "error")
            end
        end)
    end

    if commandsCfg.jailtime and commandsCfg.jailtime.enabled then
        lib.addCommand(commandsCfg.jailtime.name or "jailtime", {
            help       = "Show the remaining sentence for a player",
            params     = { { name = "id", type = "number", help = "Player server ID (defaults to you)", optional = true } },
            restricted = restricted,
        }, function(playerSource, args)
            local targetSource = args.id or playerSource
            local uniqueId     = Bridge.Framework.getUniqueId(targetSource)
            local sentence     = uniqueId and Prison.sentences[uniqueId]

            if not (sentence and sentence.status == "active") then
                return Bridge.Notify.showNotify(playerSource, locale("prison_inmate_not_found"), "error")
            end

            local name = sentence.playerName or tostring(targetSource)
            Bridge.Notify.showNotify(playerSource,
                string.format("%s: %s", name, FormatSentenceTime(sentence)), "inform")
        end)
    end

    if commandsCfg.prisoners and commandsCfg.prisoners.enabled then
        lib.addCommand(commandsCfg.prisoners.name or "prisoners", {
            help       = "List every currently jailed player",
            params     = {},
            restricted = restricted,
        }, function(playerSource)
            local lines = {}
            for _, sentence in pairs(Prison.sentences) do
                if sentence.status == "active" then
                    lines[#lines + 1] = string.format("%s (%s) - %s",
                        sentence.playerName or "?",
                        sentence.isCommunityService and "community" or "prison",
                        FormatSentenceTime(sentence))
                end
            end

            if #lines == 0 then
                return Bridge.Notify.showNotify(playerSource, "There are no prisoners right now.", "inform")
            end

            Bridge.Notify.showNotify(playerSource, table.concat(lines, "\n"), "inform")
        end)
    end
end

-- ─── Misc Admin Commands ─────────────────────────────────────────────────────

lib.addCommand("jailself", {
    help       = "Send yourself to jail (admin)",
    params     = {
        { name = "time",   type = "number", help = "Sentence time in minutes" },
        { name = "reason", type = "string", help = "Reason for jailing", optional = true },
    },
    restricted = "group.admin",
}, function(playerSource, args)
    local ok = Prison:sendToJail(playerSource, playerSource, args.time,
        args.reason or "Admin self-jail", false)
    if ok then
        Bridge.Notify.showNotify(playerSource,
            locale("prison_player_sent", "yourself"), "success")
    end
end)

lib.addCommand("prisonmanagement", {
    help       = "Open prison management panel",
    params     = {},
    restricted = false,
}, function(playerSource)
    TriggerClientEvent("p_policejob/client/prison/openManagement", playerSource)
end)
