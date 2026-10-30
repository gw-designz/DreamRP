local medical = {}

---@param serverId number
---@return boolean
function medical.isPlayerDead(serverId)
    if not serverId then return false end

    if serverId == cache.serverId then
        return exports.osp_ambulance:isDead()
    end

    local ambulanceData = exports.osp_ambulance:GetAmbulanceData(serverId)
    if not ambulanceData then return false end

    return ambulanceData.isDead == true or ambulanceData.inLastStand == true
end

---@param value number
function medical.overrideMaxHealth(value)
end

if bridge.name == bridge.currentResource then
    RegisterNetEvent('osp_ambulance:OnPlayerDead', function()
        TriggerServerEvent("prp-bridge:server:died")
        TriggerEvent("prp-bridge:client:died")
    end)

    RegisterNetEvent('osp_ambulance:OnPlayerSpawn', function()
        TriggerServerEvent("prp-bridge:server:revived")
        TriggerEvent("prp-bridge:client:revived")
    end)
end

return medical
