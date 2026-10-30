eventName = "bablo-pettycrimes:"

if not Locales then
    Locales = {}
end

if GetCurrentResourceName() ~= "bablo-pettycrimes" then
    error("Resource name must be 'bablo-pettycrimes'")
    return
end

RegisterNetEvent(eventName .. "client:syncParticles")
AddEventHandler(eventName .. "client:syncParticles", function(effectType, data)
    if effectType ~= "smoke" then return end

    local entity = nil
    if NetworkDoesNetworkIdExist(data.netId) then
        local candidate = NetworkGetEntityFromNetworkId(data.netId)
        if candidate then
            entity = candidate
        end
    end

    if not DoesEntityExist(entity) then return end

    Main:loadParticle("core")

    local activeParticles = {}
    for i = 1, 5 do
        local fx = StartNetworkedParticleFxLoopedOnEntity(
            "exp_grd_bzgas_smoke",
            entity,
            vector3(0.0, 0.0, 0.0),
            vector3(0.0, 0.0, 0.0),
            0.2, false, false, false
        )
        table.insert(activeParticles, fx)
    end

    Citizen.Wait(data.duration)

    for _, fxHandle in pairs(activeParticles) do
        StopParticleFxLooped(fxHandle)
        ClearPedTasks(entity)
    end
end)

RegisterNetEvent(eventName .. "client:registerNetworkedEntity")
AddEventHandler(eventName .. "client:registerNetworkedEntity", function(netId, entityData)
    if not netId then return end
end)
