local Ox = require "@ox_core.lib.init"

local fw = {}

local PlayerData = Ox.GetPlayer()

AddEventHandler("ox:playerLoaded", function()
    PlayerData = Ox.GetPlayer()
end)

RegisterNetEvent("ox:setActiveCharacter", function()
    PlayerData = Ox.GetPlayer()
end)

RegisterNetEvent("ox:setGroup", function()
    PlayerData = Ox.GetPlayer()
end)

AddEventHandler("ox:statusTick", function()
    PlayerData = Ox.GetPlayer()
end)

---@return number
function fw.getStress()
    return PlayerData and PlayerData.getStatus("stress") or 0
end

---@return number
function fw.getHunger()
    return PlayerData and PlayerData.getStatus("hunger") or 100
end

---@return number
function fw.getThirst()
    return PlayerData and PlayerData.getStatus("thirst") or 100
end

---@param statusType string
---@param value number
function fw.setStatus(statusType, value)
    if not PlayerData then return end

    PlayerData.setStatus(statusType, value)
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
---@param options? { position?: ShowTextUIPos, icon?: string | table<string>, iconColor?: string, iconAnimation?: ShowTextUIAnims, alignIcon?: "top" | "center" }
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
    return PlayerData and PlayerData.get("activeGroup") ~= nil
end

---@param job string
---@param grade number? do they require a minimum grade
---@param duty boolean? do they need to be on duty
---@return boolean
function fw.hasJob(job, grade, duty)
    if not PlayerData then
        return false
    end

    local playerGrade = PlayerData.getGroup(job)
    if not playerGrade then
        return false
    end

    if grade and playerGrade < grade then
        return false
    end

    if duty and PlayerData.get("activeGroup") ~= job then
        return false
    end

    return true
end

---@return string?
function fw.getIdentifier()
    return PlayerData?.stateId
end

---@return string?
function fw.getCharacterName()
    if not PlayerData then
        return nil
    end

    local firstName = PlayerData.get("firstName") or PlayerData.get("firstname")
    local lastName = PlayerData.get("lastName") or PlayerData.get("lastname")

    if not firstName or not lastName then
        return nil
    end

    return ("%s %s"):format(firstName, lastName)
end

if bridge.name == bridge.currentResource then
    AddEventHandler("ox:playerLoaded", function()
        TriggerEvent("prp-bridge:client:playerLoad")
    end)

    RegisterNetEvent("ox:startCharacterSelect", function()
        TriggerEvent("prp-bridge:client:playerUnload")
    end)
end

return fw
