local ShotGps = {};
local vehicleGps = {}
local gpsId = 0

local function placeGPS(source, data)
    local item = bridge.inv.getSlot(source, data.slot)
    if not item then return false end

    if not item.metadata then
        item.metadata = {}
    end

    if not item.metadata.uuid then
        item.metadata.uuid = GenerateUUID()
    end

    local vehNetId = lib.callback.await("prp-policeutils:getVehicleInFront", source)
    if not vehNetId then return false, locale("NO_VEHICLE_IN_FRONT") end

    -- Prevent placing multiple placeable GPS on the same vehicle
    local vehEntity = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(vehEntity) then return false, locale("VEHICLE_DOES_NOT_EXIST") end
    local existingGps = Entity(vehEntity).state.gpsData
    if existingGps and next(existingGps) then
        return false, locale("GPS_ALREADY_INSTALLED")
    end

    local completedProgress = lib.callback.await("prp-policeutils:placeGps", source)
    if not completedProgress then return false end

    if not InstallGps(vehNetId, source, item.metadata) then return false, locale("GPS_INSTALL_FAILED") end

    local vehEntity = NetworkGetEntityFromNetworkId(vehNetId)
    local objectId = exports["prp-bridge"]:CreateVehTempAttachObject(vehEntity, {
        model = GPS.attach.modelHash,
        bone = GPS.attach.boneId,
        offset = GPS.attach.offset,
        rotation = GPS.attach.rot,
        disableCollistion = { false, false }
    })

    if not objectId then return false end

    -- Store objectId per GPS UUID so each can be removed individually
    vehicleGps[vehNetId][item.metadata.uuid].objectId = objectId

    bridge.fw.notify(source, locale("GPS_PLACED"))
    bridge.inv.removeItem(source, GPS.Items.placeable_gps, 1, nil, data.slot)

    return true
end
bridge.fw.registerItemUse(GPS.Items.placeable_gps, placeGPS)

function InstallGps(vehNetId, pSource, metaData, shotData)
    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(veh) then return false, locale("VEHICLE_DOES_NOT_EXIST") end

    if not vehicleGps[vehNetId] then
        vehicleGps[vehNetId] = {}
    end

    local identifier = bridge.fw.getIdentifier(pSource)
    if not identifier then return false, locale("PLAYER_DOES_NOT_EXIST") end
    local ownerName = bridge.fw.getCharacterName(identifier) or "Unknown"
    gpsId = gpsId + 1
    vehicleGps[vehNetId][metaData.uuid] = {
        netId = vehNetId,
        id = gpsId,
        label = "GPS #" .. gpsId .. " - " .. (ownerName or "Unknown"),
        isPolice = false,
        owner = bridge.fw.getIdentifier(pSource),
        gpsData = metaData,
        shotData = shotData,
        time = os.time(),
    }
    local vehState = Entity(veh).state.gpsData;
    if not vehState then
        vehState = {}
    end
    vehState[metaData.uuid] = gpsId
    Entity(veh).state.gpsData = vehState

    return true
end

RegisterNetEvent("prp-policeutils:placeShotGps", function(vehNetId, offset, rot)
    local source = source
    if not ShotGps[source] then return end

    local sucess, err = InstallGps(vehNetId, source, ShotGps[source], { offset = offset, rot = rot })
    if not sucess then return print(err) end


    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(veh) then return end

    local objectId = exports["prp-bridge"]:CreateVehTempAttachObject(veh, {
        model = `prp_shootable_gps`,
        bone = "chassis",
        offset = offset,
        rotation = rot,
        rotationOrder = 0,
        disableCollistion = { true, true }
    })

    local uuid = ShotGps[source].uuid
    vehicleGps[vehNetId][uuid].shotData.objectId = objectId
    vehicleGps[vehNetId][uuid].objectId = objectId
    Citizen.Wait(1); -- some attach object race condition?
    exports["prp-bridge"]:SetVehObjectData(veh, objectId, "gpsId", uuid)
    Citizen.Wait(1)
    exports["prp-bridge"]:SetVehObjectData(veh, objectId, "objectId", objectId)
    ShotGps[source] = nil
end)

RegisterNetEvent("prp-policeutils:removeGps", function(vehNetId, gpsUuidId)
    local source = source
    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(veh) then return end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(source))) > 10 then return end

    if not vehicleGps[vehNetId] then return end

    if not gpsUuidId then
        gpsUuidId, _ = next(vehicleGps[vehNetId])
    end

    local gpsEntry = vehicleGps[vehNetId][gpsUuidId]
    if not gpsEntry then return end

    if gpsEntry.objectId then
        exports["prp-bridge"]:RemoveVehTempAttachObject(veh, gpsEntry.objectId)
    end

    vehicleGps[vehNetId][gpsUuidId] = nil
    local vehState = Entity(veh).state.gpsData or {}
    vehState[gpsUuidId] = nil
    Entity(veh).state.gpsData = vehState
end)

RegisterNetEvent("prp-policeutils:scannerRemoveGps", function(vehNetId)
    local source = source
    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not DoesEntityExist(veh) then return end
    if #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(source))) > 10 then return end;

    TriggerClientEvent(
        "prp-bridge:sound:playSpatial",
        -1,
        "unmute.ogg",
        0.2,
        GetEntityCoords(GetPlayerPed(source)),
        5.0
    )

    if vehicleGps[vehNetId] then
        for _, gps in pairs(vehicleGps[vehNetId]) do
            if gps.objectId then
                exports["prp-bridge"]:RemoveVehTempAttachObject(veh, gps.objectId)
            end
        end
    end

    vehicleGps[vehNetId] = {}
    Entity(veh).state.gpsData = {}
end)

Citizen.CreateThread(function()
    exports["prp-bridge"]:RegisterObject({
        objectName = "veh_gps_attach",
        modelHash = GPS.attach.modelHash,
        offset = GPS.attach.offset,
        rotation = GPS.attach.rot,
        boneId = GPS.attach.boneId,
        disableCollision = true,
        completelyDisableCollision = true,
        isWeapon = false,
    })
end)

Citizen.CreateThread(function()
    while true do
        local stateIdSendTable = {}
        local currentTime = os.time()
        for vehNetId, gpsTbl in pairs(vehicleGps) do
            for k, v in pairs(gpsTbl) do
                local entity = v.netId and NetworkGetEntityFromNetworkId(v.netId)

                if v.gpsData.liveTime and v.gpsData.liveTime ~= -1 and currentTime - v.gpsData.time > v.gpsData.liveTime then
                    vehicleGps[vehNetId][k] = nil
                    goto continue
                end
                if not entity or not DoesEntityExist(entity) then
                    vehicleGps[vehNetId][k] = nil
                    goto continue
                end
                if currentTime - (v.lastPing or 0) > (v.gpsData.pingTime or 15) then
                    v.lastPing = currentTime

                    stateIdSendTable[v.owner] = stateIdSendTable[v.owner] or {}
                    table.insert(stateIdSendTable[v.owner], {
                        v.id,
                        GetEntityCoords(entity),
                        v.label,
                        v.gpsData.liveNearby and v.netId or false,
                        v.gpsData.pingTime or 15,
                    })
                end
                ::continue::
            end
        end

        for stateId, gpsTbl in pairs(stateIdSendTable) do
            local src = bridge.fw.getSrcFromIdentifier(stateId)
            if src then
                TriggerClientEvent("prp-policeutils:gpsUpdate", src, gpsTbl)
            end
        end

        Citizen.Wait(1000)
    end
end)

local inventoryHooks = {}
local function registerInventoryHooks()
    inventoryHooks[#inventoryHooks + 1] = bridge.inv.registerCreateItemHook(function(payload)
        if not payload.metadata then
            payload.metadata = {}
        end

        if not payload.metadata.uuid then
            payload.metadata.uuid = GenerateUUID()
        end

        return payload.metadata
    end, {
        itemFilter = {
            ['WEAPON_GPSLAUNCHER'] = true,
        }
    })
end
SetTimeout(0, registerInventoryHooks)

lib.callback.register("prp-policeutils:getGpsInLauncher", function(source, weaponSlot)
    local source = source

    local slot = bridge.inv.getSlot(source, weaponSlot)
    if not slot then return nil, nil end

    local count = bridge.inv.count(source, GPS.Items.shootable_gps)
    if count <= 0 then return nil, nil end

    if not slot.metadata then
        slot.metadata = {}
    end

    if not slot.metadata.uuid then
        slot.metadata.uuid = GenerateUUID()
        bridge.inv.setItemMetaDataKey(source, weaponSlot, "uuid", slot.metadata.uuid)
    end

    return slot.metadata.uuid, true
end)

RegisterNetEvent("prp-policeutils:shotLauncher", function(weaponSlot)
    local source = source;

    local item = bridge.inv.getSlot(source, weaponSlot)
    if not item then return end
    if item.name ~= "WEAPON_GPSLAUNCHER" then return end

    local count = bridge.inv.count(source, GPS.Items.shootable_gps)
    if count <= 0 then return end

    TriggerClientEvent("prp-policeutils:installedGps", source, nil, item.metadata.uuid)

    if item then
        ShotGps[source] = item.metadata
    end

    bridge.inv.removeItem(source, GPS.Items.shootable_gps, 1)
end)

AddEventHandler("entityRemoved", function(entity)
    local vin = Entity(entity)?.state?.VIN
    if vin and vehicleGps[vin] then
        for k, v in pairs(vehicleGps[vin]) do
            v.netId = nil
        end
    end
end)
