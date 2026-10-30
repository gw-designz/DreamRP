---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: duplicate-doc-field

---@alias SkillCheckDifficulty 'easy' | 'medium' | 'hard' | { areaSize: number, speedMultiplier: number }

---@class SkillcheckOptions
---@field label? string
---@field instruction? string
---@field type? 'circle' | 'rect'

---@type promise?
local activeSkillCheck = nil

---@param difficulty SkillCheckDifficulty | SkillCheckDifficulty[]
---@param inputs? string[]
---@param options? SkillcheckOptions
---@return boolean?
function SkillCheck(difficulty, inputs, options)
    if activeSkillCheck then return end

    activeSkillCheck = promise:new()
    options = options or {}

    Utils.setNuiFocus(false, true)
    SendNUIMessage({
        action = 'startSkillCheck',
        data = {
            difficulty  = difficulty or { 'easy' },
            keys        = inputs or { 'e' },
            label       = options.label,
            instruction = options.instruction,
            type        = options.type
        }
    })

    return Citizen.Await(activeSkillCheck)
end

function CancelSkillCheck()
    if not activeSkillCheck then
        error('No skillCheck is active')
    end

    SendNUIMessage({ action = 'skillCheckCancel' })
end

---@return boolean
function SkillCheckActive()
    return activeSkillCheck ~= nil
end

RegisterNUICallback('skillCheckOver', function(success, cb)
    cb(1)

    if activeSkillCheck then
        Utils.resetNuiFocus()
        activeSkillCheck:resolve(success)
        activeSkillCheck = nil
    end
end)
