---Maps `Config.Garage.CustomVehicles` by model name (and joaat hash) and sets `cover` when `vehicle` / `model` matches. Call before `MapVehiclesData`.
---@param vehicles table[]|nil
---@return table[]|nil
local function applyGarageCustomVehicleCovers(vehicles)
    if not vehicles then return vehicles end

    local custom = (Config.Garage and Config.Garage.CustomVehicles) or {}
    local coverByModel = {}
    for i = 1, #custom do
        local e = custom[i]
        if type(e.model) == 'string' and type(e.cover) == 'string' and e.cover ~= '' then
            local name = e.model:lower()
            coverByModel[name] = e.cover
            coverByModel[joaat(name)] = e.cover
        end
    end
    if not next(coverByModel) then return vehicles end

    for i = 1, #vehicles do
        local v = vehicles[i]
        if not v.cover or v.cover == '' then
            local url
            if type(v.vehicle) == 'string' then url = coverByModel[v.vehicle:lower()] end
            if not url and type(v.model) == 'string' then url = coverByModel[v.model:lower()] end
            if not url and type(v.model) == 'number' then url = coverByModel[v.model] end
            if url then v.cover = url end
        end
    end
    return vehicles
end

RegisterNUICallback('garage:set-waypoint', function(plate, cb)
    local coords = FindVehicleByPlate(plate)
    if coords then
        SetNewWaypoint(coords.x, coords.y)

        cb({ found = true })
    else
        cb({ found = false })
    end
end)

-- ==================
-- Expected object --
-- ==================
-- [
--     {
--         "location": "Out of garage",
--         "model": "Pegassi Bati 801",
--         "plate": "0MY042VX",
--         "statistics": {
--             "body": 98,
--             "engine": 100,
--             "fuel": 97
--         },
--         "type": "car",
--         "vehicle": "bati" -- For default game vehicles this vehicle model will be used to get the vehicle photo like so - `https://docs.fivem.net/vehicles/bati.webp`
--         "cover": 'https://i.imgur.com/0JZ6X3S.png' -- If you want to use a custom image for the vehicle photo you can use this property and `vehicle` will be ignored.
--     }
-- ]
RegisterNUICallback('garage:get-vehicles', function(_, cb)
    if Config.Garages == 'auto' then
        cb(nil)
        return
    end

    local vehicles = lib.callback.await('yseries:server:garage:get-vehicles')

    vehicles = applyGarageCustomVehicleCovers(vehicles)

    vehicles = MapVehiclesData(vehicles)

    cb(vehicles)
end)

---Function to find a spawn point for the vehicle.
local function findSpawnLocation(minDist)
    if not minDist then
        minDist = 150
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local nth = 0
    local maxAttempts = 50 -- Prevent infinite loops

    local success, position, heading
    repeat
        nth += 1
        success, position, heading = GetNthClosestVehicleNodeWithHeading(playerCoords.x, playerCoords.y, playerCoords.z,
            nth, 0, 0, 0)

        -- For close spawning, ensure we're within reasonable range (5-15m)
        if minDist <= 15 and success then
            local distance = #(playerCoords - position)
            if distance >= minDist and distance <= 15.0 then
                break
            end
        end
    until (minDist > 15 and #(playerCoords - position) > minDist) or success == false or nth > maxAttempts

    return position, heading
end

local function giveVehicleKeys(plate, vehicleEntity)
    if not DoesEntityExist(vehicleEntity) then
        debugPrint("Vehicle entity does not exist when trying to give keys")
        return false
    end

    debugPrint("Giving vehicle keys - Plate: " .. plate .. ", VehicleKeys system: " .. (Config.Valet.VehicleKeys or "none"))

    if Config.Valet.VehicleKeys == "qb-vehiclekeys" or Config.Valet.VehicleKeys == "qbx_vehiclekeys" then
        TriggerEvent("vehiclekeys:client:SetOwner", plate)
    elseif Config.Valet.VehicleKeys == "jaksam-vehicles-keys" then
        TriggerServerEvent("vehicles_keys:selfGiveVehicleKeys", plate)
    elseif Config.Valet.VehicleKeys == "mk_vehiclekeys" then
        exports["mk_vehiclekeys"]:AddKey(vehicleEntity)
    elseif Config.Valet.VehicleKeys == "qs-vehiclekeys" then
        local model = GetEntityArchetypeName(vehicleEntity)
        exports["qs-vehiclekeys"]:GiveKeys(plate, model)
    elseif Config.Valet.VehicleKeys == "wasabi_carlock" then
        exports.wasabi_carlock:GiveKey(plate)
    elseif Config.Valet.VehicleKeys == "cd_garage" then
        TriggerEvent("cd_garage:AddKeys", plate)
    elseif Config.Valet.VehicleKeys == "okokGarage" then
        TriggerServerEvent("okokGarage:GiveKeys", plate)
    elseif Config.Valet.VehicleKeys == "t1ger_keys" then
        TriggerServerEvent("t1ger_keys:updateOwnedKeys", plate, true)
    elseif Config.Valet.VehicleKeys == "MrNewbVehicleKeys" then
        exports.MrNewbVehicleKeys:GiveKeys(vehicleEntity)
    elseif Config.Valet.VehicleKeys == "Renewed" then
        exports["Renewed-Vehiclekeys"]:addKey(plate)
    else
        -- Implement your own vehicle keys system here.
        debugPrint("No vehicle keys system configured or unsupported system: " .. (Config.Valet.VehicleKeys or "none"))
        return false
    end

    return true
end

local function deliverVehicle(plate, cb)
    local spawnDistance = Config.Valet.DriveToPlayer and 35 or 5 -- 5-15m for direct spawn, 50m+ for valet driving
    local location, heading = findSpawnLocation(spawnDistance)

    -- If close spawn failed and we're trying to spawn directly, try a slightly larger distance
    if not location and not Config.Valet.DriveToPlayer then
        debugPrint("Close spawn failed, trying slightly further away...")
        location, heading = findSpawnLocation(45)
    end

    if not location then
        debugPrint("No suitable location found to spawn the vehicle.")
        cb(false)
        return
    end

    if IsPedInAnyVehicle(PlayerPedId(), false) then
        debugPrint("Player is already in a vehicle.")
        cb(false)
        return
    end

    local vehicleData = lib.callback.await('garage:deliver-vehicle', false, plate)
    if not vehicleData then
        debugPrint("Vehicle data not found.")
        cb(false)
        return
    end

    local vehicle = CreateFrameworkVehicle(vehicleData, location)
    if not vehicle or not DoesEntityExist(vehicle) then
        debugPrint("Failed to create vehicle entity")
        cb(false)
        return
    end

    SetEntityHeading(vehicle, heading - 180)

    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, "OFF")
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)

    if Config.Garages == "jg-advancedgarages" then
        TriggerServerEvent("jg-advancedgarages:server:register-vehicle-outside", plate, VehToNet(vehicle))
    end

    -- Wait a moment for the vehicle to be fully networked before giving keys
    Wait(100)

    local keySuccess = giveVehicleKeys(plate, vehicle)
    debugPrint("Vehicle keys given successfully: " .. tostring(keySuccess))

    -- Check if valet should drive to player or just spawn the vehicle
    if Config.Valet.DriveToPlayer then
        local model = `S_M_Y_XMech_01`
        while not HasModelLoaded(model) do
            RequestModel(model)
            Wait(500)
        end

        local ped = CreatePedInsideVehicle(vehicle, 4, model, -1, true, false)
        local playerCoords = GetEntityCoords(PlayerPedId())
        TaskVehicleDriveToCoord(ped, vehicle, playerCoords.x, playerCoords.y, playerCoords.z, 50.0, 0, GetEntityModel(vehicle), 786603, 3.0, 1)
        SetPedKeepTask(ped, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCombatAttributes(ped, 17, true)
        SetPedAlertness(ped, 0)

        cb(true)

        -- wait for the ped to arrive
        local blip = AddBlipForEntity(vehicle)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 5)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Valet")
        EndTextCommandSetBlipName(blip)

        while #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) > 10.0 do
            Wait(1000)
        end

        RemoveBlip(blip)

        -- make the ped exit the vehicle, then wander in area, and set as no longer needed
        TaskLeaveVehicle(ped, vehicle, 0)
        TaskWanderStandard(ped, 10.0, 10)
        SetEntityAsNoLongerNeeded(ped)
    else
        cb(true)

        -- Create a temporary blip to show vehicle location
        local blip = AddBlipForEntity(vehicle)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 3) -- Green color for spawned vehicle

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Your Vehicle")
        EndTextCommandSetBlipName(blip)

        -- Remove blip after 10 seconds
        SetTimeout(30000, function()
            RemoveBlip(blip)
        end)

        debugPrint("Vehicle spawned near player at coordinates: " .. tostring(location))
    end
end

RegisterNUICallback('garage:valet', function(plate, cb)
    if not Config.Valet.Enabled then
        return
    end

    deliverVehicle(plate, cb)
end)
