local takenLocationCoords = {}
local MissionConfig = {
    cooldown = 180, -- sec
    locations = {
        {
            vehCoords = {
                vector4(938.975, -91.973, 78.345, 42.339),
                vector4(990.618, 24.928, 71.461, 96.924),
                vector4(920.033, -78.549, 78.342, 58.527),
                vector4(904.355, -78.085, 78.343, 239.162),
                vector4(900.357, -94.310, 78.342, 327.743),
                vector4(859.605, -68.520, 78.343, 326.909),
                vector4(856.881, -32.137, 78.344, 238.918)
            },
            -- pedCoords = vector4(990.618, 24.928, 71.461 - 0.95, 96.924),
            pedCoords = vector4(921.041, 42.083, 81.096 - 0.95, 30.384), 
            locationLabel = locale("VALET_MISSION_LOCATION_LABEL"),
            requiredClothing = {
                mp_m_freemode_01 = {
                    components = {
                        torso2 = {
                            [4] = true,
                            [10] = true,
                            [11] = true,
                            [13] = true,
                            [21] = true,
                            [25] = true,
                            [26] = true,
                            [27] = true,
                            [28] = true,
                            [29] = true,
                            [30] = true,
                            [31] = true,
                            [32] = true,
                            [290] = true,
                            [294] = true,
                            [295] = true,
                            [311] = true,
                            [312] = true,
                            [512] = true,
                            [515] = true,
                        },
                        leg = {
                            [24] = true,
                            [25] = true,
                            [96] = true,
                            [173] = true,
                            [187] = true,
                            [204] = true,
                        }
                    }
                },
                mp_f_freemode_01 = {
                    components = {
                        torso2 = {
                            [6] = true,
                            [7] = true,
                            [24] = true,
                            [25] = true,
                            [124] = true,
                            [305] = true,
                            [306] = true,
                        },
                        leg = {
                            [6] = true,
                            [34] = true,
                            [37] = true,
                            [133] = true,
                            [150] = true,
                            [187] = true,
                        }
                    }
                }
            }
        },
    },
    metadata = {
        label = locale("VALET_MISSION_LABEL"),
        startable = true,
        isCheckpoint = true,
    },
    prerequisites = {
        {
            label = locale("VALET_OUTFIT"),
            type = "other",
            value = "clothes",
        },
    },
}

local StealMission = {}
StealMission.__index = StealMission
StealMission = setmetatable(StealMission, Mission)

function StealMission:OnStart(stateId, contract, groupId)
    self.locationIndex = math.random(1, #MissionConfig.locations)
    self.location = MissionConfig.locations[self.locationIndex]
    local locationCoords = {}
    for k, v in pairs(self.location.vehCoords) do
        if not takenLocationCoords[self.locationIndex..'-'..k] then
            table.insert(locationCoords, k)
        end
    end

    self.locationCoordsIndex = locationCoords[math.random(1, #locationCoords)] 
    takenLocationCoords[self.locationIndex..'-'..self.locationCoordsIndex] = true
    self.locationCoords = self.location.vehCoords[self.locationCoordsIndex]

    self:SendSMSMessage(locale("VALET_MISSION_START_TEXT", self.location.locationLabel), nil, "BoostWorks")
    self.pedId = self:CreateLocalPed(`s_m_y_valet_01`, self.location.pedCoords, true, true);
    self:AddLocalObjectTarget(self.pedId, "talk_valet_boosting", {
        label = locale("TALK_TO", locale("VALET_MANAGER")),
        icon = "fas fa-person",
        event = "prp-boosting:valet:talk",
    })

    self.enableTick = true
end

function StealMission:OnDestroy(stateId, contract, groupId)
    takenLocationCoords[self.locationIndex..'-'..self.locationCoordsIndex] = nil
end

function StealMission:OnTick(stateId, contract, groupId, tickId)
    if not LoadedBoostingContracts[self.contractId].vehEntity and tickId % 5 == 0 and self.locationCoords and self:IsAnyMemberCloseToCoords(vector3(self.locationCoords.x, self.locationCoords.y, self.locationCoords.z), 250.0) then
        self:SpawnContractVehicle(bridge.fw.getSrcFromIdentifier(stateId), self.locationCoords)
        local vehEntity = LoadedBoostingContracts[self.contractId].vehEntity
        TriggerClientEvent("prp-boosting:placeVehOnGround", NetworkGetEntityOwner(vehEntity), NetworkGetNetworkIdFromEntity(vehEntity))
        SetVehicleDoorsLocked(vehEntity, 2)
        Entity(vehEntity).state.Locked = true
        Entity(vehEntity).state.DisableLockpick = true
    end
    if LoadedBoostingContracts[self.contractId].vehEntity then
        local veh = LoadedBoostingContracts[self.contractId].vehEntity
        if GetIsVehicleEngineRunning(veh) then
            self:AddProgress(1)
        end
    end
end

function StealMission:GetMetadata()
    return MissionConfig.metadata
end

function StealMission:GetPrerequisites()
    return MissionConfig.prerequisites
end

function StealMission:VerifyPlayerOutfit(src)
    local requiredClothing = MissionConfig.locations[self.locationIndex].requiredClothing;
    if not requiredClothing then
        return true, true
    end

    local result = lib.callback.await("prp-boosting:verifyOutfit", src, requiredClothing)
    if not result then return false, false end
    return true, false
end

RegisterNetEvent("prp-boosting:valet:talk", function(missionId, objectId)
    local source = source
    local stateId = bridge.fw.getIdentifier(source)
    local mission = Missions[missionId]
    local playerMission = GetActiveMissionByStateId(stateId)
    if mission and playerMission and mission.taskId == playerMission.taskId then
        if mission.lastTry and os.time() - mission.lastTry < MissionConfig.cooldown then
            mission:SendNotificationToMembers("error", locale("NOT_TALKING_TO_YOU"))
            return
        end

        local contract = LoadedBoostingContracts[mission.contractId]
        local options = {};
        local prevModels = {contract.vehicleModel}; 
        for i = 1, 4 do
            local vehData = GetVehicleFromClass(contract.vehicleClass, prevModels) 
            if not vehData then break end
            table.insert(prevModels, vehData.modelName)
            table.insert(options, {
                id = i,
                text = vehData.label,
                description = locale("IM_MOVING_THIS"),
                vehName = vehData.modelName,
            })
        end

        local correctVehData = Config.Vehicles[contract.vehicleModel]
        local correctIndex = 1
        if #options > 0 then
            correctIndex = math.random(1, #options)
            options[correctIndex].text = correctVehData.label
            options[correctIndex].vehName = contract.vehicleModel
        else
            options = {
                { id = 1, text = correctVehData.label, description = locale("IM_MOVING_THIS"), vehName = contract.vehicleModel }
            }
        end

        local hasOutfit, asCustomPed = mission:VerifyPlayerOutfit(source);
        local dialog = locale("WHAT_DO_YOU_WANT")
        if not hasOutfit then
            dialog = locale("CAN_I_HELP_YOU")
        end
        local answerIndex = mission:StartLocalPedDialog(source, mission.pedId, locale("VALET_MANAGER"), locale("TALK_TO", locale("VALET_MANAGER")), dialog, options)
        if answerIndex == nil then return end

        if not hasOutfit then
            mission.lastTry = os.time();
            if answerIndex ~= correctIndex then
                mission:SendNotificationToMembers("error", locale("WE_DONT_HAVE_THAT_CAR"))
                return
            end

            mission:SendNotificationToMembers("error", locale("NOT_THE_OWNER_OF_THIS_CAR"))
            return
        end

        if answerIndex ~= correctIndex then
            mission:SendNotificationToMembers("error", locale("WE_DONT_HAVE_THE_CAR_OUTFIT"))
            return
        end
        
        local vehEntity = LoadedBoostingContracts[mission.contractId].vehEntity
        local vehEnt = Entity(vehEntity)
        if asCustomPed then
            mission:SendNotificationToMembers("success", locale("VALET_SUCCESS_CUSTOM_PED"))
        else
            mission:SendNotificationToMembers("success", locale("VALET_SUCCESS"))
        end

        bridge.vkeys.give(source, vehEntity)
    end
end)

Citizen.CreateThread(function()
    RegisteredMissions["steal_valet"] = StealMission
end)

