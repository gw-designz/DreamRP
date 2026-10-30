if not Config.Objects.enabled then return end

Objects = {}
Objects.registry = {}  -- [netId] = { owner, model, item }

-- Pending item → player mapping (set when item is used to deploy)
-- [playerSource] = itemName
local pendingDeployItem = {}

-- ============================================================
--  File-local helpers
-- ============================================================

-- Consumes a pending deploy-item slot and returns the item name, or nil.
local function popDeployItem(playerSource, modelHash)
    local itemName = pendingDeployItem[playerSource]
    if not itemName then return nil end

    local itemDef = Config.Objects.Items and Config.Objects.Items[itemName]
    if itemDef and itemDef.model then
        if joaat(itemDef.model) == modelHash then
            pendingDeployItem[playerSource] = nil
            return itemName
        end
    end
    return nil
end

-- Gives an item back to the player and notifies them.
local function returnItem(playerSource, itemName)
    Bridge.Inventory.addItem(playerSource, itemName, 1)
    local itemData  = Bridge.Inventory.getItemData(itemName)
    local itemLabel = (itemData and itemData.label) or itemName
    Bridge.Notify.showNotify(playerSource, locale("object_returned", itemLabel), "success")
end

-- Returns Config.Jobs entry for the player's job, or nil if not allowed.
local function getJobAccess(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return nil end
    return Config.Jobs[job.name]
end

-- Resolves a netId → entity handle (or nil if invalid).
local function getEntityFromNetId(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end
    return nil
end

-- Distance check: is playerSource within maxDist of entity?
local function isPlayerNearEntity(playerSource, entity, maxDist)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return false end
    return maxDist >= #(GetEntityCoords(ped) - GetEntityCoords(entity))
end

-- Finds the trunk item definition matching modelHash + itemName.
local function findTrunkItemDef(modelHash, itemName)
    local trunkCfg = Config.Objects.Trunk
    if not trunkCfg then return nil end

    for vehicleModel, items in pairs(trunkCfg.vehicles) do
        if GetHashKey(vehicleModel) == modelHash then
            for _, itemDef in ipairs(items) do
                if itemDef.item == itemName then return itemDef end
            end
        end
    end
    return nil
end

-- ============================================================
--  Register object
-- ============================================================

RegisterNetEvent("p_policejob/server/objects/register", function(netId)
    local playerSource = source

    if not getJobAccess(playerSource) then return end

    local entity = getEntityFromNetId(netId)
    if not entity then return end

    FreezeEntityPosition(entity, true)
    Entity(entity).state:set("PoliceObject", true, true)

    local modelHash = GetEntityModel(entity)
    local itemName  = popDeployItem(playerSource, modelHash)

    Objects.registry[netId] = {
        owner = playerSource,
        model = modelHash,
        item  = itemName,
    }

    Bridge.Debug(("[Objects] Player %s registered object netId=%s model=%s")
        :format(playerSource, netId, modelHash))
    Bridge.Logs.Send(playerSource, "Objects",
        locale("player_placed_object", GetEntityModel(entity)),
        Config.Webhooks.objects)
end)

-- ============================================================
--  Remove object (single)
-- ============================================================

RegisterNetEvent("p_policejob/server/objects/remove", function(netId)
    local playerSource = source

    -- Allow if steal is enabled OR player has job access
    if not Config.Objects.allowSteal and not getJobAccess(playerSource) then return end

    local entity = getEntityFromNetId(netId)
    if not entity then return end

    local maxDist = Config.Objects.interactDistance + 2.0
    if not isPlayerNearEntity(playerSource, entity, maxDist) then return end

    local entityState = Entity(entity).state
    if not (entityState and entityState.PoliceObject) then return end

    local record = Objects.registry[netId]
    DeleteEntity(entity)
    Objects.registry[netId] = nil

    if record and record.item then
        returnItem(playerSource, record.item)
    end

    TriggerClientEvent("p_policejob/client/objects/deleted", playerSource, netId)

    Bridge.Debug(("[Objects] Player %s removed object netId=%s"):format(playerSource, netId))
    -- locale("player_took_object") expects two %s: the object id and its coords
    local obj       = NetworkGetEntityFromNetworkId(netId)
    local objCoords = (obj and obj ~= 0) and tostring(GetEntityCoords(obj)) or "unknown"
    Bridge.Logs.Send(playerSource, "Objects",
        locale("player_took_object", tostring(netId), objCoords),
        Config.Webhooks.objects)
end)

-- ============================================================
--  Remove all objects of a model (bulk)
-- ============================================================

RegisterNetEvent("p_policejob/server/objects/removeAllByModel", function(modelHash)
    local playerSource = source

    if not Config.Objects.allowSteal and not getJobAccess(playerSource) then return end

    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return end

    local pedCoords  = GetEntityCoords(ped)
    local removedIds = {}

    for netId, record in pairs(Objects.registry) do
        if record.model == modelHash then
            local entity = getEntityFromNetId(netId)
            if entity and #(pedCoords - GetEntityCoords(entity)) <= 30.0 then
                DeleteEntity(entity)
                removedIds[#removedIds + 1] = netId
                Objects.registry[netId] = nil

                if record.item then
                    returnItem(playerSource, record.item)
                end
            end
        end
    end

    if #removedIds > 0 then
        TriggerClientEvent("p_policejob/client/objects/deletedBulk", playerSource, removedIds)
        Bridge.Logs.Send(playerSource, "Objects",
            locale("player_took_objects", modelHash),
            Config.Webhooks.objects)
    end
end)

-- ============================================================
--  Deploy spike strip
-- ============================================================

RegisterNetEvent("p_policejob/server/objects/deploySpikeStrip", function(netId)
    local playerSource = source

    local stripCfg = Config.Objects.SpikeStrip
    if not (stripCfg and stripCfg.enabled) then return end

    if not getJobAccess(playerSource) then return end

    local entity = getEntityFromNetId(netId)
    if not entity then return end

    -- Optional item consumption
    local hasItem = Bridge.Inventory.getItemCount(playerSource, "spikestrip") >= 1
    if hasItem then
        Bridge.Inventory.removeItem(playerSource, "spikestrip", 1)
    end

    Entity(entity).state:set("PoliceObject", true, true)
    Objects.registry[netId] = {
        owner = playerSource,
        model = GetEntityModel(entity),
        item  = hasItem and "spikestrip" or nil,
    }

    TriggerClientEvent("p_policejob/client/objects/playSpikeAnim", -1, netId)
    Bridge.Logs.Send(playerSource, "Objects", "Deployed spike strip", Config.Webhooks.objects)
end)

-- ============================================================
--  Trunk: take item from vehicle
-- ============================================================

RegisterNetEvent("p_policejob/server/objects/trunk/take", function(netId, itemName)
    local playerSource = source

    local trunkCfg = Config.Objects.Trunk
    if not (trunkCfg and trunkCfg.enabled) then return end
    if type(itemName) ~= "string" then return end
    if not getJobAccess(playerSource) then return end

    local entity = getEntityFromNetId(netId)
    if not entity then return end

    if not isPlayerNearEntity(playerSource, entity, trunkCfg.interactDistance + 2.0) then return end

    local itemDef = findTrunkItemDef(GetEntityModel(entity), itemName)
    if not itemDef then return end

    local currentCount = Bridge.Inventory.getItemCount(playerSource, itemName)
    if currentCount >= trunkCfg.maxHold then
        return Bridge.Notify.showNotify(playerSource, locale("trunk_already_have"), "error")
    end

    Bridge.Inventory.addItem(playerSource, itemName, 1)
    Bridge.Notify.showNotify(playerSource, locale("trunk_took_item", itemDef.label), "success")
    Bridge.Logs.Send(playerSource, "Objects",
        locale("trunk_log_took", itemName),
        Config.Webhooks.objects)
end)

-- ============================================================
--  Trunk: store item in vehicle
-- ============================================================

RegisterNetEvent("p_policejob/server/objects/trunk/store", function(netId, itemName)
    local playerSource = source

    local trunkCfg = Config.Objects.Trunk
    if not (trunkCfg and trunkCfg.enabled) then return end
    if type(itemName) ~= "string" then return end
    if not getJobAccess(playerSource) then return end

    local entity = getEntityFromNetId(netId)
    if not entity then return end

    if not isPlayerNearEntity(playerSource, entity, trunkCfg.interactDistance + 2.0) then return end

    local itemDef = findTrunkItemDef(GetEntityModel(entity), itemName)
    if not itemDef then return end

    if Bridge.Inventory.getItemCount(playerSource, itemName) < 1 then return end

    Bridge.Inventory.removeItem(playerSource, itemName, 1)
    Bridge.Notify.showNotify(playerSource, locale("trunk_stored_item", itemDef.label), "success")
    Bridge.Logs.Send(playerSource, "Objects",
        locale("trunk_log_stored", itemName),
        Config.Webhooks.objects)
end)

-- ============================================================
--  Cleanup
-- ============================================================

AddEventHandler("playerDropped", function()
    pendingDeployItem[source] = nil
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for netId in pairs(Objects.registry) do
        local entity = getEntityFromNetId(netId)
        if entity then DeleteEntity(entity) end
    end
    Objects.registry = {}
end)

-- ============================================================
--  Item registration (Config.Objects.Items)
-- ============================================================

CreateThread(function()
    -- Wait until Bridge is available
    while not (Bridge and Bridge.Framework) do
        Citizen.Wait(500)
    end

    local items = Config.Objects.Items
    if not items then return end

    for itemName, itemDef in pairs(items) do
        if itemDef.model then
            Bridge.Framework.registerItem(itemName, function(playerSource)
                if not getJobAccess(playerSource) then return end

                Bridge.Inventory.removeItem(playerSource, itemName, 1)
                pendingDeployItem[playerSource] = itemName
                TriggerClientEvent("p_policejob/client/objects/deployFromItem", playerSource, itemDef.model)
            end)
        end
    end
end)
