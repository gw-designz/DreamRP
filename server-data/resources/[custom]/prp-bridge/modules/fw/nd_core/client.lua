local NDCore = exports["ND_Core"]
local fw = {}

local PlayerData = NDCore:getPlayer()

AddEventHandler("onResourceStart", function(resourceName)
    if cache.resource ~= resourceName then return end
    PlayerData = NDCore:getPlayer()
end)

RegisterNetEvent("ND:characterLoaded", function(character)
    PlayerData = character
end)

RegisterNetEvent("ND:updateCharacter", function(character)
    PlayerData = character
end)

---@return number
function fw.getStress()
    return PlayerData?.metadata?.status?.stress or 0
end

---@return number
function fw.getHunger()
    return PlayerData?.metadata?.status?.hunger or 100
end

---@return number
function fw.getThirst()
    return PlayerData?.metadata?.status?.thirst or 100
end

---@param statusType string
---@param value number
function fw.setStatus(statusType, value)
    if statusType == "stress" then
        PlayerData?.metadata?.status?.stress = value
    elseif statusType == "hunger" then
        PlayerData?.metadata?.status?.hunger = value
    elseif statusType == "thirst" then
        PlayerData?.metadata?.status?.thirst = value
    end
end

function fw.applyBuff(buff, data)
    --- Integrations with other resources
end

function fw.clearBuffs()
    --- Integrations with other resources
end

---@param type 'inform' | 'error' | 'success'| 'warning'
---@param message string
---@param title? string
---@param duration? number
function fw.notify(type, message, title, duration)
    lib.notify({
        type = type or "inform",
        title = title or nil,
        description = message or "",
        duration = duration or 3000,
    })
end

---@param text string
---@param options { position?: ShowTextUIPos, icon?: string | table<string>, iconColor?: string, iconAnimation?: ShowTextUIAnims, alignIcon?: "top" | "center" }
function fw.showTextUI(text, options)
    lib.showTextUI(text, options)
end

function fw.hideTextUI()
    lib.hideTextUI()
end

---@return boolean
---@return string | nil
function fw.isTextUIOpen()
    return lib.isTextUIOpen()
end

---@param payload FWProgressBar
---@return boolean?
function fw.progressBar(payload)
    local options = {
        duration = payload.duration or 5000,
        label = payload.label,
        useWhileDead = false,
        allowRagdoll = payload.allowRagdoll or false,
        allowSwimming = payload.allowSwimming or false,
        allowCuffed = payload.allowCuffed or false,
        allowFalling = payload.allowFalling or false,
        canCancel = payload.canCancel or false,
        disable = {}
    }

    if payload.controlDisables then
        if payload.controlDisables.disableMovement then
            options.disable.move = true
        end
        if payload.controlDisables.disableCarMovement then
            options.disable.car = true
        end
        if payload.controlDisables.disableMouse then
            options.disable.mouse = true
        end
        if payload.controlDisables.disableCombat then
            options.disable.combat = true
        end
        if payload.controlDisables.disableSprint then
            options.disable.sprint = true
        end
    end

    if payload.animation and payload.animation.animDict and payload.animation.animClip then
        options.anim = {
            dict = payload.animation.animDict,
            clip = payload.animation.animClip,
        }

        if payload.animation.animFlag then
            options.anim.flag = payload.animation.animFlag
        end
    elseif payload.animation and payload.animation.scenario then
        options.anim = {
            scenario = payload.animation.scenario
        }
    end

    return lib.progressBar(options)
end

---@param header string
---@param content string
---@param labels? {cancel?: string, confirm?: string}
---@param timeout? number Force the window to timeout after `x` milliseconds.
---@return 'cancel'|'confirm'|nil
function fw.confirmDialog(header, content, labels, timeout)
    return lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = true,
        labels = labels or {cancel = locale("Cancel"), confirm = locale("Confirm")},
    }, timeout)
end

---@param heading string
---@param rows string[] | InputDialogRowProps[]
---@param options InputDialogOptionsProps[]?
---@return string[] | number[] | boolean[] | nil
function fw.inputDialog(heading, rows, options)
    return lib.inputDialog(heading, rows, options)
end

---@param payload FWContextMenuProps | FWContextMenuProps[]
function fw.contextMenu(payload)
    lib.registerContext(payload)
end

---@param contextId string
function fw.showContext(contextId)
    lib.showContext(contextId)
end

function fw.isOnDuty()
    return true
end

---@param job string
---@param grade number? do they require a minimum grade
---@param duty boolean? do they need to be on duty
---@return boolean
function fw.hasJob(job, grade, duty)
    if not PlayerData then
        return false
    end

    local jobId = PlayerData.groups[job]?.name

    if not jobId then
        return false
    end

    if grade then
        local gradeId = PlayerData.groups[job]?.rank
        if not gradeId then
            return false
        end

        if gradeId < grade then
            return false
        end
    end

    if duty then
        return fw.isOnDuty()
    end

    return true
end

---@return string?
function fw.getIdentifier()
    return tostring(PlayerData?.id)
end

---@return string?
function fw.getCharacterName()
    local player = PlayerData
    if not player then
        return nil
    end

    if not player.fullname then
        return nil
    end

    return player.fullname
end

if bridge.name == bridge.currentResource then
    local function emitStatus(statusType, value)
        TriggerEvent('prp-bridge:client:statusChanged', statusType, value)
    end

    local function emitAllStatuses()
        emitStatus('hunger', fw.getHunger())
        emitStatus('thirst', fw.getThirst())
        emitStatus('stress', fw.getStress())
    end

    RegisterNetEvent("ND:characterLoaded", function()
        TriggerEvent('prp-bridge:client:playerLoad')
        emitAllStatuses()
    end)

    RegisterNetEvent("ND:updateCharacter", function()
        emitAllStatuses()
    end)

    RegisterNetEvent("ND:characterUnloaded", function()
        TriggerEvent('prp-bridge:client:playerUnload')
    end)
end

return fw
