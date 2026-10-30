local takenLocations = {}
local MissionConfig = {
    metadata = {
        label = locale("CRUSHER_MISSION_LABEL"),
        startable = false,
        autoStart = true
    },
    crusherCoords = {
        {
            coords = vec4(-523.7,-1680.7,18.2,305.6),
        },
        {
            coords = vec4(1220.2,-2445.3,43.5,120.1),
        },
        {
            coords = vec4(1558.0,-2186.7,76.3,163.5),
        },
        {
            coords = vec4(2424.7,3129.8,47.2,266.5),
        },
        {
            coords = vec4(1616.0,3777.3,33.7,126.5),
        },
    },
    itemsToAward = {
        default = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {30, 40},
            }
        },
        ['D'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {30, 40},
            }
        },
        ['C'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {30, 40},
            }
        },
        ['B'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {50, 80},
            }
        },
        ['A'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {50, 80},
            }
        },
        ['S'] = {
            {
                itemId = "boosting_scrap",
                weight = 1,
                amount = {50, 80},
            }
        },
    },
}

local DropOffMission = {}
DropOffMission.__index = DropOffMission
DropOffMission = setmetatable(DropOffMission, Mission)

function DropOffMission:OnStart(stateId, contract, groupId)
    local locations = {}
    local stealLocations = MissionConfig.crusherCoords
    for k, v in pairs(stealLocations) do
        if not v.taken then
            table.insert(locations, k)
        end
    end
    if #locations == 0 then
        return self:Cancel()
    end
    local location = locations[math.random(1, #locations)]
    self.location = location
    self.locationCoords = stealLocations[location].coords
    stealLocations[location].taken = true
    self.crushing = false
    self:SendEventToMembers("prp-boosting:setMissionBlip", "dropOff", "Crusher Location", self.locationCoords.xyz, 500, 3, true)
    self.crusher = self:CreateLocalObject(`reck_boosting_crusher`, self.locationCoords, true, true)
    self.crusherOpenCol = self:CreateLocalObject(`reck_boosting_crusher_open`, self.locationCoords, true, true)
    self:SetLocalObjectAnim(self.crusher, {
        dict = "reck@boosting@crusher",
        name = "crushing",
        stayInAnim = true
    })
    self:AddLocalObjectTarget(self.crusherOpenCol, "crusher_crush", {
        label = locale("CRUSH_VEHICLE"),
        icon = "fas fa-box-open",
        event = "prp-boosting:crushVehicle",
    })
    -- self:SendSMSMessage("", nil, "BoostWorks")
end

function DropOffMission:OnDestroy(stateId, contract, groupId)
    if self.location then
        MissionConfig.crusherCoords[self.location].taken = false
    end
end

function DropOffMission:OnTick(stateId, contract, groupId, tickId)
    local veh = LoadedBoostingContracts[self.contractId].vehEntity
    if not veh or not DoesEntityExist(veh) then
        if self.crushing then return end
        self:Fail()
        return
    end
end

function DropOffMission:GetMetadata()
    return MissionConfig.metadata
end

function DropOffMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

RegisterNetEvent("prp-boosting:crushVehicle", function(missionId, objectId)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.missionName == "deliver_crusher" and mission.taskId == playerMission.taskId then
        if mission.crushing then
            return bridge.fw.notify(source, "error", locale("CRUSHER_ACTIVE"))
        end
        if #(GetEntityCoords(LoadedBoostingContracts[mission.contractId].vehEntity) - mission.locationCoords.xyz) > 2.0 then
            return bridge.fw.notify(source, "error", locale("CRUSHER_VEHICLE_NOT_INSIDE"))
        end
        mission.crushing = true
        Citizen.Wait(2000)
        mission.crusherCloseCol = mission:CreateLocalObject(`reck_boosting_crusher_closed`, mission.locationCoords, true, true)
        mission:RemoveLocalObject(mission.crusherOpenCol)
        mission.crusherOpenCol = nil
        mission:SetLocalObjectAnim(mission.crusher, {
            dict = "reck@boosting@crusher",
            name = "crushing",
            stayInAnim = true
        })
        Citizen.Wait(1500)
        local veh = LoadedBoostingContracts[mission.contractId].vehEntity
        if not veh or not DoesEntityExist(veh) then
            return
        end
        LoadedBoostingContracts[mission.contractId]:RemoveKeys(veh)
        DeleteEntity(veh)
        Citizen.Wait(14000)
        mission:RemoveLocalObject(mission.crusherCloseCol)
        mission.crusherCloseCol = nil
        mission.crusherOpenCol = mission:CreateLocalObject(`reck_boosting_crusher_open`, mission.locationCoords, true, true)
        mission.cube = mission:CreateLocalObject(`reck_boosting_cube`, mission.locationCoords + vector4(0.0, 0.0, 2.5, 0.0), true, true)
        mission:AddLocalObjectTarget(mission.cube, "crusher_cube", {
            label = locale("CRUSH_COLLECT_SCRAP"),
            icon = "fas fa-box-open",
            event = "prp-boosting:collectScrap",
        })
    end
end)

RegisterNetEvent("prp-boosting:collectScrap", function(missionId, objectId)
    local source = source
    local mission = Missions[missionId]
    local stateId = bridge.fw.getIdentifier(source)
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.missionName == "deliver_crusher" and mission.taskId == playerMission.taskId then
        if not mission.crushing then
            return bridge.fw.notify(source, "error", locale("CRUSH_VEHICLE_NOT_CRUSHED"))
        end
        if not mission.cube then
            return bridge.fw.notify(source, "error", locale("CRUSHER_NOTHING_TO_COLLECT"))
        end
        local success = lib.callback.await("prp-boosting:progressBar", source, "Collecting Scrap", 15000, "anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", true, nil)
        if not success then
            bridge.fw.notify(source, "error", "You failed to collect the scrap")
            return
        end

        if not mission.cube then
            return bridge.fw.notify(source, "error", locale("CRUSHER_NOTHING_TO_COLLECT"))
        end
        mission:RemoveLocalObject(mission.cube)
        mission.cube = nil

        local contract = LoadedBoostingContracts[mission.contractId]
        local class = contract.vehicleClass
        local awardableItems = lib.table.deepclone(MissionConfig.itemsToAward.default)
        
        if MissionConfig.itemsToAward[class] then
            for _, item in pairs(MissionConfig.itemsToAward[class]) do
                table.insert(awardableItems, item)
            end
        end
        
        local awardCounts = {};
        for i = 1, 1 do
            local item = WeightedRandom(awardableItems)
            local amount = type(item.amount) == "table" and math.random(item.amount[1], item.amount[2]) or item.amount
            awardCounts[item.itemId] = (awardCounts[item.itemId] or 0) + amount
        end
        
        for itemId, amount in pairs(awardCounts) do
            bridge.inv.giveItem(source, itemId, amount)
        end
        mission:AddProgress(1)
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["deliver_crusher"] = DropOffMission
end)