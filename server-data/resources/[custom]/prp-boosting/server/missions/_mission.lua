---@class MissionHandler

Mission = {}
Mission.__index = Mission
---@type table<string, MissionHandler>
RegisteredMissions = {}
Missions = {}
MissionObjectId = 0
MissionObjects = {}

function LoadMission(contractId, taskId, stateId)
    contractId = tostring(contractId)
    if Missions[taskId] then return Missions[taskId] end
    local self = {}
    local contract = LoadBoostingContract(contractId)
    if not contract then return end
    local task = nil
    self.taskContractId = -1
    for k, v in pairs(contract.missions) do
        if tonumber(v.id) == taskId then
            task = v
            self.taskContractId = k
            break
        end
    end
    if not task then return end
    if not RegisteredMissions[task.name] then return end
    self.missionName = task.name
    self.contractId = contractId
    self.contract = contract
    self.taskId = taskId
    self.stateId = stateId
    self.addonData = json.decode(task.addonData)
    self.localObjects = {}
    self.vehTargets = {}
    self.startTime = os.time()

    self = setmetatable(self, RegisteredMissions[self.missionName])
    Missions[taskId] = self
    return Missions[taskId]
end

function Mission:Start(stateId)
    local contract = LoadBoostingContract(self.contractId)
    if not contract then return end
    local group = exports["prp-bridge"]:GetGroupFromMemberByIdentifier(stateId)
    if not group then
        local newGroup = exports["prp-bridge"]:CreateGroup(bridge.fw.getSrcFromIdentifier(stateId))
        if not newGroup.success then
            return
        end
        group = newGroup.group
    end
    LoadedBoostingContracts[self.contractId].groupId = group.getUuid()
    self:SendEventToMembers("prp-boosting:setMissionId", self.taskId, self.contractId, joaat(LoadedBoostingContracts[self.contractId].vehicleModel))
    self:SendEventToMembers("prp-boosting:clearBlips")
    Citizen.CreateThread(function()
        self:OnStart(stateId, contract, LoadedBoostingContracts[self.contractId].groupId)
        self.enableTick = true
    end)
    if not self:GetMetadata().dontLockGroup then
        group.setLocked(true)
    end
    LoadedBoostingContracts[self.contractId].missions[self.taskContractId].active = true
    self.started = true
    self.groupId = LoadedBoostingContracts[self.contractId].groupId
    MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 1 WHERE id = @id", {
        ["@id"] = self.taskId
    })
    LoadedBoostingContracts[self.contractId].activeMission = self.taskContractId
    LoadedBoostingContracts[self.contractId]:UpdateActive()
end

function Mission:Destroy(stateId, dontDelete)
    local contract = LoadBoostingContract(self.contractId)
    if not contract then return end
    self:SendEventToMembers("prp-boosting:clearBlips")
    if next(self.localObjects) then
        TriggerClientEvent("prp-boosting:removeMissionObjects", -1, self.taskId, true)
    end 
    if next(self.vehTargets) then
        TriggerClientEvent("prp-boosting:removeMissionVehTargets", -1, self.taskId)
    end
    self:SendEventToMembers("prp-boosting:setMissionId")
    if self.npcNetIds and next(self.npcNetIds) then
        for k, v in pairs(self.npcNetIds) do
            local ent = NetworkGetEntityFromNetworkId(v)
            if DoesEntityExist(ent) and GetEntityType(ent) == 1 then
                DeleteEntity(ent)
            end
        end
    end
    self:OnDestroy(stateId, contract, LoadedBoostingContracts[self.contractId].groupId)
    self.groupId = nil
    self.started = false
    LoadedBoostingContracts[self.contractId].activeMission = nil
    if not dontDelete then
        Missions[self.taskId] = nil
    end
end

function Mission:Finish()
    self.enableTick = false
    local result = MySQL.update.await("UPDATE boosting_contracts_tasks SET finished = 1 WHERE id = @id", {
        ["@id"] = self.taskId
    })
    LoadedBoostingContracts[self.contractId].missions[self.taskContractId].active = false
    if result then
        LoadedBoostingContracts[self.contractId].missions[self.taskContractId].finished = true
        MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0, finished = 1 WHERE id = @id", {
            ["@id"] = self.taskId
        })
        self.finished = true
        if self.OnFinish then
            self:OnFinish()
        end
        self:Destroy(self.stateId, true)
    end
    if LoadedBoostingContracts[self.contractId].missions[self.taskContractId + 1] then
        local nextTask = LoadedBoostingContracts[self.contractId].missions[self.taskContractId + 1]
        local task = LoadedBoostingContracts[self.contractId].missions[self.taskContractId]
        if task.nextMissionCooldown then
            local cooldown = task.nextMissionCooldown[LoadedBoostingContracts[self.contractId].vehicleClass] or task.nextMissionCooldown["default"]
            nextTask.availableTimestamp = os.time() + cooldown
            MySQL.update.await("UPDATE boosting_contracts_tasks SET availableTimestamp = FROM_UNIXTIME(@timestamp) WHERE id = @id", {
                ["@timestamp"] = nextTask.availableTimestamp,
                ["@id"] = nextTask.id
            })
        end
        local autoStart = (not nextTask.availableTimestamp) and nextTask.autoStart or false
        if autoStart then
            local nextMission = LoadMission(self.contractId, nextTask.id, self.stateId)
            if nextMission then
                nextMission:Start(self.stateId)
            end
        end
    else
        
        LoadedBoostingContracts[self.contractId]:Finish()
    end
end

function Mission:Cancel()
    local result = MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0 WHERE id = @id", {
        ["@id"] = self.taskId
    })
    self.enableTick = false
    if result then
        LoadedBoostingContracts[self.contractId].missions[self.taskContractId].active = false
        MySQL.update.await("UPDATE boosting_contracts_tasks SET active = 0 WHERE id = @id", {
            ["@id"] = self.taskId
        })
        self:Destroy(self.stateId, true)
        if LoadedBoostingContracts[self.contractId].vehEntity and DoesEntityExist(LoadedBoostingContracts[self.contractId].vehEntity) then
            LoadedBoostingContracts[self.contractId]:RemoveKeys()
            Entity(LoadedBoostingContracts[self.contractId].vehEntity).state.Deleted = true
            DeleteEntity(LoadedBoostingContracts[self.contractId].vehEntity)
        end
        LoadedBoostingContracts[self.contractId].vehEntity = nil
    end
    LoadedBoostingContracts[self.contractId]:UpdateActive()
end

function Mission:GetProgress()
    return LoadedBoostingContracts[self.contractId].missions[self.taskContractId].progress
end

function Mission:GetTarget()
    return LoadedBoostingContracts[self.contractId].missions[self.taskContractId].target
end

function Mission:IsAnyMemberCloseToCoords(coords, distance)
    local group = self:GetMissionGroup()
    if not group then return false end
    local members = group.getMembers()
    for k, v in pairs(members) do
        local playerPed = GetPlayerPed(v.src)
        if DoesEntityExist(playerPed) then
            local playerCoords = GetEntityCoords(playerPed)
            local dist = #(playerCoords - coords)
            if dist < distance then
                return true
            end
        end
    end
    return false
end

function Mission:AddProgress(count)
    count = count or 1
    local result = MySQL.update.await("UPDATE boosting_contracts_tasks SET progress = progress + @count WHERE id = @id", {
        ["@count"] = count,
        ["@id"] = self.taskId
    })
    if result then
        LoadedBoostingContracts[self.contractId].missions[self.taskContractId].progress = LoadedBoostingContracts[self.contractId].missions[self.taskContractId].progress + count
        if LoadedBoostingContracts[self.contractId].missions[self.taskContractId].progress >= LoadedBoostingContracts[self.contractId].missions[self.taskContractId].target then
            self:Finish()
        end
    end
    if self.OnProgress then
        self:OnProgress(LoadedBoostingContracts[self.contractId].missions[self.taskContractId].progress)
    end
    LoadedBoostingContracts[self.contractId]:UpdateActive()
end

function Mission:SpawnVehicle(source, coords, modelHash, stayAfterMission)
    local vehData = SpawnVeh(source, modelHash, coords)
    if not vehData or not vehData.veh then return end
    while not DoesEntityExist(vehData.veh) do
        Citizen.Wait(100)
    end
    LoadedBoostingContracts[self.contractId].spawnedVehicles = LoadedBoostingContracts[self.contractId].spawnedVehicles or {}
    LoadedBoostingContracts[self.contractId].spawnedVehicles[vehData.VIN] = vehData.veh
    if stayAfterMission then
        LoadedBoostingContracts[self.contractId].vehStayAfterMission = LoadedBoostingContracts[self.contractId].vehStayAfterMission or {}
        LoadedBoostingContracts[self.contractId].vehStayAfterMission[vehData.VIN] = stayAfterMission
    end

    return vehData.veh
end

function Mission:SpawnContractVehicle(source, coords)
    --print("SPAWN VEHICLE FOR CONTRACT", source, coords)
    local modelHash = joaat(LoadedBoostingContracts[self.contractId].vehicleModel)
    local vehData = SpawnVeh(source, modelHash, coords)
    --print("SPAWNED VEHICLE FOR CONTRACT", json.encode(vehData))
    if not vehData or not vehData.veh then return end
    --print("SPAWNED VEHICLE FOR CONTRACT2", vehData.veh)

    while not DoesEntityExist(vehData.veh) do
        Citizen.Wait(100)
    end

    while NetworkGetEntityOwner(vehData.veh) == -1 do
        Citizen.Wait(100)
    end

    LoadedBoostingContracts[self.contractId].vehEntity = vehData.veh
    Entity(vehData.veh).state.isBoostingVehicle = self.contractId

    local vehicleClass = LoadedBoostingContracts[self.contractId].vehicleClass
    if vehicleClass == "A" or vehicleClass == "S" then
        TriggerClientEvent("prp-boosting:randomVehicleTuning", source, NetworkGetNetworkIdFromEntity(vehData.veh))
    end

    return vehData.veh
end

function Mission:GetMissionGroup()
    local group  = exports["prp-bridge"]:GetGroupByUuid(LoadedBoostingContracts[self.contractId].groupId)
    if not group then
        local src = bridge.fw.getSrcFromIdentifier(LoadedBoostingContracts[self.contractId].ownerStateId)
        if not src then
            print("Failed to get source for ownerStateId", LoadedBoostingContracts[self.contractId].ownerStateId)
            self:Fail()
            return
        end
        local newGroup = exports["prp-bridge"]:CreateGroup(src)
        if not newGroup.success then
            return
        end
        group = newGroup.group
        LoadedBoostingContracts[self.contractId].groupId = group.getUuid()
    end
    return group
end

function Mission:SendSMSMessage(message, number, contactName, coords)
    local group = self:GetMissionGroup()
    if not group then return end
    if number == nil then
        if not LoadedBoostingContracts[self.contractId].contractNumber then
            LoadedBoostingContracts[self.contractId].contractNumber = ("%s-%s-%s"):format(math.random(1000, 9999), math.random(1000, 9999), math.random(1000, 9999))
        end
        number = LoadedBoostingContracts[self.contractId].contractNumber
    end
    local members = group.getMembers()
    for k, v in pairs(members) do
        if message and message ~= "" then
            bridge.phone.sendMessage(v.src, number, message)
        end
        if coords then
            bridge.phone.sendCoords(v.src, number, coords)
        end
    end
end

function Mission:SendEventToMembers(eventName, ...)
    local msg = msgpack.pack_args(...)
    local msgLen = msg:len()
    local group = exports["prp-bridge"]:GetGroupByUuid(LoadedBoostingContracts[self.contractId].groupId)
    if not group then return end
    local members = group.getMembers()
    for k, v in pairs(members) do
        if v.src and DoesPlayerExist(v.src) then
            TriggerClientEventInternal(eventName, v.src, msg, msgLen)
        end
    end
end

function Mission:SendNotificationToMembers(notifyType, title)
    local group = exports["prp-bridge"]:GetGroupByUuid(LoadedBoostingContracts[self.contractId].groupId)
    if not group then return end
    local members = group.getMembers()
    for k, v in pairs(members) do
        bridge.fw.notify(v.src, notifyType, title)
    end
end

function Mission:GetMembers()
    local group = exports["prp-bridge"]:GetGroupByUuid(LoadedBoostingContracts[self.contractId].groupId)
    if not group then return {} end
    return group?.getMembers() or {}
end

function Mission:Fail(failContract, dontRemoveVeh)
    self:Cancel()
    if failContract then
        LoadedBoostingContracts[self.contractId]:Fail(dontRemoveVeh)
    else
        LoadedBoostingContracts[self.contractId]:OnMissionCancel(self.taskContractId)
    end
end

function Mission:CreateLocalObject(model, coords, freeze, placeOnGround, visibleForMembers)
    MissionObjectId = MissionObjectId + 1
    local objectId = MissionObjectId
    MissionObjects[objectId] = { missionId = self.taskId, model = model, coords = coords, freeze = freeze, placeOnGround = placeOnGround }
    if visibleForMembers then
        self:SendEventToMembers("prp-boosting:createLocalObject", objectId, MissionObjects[objectId])
    else
        TriggerClientEvent("prp-boosting:createLocalObject", -1, objectId, MissionObjects[objectId])
    end
    self.localObjects[objectId] = true
    return objectId
end

function Mission:CreateLocalPed(model, coords, freeze, placeOnGround, visibleForMembers)
    MissionObjectId = MissionObjectId + 1
    local objectId = MissionObjectId
    MissionObjects[objectId] = { missionId = self.taskId, model = model, coords = coords, freeze = freeze, placeOnGround = placeOnGround, type = "ped" }
    if visibleForMembers then
        self:SendEventToMembers("prp-boosting:createLocalObject", objectId, MissionObjects[objectId])
    else
        TriggerClientEvent("prp-boosting:createLocalObject", -1, objectId, MissionObjects[objectId])
    end
    self.localObjects[objectId] = true
    return objectId
end

function Mission:RemoveLocalObject(objectId)
    if MissionObjects[objectId] then
        MissionObjects[objectId] = nil
        TriggerClientEvent("prp-boosting:removeLocalObject", -1, objectId)
        self.localObjects[objectId] = nil
    end
end

function Mission:RemoveLocalPed(objectId)
    return self:RemoveLocalObject(objectId)
end

function Mission:SetLocalObjectAnim(objectId, anim)
    if MissionObjects[objectId] then
        MissionObjects[objectId].anim = anim
        TriggerClientEvent("prp-boosting:setLocalObjectAnim", -1, objectId, anim)
    end
end

function Mission:AddLocalObjectTarget(objectId, targetName, targetOptions)
    if MissionObjects[objectId] then
        if not MissionObjects[objectId].targets then MissionObjects[objectId].targets = {} end
        MissionObjects[objectId].targets[targetName] = targetOptions
        TriggerClientEvent("prp-boosting:addLocalObjectTarget", -1, objectId, targetName, targetOptions)
    end
end

function Mission:RemoveLocalObjectTarget(objectId, targetName)
    if MissionObjects[objectId] then
        if MissionObjects[objectId].targets and MissionObjects[objectId].targets[targetName] then
            MissionObjects[objectId].targets[targetName] = nil
            TriggerClientEvent("prp-boosting:removeLocalObjectTarget", -1, objectId, targetName)
        end
    end
end

function Mission:AddTargetOnVehicle(vehNetId, targetName, targetOptions)
    if not self.vehTargets then self.vehTargets = {} end
    if not self.vehTargets[vehNetId] then self.vehTargets[vehNetId] = {} end
    self.vehTargets[vehNetId][targetName] = targetOptions
    TriggerClientEvent("prp-boosting:addVehicleTarget", -1, self.taskId, vehNetId, targetName, targetOptions)
end

function Mission:RemoveTargetOnVehicle(vehNetId, targetName)
    if not self.vehTargets then return end
    if self.vehTargets[vehNetId] then
        self.vehTargets[vehNetId][targetName] = nil
        TriggerClientEvent("prp-boosting:removeVehicleTarget", -1, self.taskId, vehNetId, targetName)
    end
end

function Mission:Timeout()
    self:Cancel()
    LoadedBoostingContracts[self.contractId]:Fail()
end

function Mission:NpcCheck(npcLocations, forceSpawn, guardDistance, neutral)
    local npcConfig = Config.NpcConfig[LoadedBoostingContracts[self.contractId].vehicleClass]
    if self.npcSpawned then return end
    if not npcConfig then return end
    local peds = {}
    for _, coords in pairs(npcLocations) do
        if math.random(1, 100) <= npcConfig.spawnChance or forceSpawn then
            local weaponHash = WeightedRandom(npcConfig.weapons, "weapon")
            local pedModel = WeightedRandom(npcConfig.models, "model")
            peds[#peds + 1] = { coords = coords, weapon = weaponHash, model = pedModel, guardDistance = guardDistance, isNeutral = neutral }
        end
    end
    local ownerSource = bridge.fw.getSrcFromIdentifier(self.stateId)
    if not ownerSource then return end
    local netIds = lib.callback.await("prp-boosting:spawnPeds", ownerSource, peds, self.taskId)
    if netIds then
        self.npcNetIds = netIds
        self.npcSpawned = true
    end
end

function Mission:SetNpcsAggresive()
    for k, v in pairs(self.npcNetIds) do
        TriggerClientEvent("prp-boosting:setPedAggresive", NetworkGetEntityOwner(NetworkGetEntityFromNetworkId(v)), v)
    end
end

function Mission:StartLocalPedDialog(source, objectId, pedName, title, dialog, options)
    local dialogData = {
        id = "__BOOSTING__"..self.contractId.."__"..self.taskId,
        center = true,
        pedName = pedName,
        title = title,
        dialog = dialog,
        options = options,
    }

    local selectedDialog = lib.callback.await("prp-boosting:startPedDialog", source, objectId, dialogData)
    if not selectedDialog then return nil end

    return selectedDialog
end

Citizen.CreateThread(function()
    local tickId = 0
    while true do
        tickId = tickId + 1
        if tickId > 100 then tickId = 0 end
        for k, v in pairs(Missions) do
            if LoadedBoostingContracts[v.contractId].missions[v.taskContractId].active and v.OnTick and v.enableTick and not v.performingTick then
                Citizen.CreateThread(function()
                    v.performingTick = true
                    --v.OnTick(v, v.stateId, LoadedBoostingContracts[v.contractId], v.taskId, tickId)
                    local success, err = pcall(v.OnTick, v, v.stateId, LoadedBoostingContracts[v.contractId], v.taskId, tickId)
                    v.performingTick = false
                    if not success then
                        print("ERROR DURING MISSION TICK", err)
                        v:Fail()
                    end
                end)
            end
            if v:GetMetadata().timeout and os.time() - v.startTime > v:GetMetadata().timeout then
                v:Timeout()
            end
        end
        Citizen.Wait(100)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for k, v in pairs(Missions) do
            v:Destroy(v.stateId)
        end
    end
end)

function GetActiveMissionByStateId(stateId)
    stateId = tostring(stateId)
    local contractId = ContractMembers[stateId]
    if not contractId then return end
    local contract = LoadBoostingContract(contractId)
    if not contract then return end
    for k, v in pairs(contract.missions) do
        if v.active then
            return LoadMission(contract.id, v.id, stateId)
        end
    end
end

RegisterNetEvent("prp-characters:server:characterSelected", function(source, stateId)
    Citizen.Wait(300)
    TriggerClientEvent("prp-boosting:syncMissionObjects", source, MissionObjects)
    local vehicleTargets = {}
    for k, v in pairs(MissionObjects) do
        if v.vehTargets then
            vehiclesTargets[k] = v.vehTargets
        end
    end
    if next(vehicleTargets) then
        TriggerClientEvent("prp-boosting:syncVehicleTargets", source, vehicleTargets)
    end
end)

AddEventHandler("prp-base:activityCompleted", function(source, activityName, count)
    local stateId = bridge.fw.getIdentifier(source)
    local mission = GetActiveMissionByStateId(stateId)
    if mission and mission.OnActivityEvent then
        mission:OnActivityEvent(stateId, activityName, count)
    end
end)

-- AddEventHandler('playerDropped', function(reason)
--     local _source = source
--     local stateId = bridge.fw.getIdentifier(_source)
--     local mission = GetActiveMissionByStateId(stateId)
--     if not mission then return end
--     local contract = LoadBoostingContract(mission.contractId)
--     if not contract then return end
--     if tonumber(contract.ownerStateId) == tonumber(stateId) then
--         mission:Fail()
--     end
-- end)

local CREATE_AUTOMOBILE = `CREATE_AUTOMOBILE`
function CreateAutomobile(model, coords, heading)
    if not heading then heading = 0.0 end

    local veh = Citizen.InvokeNative(CREATE_AUTOMOBILE, model, coords.x, coords.y, coords.z, heading + 0.0)

    if DoesEntityExist(veh) then
        return veh
    end
    return nil
end

function SpawnVeh(src, model, coords)
    local veh = CreateAutomobile(model, coords.xyz, coords.w)
    if not veh then return end
    local plate = lib.string.random("........"):upper()
    local vin = lib.string.random("................."):upper()
    while not DoesEntityExist(veh) do
        Citizen.Wait(10)
    end
    local vehState = Entity(veh).state
    vehState.VIN = vin
    SetVehicleNumberPlateText(veh, plate)
    bridge.vfuel.set(src, veh, 100)
    SetEntityOrphanMode(veh, 2)

    return {veh = veh, VIN = vin}
end