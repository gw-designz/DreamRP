local target = {}

local ox_target = exports.ox_target

---@param zoneId number | string can be zoneId (number) or zone name (string)
function target.removeZone(zoneId)
   ox_target:removeZone(zoneId)
end

---@param payload TargetBoxZone
---@return number | string
function target.addBoxZone(payload)
    return ox_target:addBoxZone(payload)
end

---@param payload TargetSphereZone
---@return number | string
function target.addSphereZone(payload)
    return ox_target:addSphereZone(payload)
end

---@param entities number | number[]
---@param options TargetOptions[]
function target.addLocalEntity(entities, options)
    return ox_target:addLocalEntity(entities, options)
end

---@param entities number | number[]
---@param optionNames string | string[]
function target.removeLocalEntity(entities, optionNames)
    return ox_target:removeLocalEntity(entities, optionNames)
end

---@param netIds number | number[]
---@param options TargetOptions[]
function target.addEntity(netIds, options)
    ox_target:addEntity(netIds, options)
end

---@param netIds number | number[]
---@param optionNames string | string[] | nil
function target.removeEntity(netIds, optionNames)
    ox_target:removeEntity(netIds, optionNames)
end

---@param options TargetOptions[]
function target.addGlobalPed(options)
    exports.ox_target:addGlobalPed(options)
end

---@param optionNames string | string[]
function target.removeGlobalPed(optionNames)
    exports.ox_target:removeGlobalPed(optionNames)
end

---@param options TargetOptions[]
function target.addGlobalPlayer(options)
    ox_target:addGlobalPlayer(options)
end

---@param optionNames string | string[]
function target.removeGlobalPlayer(optionNames)
    ox_target:removeGlobalPlayer(optionNames)
end

---@param options TargetOptions[]
function target.addGlobalVehicle(options)
    ox_target:addGlobalVehicle(options)
end

---@param optionNames string | string[]
function target.removeGlobalVehicle(optionNames)
    ox_target:removeGlobalVehicle(optionNames)
end

---@param models number | string | (number | string)[]
---@param options TargetOptions[]
function target.addModel(models, options)
    ox_target:addModel(models, options)
end

---@param models number | string | (number | string)[]
---@param optionNames string | string[]
function target.removeModel(models, optionNames)
    ox_target:removeModel(models, optionNames)
end

---@param disable boolean
function target.disableTargeting(disable)
    ox_target:disableTargeting(disable)
end

return target
