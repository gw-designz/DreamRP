local BoostingContract = {}
BoostingContract.__index = BoostingContract
LoadedBoostingContracts = {}
ContractMembers = {}

local function getRequiredGroupSize(contract, mission)
    local requiredSize = Config.RequiredGroupSize[contract.vehicleClass] or 1
    if mission and mission.name and RegisteredMissions[mission.name] then
        local prerequisites = RegisteredMissions[mission.name].GetPrerequisites and RegisteredMissions[mission.name]:GetPrerequisites(contract) or {}
        for _, prerequisite in ipairs(prerequisites) do
            if prerequisite.type == "PLAYER_COUNT" then
                local missionSize = prerequisite.value or 0
                if missionSize > requiredSize then
                    requiredSize = missionSize
                end
            end
        end
    end
    return requiredSize
end

---@class BoostingContract
---@field id string
---@field fileName string
---@field contractType string
---@field contractTypeLabel string
---@field contractFullLabel string
---@field vehicleModel string
---@field vehicleModelLabel string
---@field vehicleClass string
---@field rewards table
---@field missions table[]
---@field prerequisites table[] 
---@field ownerStateId number

---@param contractId number
---@return BoostingContract|nil
function LoadBoostingContract(contractId, result)
    contractId = tostring(contractId)
    if LoadedBoostingContracts[contractId] then return LoadedBoostingContracts[contractId] end
    local result = result or MySQL.single.await("SELECT * FROM boosting_contracts WHERE id = ?", { contractId })
    if not result then return nil end
    local self = {}
    self.id = tostring(result.id)
    self.fileName = result.vehicleModel .. "_" .. self.id
    self.contractType = result.contractType or "boosting"
    self.contractTypeLabel = self.contractType
    local vehData = Config.Vehicles[result.vehicleModel]
    self.contractFullLabel = (self.contractType == "boosting" and locale("CONTRACT_BOOSTING_LABEL") or locale("CONTRACT_VIN_SCRATCH_LABEL")) .. " " .. (vehData and (vehData?.manufacturer .. " " .. vehData?.label) or locale("Unknown"))
    self.vehicleModel = result.vehicleModel
    self.vehicleModelLabel = vehData and (vehData?.manufacturer .. " " .. vehData?.label) or locale("Unknown")
    self.vehicleClass = vehData?.class or result.vehicleClass
    self.rewards = {
        amount = result.reward or 0,
        cryptoName = result.cryptoName or "",
        experience = result.experience or 0,
    }
    self.ownerStateId = result.owner
    self.groupId = nil
    self.missions = {}
    self.prerequisites = {}
    self.deleted = result.deleted == 1
    self.active = result.active == 1
    self.finished = result.finished == 1
    self.timeoutTime = Config.ContractTimeouts[self.contractType][self.vehicleClass] or -1
    self.startTimestamp = result.startTimestamp and result.startTimestamp/1000 or nil
    self.addonData = result.addonData and json.decode(result.addonData) or {}
    if self.startTimestamp and self.startTimestamp < 1 then
        self.startTimestamp = nil
    end
    self.timeout = self.timeoutTime > 0 and self.startTimestamp and (self.startTimestamp + self.timeoutTime) or nil
    self.requiredLevel = result.isAdmin == 0 and (Config.LevelForClass[self.vehicleClass] or 0) or 0
    if self.addonData?.timeout and self.addonData.timeout > 0 then
        self.timeoutTime = self.addonData.timeout
        self.timeout = self.startTimestamp and (self.startTimestamp + self.timeoutTime) or nil
    end
    self.isHarderHacks = self.addonData?.isHarderHacks or false
    self.penaltyPercent = 0
    self.maxPlayers = Config.MaxGroupSize[self.vehicleClass] or Config.MaxGroupSize["default"]

    if self.requiredLevel > 0 then
        self.prerequisites[#self.prerequisites+1] = {
            label = "Required Level " .. self.requiredLevel,
            type = "LEVEL",
            value = self.requiredLevel,
            icon = "zap"
        }
    end

    local hasGroupSize = Config.RequiredGroupSize[self.vehicleClass]

    local tasks = MySQL.query.await("SELECT * FROM boosting_contracts_tasks WHERE contractId = ?", { self.id })
    for _, task in ipairs(tasks) do
        if task.type == "mission" then
            if RegisteredMissions[task.name] then
                local metadata = RegisteredMissions[task.name]:GetMetadata()
                for k, v in pairs(metadata) do
                    task[k] = v
                end
                task.active = task.active == 1
                task.availableTimestamp = task.availableTimestamp and task.availableTimestamp/1000 or nil
                task.finished = task.finished == 1
                local prerequisites = RegisteredMissions[task.name].GetPrerequisites and RegisteredMissions[task.name]:GetPrerequisites(self) or {}
                for _, prerequisite in ipairs(prerequisites) do
                    if prerequisite.addClassItem then
                        prerequisite.value = prerequisite.value .. self.vehicleClass
                    end
                    if prerequisite.type == "PLAYER_COUNT" then
                        hasGroupSize = (prerequisite.value or 0) > (hasGroupSize or 0) and (prerequisite.value or 0) or hasGroupSize
                    else
                        self.prerequisites[#self.prerequisites+1] = prerequisite
                    end
                end
                self.missions[#self.missions+1] = task
            end
        elseif task.type == "prerequisite" then
            self.prerequisites[#self.prerequisites+1] = task
        end
    end
    if hasGroupSize then
        self.prerequisites[#self.prerequisites+1] = {
            label = locale("REQUIRED_GROUP_SIZE", hasGroupSize),
            type = "PLAYER_COUNT",
            value = hasGroupSize,
        }
    end
    for i=#self.missions, 1, -1 do
        if self.missions[i].active then
            self.missions[i].active = false
            if self.missions[i].isCheckpoint then
                if self.missions[i].holdProgress then
                    MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, finished = 0 WHERE id = ?", { self.missions[i].id })
                    self.missions[i].finished = false
                else
                    MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, progress = 0, finished = 0 WHERE id = ?", { self.missions[i].id })
                    self.missions[i].progress = 0
                    self.missions[i].finished = false
                end
                break
            else
                self.missions[i].progress = 0
                self.missions[i].finished = false
                MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, progress = 0, finished = 0 WHERE id = ?", { self.missions[i].id })
            end
            if i > 1 then
                for j=i-1, 1, -1 do
                    self.missions[j].active = false
                    MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, progress = 0, finished = 0 WHERE id = ?", { self.missions[j].id })
                    if self.missions[j].isCheckpoint then
                        if self.missions[j].holdProgress then
                            MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, finished = 0 WHERE id = ?", { self.missions[j].id })
                            self.missions[j].finished = false
                        else
                            MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, progress = 0, finished = 0 WHERE id = ?", { self.missions[j].id })
                            self.missions[j].progress = 0
                            self.missions[j].finished = false
                        end
                        break
                    else
                        self.missions[j].progress = 0
                        self.missions[j].finished = false
                        MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, progress = 0, finished = 0 WHERE id = ?", { self.missions[j].id })
                    end
                end
           end
        end
    end
    self = setmetatable(self, BoostingContract)
    LoadedBoostingContracts[self.id] = self
    if self.active and self.missions[1] and not self.missions[1].finished and self.missions[1].autoStart then
        local mission = LoadMission(self.id, self.missions[1].id, self.ownerStateId)
        if mission then
            mission:Start(self.ownerStateId)
        end
    end
    
    return self
end

function BoostingContract:OnMissionCancel(taskMissionId)
    for i=taskMissionId, 1, -1 do
        self.missions[i].active = false
        if self.missions[i].isCheckpoint then
            if self.missions[i].holdProgress then
                MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, finished = 0 WHERE id = ?", { self.missions[i].id })
                self.missions[i].finished = false
            else
                MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, progress = 0, finished = 0 WHERE id = ?", { self.missions[i].id })
                self.missions[i].progress = 0
                self.missions[i].finished = false
            end
            break
        else
            self.missions[i].progress = 0
            self.missions[i].finished = false
            MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, progress = 0, finished = 0 WHERE id = ?", { self.missions[i].id })
        end
    end
    if self.groupId then
        local group = exports["prp-bridge"]:GetGroupByUuid(self.groupId)
        if group then
            group.setLocked(false)
        end
    end
    self:UpdateActive()
end

function LoadBoostingContractsForUsb(usbId)
    local contracts = MySQL.query.await("SELECT * FROM boosting_contracts WHERE usbId = ? AND DELETED = 0 AND FINISHED = 0", { usbId })
    local result = {}
    for _, contract in ipairs(contracts) do
        result[#result+1] = LoadBoostingContract(contract.id, contract)
    end

    return result
end

function LoadBoostingContractsForPlayer(stateId)
    local contracts = MySQL.query.await("SELECT * FROM boosting_contracts WHERE owner = ? AND DELETED = 0 AND FINISHED = 0", { stateId })
    local result = {}
    for _, contract in ipairs(contracts) do
        result[#result+1] = LoadBoostingContract(contract.id, contract)
    end

    return result
end

function BoostingContract:SetActive(active, dontRemoveVeh, skipUpdate)
    local result = MySQL.update.await("UPDATE boosting_contracts SET active = ? WHERE id = ?", { active and 1 or 0, self.id })
    if result then
        self.active = active
    end
    if active then
        self.startTimestamp = os.time()
        self.timeout = self.timeoutTime > 0 and (self.startTimestamp + self.timeoutTime) or nil
        MySQL.update.await("UPDATE boosting_contracts SET startTimestamp = FROM_UNIXTIME(?) WHERE id = ?", { self.startTimestamp, self.id })
        if self.missions[1] and self.missions[1].autoStart then
            local mission = LoadMission(self.id, self.missions[1].id, self.ownerStateId)
            if mission then
                mission:Start(self.ownerStateId)
            end
        end
    else
        if self.activeMission then
            local mission = LoadMission(self.id, self.missions[self.activeMission].id, self.ownerStateId)
            if mission then
                mission:Cancel(self.ownerStateId)
            end
        end
        if self.groupId then
            local group = exports["prp-bridge"]:GetGroupByUuid(self.groupId)
            if group then
                group.setLocked(false)
            end
        end
        if self.vehEntity and DoesEntityExist(self.vehEntity) and not dontRemoveVeh then
            Citizen.CreateThread(function()
                local vehEntity = self.vehEntity
                TriggerClientEvent("prp-boosting:setVehicleUndriveable", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
                Citizen.Wait(1 * 60 * 1000)
                if DoesEntityExist(vehEntity) then
                    self:RemoveKeys(vehEntity)
                    Entity(vehEntity).state.Deleted = true
                    DeleteEntity(vehEntity)
                end
            end)
        end
        for k2, v2 in pairs(self.spawnedVehicles or {}) do
            if self.vehStayAfterMission and self.vehStayAfterMission[k2] then
                local playerPed = GetPedInVehicleSeat(v2, -1)
                if playerPed and DoesEntityExist(playerPed) then
                    local playerId = NetworkGetEntityOwner(playerPed)
                    if playerId and playerId ~= -1 then
                        bridge.fw.notify(playerId, "error", ("This vehicle will be removed in %s seconds, please leave the vehicle"):format(self.vehStayAfterMission[k2]))
                    end
                end
                Citizen.SetTimeout(self.vehStayAfterMission[k2]*1000, function()
                    if DoesEntityExist(v2) then
                        DeleteEntity(v2)
                    end
                end)
            else
                if DoesEntityExist(v2) then
                    Entity(v2).state.Deleted = true
                    DeleteEntity(v2)
                end
            end
        end
    end
    if not skipUpdate then
        self:UpdateActive()
    end
end

function BoostingContract:RemoveKeys(vehicle)
    vehicle = vehicle or self.vehEntity
    if not vehicle then return end

    if self.groupId then
        local group = exports["prp-bridge"]:GetGroupByUuid(self.groupId)
        if group then
            for _, member in pairs(group.getMembers()) do
                if member.src and DoesPlayerExist(member.src) then
                    bridge.vkeys.remove(member.src, vehicle)
                end
            end
            return
        end
    end

    local ownerSource = bridge.fw.getSrcFromIdentifier(self.ownerStateId)
    if ownerSource then
        bridge.vkeys.remove(ownerSource, vehicle)
    end
end

function BoostingContract:Delete()
    local result = MySQL.update.await("UPDATE boosting_contracts SET deleted = 1 WHERE id = ?", { self.id })
    if result then
        self.deleted = true
    end
end

function BoostingContract:Finish()
    if self.finished then return end
    self.finished = true
    if self.groupId then
        local group = exports["prp-bridge"]:GetGroupByUuid(self.groupId)
        if group then
            group.setLocked(false)
        end
    end
    self:SetActive(false)
    local result = MySQL.update.await("UPDATE boosting_contracts SET finished = 1, active = 0 WHERE id = ?", { self.id })
    if result then
        self.finished = true
        self.active = false
    end

    local ownerSource = bridge.fw.getSrcFromIdentifier(self.ownerStateId)
    local ownerCoords = GetEntityCoords(GetPlayerPed(ownerSource))

    local group = exports["prp-bridge"]:GetGroupByUuid(self.groupId)

    local requiredSize = Config.RequiredGroupSize[self.vehicleClass] or 1
    local groupSize = 0
    local members = {}
    if group then
        members = group.getMembers()
        for identifier, memberData in pairs(members) do
            local memberSource = memberData.src
            if DoesPlayerExist(memberSource) and #(GetEntityCoords(GetPlayerPed(memberSource)) - ownerCoords) < 250.0 then
                groupSize = groupSize + 1
            end
        end
    end
    if groupSize < requiredSize then
        bridge.fw.notify(ownerSource, "error", locale("NOT_ENOUGH_MEMBERS_FINISH", requiredSize))
        return
    end

    if self.rewards.amount and self.rewards.amount > 0 then
        if self.penaltyPercent then
            self.rewards.amount = math.floor(self.rewards.amount * (1 - (self.penaltyPercent / 100)))
            MySQL.update.await("UPDATE boosting_contracts SET reward = ? WHERE id = ?", { self.rewards.amount, self.id })
        end
        if Config.CurrencyForAllMembers and group then
            local rewardPerMember = math.floor(self.rewards.amount / groupSize)
            for identifier, member in pairs(members) do
                if member.src and DoesPlayerExist(member.src) then
                    AddPlayerCurrency(identifier, self.rewards.cryptoName, rewardPerMember, "Boosting Reward", "Boosting Reward", "boosting_contract_reward")
                    LoggerBySid(identifier, "boosting", ("Player %s got %s %s for boosting"):format(identifier, rewardPerMember, self.rewards.cryptoName), {
                        boosting_eventType = "contract_reward",
                        boosting_contractId = self.id,
                        boosting_vehicleModel = self.vehicleModel,
                        boosting_vehicleClass = self.vehicleClass,
                        boosting_reward_amount = rewardPerMember,
                        boosting_reward_cryptoName = self.rewards.cryptoName,
                        boosting_ownerStateId = self.ownerStateId,
                    })
                end
            end
        else
            AddPlayerCurrency(self.ownerStateId, self.rewards.cryptoName, self.rewards.amount, "Boosting Reward", "Boosting Reward", "boosting_contract_reward")
            LoggerBySid(self.ownerStateId, "boosting", ("Player %s got %s %s for boosting"):format(self.ownerStateId, self.rewards.amount, self.rewards.cryptoName), {
                boosting_eventType = "contract_reward",
                boosting_contractId = self.id,
                boosting_vehicleModel = self.vehicleModel,
                boosting_vehicleClass = self.vehicleClass,
                boosting_reward_amount = self.rewards.amount,
                boosting_reward_cryptoName = self.rewards.cryptoName,
                boosting_ownerStateId = self.ownerStateId,
            })
        end
        local gloveBox = Config.BoostingGlovebox[self.vehicleClass]
        if gloveBox then
            local item = WeightedRandom(gloveBox)
            if item and item.name ~= "__NOTHING__" then
                bridge.inv.giveItem(bridge.fw.getSrcFromIdentifier(self.ownerStateId), item.name, math.random(item.count[1], item.count[2]), item.metadata)
            end
        end
    end

    if group then
        local groupPointsTotal = GetGroupPointsExpForClass(self.vehicleClass)
        local groupPointsViaBridge = false
        if groupPointsTotal > 0 then
            if group.addExperience then
                group.addExperience(groupPointsTotal)
                groupPointsViaBridge = true
            elseif group.addExp then
                group.addExp(groupPointsTotal)
                groupPointsViaBridge = true
            elseif group.addPoints then
                group.addPoints(groupPointsTotal)
                groupPointsViaBridge = true
            end
        end

        local members = group.getMembers()
        for stateId, member in pairs(members) do
            local isNear = #(GetEntityCoords(GetPlayerPed(member.src)) - ownerCoords) < 250.0
            if not isNear then
                if member.src and DoesPlayerExist(member.src) then
                    bridge.fw.notify(member.src, "error", locale("NOT_NEAR_OWNER"))
                end
            end
            if stateId == self.ownerStateId or Config.ContractsGroupCooldown[self.vehicleClass] then
                local cooldown = Config.ContractsCooldown[self.vehicleClass] or 0
                if cooldown and cooldown > 0 then
                    exports["prp-bridge"]:startCooldownByIdentifier(stateId, "boosting", cooldown)
                end
            end
            if self.rewards.experience and self.rewards.experience > 0 and isNear then
                AwardBoostingExperienceByStateId(stateId, self.rewards.experience, "contract_experience", self)
            end
            if not groupPointsViaBridge and groupPointsTotal > 0 and isNear and groupSize > 0 then
                AwardBoostingExperienceByStateId(stateId, math.floor(groupPointsTotal / groupSize), "contract_group_experience", self)
            end
            TriggerEvent("prp-base:activityCompleted", member.src, "boosting_"..self.vehicleClass)
        end
    end

    AddActionHistory(self.ownerStateId, self.contractType == "boosting" and "BOOST" or "VIN_SCRATCH", self.vehicleClass, true)
    self:UpdateActive()
end

function BoostingContract:UpdateActive(source)
    local group = nil
    local ownerSrc = bridge.fw.getSrcFromIdentifier(self.ownerStateId)
    if ownerSrc and GetPlayerPing(ownerSrc) > 0 then
        if not self.groupId or not exports["prp-bridge"]:GetGroupByUuid(self.groupId) then
            group = exports["prp-bridge"]:GetGroupFromMemberByIdentifier(self.ownerStateId)
            if not group then
                local newGroup = exports["prp-bridge"]:CreateGroup(bridge.fw.getSrcFromIdentifier(self.ownerStateId))
                if not newGroup.success then
                    return
                end
                group = newGroup.group
            end
            self.groupId = group.getUuid()
        else
            group = exports["prp-bridge"]:GetGroupByUuid(self.groupId)
        end
    end

    if not self.active then
        for k, v in pairs(ContractMembers) do
            if v == self.id then
                ContractMembers[k] = nil
            end
        end
    end
    if not group then
        if self.active then
            self:SetActive(false, true, true)
        end
        return
    end
    local players = {}
    local members = group.getMembers()
    for stateId, member in pairs(members) do
        if member.playerId then
            players[#players+1] = {
                stateId = stateId,
                nickname = PlayerUsernames[stateId],
                experience = {
                    currentLevel = GetBoostingLevelByStateId(stateId),
                }
            } 
        end
        ContractMembers[tostring(stateId)] = self.active and self.id or nil
    end
    if source then
        TriggerClientEvent("prp-boosting:setActiveContract", source, self.active and self or nil, players)
    else
        for stateId, member in pairs(members) do
            if member.src and DoesPlayerExist(member.src) then
                TriggerClientEvent("prp-boosting:setActiveContract", member.src, self.active and self or nil, players)
            end
        end
    end
end

function BoostingContract:Fail(dontRemoveVeh)
    if self.groupId then
        local group = exports["prp-bridge"]:GetGroupByUuid(self.groupId)
        group.setLocked(false)
        local members = group.getMembers()
        if members then
            for stateId, member in pairs(members) do
                if stateId == self.ownerStateId or Config.ContractsGroupCooldown[self.vehicleClass] then
                    local cooldown = Config.ContractsCooldown[self.vehicleClass] or 0
                    if cooldown and cooldown > 0 then
                        exports["prp-bridge"]:startCooldownByIdentifier(stateId, "boosting", cooldown)
                    end
                end
            end
        end
    end
    LoggerBySid(self.ownerStateId, "boosting", ("Boosting contract %s failed"):format(self.id), {
        boosting_eventType = "contract_fail",
        boosting_contractId = self.id,
        boosting_vehicleModel = self.vehicleModel,
        boosting_vehicleClass = self.vehicleClass,
        boosting_ownerStateId = self.ownerStateId,
    })

    AddActionHistory(self.ownerStateId, self.contractType == "boosting" and "BOOSTING" or "VIN_SCRATCH", self.vehicleClass, false)
    self:SetActive(false, dontRemoveVeh)
    self:Delete()
end

function BoostingContract:UpdateData()
    local src = bridge.fw.getSrcFromIdentifier(self.ownerStateId)
    if not src then return end
    local group = nil
    if self.groupId then
        group = exports["prp-bridge"]:GetGroupByUuid(self.groupId)
    end
    if not group then
        return
    end
    local contractData, players = GetActiveContract(src)
    local groupMembers = group.getMembers()
    for k,v in pairs(groupMembers) do
        if v.src and DoesPlayerExist(v.src) then
            TriggerClientEvent("prp-boosting:setActiveContract", v.src, contractData, players)
        end
    end
end

lib.callback.register("prp-boosting:loadOwnedContracts", function(source)
    local stateId = bridge.fw.getIdentifier(source)

    return LoadBoostingContractsForPlayer(stateId)
end)

lib.callback.register("prp-boosting:startContract", function(source, contractId)
    local stateId = bridge.fw.getIdentifier(source)
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("INVALID_CONTRACT") } end
    if contract.ownerStateId ~= stateId then return { success = false, error = locale("YOU_ARE_NOT_THE_OWNER") } end
    if contract.finished or contract.deleted then return { success = false, error = locale("CONTRACT_IS_FINISHED_OR_DELETED") } end
    local onMarket = MySQL.scalar.await("SELECT COUNT(*) FROM boosting_listings WHERE contractId = ? AND active = 1", { contractId }) > 0
    if onMarket then return { success = false, error = locale("CONTRACT_IS_ON_MARKET") } end
    local group = exports["prp-bridge"]:GetGroupFromMemberByIdentifier(stateId)
    if not group then
        local newGroup = exports["prp-bridge"]:CreateGroup(bridge.fw.getSrcFromIdentifier(stateId))
        if not newGroup.success then
            return { success = false, error = locale("OWNER_NOT_IN_GROUP") }
        end
        group = newGroup.group
    end
    if not group then return { success = false, error = locale("OWNER_NOT_IN_GROUP") } end
    local requiredLevel = contract.requiredLevel
    local members = group.getMembers()
    for k, v in pairs(members) do
        if not v.src then
            return { success = false, error = locale("SOMEONE_NOT_ONLINE") }
        end
        local currentLevel = GetBoostingLevelByStateId(k)
        local isOwner = contract.ownerStateId == k
        if requiredLevel and requiredLevel > 0 and (currentLevel or 0) < (isOwner and requiredLevel or math.floor(requiredLevel/2)) then
            return { success = false, error = locale("LEVEL_TOO_LOW") }
        end
        if k == contract.ownerStateId and exports["prp-bridge"]:isCooldownActiveForIdentifier(k, "boosting") then
            return { success = false, error = locale("SOMEONE_ON_COOLDOWN") }
        end
    end
    local policeRequirement = Config.PolicePowerRequirement[contract.vehicleClass] or Config.PolicePowerRequirement["default"]
    if policeRequirement and policeRequirement > 0 then
        local policePower = exports["prp-bridge"]:GetFreePolicePower()
        if policePower < policeRequirement then
            return { success = false, error = locale("NOT_ENOUGH_COPS") }
        end
    end
    LoggerBySid(stateId, "boosting", ("Player %s started contractId %s"):format(stateId, contract.id), {
        boosting_eventType = "start_contract",
        boosting_contractId = contract.id,
        boosting_vehicleModel = contract.vehicleModel,
        boosting_vehicleClass = contract.vehicleClass,
        boosting_ownerStateId = contract.ownerStateId
    })
    contract:SetActive(true)
    return { success = true }
end)

lib.callback.register("prp-boosting:startMission", function(source, missionId)
    local stateId = bridge.fw.getIdentifier(source)
    local contractId = MySQL.scalar.await("SELECT contractId FROM boosting_contracts_tasks WHERE id = ?", { missionId })
    if not contractId then return { success = false, error = locale("INVALID_MISSION") } end
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("INVALID_CONTRACT") } end
    if contract.ownerStateId ~= stateId then return { success = false, error = locale("YOU_ARE_NOT_THE_OWNER") } end
    if not contract.active then return { success = false, error = locale("CONTRACT_NOT_STARTED") } end
    local mission = nil
    for k, v in pairs(contract.missions) do
        if v.id == missionId then
            mission = v
            break
        end
    end
    local group = nil
    if not contract.groupId or not exports["prp-bridge"]:GetGroupByUuid(contract.groupId) then
        group = exports["prp-bridge"]:GetGroupFromMemberByIdentifier(stateId)
        if not group then
            local newGroup = exports["prp-bridge"]:CreateGroup(bridge.fw.getSrcFromIdentifier(stateId))
            if not newGroup.success then
                return { success = false, error = locale("OWNER_NOT_IN_GROUP") }
            end
            group = newGroup.group
        end
        contract.groupId = group.getUuid()
    else
        group = exports["prp-bridge"]:GetGroupByUuid(contract.groupId)
    end
    if not group then
        return { success = false, error = locale("OWNER_NOT_IN_GROUP") }
    end
    if not mission then return { success = false, error = locale("INVALID_MISSION") } end
    local task = LoadMission(contractId, missionId, stateId)
    if not task then return { success = false, error = locale("INVALID_MISSION") } end
    if task.active then return { success = false, error = locale("MISSION_ALREADY_STARTED") } end
    local requiredLevel = contract.requiredLevel
    local requiredMembers = getRequiredGroupSize(contract, mission)
    local groupSize = 0
    local members = group.getMembers()
    for k, v in pairs(members) do
        if not v.src then
            return { success = false, error = locale("SOMEONE_NOT_ONLINE") }
        end
        local currentLevel = GetBoostingLevelByStateId(k)
        local isOwner = contract.ownerStateId == k
        print(v.src, "Required Level:", requiredLevel, "Current Level:", currentLevel, "Is Owner:", isOwner)
        if requiredLevel and requiredLevel > 0 and currentLevel < (isOwner and requiredLevel or math.floor(requiredLevel/2)) then
            return { success = false, error = locale("LEVEL_TOO_LOW") }
        end
        if contract.ownerStateId == k and exports["prp-bridge"]:isCooldownActiveForIdentifier(k, "boosting") then
            return { success = false, error = locale("SOMEONE_ON_COOLDOWN") }
        end
        groupSize = groupSize + 1
    end
    if groupSize < requiredMembers then
        return { success = false, error = locale("NOT_ENOUGH_MEMBERS", requiredMembers) }
    end
    if mission.availableTimestamp and mission.availableTimestamp > os.time() then
        return { success = false, error = locale("MISSION_NOT_AVAILABLE_YET") }
    end
    local policeRequirement = Config.PolicePowerRequirement[contract.vehicleClass] or Config.PolicePowerRequirement["default"]
    if policeRequirement and policeRequirement > 0 then
        local policePower = exports["prp-bridge"]:GetFreePolicePower()
        if policePower < policeRequirement then
            return { success = false, error = locale("NOT_ENOUGH_COPS") }
        end
    end
    task:Start(stateId)
    return { success = true }
end)

lib.callback.register("prp-boosting:stopMission", function(source, missionId)
    local stateId = bridge.fw.getIdentifier(source)
    local contractId = MySQL.scalar.await("SELECT contractId FROM boosting_contracts_tasks WHERE id = ?", { missionId })
    if not contractId then return { success = false, error = locale("INVALID_MISSION") } end
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("INVALID_CONTRACT") } end
    if contract.ownerStateId ~= stateId then return { success = false, error = locale("YOU_ARE_NOT_THE_OWNER") } end
    local mission = nil
    for k, v in pairs(contract.missions) do
        if v.id == missionId then
            mission = v
            break
        end
    end
    if not mission then return { success = false, error = locale("INVALID_MISSION") } end
    local missionData = LoadMission(contractId, missionId, stateId)
    if not missionData then return { success = false, error = locale("INVALID_MISSION") } end
    if not contract.missions[missionData.taskContractId].active then return { success = false, error = "Mission not started" } end
    contract.missions[missionData.taskContractId].availableTimestamp = os.time() + Config.MissionCancelCooldown
    missionData:Cancel(stateId)
    local group = exports["prp-bridge"]:GetGroupByUuid(contract.groupId)
    if group then
        group.setLocked(false)
    end
    MySQL.update.await("UPDATE boosting_contracts_tasks SET availableTimestamp = FROM_UNIXTIME(?) WHERE id = ?", { contract.missions[missionData.taskContractId].availableTimestamp, contract.missions[missionData.taskContractId].id })
    return { success = true }
end)

lib.callback.register("prp-boosting:cancelContract", function(source, contractId)
    local stateId = bridge.fw.getIdentifier(source)
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("INVALID_CONTRACT") } end
    if contract.ownerStateId ~= stateId then return { success = false, error = locale("YOU_ARE_NOT_THE_OWNER") } end
    for k, v in pairs(contract.missions) do
        local task = LoadMission(contractId, v.id, stateId)
        if task and task.active then
            task:Destroy(stateId, true)
        end
    end
    contract:SetActive(false)
    contract:Delete()
    return { success = true }
end)

lib.callback.register("prp-boosting:loadContract", function(source, contractId)
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("INVALID_CONTRACT") } end
    return contract
end)

function GetActiveContract(src)
    local stateId = bridge.fw.getIdentifier(src)
    local contractId = ContractMembers[tostring(stateId)]
    if not contractId then return nil end
    local contract = LoadBoostingContract(contractId)
    if not contract then return nil end
    local players = {}

    local group = nil
    if not contract.groupId or not exports["prp-bridge"]:GetGroupByUuid(contract.groupId) then
        group = exports["prp-bridge"]:GetGroupFromMemberByIdentifier(stateId)
        if not group then
            local newGroup = exports["prp-bridge"]:CreateGroup(src)
            if not newGroup.success then
                return
            end
            group = newGroup.group
        end
        contract.groupId = group.getUuid()
    else
        group = exports["prp-bridge"]:GetGroupByUuid(contract.groupId)
    end
    if not group then
        return
    end
    local members = group.getMembers()
    for mStateId, member in pairs(members or {}) do
        if member.src then
            players[#players+1] = {
                stateId = mStateId,
                nickname = PlayerUsernames[mStateId],
                experience = {
                    currentLevel = GetBoostingLevelByStateId(mStateId),
                }
            }
        end
    end
    return contract, players
end

lib.callback.register("prp-boosting:getActiveContract", function(source)
    local contract, players = GetActiveContract(source)
    return contract, players
end)

lib.callback.register("prp-boosting:adminCreateContract", function(source, data)
    if not isAdmin(source) then return { success = false, error = locale("NO_PERMISSION") } end
    local stateId = bridge.fw.getIdentifier(source)

    local targetStateId = stateId;
    local onMarket = data.isMarket

    if data.targetNickname and string.len(data.targetNickname) > 0 then
        targetStateId = MySQL.scalar.await("SELECT stateId FROM boosting_users WHERE LOWER(username) = ?", { string.lower(data.targetNickname) })
        if not targetStateId then return { success = false, error = locale("USER_NOT_FOUND") } end
    end

    local vehicleData = Config.Vehicles[data.vehicleName]
    if not vehicleData then return { success = false, error = "Invalid vehicle" } end

    local contractType = data.contractType or "boosting"
    local contractAddonData = {
        timeout = data.timeout or -1,
        isHarderHacks = data.isHarderHacks or false,
    }
    local id = MySQL.insert.await("INSERT INTO boosting_contracts (contractType, vehicleModel, vehicleClass, reward, experience, owner, isAdmin, addonData) VALUES (@contractType, @vehicleModel, @vehicleClass, @reward, @experience, @owner, 1, @addonData)", {
        ["@contractType"] = contractType,
        ["@vehicleModel"] = data.vehicleName,
        ["@vehicleClass"] = vehicleData.class,
        ["@reward"] = data.rewards.amount,
        ["@experience"] = data.rewards.experience,
        ["@owner"] = stateId,
        ["@addonData"] = json.encode(contractAddonData or {})
    })

    if id then
        for k, v in ipairs(data.missions) do
            local missionConfig = RegisteredMissions[v.name]:GetMetadata()
            local addonData = RegisteredMissions[v.name].GenerateAddonData and RegisteredMissions[v.name]:GenerateAddonData() or {}
            local target = missionConfig.genTarget and (type(missionConfig.genTarget) == "table" and math.random(missionConfig.genTarget[1], missionConfig.genTarget[2]) or missionConfig.genTarget) or 1
            if v.target then
                target = v.target
            end
            MySQL.insert.await("INSERT INTO boosting_contracts_tasks (contractId, name, target, type, vehicleClass, addonData) VALUES (@contractId, @name, @target, 'mission', @vehicleClass, @addonData)", {
                ["@contractId"] = id,
                ["@name"] = v.name,
                ["@target"] = target,
                ["@vehicleClass"] = vehicleData.class,
                ["@addonData"] = json.encode(addonData or {})
            })
        end
        bridge.fw.notify(source, "success", locale("CONTRACT_CREATED"))
        if onMarket then
            local buyType = data.type or "bin"
            local price = data.price or 0
            local listingId = MySQL.insert.await("INSERT INTO boosting_listings (contractId, authorStateId, `type`, price, endTimestamp) VALUES (@contractId, @authorStateStateId, @buyType, @price, FROM_UNIXTIME(@endTimestamp))", {
                ["@contractId"] = id,
                ["@authorStateStateId"] = stateId,
                ["@buyType"] = buyType,
                ["@price"] = price,
                ["@endTimestamp"] = buyType == "auction" and (os.time() + 24 * 60 * 60)
            })
            if buyType == "auction" then
                CachedAuctions[#CachedAuctions+1] = MySQL.single.await("SELECT * FROM boosting_listings WHERE id = ?", { listingId })
            end
        end
        return { success = true }
    end
    return { success = false, error = "Failed to create contract" }
end)

lib.callback.register("prp-boosting:getAdminData", function(source)
    if not isAdmin(source) then return { success = false, error = locale("NO_PERMISSION") } end
    local data = {}
    local parts = {"pre", "middle", "steal", "deliver", "vinDeliver"}
    for _, part in ipairs(parts) do
        data[part.."Missions"] = {}
        for missionName, mission in pairs(RegisteredMissions) do
            for i in string.gmatch(missionName, "[^_]+") do
                if i == part then
                    table.insert(data[part.."Missions"], {  name = missionName, label = mission:GetMetadata().label .. (" (%s)"):format(missionName), target = mission:GetMetadata().genTarget ~= nil and 1 or nil })
                end
                break
            end
        end
    end
    return data
end)

local function getBoostingContractByGroupId(groupId)
    for _, contract in pairs(LoadedBoostingContracts) do
        if contract.groupId == groupId then
            return contract
        end
    end
    for _, contractId in pairs(ContractMembers) do
        local contract = LoadBoostingContract(contractId)
        if contract and contract.groupId == groupId then
            return contract
        end
    end
    return nil
end

local function isBoostingGroupFull(group, contract)
    if not contract or not contract.maxPlayers then
        return false
    end
    return group.getMembersCount() >= contract.maxPlayers
end

lib.callback.register("prp-boosting:invitePlayer", function(source, username)
    local stateId = bridge.fw.getIdentifier(source)
    local targetStateId = MySQL.scalar.await("SELECT stateId FROM boosting_users WHERE LOWER(username) = ?", { string.lower(username) })
    if not targetStateId then return { success = false, error = locale("USER_NOT_FOUND") } end
    local playerContractId = ContractMembers[tostring(stateId)]
    if not playerContractId then return { success = false, error = locale("NO_ACTIVE_CONTRACT") } end
    local targetSource = bridge.fw.getSrcFromIdentifier(targetStateId)
    if not targetSource then return { success = false, error = locale("USER_NOT_FOUND") } end
    local contract = LoadBoostingContract(playerContractId)
    if not contract then return { success = false, error = locale("INVALID_CONTRACT") } end
    if contract.ownerStateId ~= stateId then return { success = false, error = locale("YOU_ARE_NOT_THE_OWNER") } end
    if not contract.groupId then return { success = false, error = locale("CONTRACT_HAS_NO_GROUP") } end
    local group = exports["prp-bridge"]:GetGroupByUuid(contract.groupId)
    if not group then return { success = false, error = locale("CONTRACT_HAS_NO_GROUP") } end
    if group.isSrcAMember(targetSource) then
        return { success = false, error = locale("USER_ALREADY_IN_GROUP") }
    end
    if isBoostingGroupFull(group, contract) then
        return { success = false, error = locale("GROUP_FULL", contract.maxPlayers) }
    end
    if Config.Invitation and Config.Invitation.Enabled then
        if Config.Invitation.DistanceCheck ~= nil then
            local targetPed = GetPlayerPed(targetSource)
            local ownerPed = GetPlayerPed(source)
            if not DoesEntityExist(targetPed) or not DoesEntityExist(ownerPed) then
                return { success = false, error = locale("USER_NOT_FOUND") }
            end
            local targetCoords = GetEntityCoords(targetPed)
            local ownerCoords = GetEntityCoords(ownerPed)
            if #(targetCoords - ownerCoords) > Config.Invitation.DistanceCheck then
                return { success = false, error = locale("USER_TOO_FAR") }
            end
        end
        if Config.Invitation.ItemCheck then
            local count = bridge.inv.count(targetSource, "boosting_tablet")
            if count <= 0 then
                return { success = false, error = locale("USER_NO_TABLET") }
            end
        end
        local invitationResult = lib.callback.await("prp-boosting:requestToJoin", targetSource)
        if not invitationResult then
            return { success = false, error = locale("USER_DECLINED_INVITE") }
        end
    end
    group.addMember(targetSource)
    contract:UpdateData()
    return { success = true }
end)

lib.callback.register("prp-boosting:deleteContract", function(source, contractId)
    local stateId = bridge.fw.getIdentifier(source)
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("CONTRACT_NOT_FOUND") } end
    if contract.ownerStateId ~= stateId then return { success = false, error = "You can't delete this contract" } end
    local onMarket = MySQL.scalar.await("SELECT COUNT(*) FROM boosting_listings WHERE contractId = ? AND active = 1", { contractId }) > 0
    if onMarket then return { success = false, error = locale("CONTRACT_ON_MARKET") } end
    if contract.active then return { success = false, error = locale("CONTRACT_IS_ACTIVE") } end
    contract:Delete()
    if not contract.deleted then return { success = false, error = "Failed to delete contract" } end
    LoggerBySid(stateId, "boosting", ("Player deleted contract %s"):format(contractId), {
        boosting_eventType = "transfer_contract",
        boosting_contractId = contract.id,
        boosting_vehicleModel = contract.vehicleModel,
        boosting_vehicleClass = contract.vehicleClass,
        boosting_ownerStateId = stateId,
    })
    return { success = true }
end)

RegisterNetEvent("prp-bridge:server:groupMemberAdded", function(source, groupId)
    local stateId = bridge.fw.getIdentifier(source)
    local contract = getBoostingContractByGroupId(groupId)
    if not contract then
        return
    end

    ContractMembers[tostring(stateId)] = contract.id
    contract:UpdateActive()

    local group = exports["prp-bridge"]:GetGroupByUuid(groupId)
    if not group or group.getMembersCount() <= contract.maxPlayers then
        return
    end

    group.removeMember(source)
    ContractMembers[tostring(stateId)] = nil
    contract:UpdateActive()

    if DoesPlayerExist(source) then
        bridge.fw.notify(source, "error", locale("GROUP_FULL", contract.maxPlayers))
    end

    local ownerSrc = bridge.fw.getSrcFromIdentifier(contract.ownerStateId)
    if ownerSrc and DoesPlayerExist(ownerSrc) and ownerSrc ~= source then
        bridge.fw.notify(ownerSrc, "error", locale("GROUP_FULL", contract.maxPlayers))
    end
end)

RegisterNetEvent("prp-boosting:kickPlayer", function(stateId)
    local src = source
    local targetSrc = bridge.fw.getSrcFromIdentifier(stateId)
    if not targetSrc then return end
    local contractId = ContractMembers[tostring(stateId)]
    if not contractId then return end
    local contract = LoadBoostingContract(contractId)
    if not contract then return end
    local contractOwner = bridge.fw.getSrcFromIdentifier(contract.ownerStateId)
    if src ~= contractOwner then return end
    local group = nil
    if contract.groupId then
        group = exports["prp-bridge"]:GetGroupByUuid(contract.groupId)
    end
    if not group then return end
    group.removeMember(targetSrc)
end)

RegisterNetEvent("prp-bridge:server:groupMemberRemoved", function(source, groupId)
    local stateId = bridge.fw.getIdentifier(source)
    local contractId = ContractMembers[tostring(stateId)]
    if contractId then
        local contract = LoadBoostingContract(contractId)
        ContractMembers[tostring(stateId)] = nil
        if contract and contract.groupId == groupId then
            Citizen.SetTimeout(0, function()
                if stateId == contract.ownerStateId then
                    contract.groupId = nil
                end
                contract:UpdateActive()
            end)
            TriggerClientEvent("prp-boosting:setActiveContract", source, nil, nil)
            if contract.activeMission then
                TriggerClientEvent("prp-boosting:setMissionId", source)
            end
            contract:UpdateData()
        end
    end
end)

lib.callback.register("prp-boosting:loadBoostingHistory", function(source, usbId, query, offset)
    local results = MySQL.query.await("SELECT * FROM boosting_contracts WHERE (FINISHED = 1 OR DELETED = 1) AND LOWER(vehicleModel) LIKE ? ORDER BY id DESC LIMIT 10 OFFSET ?", { string.lower("%" .. query .. "%"), offset })
    local contracts = {}
    for k, v in pairs(results) do
        contracts[#contracts+1] = LoadBoostingContract(v.id, v)
    end
    return contracts
end)

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    local results = MySQL.query.await("SELECT * FROM boosting_contracts WHERE active = 1")
    for _, result in ipairs(results) do
        ContractMembers[tostring(result.owner)] = result.id
    end
    while true do
        local time = os.time()
        for _, contract in pairs(LoadedBoostingContracts) do
            local lastMission = nil
            if contract.active and not contract.finished and contract.timeout and contract.timeout < time then
                local src = bridge.fw.getSrcFromIdentifier(contract.ownerStateId)
                if src then
                    bridge.fw.notify(src, "error", locale("CONTRACT_TIMED_OUT"))
                end
                if contract.activeMission then
                    local mission = LoadMission(contract.id, contract.missions[contract.activeMission].id, contract.ownerStateId)
                    if mission then
                        mission:Fail(true)
                    else
                        contract:Fail()
                    end
                else
                    contract:Fail()
                end
            end
            for k, v in ipairs(contract.missions) do
                if v.finished then
                    lastMission = k
                end
            end
            if lastMission and contract.missions[lastMission+1] then
                local nextMission = contract.missions[lastMission+1]
                if nextMission.autoStart and not nextMission.active and nextMission.availableTimestamp and nextMission.availableTimestamp < os.time() and bridge.fw.getSrcFromIdentifier(contract.ownerStateId) then
                    local mission = LoadMission(contract.id, nextMission.id, contract.ownerStateId)
                    if mission and not mission.started then
                        mission:Start(contract.ownerStateId)
                    end
                end
            end
        end
        Citizen.Wait(1000)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for k, v in pairs(LoadedBoostingContracts) do
            if v.vehEntity and DoesEntityExist(v.vehEntity) then
                v:RemoveKeys()
                DeleteEntity(v.vehEntity)
            end
            for k2, v2 in pairs(v.spawnedVehicles or {}) do
                if DoesEntityExist(v2) then
                    DeleteEntity(v2)
                end
            end
        end
    end
end)

exports("FailContract", function(contractId)
    local contract = LoadBoostingContract(contractId)
    if contract then
        if contract.activeMission then
            local mission = LoadMission(contractId, contract.missions[contract.activeMission].id, contract.ownerStateId)
            if mission then
                mission:Fail(true)
            else
                contract:Fail()
            end
        else
            contract:Fail()
        end
    end
end)