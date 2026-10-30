
Target = Target or {}

CreateThread(function()
    if Config.Target ~= 'ox_target' then
        return
    end

    local function isEntityValid(entity)
        return entity and entity ~= 0 and DoesEntityExist(entity) and not IsEntityDead(entity)
    end

    function Target:addTargetEntity(entity, data)
        if not isEntityValid(entity) then return nil end

        exports.ox_target:addLocalEntity(entity, {
            label = data.label,
            name = tostring(data.label) .. tostring(entity),
            icon = data.icon or false,
            distance = data.distance or 2.5,
            onSelect = function(hitData)
                local ent = hitData and hitData.entity or nil
                if not isEntityValid(ent) then return end
                if data.action then data.action(ent) end
            end,
            canInteract = function(ent)
                if not isEntityValid(ent) then return false end
                if data.canInteract then return data.canInteract(ent) end
                return true
            end,
        })

        return tostring(data.label) .. tostring(entity)
    end

    function Target:removeTargetEntity(entity, contextId)
        if not entity then return end
        exports.ox_target:removeLocalEntity(entity, contextId)
    end

    function Target:addGlobalPed(data)
        exports.ox_target:addGlobalPed({
            label = data.label,
            name = data.label,
            icon = data.icon or false,
            distance = data.distance or 2.5,
            onSelect = function(hitData)
                local ent = hitData and hitData.entity or nil
                if not isEntityValid(ent) or IsPedAPlayer(ent) then return end
                if data.action then data.action(ent) end
            end,
            canInteract = function(ent)
                if not isEntityValid(ent) or IsPedAPlayer(ent) then return false end
                if data.canInteract then return data.canInteract(ent) end
                return true
            end
        })

        return data.label
    end

    function Target:removeGlobalPed(contextId)
        exports.ox_target:removeGlobalPed(contextId)
    end

    function Target:addGlobalVehicle(data)
        exports.ox_target:addGlobalVehicle({
            label = data.label,
            name = data.label,
            icon = data.icon or false,
            distance = data.distance or 2.5,
            onSelect = function(hitData)
                local ent = hitData and hitData.entity or nil
                if not ent or not DoesEntityExist(ent) then return end
                if data.action then data.action(ent) end
            end,
            canInteract = function(ent)
                if not ent or not DoesEntityExist(ent) then return false end
                if data.canInteract then return data.canInteract(ent) end
                return true
            end,
        })
        return data.label
    end

    function Target:addTargetModel(models, data)
        Citizen.Wait(1000)

        exports.ox_target:addModel(models, {
            label = data.label,
            name = data.label,
            icon = data.icon or false,
            distance = data.distance or 2.5,
            onSelect = function(hitData)
                local ent = hitData and hitData.entity or nil
                if not isEntityValid(ent) then return end
                if data.action then data.action(ent) end
            end,
            canInteract = function(ent)
                if not isEntityValid(ent) then return false end
                if data.canInteract then return data.canInteract(ent) end
                return true
            end
        })

        return data.label
    end

    function Target:removeTargetModel(models, contextId)
        exports.ox_target:removeModel(models, contextId)
    end
end)
