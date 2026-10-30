local medical = {}

---@param serverId number
---@return boolean
function medical.isPlayerDead(serverId)
    return Player(serverId).state?.isDead or false
end

---@param value number
function medical.overrideMaxHealth(value)
    -- Integrations with other resources
end

if bridge.name == bridge.currentResource then
    local deathState = {
        isdead = false,
        inlaststand = false,
    }
    local cachedDeadState = false

    RegisterNetEvent("qbx_core:client:onSetMetaData", function(key, _, value)
        if key ~= "isdead" and key ~= "inlaststand" then return end
        deathState[key] = value == true or value == "true"

        local isDead = deathState.isdead or deathState.inlaststand
        if cachedDeadState == isDead then
            return
        end

        cachedDeadState = isDead

        if isDead then
            TriggerServerEvent("prp-bridge:server:died")
            TriggerEvent("prp-bridge:client:died")
            return
        end

        TriggerServerEvent("prp-bridge:server:revived")
        TriggerEvent("prp-bridge:client:revived")
    end)
end

return medical
