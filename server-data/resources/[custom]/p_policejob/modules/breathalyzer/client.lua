-- Wait for Config to be available
while true do
    if Config and Config.Breathalyzer then break end
    Citizen.Wait(500)
end

if not Config.Breathalyzer.Enabled then return end

Breathalyzer = {}
Breathalyzer.isActive     = false
Breathalyzer.targetId     = nil
Breathalyzer.localAlcohol = 0

-- ============================================================
--  Alcohol tracking
-- ============================================================

RegisterNetEvent("evidence:client:SetStatus", function(statusKey, value)
    if statusKey:find("alcohol") then
        Breathalyzer.localAlcohol = value
    end
end)

-- Decay alcohol level by 1 every second
CreateThread(function()
    while true do
        Wait(1000)
        if Breathalyzer.localAlcohol > 0 then
            Breathalyzer.localAlcohol = Breathalyzer.localAlcohol - 1
        end
    end
end)

-- ============================================================
--  Drunk level
-- ============================================================

function Breathalyzer.getDrunkLevel(self)
    local customLevel = Config.Breathalyzer.getDrunkLevel()
    if not customLevel or customLevel == 0 then
        return self.localAlcohol
    end
    return customLevel
end

-- ============================================================
--  NUI helpers
-- ============================================================

local function sendNUI(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setBreathalyzerStatus(status, value)
    sendNUI("setBreathalyzerData", { status = status, value = value })
end

-- ============================================================
--  Open / Close / Toggle
-- ============================================================

function Breathalyzer.open(self, targetId)
    self.isActive = true
    self.targetId = targetId

    Config.Breathalyzer.onOpen()

    sendNUI("setBreathalyzerConfig", {
        thresholds = Config.Breathalyzer.thresholds,
        colors     = Config.Breathalyzer.colors,
        locales    = {
            guide_title  = locale("breathalyzer_guide_title"),
            guide_step_1 = locale("breathalyzer_guide_step_1"),
            guide_step_2 = locale("breathalyzer_guide_step_2"),
            guide_step_3 = locale("breathalyzer_guide_step_3"),
            start        = locale("breathalyzer_start"),
            stop         = locale("breathalyzer_stop"),
        },
    })

    sendNUI("setVisibleBreathalyzer", true)
    setBreathalyzerStatus("idle", 0)
    SetNuiFocus(true, true)
end

function Breathalyzer.close(self)
    self.isActive = false
    self.targetId = nil

    Config.Breathalyzer.onClose()

    sendNUI("setVisibleBreathalyzer", false)
    SetNuiFocus(false, false)
end

function Breathalyzer.toggle(self, state, targetId)
    if state == nil then
        state = not self.isActive
    end

    if state then
        self:open(targetId or self.targetId)
    else
        self:close()
    end
end

-- ============================================================
--  Test logic
-- ============================================================

function Breathalyzer.startTest(self)
    if not self.targetId then
        return Bridge.Notify.showNotify(locale("no_player_nearby"), "error")
    end

    Config.Breathalyzer.onTestStart(self.targetId)
    setBreathalyzerStatus("testing", 0)

    local result = lib.callback.await("p_policejob/server/breathalyzer/startBreathalyzer", false, self.targetId)

    if result then
        setBreathalyzerStatus("complete", result)
        Config.Breathalyzer.onTestComplete(self.targetId, result)
    else
        setBreathalyzerStatus("idle", 0)
    end

    return result
end

function Breathalyzer.resetTest(self)
    setBreathalyzerStatus("idle", 0)
end

-- ============================================================
--  Use (find nearby target, then open)
-- ============================================================

function Breathalyzer.use(self, targetId)
    local job = Bridge.Framework.fetchPlayerJob()
    if not Config.Jobs[job.name] then
        return Bridge.Notify.showNotify(locale("no_access_breathalyzer"), "error")
    end

    -- Accept an explicit numeric target or scan for the closest player
    if not targetId or type(targetId) ~= "number" then
        local closestPlayer = lib.getClosestPlayer(GetEntityCoords(cache.ped), 4.0, false)
        if closestPlayer and closestPlayer ~= 0 then
            local closestServerId = GetPlayerServerId(closestPlayer)
            if closestServerId ~= cache.serverId then
                targetId = closestServerId
            end
        end
    end

    if not targetId or type(targetId) ~= "number" then
        return Bridge.Notify.showNotify(locale("no_player_nearby"), "error")
    end

    self:open(targetId)
end

-- ============================================================
--  Exports
-- ============================================================

exports("isBreathalyzerActive", function()
    return Breathalyzer.isActive
end)

exports("useBreathalyzer", function(targetId)
    Breathalyzer:use(targetId)
end)

exports("OpenBreathalyzer", function(targetId)
    Breathalyzer:open(targetId)
end)

exports("CloseBreathalyzer", function()
    Breathalyzer:close()
end)

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("StartBreathalyzer", function(_, cb)
    local result = Breathalyzer:startTest()
    cb(result or 0)
end)

RegisterNUICallback("StopBreathalyzer", function(_, cb)
    Breathalyzer:resetTest()
    cb("ok")
end)

RegisterNUICallback("CloseBreathalyzer", function(_, cb)
    Breathalyzer:close()
    cb("ok")
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/client/breathalyzer/toggle", function(state, targetId)
    Breathalyzer:toggle(state, targetId)
end)

RegisterNetEvent("p_policejob/client/breathalyzer/open", function(targetId)
    Breathalyzer:use(targetId)
end)

RegisterNetEvent("p_policejob/client/breathalyzer/close", function()
    Breathalyzer:close()
end)

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if data.name == "setVisibleBreathalyzer" then
        Breathalyzer:close()
    end
end)

-- ============================================================
--  lib callbacks
-- ============================================================

lib.callback.register("p_policejob/client/breathalyzer/getDrunkLevel", function()
    return Breathalyzer:getDrunkLevel()
end)

lib.callback.register("p_policejob/client/breathalyzer/requestConsent", function(officerName)
    -- Cuffed or hands-up players give automatic consent
    local isCuffed  = LocalPlayer.state.isCuffed
    local isHandsUp = IsEntityPlayingAnim(cache.ped, "random@mugging3", "handsup_standing_base", 3)

    if isCuffed or isHandsUp then return true end

    local confirmed = lib.alertDialog({
        header   = locale("breathalyzer_consent_header"),
        content  = locale("breathalyzer_consent_content"):format(officerName or "?"),
        centered = true,
        cancel   = true,
        labels   = {
            confirm = locale("breathalyzer_consent_accept"),
            cancel  = locale("breathalyzer_consent_decline"),
        },
    })

    return confirmed == "confirm"
end)
