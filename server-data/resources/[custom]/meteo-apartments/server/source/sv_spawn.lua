local QBCore = exports['qb-core']:GetCoreObject()

-- Select starting apartment (secure)
lib.callback.register('meteo-apartments:server:selectStartingApartment', function(source, complexId)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return { success = false } end

    local citizenid = player.PlayerData.citizenid
    local complex = Apartments.Complexes[complexId]

    if not complex or not complex.startingEnabled then
        DebugPrint('Invalid starter complex:', complexId)
        local coords = Config.starterApartments.defaultSpawn
        TriggerClientEvent('meteo-apartments:client:spawnAtDefaultLocation', source, coords, true)
        return { success = false }
    end

    -- Use the proper createApartment export (handles all room finding, database, etc.)
    local apartmentId, err = exports['meteo-apartments']:createApartment(source, complexId)

    if not apartmentId then
        DebugPrint('Failed to create apartment:', err or 'unknown error')
        QBCore.Functions.Notify(source, locale('spawn_apartment_failed') or 'Failed to create apartment', 'error')
        local coords = Config.starterApartments.defaultSpawn
        TriggerClientEvent('meteo-apartments:client:spawnAtDefaultLocation', source, coords, true)
        return { success = false, error = err }
    end

    DebugPrint('Created starter apartment:', apartmentId, 'for', citizenid)

    -- Spawn player inside apartment (isFirstTime = true)
    -- Apartments resource handles everything: spawn, clothing trigger, etc.
    exports['meteo-apartments']:spawnInsideApartment(source, apartmentId, true)

    return { success = true }
end)

-- Select default spawn (secure)
lib.callback.register('meteo-apartments:server:selectDefaultSpawn', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return { success = false } end

    local coords = Config.starterApartments.defaultSpawn
    TriggerClientEvent('meteo-apartments:client:spawnAtDefaultLocation', source, coords, true)
    return { success = true }
end)