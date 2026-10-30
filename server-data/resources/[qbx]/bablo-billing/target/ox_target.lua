
Target = Target or {}

CreateThread(function()
    if Config.Target ~= 'ox_target' then
        return
    end

    ---@diagnostic disable-next-line
    function Target:addTargetEntity(entity, data)
        if not data.bones then
            data.bones = nil
        end

        if Config.DEBUG then
            Trace("Adding target with bones:", json.encode(data.bones), "for entity:", entity)
        end

        exports.ox_target:addLocalEntity(entity, {
            label = data.label,
            name = data.name or (data.label .. entity),
            bones = data.bones,
            icon = data.icon or false,
            distance = 2.5,
            onSelect = function(hitData)
                data.action(hitData.entity)
            end,
            canInteract = function(entity)
                if not entity then return false end
                return data.canInteract(entity)
            end,
        })

        return data.name or (data.label .. entity)
    end

    ---@diagnostic disable-next-line
    function Target:removeTargetEntity(entity, contextId)
        exports.ox_target:removeLocalEntity(entity, contextId)
    end

    ---@diagnostic disable-next-line
    function Target:addGlobalPed(data)
        exports.ox_target:addGlobalPed({
            {
                label = data.label,
                name = data.label,
                icon = data.icon or false,
                distance = 2.5,
                onSelect = function(hitData)
                    data.action(hitData.entity)
                end,
                canInteract = function(entity)
                    return data.canInteract(entity)
                end
            }
        })

        return data.label
    end

    ---@diagnostic disable-next-line
    function Target:removeGlobalPed(contextId)
        exports.ox_target:removeGlobalPed(contextId)
    end

    ---@diagnostic disable-next-line
    function Target:addTargetModel(models, data)
        Citizen.Wait(1000)

        exports.ox_target:addModel(models, {
            label = data.label,
            name = data.label,
            icon = data.icon or false,
            distance = 2.5,
            onSelect = function(hitData)
                data.action(hitData.entity)
            end,
            canInteract = function(entity)
                if not entity then return false end
                return data.canInteract(entity)
            end
        })

        return data.label
    end

    ---@diagnostic disable-next-line
    function Target:removeTargetModel(models, contextId)
        exports.ox_target:removeModel(models, contextId)
    end

    ---@diagnostic disable-next-line
    function Target:addGlobalPlayer(data)
        local optionName = data.name or data.label
        local option = {
            label = data.label,
            name = optionName,
            icon = data.icon or false,
            distance = data.distance or 2.5,
            onSelect = function(hitData)
                data.action(hitData.entity)
            end,
            canInteract = function(entity)
                if not entity then return false end
                if not IsPedAPlayer(entity) then return false end
                return data.canInteract(entity)
            end
        }

        local hasNativeGlobalPlayer = pcall(function()
            exports.ox_target:addGlobalPlayer({ option })
        end)

        if not hasNativeGlobalPlayer then
            exports.ox_target:addGlobalPed({ option })
        end

        return optionName
    end

    ---@diagnostic disable-next-line
    function Target:removeGlobalPlayer(contextId)
        local ok = pcall(function()
            exports.ox_target:removeGlobalPlayer(contextId)
        end)
        if not ok then
            exports.ox_target:removeGlobalPed(contextId)
        end
    end

    ---@diagnostic disable-next-line
    function Target:addGlobalVehicle(data)
        exports.ox_target:addGlobalVehicle({
            {
                label = data.label,
                name = data.label,
                icon = data.icon or false,
                distance = data.distance or 2.5,
                onSelect = function(hitData)
                    data.action(hitData.entity)
                end,
                canInteract = function(entity)
                    if not entity then return false end
                    return data.canInteract(entity)
                end
            }
        })
    end
end)
