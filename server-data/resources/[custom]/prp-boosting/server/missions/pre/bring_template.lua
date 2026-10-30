local events = {
    ["bring_boosting_pdm_key"] = {
        label = "Bring PDM Key",
        itemName = "boosting_pdm_key",
        genTarget = { 1, 2 },
        genTargetClasses = {
            ["D"] = { 1, 1 },
            ["C"] = { 1, 1 },
            ["B"] = { 1, 1 },
            ["A"] = { 1, 1 },
            ["S"] = { 1, 2 }
        }
    },
    ["bring_boosting_bank_key"] = {
        label = "Bring Bank Key",
        itemName = "boosting_bank_key",
        genTarget = { 1, 2 },
        genTargetClasses = {
            ["D"] = { 1, 1 },
            ["C"] = { 1, 1 },
            ["B"] = { 1, 1 },
            ["A"] = { 1, 1 },
            ["S"] = { 1, 2 }
        }
    },
    ["bring_boosting_jewelery_key"] = {
        label = "Bring Jewelery Key",
        itemName = "boosting_jewelery_key",
        genTarget = { 1, 2 },
        genTargetClasses = {
            ["D"] = { 1, 1 },
            ["C"] = { 1, 1 },
            ["B"] = { 1, 1 },
            ["A"] = { 1, 1 },
            ["S"] = { 1, 2 }
        }
    },
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
        pedModels = {
            `a_m_m_bevhills_02`,
            `a_m_m_business_01`,
            `a_m_m_golfer_01`,
        },
        pedLocations = {
            vec4(-32.5, -184.6, 52.7, 165.4),
        },
        requiredEvent = k,
        cooldown = 2 * 60 * 60
    }
    
    local PrepMission = {}
    PrepMission.__index = PrepMission
    PrepMission = setmetatable(PrepMission, Mission)
    
    function PrepMission:OnStart(stateId, contract, groupId)
        local pedLocation = MissionConfig.pedLocations[math.random(1, #MissionConfig.pedLocations)]
        local pedModel = MissionConfig.pedModels[math.random(1, #MissionConfig.pedModels)]
        self:SendEventToMembers("prp-boosting:setMissionBlip", "buyer", "Boosting Delivery Location", pedLocation.xyz, 500, 3, false)
        self.ped = self:CreateLocalPed(pedModel, pedLocation, true, true, true)
        self:AddLocalObjectTarget(self.ped, "bring_ped", {
            label = "Give item",
            icon = "fas fa-hands",
            event = "prp-boosting:bringItem",
        })
        self.itemName = v.itemName
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

RegisterNetEvent("prp-boosting:bringItem", function(missionId, objectId)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and string.find(mission.missionName, "pre_bring") and mission.taskId == playerMission.taskId then
        local itemCount = bridge.inv.count(source, mission.itemName)
        if type(itemCount) == "table" then
            itemCount = itemCount[mission.itemName] or 0
        end
        if not itemCount or itemCount < 1 then
            bridge.fw.notify(source, "error", "You don't have the item")
            return
        end
        local itemsLeft = (mission:GetTarget()-mission:GetProgress())
        if itemCount > itemsLeft then
            itemCount = itemsLeft
        end
        local success = bridge.inv.removeItem(source, mission.itemName, itemCount)
        if not success then
            bridge.fw.notify(source, "error", "Failed to remove the item")
            return
        end
        mission:AddProgress(itemCount)
    end
end)