-- Based on: https://github.com/scriptforge-gg/prp-bridge:attachobj

local registeredObjects = {}
local scopedPlayers = {} ---@type table<number, boolean>
local playerToObjects = {}
local toRemoveObjects = {}
local objects = {} ---@type table<string, { src: number, objectName: number, objectId: number, weaponData: number[]?, spawnTime: number?, ped: number?, handle: number? } >
local allSpawnedObjects = {} ---@type table<number, { src: number, objectName: number, objectId: number, weaponData: number[]? } > --- key: entityHandle

local DoesEntityExist = DoesEntityExist
local GetEntityCoords = GetEntityCoords
local GetPlayerFromServerId = GetPlayerFromServerId
local GetPlayerFromStateBagName = GetPlayerFromStateBagName
local GetPlayerServerId = GetPlayerServerId
local StopParticleFxLooped = StopParticleFxLooped
local RemoveNamedPtfxAsset = RemoveNamedPtfxAsset
local DeleteEntity = DeleteEntity
local SetEntityAsMissionEntity = SetEntityAsMissionEntity
local CreateObjectNoOffset = CreateObjectNoOffset
local CreateWeaponObject = CreateWeaponObject
local AttachEntityToEntity = AttachEntityToEntity
local GiveWeaponComponentToWeaponObject = GiveWeaponComponentToWeaponObject
local SetWeaponObjectTintIndex = SetWeaponObjectTintIndex
local RequestWeaponAsset = RequestWeaponAsset
local RemoveWeaponAsset = RemoveWeaponAsset
local GetPedBoneIndex = GetPedBoneIndex
local StartParticleFxLoopedOnEntityBone = StartParticleFxLoopedOnEntityBone
local SetParticleFxLoopedColour = SetParticleFxLoopedColour
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local PlayEntityAnim = PlayEntityAnim
local RequestModel = RequestModel
local HasModelLoaded = HasModelLoaded
local RequestAnimDict = RequestAnimDict
local HasAnimDictLoaded = HasAnimDictLoaded
local RequestNamedPtfxAsset = RequestNamedPtfxAsset
local HasNamedPtfxAssetLoaded = HasNamedPtfxAssetLoaded
local RequestWeaponAsset = RequestWeaponAsset
local HasWeaponAssetLoaded = HasWeaponAssetLoaded
local joaat = joaat
local IsModelValid = IsModelValid
local IsModelAPed = IsModelAPed
local IsModelAVehicle = IsModelAVehicle
local GetModelDimensions = GetModelDimensions
local SetModelAsNoLongerNeeded = SetModelAsNoLongerNeeded

local maxAttachModelSize = tonumber(GetConvar('prp:attachObjectMaxSize', '5.0')) or 5.0
local maxAttachObjects = GetConvarInt('prp:attachObjectLimit', 16)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent("prp-bridge:attachobj:ready")
end)

---@param modelHash number
local function reqModel(modelHash)
    local timeout = 0
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) and timeout < 30 do
        timeout = timeout + 1
        Wait(50)
    end
end

---@param model number
---@return boolean
local function isValidObjectModel(model)
    if not model or not IsModelValid(model) then return false end

    reqModel(model)
    if not HasModelLoaded(model) then return false end

    if IsModelAPed(model) or IsModelAVehicle(model) then
        SetModelAsNoLongerNeeded(model)
        return false
    end

    local min, max = GetModelDimensions(model)
    local size = max - min

    if math.max(size.x, size.y, size.z) > maxAttachModelSize then
        SetModelAsNoLongerNeeded(model)
        return false
    end

    return true
end

---@param dict string
---@param anim string
local function reqAnim(dict, anim)
    local timeout = 0
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) and timeout < 30 do
        timeout = timeout + 1
        Wait(50)
    end
end

---@param asset string
local function reqPtfx(asset)
    local timeout = 0
    RequestNamedPtfxAsset(asset)
    while not HasNamedPtfxAssetLoaded(asset) and timeout < 30 do
        timeout = timeout + 1
        Wait(50)
    end
end

---@param data number[]
---@return { weaponHash: number, components: number[], tint: number }?
local function unpackWeaponData(data)
    if not data then return nil end
    local unpackedWeaponData = {
        weaponHash = 0,
        components = {},
        tint = 0
    }

    unpackedWeaponData.weaponHash = data[1]
    unpackedWeaponData.tint = data[2]

    local addToComponents = true
    for i=3, #data do
        unpackedWeaponData.components[#unpackedWeaponData.components + 1] = data[i]
    end

    return unpackedWeaponData
end

---@param handle number
local function deleteEntity(handle)
    allSpawnedObjects[handle] = nil
    SetEntityAsMissionEntity(handle, true, true)
    DeleteEntity(handle)
end

RegisterNetEvent("prp-bridge:attachobj:registerObject", function (name, object)
    if registeredObjects[name] ~= nil then return end
    registeredObjects[name] = object
end)

RegisterNetEvent("prp-bridge:attachobj:unregisterObject", function (name)
    registeredObjects[name] = nil
end)

RegisterNetEvent("prp-bridge:attachobj:registeredObjects", function(data)
    registeredObjects = data
end)

RegisterNetEvent("prp-bridge:attachobj:player:getObjects", function(data)
    for k, v in pairs(data) do
        if v.weaponData then
            data[k].weaponData = unpackWeaponData(v.weaponData)
        end
    end
    objects = data
end)

CreateThread(function()
    local plaIds = GetActivePlayers()
    for i = 1, #plaIds do
        scopedPlayers[GetPlayerServerId(plaIds[i])] = true
    end
end)

---@param objectId number
---@return boolean
local function createObj(objectId)
    local data = objects[objectId]

    if not data then
        return false
    end

    if data.handle and DoesEntityExist(data.handle) then
        return false
    end

    local objData = registeredObjects[data.objectName]
    if objData == nil then
        return false
    end

    local player = GetPlayerFromServerId(data.src)
    if player == -1 and cache.serverId ~= data.src then return false end
    data.ped = GetPlayerPed(player)

    if not DoesEntityExist(data.ped) then
        return true
    end

    if not IsEntityVisible(data.ped) then
        return true
    end

    data.spawnTime = GetGameTimer()
    local coords = GetEntityCoords(data.ped)
    local weaponData = data.weaponData
    if weaponData then
        local overrideWeaponHash

        RequestWeaponAsset(weaponData.weaponHash, 31, 0)
        local timeout = 0
        while not HasWeaponAssetLoaded(weaponData.weaponHash) and timeout < 30 do
            timeout += 1
            Wait(0)
        end

        for i=1, #weaponData.components do
            local component = weaponData.components[i]

            if (component:find("SKIN") or component:find("CAMO")) and DoesWeaponTakeWeaponComponent(weaponData.weaponHash, joaat(component)) then
                overrideWeaponHash = GetWeaponComponentTypeModel(joaat(component))
            end
        end

        data.handle = CreateWeaponObject(weaponData.weaponHash, 1, coords.x, coords.y, coords.z + 5.0, true, 1.0, overrideWeaponHash)
        RemoveWeaponAsset(weaponData.weaponHash)
        SetEntityAsMissionEntity(data.handle, true, true)
        if objData[5] then SetEntityCollision(data.handle, false, false) end
        if objData[6] then SetEntityCompletelyDisableCollision(data.handle, true, true) end
        for i=1, #weaponData.components do
            GiveWeaponComponentToWeaponObject(data.handle, joaat(weaponData.components[i]))
        end
        SetWeaponObjectTintIndex(data.handle, weaponData.tint)
        AttachEntityToEntity(data.handle, data.ped, GetPedBoneIndex(data.ped, objData[4]), objData[2].x, objData[2].y, objData[2].z, objData[3].x, objData[3].y, objData[3].z, true, true, false, true, 1, true)
    else
        if not isValidObjectModel(objData[1]) then return false end

        data.handle = CreateObjectNoOffset(objData[1], coords.x, coords.y, coords.z + 5.0, false, false, false)
        SetEntityAsMissionEntity(data.handle, true, true)
        SetModelAsNoLongerNeeded(objData[1])
        if objData[5] then SetEntityCollision(data.handle, false, false) end
        if objData[6] then SetEntityCompletelyDisableCollision(data.handle, true, true) end

        AttachEntityToEntity(data.handle, data.ped, GetPedBoneIndex(data.ped, objData[4]), objData[2].x, objData[2].y, objData[2].z, objData[3].x, objData[3].y, objData[3].z, true, true, false, true, 1, true)
    end

    if objData[9] ~= nil and objData[10] ~= nil then
        reqAnim(objData[9], objData[10])
        PlayEntityAnim(data.handle, objData[10], objData[9], 8.0, true, false, 0, 0, 0)
    end

    if objData[11] ~= nil and objData[12] ~= nil and objData[13] ~= nil and objData[14] ~= nil and objData[15] ~= nil then
        reqPtfx(objData[11])
        UseParticleFxAssetNextCall(objData[11])
        data.ptfxAsset = objData[11]
        data.ptfx = StartParticleFxLoopedOnEntityBone(
            objData[12],
            data.handle,
            objData[13].x, objData[13].y, objData[13].z, objData[14].x, objData[14].y, objData[14].z,
            GetEntityBoneIndexByName(data.handle, "VFX"),
            objData[15], false, false, false)

        if objData[16] ~= nil then
            SetParticleFxLoopedColour(data.ptfx, objData[16].x, objData[16].y, objData[16].z, false)
        end
    end

    allSpawnedObjects[data.handle] = {
        objectId = objectId,
        src = data.src,
        ptfxAsset = data.ptfxAsset,
        ptfx = data.ptfx
    }

    return true
end

---@param objectId number
local function removeObject(objectId)
    local obj = objects[objectId]
    if not obj then return end

    if playerToObjects[obj.srv] then
        playerToObjects[obj.srv][objectId] = nil
    end

    if obj.handle ~= nil then
        if obj.ptfx then
            StopParticleFxLooped(obj.ptfx, false)
            RemoveNamedPtfxAsset(obj.ptfxAsset)
        end
        deleteEntity(obj.handle)
    end

    objects[objectId] = nil
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id, object in pairs(objects) do
        if object.handle and DoesEntityExist(object.handle) then
            removeObject(id)
        end
    end
end)

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler("AttachObjects", nil, function(bagName, key, value, reserved, replicated)
    local playerId = GetPlayerFromStateBagName(bagName)
    local src = GetPlayerServerId(playerId)
    if src == 0 then return end

    scopedPlayers[src] = value and true or nil

    if value == nil or not next(value) then
        for objectId, _ in pairs(playerToObjects[src] or {}) do
            removeObject(objectId)
        end
    else
        if not playerToObjects[src] then playerToObjects[src] = {} end

        for objectId, _ in pairs(playerToObjects[src] or {}) do
            if not value[objectId] then
                removeObject(objectId)
            end
        end

        local count = 0
        for objectId, data in pairs(value) do
            count = count + 1
            if count > maxAttachObjects then
                lib.print.error(("%s object limit (%d) reached, rejecting rest"):format(bagName, maxAttachObjects))
                break
            end

            if not playerToObjects[src][objectId] then
                objects[objectId] = {
                    src = src,
                    objectName = data[1],
                    objectId = objectId,
                    weaponData = unpackWeaponData(data[2])
                }

                playerToObjects[src][objectId] = true
                createObj(objectId)
            end
        end
    end
end)

CreateThread(function()
    local function loop()
        local timer = GetGameTimer()
        for src, _ in pairs(scopedPlayers) do
            for objectId, _ in pairs(playerToObjects[src] or {}) do
                local object = objects[objectId]

                if not object then
                    goto skip
                end

                if object?.spawnTime ~= nil and timer - object?.spawnTime < 100 then
                    goto skip
                end

                local entityExist = object.handle ~= nil and DoesEntityExist(object.handle) or false
                if object.handle ~= nil and entityExist then
                    if not IsEntityAttached(object.handle) then
                        deleteEntity(object.handle)
                        object.handle = nil
                        entityExist = false
                    end
                end

                if not entityExist then
                    createObj(objectId)
                end

                ::skip::
            end
            Wait(100)
        end
    end

    while true do
        local success, err = pcall(loop)
        if not success then
            print(err)
        end
        Wait(5000)
    end
end)

CreateThread(function()
    while true do
        local success, err = pcall(function()
            local _counter = 0
            for handle, data in pairs(toRemoveObjects) do
                _counter = _counter + 1
                if handle ~= 0 then
                    deleteEntity(handle)
                end
                if data.ptfx then
                    StopParticleFxLooped(data.ptfx, false)
                    RemoveNamedPtfxAsset(data.ptfxAsset)
                end
                data.ptfx = nil
                data.ptfxAsset = nil

                toRemoveObjects[handle] = nil
                if _counter % 10 == 0 then Wait(50) end
            end
        end)
        Wait(2500)
    end
end)

CreateThread(function()
    local function rmProp(handle, data)
        if data.ptfx then
            StopParticleFxLooped(data.ptfx, false)
            RemoveNamedPtfxAsset(data.ptfxAsset)
        end
        data.ptfx = nil
        data.ptfxAsset = nil

        objects[data.objectId].handle = nil
        toRemoveObjects[handle] = nil
        allSpawnedObjects[handle] = nil
    end

    local function loop()
        local alreadyRemoved = false
        local _counter = 0
        for entityHandle, data in pairs(allSpawnedObjects or {}) do
            _counter = _counter + 1
            alreadyRemoved = false

            pcall(function()
                if not DoesEntityExist(entityHandle) then
                    rmProp(entityHandle, data)
                    alreadyRemoved = true
                end
            end)

            local player = nil
            if not alreadyRemoved then
                pcall(function()
                    player = GetPlayerFromServerId(data.src)
                    if cache.serverId ~= data.src and player == -1 then
                        deleteEntity(entityHandle)
                        rmProp(entityHandle, data)
                        alreadyRemoved = true
                    end
                end)
            end

            if not alreadyRemoved then
                pcall(function()
                    if player ~= nil then
                        local ped = GetPlayerPed(player)
                        if ped ~= cache.ped and not DoesEntityExist(ped) then
                            deleteEntity(entityHandle)
                            rmProp(entityHandle, data)
                            alreadyRemoved = true
                        else
                            local coords2 = GetEntityCoords(ped)
                            if #(GetEntityCoords(entityHandle) - coords2) > 50.0 then
                                deleteEntity(entityHandle)
                                rmProp(entityHandle, data)
                                alreadyRemoved = true
                            end
                        end
                    end
                end)
            end

            if _counter % 10 == 0 then Wait(50) end
        end
    end

    while true do
        local success, err = pcall(loop)
        Wait(5000)
    end
end)

exports("GetObjectHandle", function(objectId)
    return objects[objectId]?.handle
end)