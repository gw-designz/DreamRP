function GetGarageSystem()
    if Config.garage ~= 'auto' then
        local validGarages = { ['meteo-garages'] = true, ['jg-advancedgarages'] = true, ['qbx_garages'] = true, ['op-garages'] = true }
        if validGarages[Config.garage] then
            return Config.garage
        end
    end

    if GetResourceState('meteo-garages') == 'started' then
        return 'meteo-garages'
    elseif GetResourceState('qbx_garages') == 'started' then
        return 'qbx_garages' -- pls check docs
    elseif GetResourceState('jg-advancedgarages') == 'started' then
        return 'jg-advancedgarages'
    elseif GetResourceState('op-garages') == 'started' then
        return 'op-garages'
    end

    return nil
end

-- Open garage menu (spawn vehicle)
function OpenPropertyGarage(garageId, vehicleClass, spawnPoint)
    local garageSystem = GetGarageSystem()

    if not garageSystem then
        QBCore.Functions.Notify(locale('garage_not_available'), 'error')
        return false
    end

    if garageSystem == 'meteo-garages' then
        TriggerEvent('meteo-garages:client:openPropertyGarage', garageId, vehicleClass, spawnPoint)
        return true
    elseif garageSystem == 'jg-advancedgarages' then
        TriggerEvent('jg-advancedgarages:client:open-garage', garageId, vehicleClass)
        return true
    elseif garageSystem == 'qbx_garages' then
        -- Ensure garage exists first
        lib.callback.await('meteo-apartments:server:ensureQbxGarage', false, garageId, vehicleClass, spawnPoint)
        exports['qbx_garages']:OpenPropertyGarage(garageId, vehicleClass)
        return true
    elseif garageSystem == 'op-garages' then
        if spawnPoint then
            local coords = vec4(spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w or 0.0)
            exports['op-garages']:OpenGarageHere(coords, true)
        end
        return true
    end

    return false
end

-- Park vehicle in garage
function ParkPropertyVehicle(garageId, vehicleClass, spawnPoint)
    local garageSystem = GetGarageSystem()

    if not garageSystem then
        QBCore.Functions.Notify(locale('garage_not_available'), 'error')
        return false
    end

    if not cache.vehicle then
        QBCore.Functions.Notify(locale('not_in_vehicle'), 'error')
        return false
    end

    if garageSystem == 'meteo-garages' then
        TriggerEvent('meteo-garages:client:parkPropertyVehicle', garageId, vehicleClass)
        return true
    elseif garageSystem == 'jg-advancedgarages' then
        TriggerEvent('jg-advancedgarages:client:store-vehicle', garageId, vehicleClass)
        return true
    elseif garageSystem == 'qbx_garages' then
        -- Ensure garage exists first
        lib.callback.await('meteo-apartments:server:ensureQbxGarage', false, garageId, vehicleClass, spawnPoint)
        exports['qbx_garages']:ParkPropertyVehicle(garageId)
        return true
    elseif garageSystem == 'op-garages' then
        if spawnPoint then
            local coords = vec4(spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w or 0.0)
            exports['op-garages']:OpenGarageHere(coords, true)
        end
        return true
    end

    return false
end

-- STARTER APARTMENTS INTEGRATION

-- Export: Open spawn selection (used by QBX and other multichar systems)
exports('OpenSpawnSelection', function()
    DebugPrint('OpenSpawnSelection export called')

    if not Config.starterApartments or not Config.starterApartments.enabled then
        DebugPrint('Starter apartments disabled, triggering no apartments event')
        TriggerEvent('qbx_core:client:spawnNoApartments')
        return false
    end

    Wait(500) -- Wait for everything to initialize

    -- Get starter complexes with available counts from server
    local complexes = lib.callback.await('meteo-apartments:server:getStarterComplexesWithCounts', false)
    if not complexes or #complexes == 0 then
        DebugPrint('No starter apartment complexes found')
        TriggerEvent('qbx_core:client:spawnNoApartments')
        return false
    end

    DebugPrint('Opening spawn selection UI with', #complexes, 'complexes')
    OpenSpawnSelectionUI(complexes)
    return true
end)

RegisterNetEvent('meteo-apartments:client:spawnAtDefaultLocation', function(coords, isNewCharacter)
    if GetInvokingResource() then return end

    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z)
    SetEntityHeading(ped, coords.w or 0.0)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)

    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    Wait(500)
    DoScreenFadeIn(500)

    if isNewCharacter then
        Wait(1000)
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end
end)

-- Spawn inside apartment
RegisterNetEvent('meteo-apartments:client:spawnInApartment', function(spawnPoint, apartment, isFirstTime)
    if not spawnPoint then return end

    DoScreenFadeOut(500)
    Wait(500)

    PlayArrivedElevatorSound()

    SetEntityCoords(cache.ped, spawnPoint.x, spawnPoint.y, spawnPoint.z, false, false, false, false)
    SetEntityHeading(cache.ped, spawnPoint.w or 0.0)

    Wait(500)
    DoScreenFadeIn(500)

    if apartment then
        SetCurrentApartment(apartment.complexId, apartment.roomNumber, apartment.id)
    end

    DebugPrint('Spawned in apartment - isFirstTime:', isFirstTime or false)

    -- Trigger clothing selection for first-time character
    if isFirstTime then
        Wait(1000)
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
        DebugPrint('Triggered first character clothing event')
    end
end)