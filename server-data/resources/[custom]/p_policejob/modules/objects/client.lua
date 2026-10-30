if not Config.Objects.enabled then return end

Objects = {}
Objects.placed = {}  -- [netId] = { model, entity }
Objects.shield = nil

-- Wheel indices for spike strip tyre bursting
local WHEEL_INDICES = { wheel_lf = 0, wheel_rf = 1, wheel_lr = 4, wheel_rr = 5 }
local STINGER_HASH  = GetHashKey("p_ld_stinger_s")
local spikeStripMonitorActive = false

-- ============================================================
--  File-local helpers
-- ============================================================

-- Ensures an entity is networked and returns its netId, or 0 on failure.
local function ensureNetworked(entity)
    if not DoesEntityExist(entity) then return 0 end

    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        local attempts = 0
        while not NetworkGetEntityIsNetworked(entity) and attempts < 50 do
            Wait(10)
            attempts = attempts + 1
        end
    end

    return NetworkGetNetworkIdFromEntity(entity)
end

-- Returns true if the player has a police job.
local function hasJobAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    return job and Config.Jobs[job.name] or false
end

-- Returns true if the entity is a PoliceObject state bag AND player has access (or steal is allowed).
local function canInteractWithObject(entity)
    if not DoesEntityExist(entity) then return false end
    local entityState = Entity(entity).state
    if not (entityState and entityState.PoliceObject) then return false end
    if Config.Objects.allowSteal then return true end
    return hasJobAccess()
end

-- Pick-up animation helper
local function playPickupAnim()
    local animDict = lib.requestAnimDict("random@domestic")
    TaskPlayAnim(cache.ped, animDict, "pickup_low", -8.0, 8.0, 1000, 1, false)
    Wait(700)
    RemoveAnimDict(animDict)
end

-- Trunk animation helper
local function playTrunkAnim()
    local trunkAnim = Config.Objects.Trunk.anim
    local animDict  = lib.requestAnimDict(trunkAnim.dict)
    TaskPlayAnim(cache.ped, animDict, trunkAnim.anim, -8.0, 8.0, trunkAnim.duration, 1, false)
    Wait(trunkAnim.duration or 700)
    RemoveAnimDict(animDict)
end

-- Returns true if a vehicle's trunk door (door 5) is open past a threshold.
local function isTrunkOpen(vehicle)
    return GetVehicleDoorAngleRatio(vehicle, 5) > 0.1
end

-- Resolves a target argument that may be a raw entity handle or { entity = X }
local function resolveEntity(arg)
    if type(arg) == "number" then return arg end
    return arg.entity
end

-- ============================================================
--  Objects: open / close / placed count
-- ============================================================

function Objects.open(self)
    if not hasJobAccess() then return end
    if cache.vehicle then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end

    -- Build category list for NUI (strip internal data, keep display fields)
    local categories = {}
    for _, category in ipairs(Config.Objects.Categories) do
        local objs = {}
        for _, obj in ipairs(category.objects) do
            objs[#objs + 1] = { model = obj.model, label = obj.label, icon = obj.icon }
        end
        categories[#categories + 1] = {
            name    = category.name,
            label   = category.label,
            icon    = category.icon,
            objects = objs,
        }
    end

    SendNUIMessage({ action = "setVisibleObjects", data = true })
    SendNUIMessage({ action = "setObjectsData", data = {
        categories  = categories,
        placed      = self:getPlacedCount(),
        maxObjects  = Config.Objects.maxObjectsPerPlayer,
    }})
    SetNuiFocus(true, true)
end

function Objects.close(self)
    SendNUIMessage({ action = "setVisibleObjects", data = false })
    SetNuiFocus(false, false)
end

function Objects.updatePlacedCount(self)
    SendNUIMessage({ action = "setObjectsPlaced", data = self:getPlacedCount() })
end

function Objects.getPlacedCount(self)
    local count = 0
    for _ in pairs(self.placed) do count = count + 1 end
    return count
end

-- ============================================================
--  Place objects
-- ============================================================

function Objects.placeObjects(self, modelName, amount)
    if cache.vehicle then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end

    lib.requestModel(modelName)
    local modelHash = GetHashKey(modelName)

    for i = 1, amount do
        local pedCoords   = GetEntityCoords(cache.ped)
        local forwardVec  = GetEntityForwardVector(cache.ped)
        local spawnCoords = pedCoords + forwardVec * 2.5

        local entity = CreateObject(modelHash,
            spawnCoords.x, spawnCoords.y, spawnCoords.z,
            true, false, true)

        if DoesEntityExist(entity) then
            PlaceObjectOnGroundProperly(entity)
            FreezeEntityPosition(entity, true)

            -- Optional gizmo placement
            local usedGizmo = false
            if Config.Objects.useGizmo and GetResourceState("object_gizmo") == "started" then
                FreezeEntityPosition(entity, false)
                local confirmed = exports.object_gizmo:useGizmo(entity)

                if confirmed and DoesEntityExist(entity) then
                    if Config.Objects.snapToGround then PlaceObjectOnGroundProperly(entity) end
                    FreezeEntityPosition(entity, true)
                    usedGizmo = true
                else
                    if DoesEntityExist(entity) then DeleteEntity(entity) end
                    goto continue
                end
            end

            -- Network the entity
            local netId = ensureNetworked(entity)
            if netId == 0 then
                DeleteEntity(entity)
                goto continue
            end

            SetNetworkIdCanMigrate(netId, true)
            SetNetworkIdExistsOnAllMachines(netId, true)

            self.placed[netId] = { model = modelName, entity = entity }
            TriggerServerEvent("p_policejob/server/objects/register", netId)
            Config.Objects.onPlace(modelName, GetEntityCoords(entity))
            self:updatePlacedCount()
        end

        ::continue::
    end

    SetModelAsNoLongerNeeded(modelName)
end

-- ============================================================
--  Remove object (by netId) with pickup anim
-- ============================================================

function Objects.removeObject(self, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then return end

    playPickupAnim()
    TriggerServerEvent("p_policejob/server/objects/remove", netId)
end

-- ============================================================
--  Remove all objects of a model with pickup anim
-- ============================================================

function Objects.removeAllByModel(self, modelName)
    local modelHash = GetHashKey(modelName)
    playPickupAnim()
    TriggerServerEvent("p_policejob/server/objects/removeAllByModel", modelHash)
end

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("objects/place", function(data, cb)
    cb("ok")
    Objects:close()

    local modelName = data.model
    local amount    = math.max(1, math.min(data.amount or 1, 20))

    if type(modelName) ~= "string" then return end

    -- Enforce per-player object limit
    local maxObjects = Config.Objects.maxObjectsPerPlayer
    if maxObjects > 0 then
        local currentCount = Objects:getPlacedCount()
        if currentCount + amount > maxObjects then
            amount = maxObjects - currentCount
            if amount <= 0 then
                return Bridge.Notify.showNotify(locale("obj_max_reached"), "error")
            end
        end
    end

    Objects:placeObjects(modelName, amount)
end)

RegisterNUICallback("objects/removeAll", function(data, cb)
    cb("ok")
    Objects:close()
    if type(data.model) ~= "string" then return end
    Objects:removeAllByModel(data.model)
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/client/objects/deployFromItem", function(modelName)
    if type(modelName) ~= "string" then return end
    Objects:placeObjects(modelName, 1)
end)

RegisterNetEvent("p_policejob/client/objects/deleted", function(netId)
    local entry = Objects.placed[netId]
    if entry then
        Config.Objects.onRemove(entry.model)
        Objects.placed[netId] = nil
        Objects:updatePlacedCount()
    end
end)

RegisterNetEvent("p_policejob/client/objects/deletedBulk", function(netIds)
    for _, netId in ipairs(netIds) do
        Objects.placed[netId] = nil
    end
    Objects:updatePlacedCount()
end)

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function()
    Objects:close()
end)

-- ============================================================
--  Spike strip
-- ============================================================

local function deploySpikeStrip()
    if not Config.Objects.SpikeStrip.enabled then return end
    if not hasJobAccess() then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end
    if cache.vehicle then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end

    local stripCfg    = Config.Objects.SpikeStrip
    local spawnCoords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.5, 0.0)
    local heading     = GetEntityHeading(cache.ped)

    lib.requestModel(stripCfg.model)
    local strip = CreateObject(GetHashKey(stripCfg.model),
        spawnCoords.x, spawnCoords.y, spawnCoords.z,
        true, true, true)

    SetEntityHeading(strip, heading)
    PlaceObjectOnGroundProperly(strip)

    local netId = ensureNetworked(strip)
    if netId == 0 then DeleteEntity(strip); return end

    -- Deploy animation
    local deployAnim = stripCfg.deployAnim
    local animDict   = lib.requestAnimDict(deployAnim.dict)
    TaskPlayAnim(cache.ped, animDict, deployAnim.anim, -8.0, 8.0, deployAnim.duration, 1, 0)
    RemoveAnimDict(animDict)

    TriggerServerEvent("p_policejob/server/objects/deploySpikeStrip", netId)
    SetModelAsNoLongerNeeded(stripCfg.model)
end

RegisterNetEvent("p_policejob/useSpikeStrip", deploySpikeStrip)

lib.callback.register("p_policejob/useSpikeStrip", function()
    return deploySpikeStrip()
end)

-- Spike strip deployment animation (plays on all clients)
RegisterNetEvent("p_policejob/client/objects/playSpikeAnim", function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then return end

    local animDict = lib.requestAnimDict("p_ld_stinger_s")
    PlayEntityAnim(entity, "p_stinger_s_deploy", animDict, 1000.0, false, true, false, 0.0, 0)
    RemoveAnimDict(animDict)
end)

-- Spike strip tyre burst detection (runs while in a vehicle)
lib.onCache("vehicle", function(vehicle)
    if vehicle and vehicle ~= 0 then
        if not spikeStripMonitorActive then
            spikeStripMonitorActive = true
            CreateThread(function()
                while spikeStripMonitorActive do
                    local waitMs  = 500
                    local pedCoords = GetEntityCoords(cache.ped)
                    local strip   = GetClosestObjectOfType(
                        pedCoords.x, pedCoords.y, pedCoords.z,
                        35.0, STINGER_HASH, false, false, false)

                    if DoesEntityExist(strip) then
                        local stripDist = #(pedCoords - GetEntityCoords(strip))
                        if stripDist <= 20.0 then
                            waitMs = 5

                            if IsEntityTouchingEntity(cache.vehicle, strip) then
                                for boneName, wheelIdx in pairs(WHEEL_INDICES) do
                                    if not IsVehicleTyreBurst(cache.vehicle, wheelIdx, false) then
                                        local boneIdx   = GetEntityBoneIndexByName(cache.vehicle, boneName)
                                        local wheelPos  = GetWorldPositionOfEntityBone(cache.vehicle, boneIdx)
                                        local nearStrip = #(wheelPos - GetEntityCoords(strip)) < 1.5
                                        if nearStrip then
                                            SetVehicleTyreBurst(cache.vehicle, wheelIdx, true, 1148846080)
                                        end
                                    end
                                end
                            end
                        else
                            waitMs = 250
                        end
                    end

                    Wait(waitMs)
                end
            end)
        end
    else
        spikeStripMonitorActive = false
    end
end)

-- ============================================================
--  Shield toggle
-- ============================================================

function Objects.toggleShield(self, modelOverride)
    local shieldCfg = Config.Objects.Shield
    if not shieldCfg.enabled then return end

    if not hasJobAccess() then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end

    -- Toggle off if already active
    if self.shield then
        DeleteEntity(self.shield)
        self.shield = nil
        return
    end

    if cache.vehicle then
        return Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
    end

    local model = modelOverride or shieldCfg.defaultModel
    lib.requestModel(model)

    local prop = CreateObject(GetHashKey(model), GetEntityCoords(cache.ped), true, true, true)
    self.shield = prop

    local boneIndex = GetPedBoneIndex(cache.ped, shieldCfg.boneIndex)
    AttachEntityToEntity(
        prop, cache.ped, boneIndex,
        shieldCfg.offset.x, shieldCfg.offset.y, shieldCfg.offset.z,
        shieldCfg.rotation.x, shieldCfg.rotation.y, shieldCfg.rotation.z,
        true, true, true, true, false, true)

    -- Block vehicle entry while shield is held
    CreateThread(function()
        while self.shield and DoesEntityExist(self.shield) do
            SetPlayerMayNotEnterAnyVehicle(cache.playerId)
            Wait(0)
        end
    end)

    -- Auto-delete shield on death
    CreateThread(function()
        while self.shield and DoesEntityExist(self.shield) do
            Wait(1000)
            if LocalPlayer.state.isDead then
                DeleteEntity(self.shield)
                self.shield = nil
            end
        end
    end)

    SetModelAsNoLongerNeeded(model)
end

RegisterNetEvent("p_policejob/client/objects/togglePoliceShield", function(modelOverride)
    if type(modelOverride) ~= "string" or modelOverride == "" then
        modelOverride = nil
    end
    Objects:toggleShield(modelOverride)
end)

-- ============================================================
--  Target options for placed objects
-- ============================================================

CreateThread(function()
    Wait(1500)

    -- Collect all model names that should have target options
    local modelNames = { "p_ld_stinger_s" }
    local seenModels = { ["p_ld_stinger_s"] = true }

    for _, category in ipairs(Config.Objects.Categories) do
        for _, obj in ipairs(category.objects) do
            if not seenModels[obj.model] then
                seenModels[obj.model] = true
                modelNames[#modelNames + 1] = obj.model
            end
        end
    end

    local interactDist = Config.Objects.interactDistance

    Bridge.Target.addModel(modelNames, {
        {
            name        = "p_policejob/objects/take",
            label       = locale("take_object"),
            icon        = "fas fa-hand",
            distance    = interactDist,
            onSelect    = function(arg)
                local entity = resolveEntity(arg)
                local netId  = ensureNetworked(entity)
                if netId == 0 then return end
                Objects:removeObject(netId)
            end,
            canInteract = function(arg) return canInteractWithObject(resolveEntity(arg)) end,
        },
        {
            name        = "p_policejob/objects/takeAll",
            label       = locale("take_all_objects"),
            icon        = "fas fa-trash",
            distance    = interactDist,
            onSelect    = function(arg)
                local entity    = resolveEntity(arg)
                local modelHash = GetEntityModel(entity)
                local animDict  = lib.requestAnimDict("random@domestic")
                TaskPlayAnim(cache.ped, animDict, "pickup_low", -8.0, 8.0, 1000, 1, false)
                Wait(700)
                RemoveAnimDict(animDict)
                TriggerServerEvent("p_policejob/server/objects/removeAllByModel", modelHash)
            end,
            canInteract = function(arg) return canInteractWithObject(resolveEntity(arg)) end,
        },
    })
end)

-- ============================================================
--  Trunk
-- ============================================================

-- Opens a context menu to take items from a vehicle trunk
local function openTrunkTakeMenu(vehicle, trunkItems)
    local netId = ensureNetworked(vehicle)
    if netId == 0 then return end

    local trunkCfg = Config.Objects.Trunk
    local options  = {}

    for _, itemDef in ipairs(trunkItems) do
        local itemName    = itemDef.item
        local currentCount = Bridge.Inventory.getItemCount(itemName)
        local maxReached  = currentCount >= trunkCfg.maxHold

        options[#options + 1] = {
            title    = itemDef.label,
            icon     = itemDef.icon or "fa-solid fa-hand",
            disabled = maxReached,
            onSelect = function()
                TriggerServerEvent("p_policejob/server/objects/trunk/take", netId, itemName)
            end,
        }
    end

    if #options == 0 then return end

    lib.registerContext({
        id      = "p_policejob_trunk_take",
        title   = locale("take_from_trunk"),
        options = options,
    })
    lib.showContext("p_policejob_trunk_take")
end

-- Register trunk target options for each vehicle model
CreateThread(function()
    local trunkCfg = Config.Objects.Trunk
    if not (trunkCfg and trunkCfg.enabled) then return end

    Wait(1500)

    for vehicleModel, trunkItems in pairs(trunkCfg.vehicles) do
        local options = {}

        -- "Take from trunk" option
        options[#options + 1] = {
            name        = "p_policejob/objects/trunk/take/" .. vehicleModel,
            label       = locale("take_from_trunk"),
            icon        = "fa-solid fa-box-open",
            distance    = trunkCfg.interactDistance,
            onSelect    = function(arg)
                openTrunkTakeMenu(resolveEntity(arg), trunkItems)
            end,
            canInteract = function(arg)
                if not hasJobAccess() then return false end
                if trunkCfg.requireOpenTrunk and not isTrunkOpen(resolveEntity(arg)) then return false end
                return true
            end,
        }

        -- "Store to trunk" options (one per item)
        for _, itemDef in ipairs(trunkItems) do
            local itemName = itemDef.item
            options[#options + 1] = {
                name        = ("p_policejob/objects/trunk/store/%s/%s"):format(vehicleModel, itemName),
                label       = locale("store_object_trunk", itemDef.label),
                icon        = itemDef.icon or "fa-solid fa-hand",
                distance    = trunkCfg.interactDistance,
                onSelect    = function(arg)
                    local entity = resolveEntity(arg)
                    local netId  = ensureNetworked(entity)
                    if netId == 0 then return end
                    playTrunkAnim()
                    TriggerServerEvent("p_policejob/server/objects/trunk/store", netId, itemName)
                end,
                canInteract = function(arg)
                    if not hasJobAccess() then return false end
                    if trunkCfg.requireOpenTrunk and not isTrunkOpen(resolveEntity(arg)) then return false end
                    return Bridge.Inventory.getItemCount(itemName) >= 1
                end,
            }
        end

        Bridge.Target.addModel(vehicleModel, options)
    end
end)

-- ============================================================
--  Exports + commands + net events
-- ============================================================

exports("ObjectMenu",    function() Objects:open() end)
exports("isObjectsOpen", function() return false end)

RegisterNetEvent("p_policejob/client/objects/open", function()
    Objects:open()
end)

RegisterCommand("openObjectMenu", function()
    Objects:open()
end, false)
