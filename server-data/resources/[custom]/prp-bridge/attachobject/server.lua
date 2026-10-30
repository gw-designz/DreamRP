local registeredObjects = {} ---@type table<number, table>
local objectId = 0
local readyPlayers = {} ---@type table<number, boolean> This is to make sure nobody tries to request all objects multiple times, trying to lag the server.
local playerObjects = {}
local objects = {} ---@type table<string, { src: number, objectName: number, objectId: number, weaponData: number[]? } >

---@return number
local function getObjectId()
    if objectId < 2097120 then
		objectId = objectId + 1
	else
		objectId = 0
	end
    return objectId
end

---@class ObjectData
---@field objectName string
---@field modelHash number | string
---@field offset vector3
---@field rotation vector3
---@field boneId number | string
---@field disableCollision boolean
---@field completelyDisableCollision boolean
---@field isWeapon boolean
---@field dict string? -- Animation dictionary for PlayEntityAnim,
---@field anim string? -- Animation name for PlayEntityAnim,
---@field ptfxAsset string? -- Particle asset,
---@field ptfxName string? -- Particle name,
---@field ptfxOffset vector3? -- Particle offset,
---@field ptfxRot vector3? -- Particle rotation,
---@field ptfxScale number? -- Particle scale,
---@field ptfxColor vector3? -- Particle color

--- It register an object with all parameters needed to attach it to a player
--- This way it does not take so much network bandwith when players are constantly
--- getting props attached and detached from them.
---@param data ObjectData
function RegisterObject(data)
    if type(data.objectName) ~= "string" then
        print("ERROR: objectName has to be a string!")
        return
    end

    local nameHash = joaat(data.objectName)

    if registeredObjects[nameHash] ~= nil then
        -- print(("ERROR: Object with name %s is already registered! Change used name of object in resource %s"):format(objectName, GetInvokingResource()))
        return
    end

    if type(data.modelHash) ~= "number" then data.modelHash = joaat(data.modelHash) end

    if type(data.offset) ~= "vector3" then
        print("ERROR: offset is not a vector3!")
        return
    end

    if type(data.rotation) ~= "vector3" then
        print("ERROR: rotation is not a vector3!")
        return
    end

    if type(data.disableCollision) ~= "boolean" then
        print("ERROR: disableCollision is not a boolean!")
        return
    end

    if type(data.completelyDisableCollision) ~= "boolean" then
        print("ERROR: completelyDisableCollision is not a boolean!")
        return
    end

    if data.isWeapon ~= nil and type(data.isWeapon) ~= "boolean" then
        print("ERROR: isWeapon is not a boolean!")
        return
    end

    if not data.isWeapon then
        data.isWeapon = nil
    end

    registeredObjects[nameHash] = {
        data.modelHash,                  -- 1
        data.offset,                     -- 2
        data.rotation,                   -- 3
        data.boneId,                     -- 4
        data.disableCollision,           -- 5
        data.completelyDisableCollision, -- 6
        data.objectName,                 -- 7
        data.isWeapon,                   -- 8
        data.dict,                       -- 9
        data.anim,                       -- 10
        data.ptfxAsset,                  -- 11
        data.ptfxName,                   -- 12
        data.ptfxOffset,                 -- 13
        data.ptfxRot,                    -- 14
        data.ptfxScale,                  -- 15
        data.ptfxColor                   -- 16
    }

    TriggerClientEvent("prp-bridge:attachobj:registerObject", -1, nameHash, registeredObjects[nameHash])
end
exports("RegisterObject", RegisterObject)

---@param objectName string
function UnregisterObject(objectName)
    local nameHash = joaat(objectName)
    if registeredObjects[nameHash] == nil then return end
    registeredObjects[nameHash] = nil
    TriggerClientEvent("prp-bridge:attachobj:unregisterObject", -1, nameHash)
end
exports("UnregisterObject", UnregisterObject)

RegisterNetEvent("prp-bridge:attachobj:ready", function()
    local src = tonumber(source)
    if src == nil then return end

    if readyPlayers[src] == nil then
        readyPlayers[src] = true
        -- This might need a change to TriggerLatentClientEvent if the number of registered objects is huge,
        -- but it's not certain lantents work properly.
        TriggerClientEvent("prp-bridge:attachobj:registeredObjects", src, registeredObjects)
        TriggerClientEvent("prp-bridge:attachobj:player:getObjects", src, objects)
    end
end)

AddEventHandler("playerDropped", function()
    local src = tonumber(source)
    if src == nil then return end
    readyPlayers[src] = nil
end)

---@param weaponData { name: string, tint: number, components: number[] }?
---@return number[]?
local function packWeaponData(weaponData)
    if not weaponData then return nil end
    local packedWeaponData = {} -- array of numbers
    packedWeaponData[#packedWeaponData + 1] = joaat(weaponData.name) -- name of the weapon at index 1
    packedWeaponData[#packedWeaponData + 1] = weaponData.tint
    for i=1, #weaponData.components do
        packedWeaponData[#packedWeaponData + 1] = weaponData.components[i] -- hashed component
    end
    return packedWeaponData
end

---@param src number | string
---@param objectName string
---@param weaponData { name: string, tint: number, components: number[] }?
---@return number --Returns objectId
function CreateAttachObject(src, objectName, weaponData)
    ---@diagnostic disable-next-line: cast-local-type
    src = tonumber(src)
    if src == nil or not objectName then
        print("ERROR: src or objectName is nil")
        return -1
    end

    local objectId = getObjectId()
    local nameHash = joaat(objectName)
    objects[objectId] = {
        src = src,
        objectName = nameHash,
        objectId = objectId,
        weaponData = packWeaponData(weaponData)
    }

    if playerObjects[src] == nil then playerObjects[src] = {} end
    playerObjects[src][objectId] = nameHash

    local state = Player(src).state?.AttachObjects or {}

    state[objectId] = { nameHash, objects[objectId].weaponData }

    Player(src).state.AttachObjects = state

    return objectId
end
exports("CreateAttachObject", CreateAttachObject)

---@param src number | string
---@param objectId number
---@return boolean
function RemoveAttachObject(src, objectId)
    ---@diagnostic disable-next-line: cast-local-type
    src = tonumber(src)
    if src == nil or not objectId then
        print("ERROR: src or objectId is nil")
        return false
    end

    if objects[objectId] and playerObjects[src] and playerObjects[src][objectId] then
        playerObjects[src][objectId] = nil
        objects[objectId] = nil

        local state = Player(src).state?.AttachObjects or {}

        state[objectId] = nil

        Player(src).state.AttachObjects = state

        return true
    end

    return false
end
exports("RemoveAttachObject", RemoveAttachObject)

---@param src number | string
---@return { objectId: number, objectName: string }[]
function GetObjectsOnPlayer(src)
    ---@diagnostic disable-next-line: cast-local-type
    src = tonumber(src)
    if src == nil then
        print("ERROR: src is nil")
        return {}
    end

    if playerObjects[src] == nil then
        return {}
    end

    local objectList = {}

    for objectId, nameHash in pairs(playerObjects[src]) do
        objectList[#objectList+1] = {
            objectId = objectId,
            objectName = registeredObjects[nameHash]?[7]
        }
    end

    return objectList
end
exports("GetObjectsOnPlayer", GetObjectsOnPlayer)

---@param src number | string
---@param objectName string? If it's nil, it will clear all objects from the player
function ClearPlayerObjects(src, objectName)
    ---@diagnostic disable-next-line: cast-local-type
    src = tonumber(src)
    if src == nil then
        return
    end

    if not playerObjects[src] then return false end

    local objsToRemove = {}

    local objectNameHashed = nil
    if objectName ~= nil then
        objectNameHashed = joaat(objectName)
    end

    local state = Player(src).state?.AttachObjects or {}

    for objectId, hash in pairs(playerObjects[src]) do
        if not objectName or (objectNameHashed == hash) then
            objsToRemove[#objsToRemove + 1] = objectId
            playerObjects[src][objectId] = nil
            objects[objectId] = nil
            state[objectId] = nil
        end
    end

    Player(src).state.AttachObjects = next(state) and state or nil
end
exports("ClearPlayerObjects", ClearPlayerObjects)

---@class VehTempAttachObject
---@field model number
---@field bone string
---@field offset vector3
---@field rotation vector3
---@field rotationOrder number?
---@field disableCollistion table<number, boolean>?

---@param entity number
---@param objectData VehTempAttachObject
---@return number?
function CreateVehTempAttachObject(entity, objectData)
    if not objectData then return nil end
    if not DoesEntityExist(entity) then return nil end
    local objectId = getObjectId()

    local tempAttach = Entity(entity).state.VehTempAttachObjects
    if not tempAttach then tempAttach = {} end

    tempAttach[objectId] = {
        objectId,
        objectData.model,
        objectData.bone,
        objectData.offset,
        objectData.rotation,
        objectData.rotationOrder or 1,
        objectData.disableCollistion or { true, true, true, true },
        {} -- props
    }

    Entity(entity).state.VehTempAttachObjects = tempAttach

    return objectId
end
exports("CreateVehTempAttachObject", CreateVehTempAttachObject)

---@param entity number
---@param objectId number
---@return boolean
function RemoveVehTempAttachObject(entity, objectId)
    if objectId == nil then return false end
    if not DoesEntityExist(entity) then return false end
    local tempAttach = Entity(entity).state.VehTempAttachObjects
    if not tempAttach then return false end
    if not tempAttach[objectId] then return false end

    tempAttach[objectId] = nil
    Entity(entity).state.VehTempAttachObjects = tempAttach

    return true
end
exports("RemoveVehTempAttachObject", RemoveVehTempAttachObject)

---@param entity number
---@param objectId number
---@param key string
---@param value any
---@return boolean
function SetVehObjectData(entity, objectId, key, value)
    if objectId == nil then return false end
    if not DoesEntityExist(entity) then return false end
    local tempAttach = Entity(entity).state.VehTempAttachObjects
    if not tempAttach then return false end
    if not tempAttach[objectId] then return false end

    if tempAttach[objectId][8] == nil then tempAttach[objectId][8] = {} end
    tempAttach[objectId][8][key] = value
    Entity(entity).state.VehTempAttachObjects = tempAttach
    return true
end
exports("SetVehObjectData", SetVehObjectData)

---@param entity number
function ClearVehTempAttachObjects(entity)
    if not DoesEntityExist(entity) then return end
    Entity(entity).state.VehTempAttachObjects = nil
end
exports("ClearVehTempAttachObjects", ClearVehTempAttachObjects)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src, objects in pairs(playerObjects) do
        ClearPlayerObjects(src)
    end
end)