local config = require 'config'

if not config then return end

-- fuel is consumed by this resource based on rpm, not by the game
SetFuelConsumptionState(true)
SetFuelConsumptionRateMultiplier(0.0)

AddTextEntry('ox_fuel_station', locale('fuel_station_blip'))

local utils = require 'client.utils'
local state = require 'client.state'
local fuel  = require 'client.fuel'

require 'client.stations'
require 'client.pump'
require 'client.editor'

local fuelUsage = config.fuelUsage

---Percent of the tank burned this second; harder driving (higher rpm) burns more
---@param vehicle integer
local function getConsumption(vehicle)
	local rpm = math.clamp(GetVehicleCurrentRpm(vehicle), 0.0, 1.0)
	local index = math.floor(rpm * 10) + 1
	local usage = fuelUsage[index] or fuelUsage[#fuelUsage]

	return usage * (config.classUsage[GetVehicleClass(vehicle)] or 1.0) / 10 * config.consumptionMultiplier
end

local function startDrivingVehicle()
	local vehicle = cache.vehicle

	if not DoesVehicleUseFuel(vehicle) then return end

	local vehState = Entity(vehicle).state

	if not vehState.fuel then
		TriggerServerEvent('ox_fuel:setFuel', GetVehicleFuelLevel(vehicle))
		while not vehState.fuel do Wait(0) end
	end

	local electric = utils.isElectric(vehicle)

	-- electric vehicles never run dry
	SetVehicleFuelLevel(vehicle, electric and 100.0 or vehState.fuel)

	local fuelTick = 0

	while cache.seat == -1 do
		if not DoesEntityExist(vehicle) then return end

		SetFuelConsumptionRateMultiplier(0.0)

		if not electric and GetIsVehicleEngineRunning(vehicle) then
			local fuelAmount = tonumber(vehState.fuel)

			if fuelAmount > 0 then
				local newFuel = fuelAmount - getConsumption(vehicle)

				if GetVehiclePetrolTankHealth(vehicle) < 700 then
					newFuel -= math.random(10, 20) * 0.01
				end

				if newFuel <= 0 then
					newFuel = 0
					SetVehicleEngineOn(vehicle, false, true, true)
				end

				if fuelAmount ~= newFuel then
					if fuelTick == 15 then
						fuelTick = 0
					end

					fuel.setFuel(vehState, vehicle, newFuel, fuelTick == 0 or newFuel == 0)
					fuelTick += 1
				end
			end
		end

		Wait(1000)
	end

	fuel.setFuel(vehState, vehicle, vehState.fuel, true)
end

if cache.seat == -1 then CreateThread(startDrivingVehicle) end

lib.onCache('seat', function(seat)
	if cache.vehicle then
		state.lastVehicle = cache.vehicle
	end

	if seat == -1 then
		SetTimeout(0, startDrivingVehicle)
	end
end)

local interaction = config.interaction

if interaction == 'interact' and GetResourceState('interact') ~= 'started' then
	lib.print.warn('interact is not started, falling back to help text')
	interaction = 'helptext'
end

if interaction == 'ox_target' then
	require 'client.target'
elseif interaction == 'interact' then
	require 'client.interact'
else
	require 'client.helptext'
end
