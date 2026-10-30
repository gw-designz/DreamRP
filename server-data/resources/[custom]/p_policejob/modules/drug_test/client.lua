-- Wait for Config.DrugTestKit to be available
while not (Config and Config.DrugTestKit) do Citizen.Wait(500) end

if not Config.DrugTestKit.enabled then return end

-- Global DrugTestKit object shared across the resource
DrugTestKit = {}
DrugTestKit.isOpen          = false
DrugTestKit.targetId        = nil
DrugTestKit.awaitingConsent = false

-- ─── QBCore item-use tracking (optional) ─────────────────────────────────────
-- When running on QBCore, listen for item-use events so consumed drugs are
-- reported to the server's detection window.

local detectionConfig = Config.DrugTestKit.Detection
if detectionConfig and detectionConfig.trackItemUse ~= false then
    if GetResourceState("qb-core") == "started" then
        RegisterNetEvent("inventory:client:ItemBox", function(itemData, action)
            if action ~= "use" then return end

            local itemName = (type(itemData) == "table") and (itemData.name or itemData.item) or nil
            if type(itemName) ~= "string" then return end

            local trackedItems = (detectionConfig.items or {})
            if not trackedItems[itemName] then return end

            TriggerServerEvent("p_policejob/server/drugtest/itemUsed", itemName)
        end)
    end
end

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Shows the consent dialog to the local player and returns true if they accepted
local function ShowConsentDialog(officerName)
    local contentTemplate = locale("drug_test_consent_content")
    local result = lib.alertDialog({
        header  = locale("drug_test_consent_header"),
        content = contentTemplate:format(officerName or "?"),
        centered = true,
        cancel   = true,
        labels   = {
            confirm = locale("drug_test_consent_accept"),
            cancel  = locale("drug_test_consent_decline"),
        },
    })
    return result == "confirm"
end

-- Returns true if the local player's job and grade allow using the drug test kit
local function LocalPlayerHasAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    if not (job and job.name) then return false end

    local jobEntry = Config.Jobs[job.name]
    if jobEntry == nil   then return false end
    if jobEntry == true  then return true  end

    local playerGrade   = job.grade or 0
    local requiredGrade = tonumber(jobEntry) or 0
    return playerGrade >= requiredGrade
end

-- ─── DrugTestKit Methods ──────────────────────────────────────────────────────

-- Returns the closest player's server id (excluding self), or nil if none in range
function DrugTestKit:getClosestTarget()
    local pedCoords    = GetEntityCoords(cache.ped)
    local maxDistance  = Config.DrugTestKit.maxDistance
    local localHandle  = lib.getClosestPlayer(pedCoords, maxDistance, false)

    if not localHandle or localHandle == 0 then return nil end

    local serverId = GetPlayerServerId(localHandle)
    if serverId == cache.serverId then return nil end

    return serverId
end

-- Returns the display name for a given server id, falling back to "ID <n>"
function DrugTestKit:getTargetName(targetServerId)
    local localHandle = GetPlayerFromServerId(targetServerId)
    if localHandle and localHandle ~= -1 then
        local name = GetPlayerName(localHandle)
        if name and name ~= "" then return name end
    end
    return string.format("ID %s", targetServerId)
end

-- Opens the drug test kit NUI, optionally targeting a specific server id
function DrugTestKit:open(targetServerId)
    if not LocalPlayerHasAccess() then
        return Bridge.Notify.showNotify(locale("no_access_drug_test_kit"), "error")
    end

    local resolvedId = targetServerId or self:getClosestTarget()
    if not resolvedId then
        return Bridge.Notify.showNotify(locale("no_player_nearby"), "error")
    end

    self.targetId = resolvedId
    self.isOpen   = true

    Config.DrugTestKit.onOpen(self.targetId)

    local officerName = GetPlayerName(PlayerId()) or string.format("ID %s", cache.serverId)

    SendNUIMessage({
        action = "setDrugTestKitData",
        data   = {
            status       = "idle",
            officerName  = officerName,
            targetId     = self.targetId,
            targetName   = self:getTargetName(self.targetId),
            positive     = false,
            substances   = {},
            details      = {},
            testDuration = Config.DrugTestKit.testDuration or 6000,
        },
    })
    SendNUIMessage({ action = "setVisibleDrugTestKit", data = true })
    SetNuiFocus(true, true)
end

-- Closes the drug test kit NUI and clears state
function DrugTestKit:close()
    if not self.isOpen then return end

    Config.DrugTestKit.onClose(self.targetId)

    self.isOpen   = false
    self.targetId = nil
    SendNUIMessage({ action = "setVisibleDrugTestKit", data = false })
    SetNuiFocus(false, false)
end

-- Initiates a drug test on the given server id (consent-first flow)
function DrugTestKit:runTargetTest(targetServerId)
    if not LocalPlayerHasAccess() then
        return Bridge.Notify.showNotify(locale("no_access_drug_test_kit"), "error")
    end

    local resolvedId = tonumber(targetServerId)
    if not resolvedId then
        return Bridge.Notify.showNotify(locale("no_player_nearby"), "error")
    end

    if self.awaitingConsent then
        return Bridge.Notify.showNotify(locale("drug_test_pending"), "error")
    end

    self.targetId        = resolvedId
    self.awaitingConsent = true
    TriggerServerEvent("p_policejob/server/drugtest/requestConsent", resolvedId)
end

-- Handles the consent result returned by the server; runs the full test if accepted
function DrugTestKit:onConsentResult(targetServerId, accepted)
    self.awaitingConsent = false

    local resolvedId = tonumber(targetServerId)
    if not resolvedId then
        self.targetId = nil
        return
    end

    if not accepted then
        Bridge.Notify.showNotify(locale("drug_test_declined"), "error")
        self.targetId = nil
        return
    end

    self.targetId = resolvedId
    Config.DrugTestKit.onTestStart(resolvedId)

    local completed = Bridge.Progress.Start({
        duration     = Config.DrugTestKit.testDuration or 6000,
        label        = locale("performing_drug_test"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = Config.DrugTestKit.progressAnim,
    })

    if not completed then
        self.targetId = nil
        return
    end

    local results = lib.callback.await("p_policejob/server/drugtest/start", false, resolvedId)
    if not results then
        self.targetId = nil
        return
    end

    Config.DrugTestKit.onTestComplete(resolvedId, results)
    self:showResults(resolvedId, results)
    self.targetId = nil
end

-- Runs the test directly from the NUI (no progress bar, streams status to NUI)
function DrugTestKit:startTest()
    if not self.targetId then
        Bridge.Notify.showNotify(locale("no_player_nearby"), "error")
        return nil
    end

    Config.DrugTestKit.onTestStart(self.targetId)

    SendNUIMessage({
        action = "setDrugTestKitData",
        data   = {
            status     = "testing",
            targetId   = self.targetId,
            targetName = self:getTargetName(self.targetId),
        },
    })

    local results = lib.callback.await("p_policejob/server/drugtest/start", false, self.targetId)

    if not results then
        SendNUIMessage({
            action = "setDrugTestKitData",
            data   = {
                status     = "idle",
                targetId   = self.targetId,
                targetName = self:getTargetName(self.targetId),
            },
        })
        return nil
    end

    local nuiData = {
        status     = "complete",
        targetId   = self.targetId,
        targetName = self:getTargetName(self.targetId),
        positive   = results.positive == true,
        substances = results.substances or {},
        details    = results.details   or {},
    }

    Config.DrugTestKit.onTestComplete(self.targetId, nuiData)
    SendNUIMessage({ action = "setDrugTestKitData", data = nuiData })
    return nuiData
end

-- Builds and shows the drug test result context menu
function DrugTestKit:showResults(targetServerId, results)
    local options = {}

    -- Target row
    options[#options + 1] = {
        title       = locale("drug_test_result_target"),
        description = self:getTargetName(targetServerId) or string.format("ID %s", targetServerId),
        icon        = "user",
        readOnly    = true,
    }

    -- Status row
    local statusLabel = results.positive
        and locale("drug_test_result_positive")
        or  locale("drug_test_result_negative")

    options[#options + 1] = {
        title       = locale("drug_test_result_status"),
        description = statusLabel,
        icon        = results.positive and "triangle-exclamation" or "check",
        iconColor   = results.positive and "#ff5d5d" or "#5dd9a4",
        readOnly    = true,
    }

    -- Substances
    local substances = results.substances or {}
    if #substances > 0 then
        for _, substance in ipairs(substances) do
            options[#options + 1] = {
                title     = tostring(substance),
                icon      = "flask",
                iconColor = "#ff5d5d",
                readOnly  = true,
            }
        end
    elseif results.positive then
        options[#options + 1] = { title = locale("drug_test_result_unknown"),       icon = "circle-question", readOnly = true }
    else
        options[#options + 1] = { title = locale("drug_test_result_no_substances"), icon = "check",           readOnly = true }
    end

    -- Extra details
    if type(results.details) == "table" then
        for key, value in pairs(results.details) do
            if value ~= nil then
                options[#options + 1] = {
                    title       = tostring(key),
                    description = tostring(value),
                    icon        = "circle-info",
                    readOnly    = true,
                }
            end
        end
    end

    lib.registerContext({
        id      = "p_policejob_drug_test_result",
        title   = locale("drug_test_result_title"),
        options = options,
    })
    lib.showContext("p_policejob_drug_test_result")
end

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

-- NUI: player pressed "start test"
RegisterNUICallback("drugtest:start", function(_, cb)
    local result = DrugTestKit:startTest()
    cb(result or { success = false })
end)

-- NUI: player pressed "reset" (run another test on the same target)
RegisterNUICallback("drugtest:reset", function(_, cb)
    if not DrugTestKit.targetId then
        return cb({ success = false })
    end

    SendNUIMessage({
        action = "setDrugTestKitData",
        data   = {
            status     = "idle",
            targetId   = DrugTestKit.targetId,
            targetName = DrugTestKit:getTargetName(DrugTestKit.targetId),
            positive   = false,
            substances = {},
            details    = {},
        },
    })
    cb({ success = true })
end)

-- NUI: player closed the kit
RegisterNUICallback("drugtest:close", function(_, cb)
    DrugTestKit:close()
    cb({ success = true })
end)

-- ─── Event Handlers ──────────────────────────────────────────────────────────

-- Close when the NUI frame signals hide
AddEventHandler("p_policejob:client:hideFrame", function(frameData)
    if frameData and frameData.name == "setVisibleDrugTestKit" then
        DrugTestKit:close()
    end
end)

-- Server → client: open the kit targeting a specific server id
RegisterNetEvent("p_policejob/client/drugtest/open", function(targetServerId)
    DrugTestKit:open(targetServerId)
end)

-- Server → client: force close the kit
RegisterNetEvent("p_policejob/client/drugtest/close", function()
    DrugTestKit:close()
end)

-- Server → client: the subject has been prompted; show the local consent dialog
RegisterNetEvent("p_policejob/client/drugtest/consentPrompt", function(officerName)
    local accepted = ShowConsentDialog(officerName)
    TriggerServerEvent("p_policejob/server/drugtest/consentResponse", accepted)
end)

-- Server → client: consent result delivered back to the officer
RegisterNetEvent("p_policejob/client/drugtest/consentResult", function(targetServerId, accepted)
    DrugTestKit:onConsentResult(targetServerId, accepted)
end)

-- Client callback: used by the server to ask the local player for consent directly
lib.callback.register("p_policejob/client/drugtest/requestConsent", function(officerName)
    return ShowConsentDialog(officerName)
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("OpenDrugTestKit", function(targetServerId)
    DrugTestKit:open(targetServerId)
end)

exports("useDrugTestKit", function(targetServerId)
    DrugTestKit:open(targetServerId)
end)

exports("runDrugTestTarget", function(targetServerId)
    DrugTestKit:runTargetTest(targetServerId)
end)
