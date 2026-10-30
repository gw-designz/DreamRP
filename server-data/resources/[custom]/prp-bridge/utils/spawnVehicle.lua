---@class SpawmTemporaryVehiclePayload
---@field model  string | number
---@field coords vector3
---@field heading number
---@field plate string

---@param payload SpawmTemporaryVehiclePayload
---@return nil | number, string | nil
local function spawnTemporaryVehicle(payload)
    local model = type(payload.model) == 'string' and joaat(payload.model) or payload.model
    
    local success, response = pcall(function()
        local tempVehicle = CreateVehicle(model, 0, 0, -200, 0, true, true)

        local spawned = lib.waitFor(function()
            if DoesEntityExist(tempVehicle) then
                return true
            end
        end, 'Vehicle failed to spawn', 5 * 1000)

        if not spawned then
            lib.print.error("Failed to spawn temporary vehicle for model:", model)
        end

        local vehicleType = GetVehicleType(tempVehicle)
        DeleteEntity(tempVehicle)

        local vehicle = CreateVehicleServerSetter(
            model,
            vehicleType,
            payload.coords.x,
            payload.coords.y,
            payload.coords.z,
            payload.heading
        )

        local spawned = lib.waitFor(function()
            if DoesEntityExist(vehicle) then
                return true
            end
        end, 'Vehicle failed to spawn', 5 * 1000)

        if not spawned then
            lib.print.error("Failed to spawn vehicle for model:", model)
            return nil
        end

        if payload.plate then
            SetVehicleNumberPlateText(vehicle, payload.plate)
        end

        local plateAvailable = lib.waitFor(function()
            local plate = GetVehicleNumberPlateText(vehicle)
            if plate and plate ~= '' then
                return true
            end
        end, 'Vehicle plate failed to set', 5000)

        if not plateAvailable then
            lib.print.error("Failed to set plate for vehicle:", model)
            DeleteEntity(vehicle)
            return nil
        end

        return {
            vehicle = vehicle,
            plate = GetVehicleNumberPlateText(vehicle),
        }
    end)
    
    if not success then
        lib.print.error("Error spawning temporary vehicle:", response)
        return nil, nil
    end

    if not response then
        return nil, nil
    end
    
    return response.vehicle, response.plate
end
exports('SpawnTemporaryVehicle', spawnTemporaryVehicle)
