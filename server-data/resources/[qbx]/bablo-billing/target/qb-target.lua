
Target = Target or {}

CreateThread(function()
    if Config.Target ~= 'qb-target' then
        return
    end

    function Target:addTargetEntity(entity, data)
        exports['qb-target']:AddTargetEntity(entity, {
            options = {
                {
                    icon = data.icon or false,
                    label = data.label,
                    bones = data.bones or {},
                    action = function(entity)
                        data.action(entity)
                    end,
                    canInteract = function(entity)
                        if not entity then return false end
                        return data.canInteract(entity)
                    end,
                }
            },
            distance = 2.5,
        })

        return data.label
    end

    function Target:removeTargetEntity(entity, contextId)
        exports['qb-target']:RemoveTargetEntity(entity, contextId)
    end

    function Target:addGlobalPed(data)
        exports['qb-target']:AddGlobalPed({
            options = {
                {
                    icon = data.icon or false,
                    label = data.label,
                    action = function(entity)
                        if IsPedAPlayer(entity) then return false end
                        data.action(entity)
                    end,
                    canInteract = function(entity)
                        if IsPedAPlayer(entity) then return false end
                        return data.canInteract(entity)
                    end,
                }
            },
            distance = 2.5,
        })

        return data.label
    end

    function Target:removeGlobalPed(contextId)
        exports['qb-target']:RemoveGlobalPed(contextId)
    end

    function Target:addGlobalPlayer(data)
        exports['qb-target']:AddGlobalPlayer({
            options = {
                {
                    icon = data.icon or false,
                    label = data.label,
                    action = function(entity)
                        data.action(entity)
                    end,
                    canInteract = function(entity)
                        if not entity then return false end
                        return data.canInteract(entity)
                    end,
                }
            },
            distance = data.distance or 2.5,
        })

        return data.label
    end

    function Target:removeGlobalPlayer(contextId)
        exports['qb-target']:RemoveGlobalPlayer(contextId)
    end

    function Target:addGlobalVehicle(data)
        exports['qb-target']:AddGlobalVehicle({
            options = {
                {
                    icon = data.icon or false,
                    label = data.label,
                    action = function(entity)
                        if IsPedAPlayer(entity) then return false end
                        data.action(entity)
                    end,
                    canInteract = function(entity)
                        if IsPedAPlayer(entity) then return false end
                        return data.canInteract(entity)
                    end,
                }
            },
            distance = data.distance or 2.5,
        })
    end

    function Target:removeGlobalVehicle(contextId)
        exports['qb-target']:RemoveGlobalVehicle(contextId)
    end

    function Target:addTargetModel(models, data)
        exports['qb-target']:AddTargetModel(models, {
            options = {
                {
                    icon = data.icon or false,
                    label = data.label,
                    action = function(entity)
                        data.action(entity)
                    end,
                    canInteract = function(entity)
                        return data.canInteract(entity)
                    end,
                }
            },
            distance = 2.5
        })
    end
end)
