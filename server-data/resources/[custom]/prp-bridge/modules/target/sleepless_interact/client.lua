local target = {}

local sleepless_interact = exports.sleepless_interact

---@param zoneId number | string can be zoneId (number) or zone name (string)
function target.removeZone(zoneId)
    sleepless_interact:removeCoords(zoneId)
end

---@param payload TargetBoxZone
---@return number | string
function target.addBoxZone(payload)
    return sleepless_interact:addCoords(payload.coords, payload.options)
end

---@param payload TargetSphereZone
---@return number | string
function target.addSphereZone(payload)
    return sleepless_interact:addCoords(payload.coords, payload.options)
end

---@param entities number | number[]
---@param options TargetOptions[]
function target.addLocalEntity(entities, options)
    sleepless_interact:addLocalEntity(entities, options)
end

---@param entities number | number[]
---@param optionNames string | string[]
function target.removeLocalEntity(entities, optionNames)
    sleepless_interact:removeLocalEntity(entities, optionNames)
end

---@param netIds number | number[]
---@param options TargetOptions[]
function target.addEntity(netIds, options)
    sleepless_interact:addEntity(netIds, options)
end

---@param netIds number | number[]
---@param optionNames string | string[]
function target.removeEntity(netIds, optionNames)
    sleepless_interact:removeEntity(netIds, optionNames)
end

---@param options TargetOptions[]
function target.addGlobalPed(options)
    sleepless_interact:addGlobalPed(options)
end

---@param optionNames string | string[]
function target.removeGlobalPed(optionNames)
    sleepless_interact:removeGlobalPed(optionNames)
end

---@param options TargetOptions[]
function target.addGlobalPlayer(options)
    sleepless_interact:addGlobalPlayer(options)
end

---@param optionNames string | string[]
function target.removeGlobalPlayer(optionNames)
    sleepless_interact:removeGlobalPlayer(optionNames)
end

---@param options TargetOptions[]
function target.addGlobalVehicle(options)
    sleepless_interact:addGlobalVehicle(options)
end

---@param optionNames string | string[]
function target.removeGlobalVehicle(optionNames)
    sleepless_interact:removeGlobalVehicle(optionNames)
end

---@param models number | string | (number | string)[]
---@param options TargetOptions[]
function target.addModel(models, options)
    sleepless_interact:addModel(models, options)
end

---@param models number | string | (number | string)[]
---@param optionNames string | string[]
function target.removeModel(models, optionNames)
    sleepless_interact:removeModel(models, optionNames)
end

---@param disable boolean
function target.disableTargeting(disable)
    sleepless_interact:disableInteract(disable)
end

return target