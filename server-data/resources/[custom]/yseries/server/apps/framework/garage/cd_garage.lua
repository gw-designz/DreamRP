----
-- NOTICE: This garage integration is provided as-is.
-- TeamsGG does not provide official support for this integration.
-- For any issues, please contact the script author. - https://discord.gg/codesign
----

CreateThread(function()
    if Config.Garages ~= 'cd_garage' then return end

    debugPrint("Using cd_garage")

    local FW = {}
    if Config.Framework == 'esx' then
        FW = {
            vehicle_table = 'owned_vehicles',
            vehicle_identifier = 'owner',
            vehicle_props = 'vehicle',
        }
    elseif Config.Framework == 'qb' or Config.Framework == 'qbox' then
        FW = {
            vehicle_table = 'player_vehicles',
            vehicle_identifier = 'citizenid',
            vehicle_props = 'mods',
        }
    end

    function GetPlayerVehicles(source)
        local vehicles = MySQL.query.await('SELECT * FROM ' .. FW.vehicle_table .. ' WHERE ' .. FW.vehicle_identifier .. ' = @idenfitier', {
            ['@idenfitier'] = Framework.GetPlayerFromId(source)?.identifier
        })

        if not vehicles then
            return nil
        end

        local VehiclesData = {}
        for _, v in pairs(vehicles) do
            local state

            if v.in_garage == 0 then
                state = "outOfGarage"
            elseif v.in_garage == 1 then
                state = v.garage_id or "garage"
            end

            if v.impound > 0 then
                local impoundData = json.decode(v.impound_data) or {}
                state = impoundData and impoundData.impound_label or "impounded"
            end

            local props = json.decode(v[FW.vehicle_props]) or {}
            local vehicle = {
                plate = v.plate,
                type = v.garage_type or "car",
                location = state,
                statistics = {
                    engine = props.engineHealth and math.floor(props.engineHealth / 10 + 0.5) or 0,
                    body = props.BodyHealth and math.floor(props.BodyHealth / 10 + 0.5) or 0,
                    fuel = props.fuelLevel and props.fuelLevel or 0
                },
                model = tonumber(props.model),
                vehicle = v.vehicle
            }

            VehiclesData[#VehiclesData + 1] = vehicle
        end

        return VehiclesData
    end

    local function IsVehicleOut(plate, vehicles)
        if not vehicles then
            vehicles = GetAllVehicles()
        end

        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            if DoesEntityExist(vehicle) and GetVehicleNumberPlateText(vehicle):gsub('%s+', '') == plate:gsub('%s+', '') then
                return true, vehicle
            end
        end

        return false
    end

    function GetVehicle(plate, source)
        local vehicle = MySQL.query.await(
            'SELECT plate, ' .. FW.vehicle_props .. ' FROM ' .. FW.vehicle_table .. ' WHERE ' .. FW.vehicle_identifier .. ' = @idenfitier AND plate = @plate AND in_garage = 1', {
                ['@idenfitier'] = Framework.GetPlayerFromId(source)?.identifier,
                ['@plate'] = plate
            })

        if not vehicle then return nil end

        local vehicleData = vehicle[1]

        if not vehicleData then return nil end

        local props = json.decode(vehicleData[FW.vehicle_props]) or {}
        vehicleData.fuel = props.fuelLevel and props.fuelLevel or 0
        vehicleData.hash = tonumber(props.model)

        MySQL.query.await('UPDATE ' .. FW.vehicle_table .. ' SET in_garage = 0 WHERE plate = @plate', {
            ['@plate'] = plate
        })

        return vehicleData
    end

    lib.callback.register('yseries:server:garage:get-vehicles', function(source)
        local vehicles = GetPlayerVehicles(source)
        if vehicles and #vehicles > 0 then
            local allVehicles = GetAllVehicles()

            for i = 1, #vehicles do
                if IsVehicleOut(vehicles?[i].plate, allVehicles) then
                    vehicles[i].location = 'Out of garage'
                end
            end
        end

        return vehicles
    end)

    lib.callback.register('yseries:server:garage:find-vehicle-by-plate', function(source, plate)
        local out, vehicle = IsVehicleOut(plate)
        if out and vehicle then
            return GetEntityCoords(vehicle)
        elseif not out then
            local exist, allGarages = pcall(function()
                return exports['cd_garage']:GetConfig().Locations
            end)
            if not exist then return false end

            local idenfitier = Framework.GetPlayerFromId(source)?.identifier
            local garageVehicle = MySQL.query.await('SELECT garage_id FROM ' .. FW.vehicle_table .. ' WHERE ' .. FW.vehicle_identifier .. ' = @idenfitier AND plate = @plate', {
                ['@idenfitier'] = idenfitier,
                ['@plate'] = plate
            })

            if garageVehicle and allGarages then
                for k, v in pairs(allGarages) do
                    if v.Garage_ID == garageVehicle[1].garage_id then
                        return vector3(allGarages[k].x_1, allGarages[k].y_1, allGarages[k].z_1)
                    end
                end
            end

            return false
        else
            return false
        end
    end)
end)
