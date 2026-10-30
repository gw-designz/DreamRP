if not (Config and Config.DrugTestKit and Config.DrugTestKit.enabled) then return end

-- Global DrugTestKit object shared across the resource
DrugTestKit = {}

-- pendingConsents[targetServerId] = officerServerId
-- Tracks which officer has requested consent from which target
local pendingConsents = {}

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Returns true if the given server source has an authorised job/grade to use the kit
local function PlayerHasDrugTestAccess(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not (job and job.name) then return false end

    local jobEntry = Config.Jobs[job.name]
    if jobEntry == nil  then return false end
    if jobEntry == true then return true  end

    local playerGrade   = job.grade or 0
    local requiredGrade = tonumber(jobEntry) or 0
    return playerGrade >= requiredGrade
end

-- Normalises any raw result value from getDrugTestResults into a standard table:
--   { positive, substances, details }
local function NormaliseTestResult(rawResult)
    local out = { positive = false, substances = {}, details = {} }

    local resultType = type(rawResult)

    if resultType == "boolean" then
        out.positive = rawResult

    elseif resultType == "string" and rawResult ~= "" then
        out.positive = true
        out.substances = { rawResult }

    elseif resultType == "table" then
        out.positive = (rawResult.positive == true)

        -- Normalise substance list (accepts .substances table or single .substance string)
        if type(rawResult.substances) == "table" then
            for _, s in ipairs(rawResult.substances) do
                if type(s) == "string" and s ~= "" then
                    out.substances[#out.substances + 1] = s
                end
            end
        elseif type(rawResult.substance) == "string" and rawResult.substance ~= "" then
            out.substances = { rawResult.substance }
        end

        if type(rawResult.details) == "table" then
            out.details = rawResult.details
        end

        -- Implicitly positive if any substances were found
        if not out.positive and #out.substances > 0 then
            out.positive = true
        end
    end

    return out
end

-- ─── DrugTestKit Methods ─────────────────────────────────────────────────────

-- Initiates an officer-initiated drug test.
-- If requireConsent is on and targetServerId differs from officerSource, prompts consent first.
function DrugTestKit:use(officerSource, targetServerId)
    if not PlayerHasDrugTestAccess(officerSource) then
        Bridge.Notify.showNotify(officerSource, locale("no_access_drug_test_kit"), "error")
        return
    end

    local targetId = tonumber(targetServerId)

    if targetId and targetId ~= officerSource then
        if Config.DrugTestKit.requireConsent then
            -- Resolve officer display name for consent prompt
            local officerName = (Bridge.Framework.getPlayerName and Bridge.Framework.getPlayerName(officerSource))
                or ("ID " .. tostring(officerSource))

            Bridge.Notify.showNotify(officerSource, locale("test_request_sent"), "inform")

            local accepted = lib.callback.await("p_policejob/client/drugtest/requestConsent", targetId, officerName)
            if not accepted then
                return Bridge.Notify.showNotify(officerSource, locale("drug_test_declined"), "error")
            end
        end
    end

    TriggerClientEvent("p_policejob/client/drugtest/open", officerSource, targetServerId)
end

-- Runs the actual drug test: validates proximity, calls getDrugTestResults,
-- notifies the target (if configured), and returns the normalised result.
function DrugTestKit:startTest(officerSource, targetServerId)
    if not PlayerHasDrugTestAccess(officerSource) then
        Bridge.Notify.showNotify(officerSource, locale("no_access_drug_test_kit"), "error")
        return nil
    end

    local isInRange = Editable:canInteract(officerSource, targetServerId, Config.DrugTestKit.maxDistance)
    if not isInRange then
        Bridge.Notify.showNotify(officerSource, locale("no_player_nearby"), "error")
        return nil
    end

    Config.DrugTestKit.onTestStart_Server(officerSource, targetServerId)

    -- Notify target that a test has started (if enabled and target differs from officer)
    local targetId = tonumber(targetServerId)
    if Config.DrugTestKit.notifyTarget and targetId and targetId ~= officerSource then
        Bridge.Notify.showNotify(targetId, locale("drug_test_target_started"), "inform")
    end

    -- Call the configured result provider (pcall for safety)
    local ok, rawResult = pcall(Config.DrugTestKit.getDrugTestResults, targetServerId, officerSource)
    if not ok then
        Bridge.Debug(string.format("[DrugTestKit] getDrugTestResults failed: %s", rawResult))
        rawResult = { positive = false, substances = {}, details = { error = "integration_failed" } }
    end

    local result = NormaliseTestResult(rawResult)

    Config.DrugTestKit.onTestComplete_Server(officerSource, targetServerId, result)

    -- Notify target of outcome (if enabled and target differs from officer)
    if Config.DrugTestKit.notifyTarget and targetId and targetId ~= officerSource then
        local notifyMsg  = result.positive and locale("drug_test_target_positive") or locale("drug_test_target_negative")
        local notifyType = result.positive and "error" or "success"
        Bridge.Notify.showNotify(targetId, notifyMsg, notifyType)
    end

    return result
end

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("useDrugTestKitItem", function(officerSource, targetServerId)
    DrugTestKit:use(officerSource, targetServerId)
end)

-- ox_inventory / item hook: called when the drug_test_kit item is used
exports("drug_test_kit", function(action, _, itemData)
    if action == "usingItem" then
        DrugTestKit:use(itemData.id)
    end
end)

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Client → server: player used the kit via a server event
RegisterNetEvent("p_policejob/server/drugtest/use", function(targetServerId)
    DrugTestKit:use(source, targetServerId)
end)

-- Client → server: officer requested consent from a target
RegisterNetEvent("p_policejob/server/drugtest/requestConsent", function(targetServerId)
    local officerSource = source
    if not PlayerHasDrugTestAccess(officerSource) then return end

    local targetId = tonumber(targetServerId)
    if not targetId then
        return Bridge.Notify.showNotify(officerSource, locale("no_player_nearby"), "error")
    end

    local isInRange = Editable:canInteract(officerSource, targetId, Config.DrugTestKit.maxDistance)
    if not isInRange then
        return Bridge.Notify.showNotify(officerSource, locale("no_player_nearby"), "error")
    end

    -- If consent is not required, or testing self, immediately approve
    if targetId == officerSource or not Config.DrugTestKit.requireConsent then
        return TriggerClientEvent("p_policejob/client/drugtest/consentResult", officerSource, targetId, true)
    end

    pendingConsents[targetId] = officerSource

    local officerName = (Bridge.Framework.getPlayerName and Bridge.Framework.getPlayerName(officerSource))
        or ("ID " .. tostring(officerSource))

    Bridge.Notify.showNotify(officerSource, locale("test_request_sent"), "inform")
    TriggerClientEvent("p_policejob/client/drugtest/consentPrompt", targetId, officerName)
end)

-- Client → server: the target responded to the consent dialog
RegisterNetEvent("p_policejob/server/drugtest/consentResponse", function(accepted)
    local targetSource  = source
    local officerSource = pendingConsents[targetSource]
    if not officerSource then return end

    pendingConsents[targetSource] = nil
    TriggerClientEvent("p_policejob/client/drugtest/consentResult", officerSource, targetSource, accepted == true)
end)

-- Clean up consent records when either party disconnects
AddEventHandler("playerDropped", function()
    local droppedSource = source

    -- If they were a pending target
    pendingConsents[droppedSource] = nil

    -- If they were a pending officer, clear any target waiting on them
    for targetId, officerId in pairs(pendingConsents) do
        if officerId == droppedSource then
            pendingConsents[targetId] = nil
        end
    end
end)

-- ─── Callbacks ───────────────────────────────────────────────────────────────

-- Called by the client progress-bar flow to run the test server-side
lib.callback.register("p_policejob/server/drugtest/start", function(officerSource, targetServerId)
    return DrugTestKit:startTest(officerSource, targetServerId)
end)

-- ─── Drug Detection System ────────────────────────────────────────────────────

-- Global detection tracker; other resources can record drug consumption here.
DrugTestDetection = { consumed = {} }

local detectionConfig = Config.DrugTestKit.Detection or {}

-- Records that a player consumed a substance, with an expiry window.
-- playerSource: server id (or unique id string)
-- substance:    drug name string
-- windowMinutes: optional override for how long it stays detectable
function DrugTestDetection:record(playerSource, substance, windowMinutes)
    if type(substance) ~= "string" or substance == "" then return end

    local uniqueId = Bridge.Framework.getUniqueId(playerSource)
    if not uniqueId then return end

    local minutes = tonumber(windowMinutes) or detectionConfig.windowMinutes or 20
    local expiresAt = math.floor(os.time() + minutes * 60)

    if not self.consumed[uniqueId] then
        self.consumed[uniqueId] = {}
    end

    -- Only extend the window, never shorten it
    if not self.consumed[uniqueId][substance] or expiresAt > self.consumed[uniqueId][substance] then
        self.consumed[uniqueId][substance] = expiresAt
    end
end

-- Returns a normalised result table for the given player, pruning expired substances.
-- Also optionally checks esx_status for a residual drug value.
function DrugTestDetection:getResults(targetServerId)
    local substances = {}

    local uniqueId = Bridge.Framework.getUniqueId(
        tonumber(targetServerId) or targetServerId
    )

    local playerRecord = uniqueId and self.consumed[uniqueId]

    if playerRecord then
        local now = os.time()
        for substance, expiresAt in pairs(playerRecord) do
            if expiresAt > now then
                substances[#substances + 1] = substance
            else
                playerRecord[substance] = nil
            end
        end
    end

    -- Fallback: check esx_status "drug" value if no substances found and integration is on
    if #substances == 0 and detectionConfig.checkEsxStatus ~= false then
        if GetResourceState("esx_status") == "started" then
            TriggerEvent("esx_status:getStatus", tonumber(targetServerId), "drug", function(status)
                if status then
                    local val = tonumber(status.val) or 0
                    if val > 0 then
                        substances[#substances + 1] = "Narcotics (unspecified)"
                    end
                end
            end)
        end
    end

    table.sort(substances)

    return {
        positive   = #substances > 0,
        substances = substances,
        details    = {
            sample = "Saliva",
            window = string.format("%d min", detectionConfig.windowMinutes or 20),
        },
    }
end

-- ─── Detection Event Hooks ────────────────────────────────────────────────────

-- Helper shared by all three recording hooks below
local function HandleItemUsed(playerSource, itemName)
    if detectionConfig.trackItemUse == false then return end

    local trackedItems = detectionConfig.items or {}
    local substance    = trackedItems[itemName]
    if substance then
        DrugTestDetection:record(playerSource, substance)
    end
end

-- ox_inventory: item was used
AddEventHandler("ox_inventory:usedItem", function(playerSource, itemName)
    HandleItemUsed(playerSource, tostring(itemName))
end)

-- ESX: item was used
RegisterNetEvent("esx:useItem", function(itemName)
    HandleItemUsed(source, tostring(itemName))
end)

-- QBCore / custom: item used event forwarded from client
RegisterNetEvent("p_policejob/server/drugtest/itemUsed", function(itemName)
    HandleItemUsed(source, tostring(itemName))
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

-- Other resources can register a drug consumption event
exports("RegisterDrugConsumption", function(playerSource, substance, windowMinutes)
    DrugTestDetection:record(playerSource, substance, windowMinutes)
end)

-- Internal event alias for the same purpose
AddEventHandler("p_policejob:drugConsumed", function(playerSource, substance, windowMinutes)
    DrugTestDetection:record(playerSource, substance, windowMinutes)
end)
