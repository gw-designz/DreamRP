
Target = Target or {}

CreateThread(function()
    if Config.Target ~= 'standalone' then
        return
    end

    local registeredTargets = {}

    function Target:addTargetEntity(entity, data)
        table.insert(registeredTargets, {
            type = "entity",
            entity = entity,
            label = data.label,
            icon = data.icon,
            action = data.action,
            canInteract = data.canInteract or function() return true end
        })
        return data.label
    end

    function Target:removeTargetEntity(entityToRemove)
        for i = #registeredTargets, 1, -1 do
            if registeredTargets[i].type == "entity" and registeredTargets[i].entity == entityToRemove then
                table.remove(registeredTargets, i)
            end
        end
    end

    function Target:addGlobalPed(data)
        table.insert(registeredTargets, {
            type = "globalPed",
            label = data.label,
            icon = data.icon,
            action = data.action,
            canInteract = function(ped)
                return not IsPedAPlayer(ped) and (data.canInteract and data.canInteract(ped) or true)
            end
        })
        return data.label
    end

    function Target:removeGlobalPed(label)
        for i = #registeredTargets, 1, -1 do
            if registeredTargets[i].type == "globalPed" and registeredTargets[i].label == label then
                table.remove(registeredTargets, i)
            end
        end
    end

    function Target:addGlobalVehicle(data)
        table.insert(registeredTargets, {
            type = "globalVehicle",
            label = data.label,
            icon = data.icon,
            action = data.action,
            canInteract = data.canInteract or function() return true end,
            distance = data.distance or 2.5,
        })
        return data.label
    end

    function Target:addTargetModel(models, data)
        table.insert(registeredTargets, {
            type = "model",
            models = models,
            label = data.label,
            icon = data.icon,
            action = data.action,
            canInteract = data.canInteract or function() return true end
        })
        return data.label
    end

    function Draw2DText(text)
        text = "~INPUT_PICKUP~ " .. text

        AddTextEntry('esxHelpNotification', text)
        BeginTextCommandDisplayHelp('esxHelpNotification')
        EndTextCommandDisplayHelp(0, false, true, -1)
    end

    local nearbyTarget = false
    local pedCache = {}
    local objCache = {}
    local vehCache = {}

    CreateThread(function()
        while true do
            pedCache = GetGamePool("CPed")
            objCache = GetGamePool("CObject")
            vehCache = GetGamePool("CVehicle")
            Wait(2000)
        end
    end)

    CreateThread(function()
        while true do
            local interval = 500
            local coords = GetEntityCoords(cache.ped)
            local isPedInVehicle = IsPedInAnyVehicle(cache.ped, false)
            nearbyTarget = false

            if not isPedInVehicle then
                for _, target in ipairs(registeredTargets) do
                    if target.type == "entity" and DoesEntityExist(target.entity) then
                        local entCoords = GetEntityCoords(target.entity)
                        if #(coords - entCoords) < 2.5 and target.canInteract(target.entity) then
                            Draw2DText(target.label)
                            if IsControlJustPressed(0, 38) then
                                target.action(target.entity)
                            end
                            nearbyTarget = true
                            break
                        end
                    elseif target.type == "globalPed" then
                        for _, ped in ipairs(pedCache) do
                            if not IsPedAPlayer(ped) and #(coords - GetEntityCoords(ped)) < 2.5 and target.canInteract(ped) then
                                Draw2DText(target.label)
                                if IsControlJustPressed(0, 38) then
                                    target.action(ped)
                                end
                                nearbyTarget = true
                                break
                            end
                        end
                    elseif target.type == "model" then
                        for _, obj in ipairs(objCache) do
                            local model = GetEntityModel(obj)
                            for _, m in ipairs(target.models) do
                                if model == GetHashKey(m) and #(coords - GetEntityCoords(obj)) < 2.5 and target.canInteract(obj) then
                                    Draw2DText(target.label)
                                    if IsControlJustPressed(0, 38) then
                                        target.action(obj)
                                    end
                                    nearbyTarget = true
                                    break
                                end
                            end
                        end
                    elseif target.type == "globalVehicle" then
                        local d = target.distance or 2.5
                        for _, veh in ipairs(vehCache) do
                            if #(coords - GetEntityCoords(veh)) < d and target.canInteract(veh) then
                                Draw2DText(target.label)
                                if IsControlJustPressed(0, 38) then
                                    target.action(veh)
                                end
                                nearbyTarget = true
                                break
                            end
                        end
                    end
    
                    if nearbyTarget then break end
                end
            end

            if nearbyTarget then
                interval = 0
            end

            Wait(interval)
        end
    end)
end)
