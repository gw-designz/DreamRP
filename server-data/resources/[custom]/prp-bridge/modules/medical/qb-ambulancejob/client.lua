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
    RegisterNetEvent("QBCore:Player:SetPlayerData", function(playerData)
        if not playerData or not playerData.metadata then return end
        if not playerData.metadata.isdead and not playerData.metadata.inlaststand then return end
        
        TriggerServerEvent("prp-bridge:server:died")
        TriggerEvent("prp-bridge:client:died")

        lib.print.info("Player dead", playerData.metadata.isdead, playerData.metadata.inlaststand)
    end)
end

return medical
