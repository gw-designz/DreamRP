local events = {
    -- ["heist_pdm"] = {
    --     label = "Do the PDM Heist",
    --     genTarget = { 1, 2 },
    --     genTargetClasses = {
    --         ["D"] = { 1, 2 },
    --         ["C"] = { 1, 2 },
    --         ["B"] = { 1, 2 },
    --         ["A"] = { 1, 3 },
    --         ["S"] = { 1, 3 }
    --     }
    -- },
    -- ["heist_jewelery"] = {
    --     label = "Do the Jewelry Heist",
    --     genTarget = { 1, 2 },
    --     genTargetClasses = {
    --         ["D"] = { 1, 2 },
    --         ["C"] = { 1, 2 },
    --         ["B"] = { 1, 2 },
    --         ["A"] = { 1, 3 },
    --         ["S"] = { 1, 3 }
    --     }
    -- },
    -- ["race_ranked"] = {
    --     label = "Do a Ranked Race",
    --     genTarget = { 1, 5 },
    --     genTargetClasses = {
    --         ["D"] = { 1, 2 },
    --         ["C"] = { 1, 2 },
    --         ["B"] = { 1, 2 },
    --         ["A"] = { 1, 3 },
    --         ["S"] = { 1, 3 }
    --     }
    -- },
}

for k, v in pairs(events) do
    local MissionConfig = {
        metadata = {
            label = v.label,
            startable = true,
            autoStart = false,
            dontLockGroup = true,
            genTarget = v.genTarget,
            holdProgress = true,
            isCheckpoint = true,
            nextMissionCooldown = {
                ["default"] = 5 * 60,
                ["D"] = 5 * 60,
                ["C"] = 5 * 60,
                ["B"] = 5 * 60,
                ["A"] = 5 * 60,
                ["S"] = 5 * 60
            }
        },
        genTargetClasses = v.genTargetClasses,
        requiredEvent = k,
        cooldown = 2 * 60 * 60
    }
    
    local PrepMission = {}
    PrepMission.__index = PrepMission
    PrepMission = setmetatable(PrepMission, Mission)
    
    function PrepMission:OnStart(stateId, contract, groupId)
    
    end
    
    function PrepMission:OnDestroy(stateId, contract, groupId)
    
    end
    
    function PrepMission:OnTick(stateId, contract, groupId, tickId)
    
    end
    
    function PrepMission:OnActivityEvent(stateId, eventName, count)
        if eventName == MissionConfig.requiredEvent and (not self.lastEvent or os.time() - self.lastEvent > MissionConfig.cooldown) then
            self.lastEvent = os.time()
            self:AddProgress(count or 1)
        end
    end

    
    function PrepMission:GetMetadata()
        local metadata = lib.table.deepclone(MissionConfig.metadata)
        if contract and contract.vehicleClass then
            metadata.genTarget = MissionConfig.genTargetClasses[contract.vehicleClass] or metadata.genTarget
        end
        return metadata
    end
    
    function PrepMission:GetPrerequisites()
        return MissionConfig.prerequisites
    end
    
    Citizen.CreateThread(function()
        RegisteredMissions["pre_"..k] = PrepMission
    end)
end