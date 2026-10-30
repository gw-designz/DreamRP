local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local screen = require 'client.screen'
local nozzle = require 'client.nozzle'
local fuel = require 'client.fuel'
local pump = {}

---@class FuelSession
---@field vehicle integer
---@field target number litres paid for
---@field dispensed number
---@field price number per litre
---@field total number paid up front
---@field startFuel number
---@field tank number
---@field grade string
---@field active boolean
local session

local function getVehicleInfo()
	local vehicle = state.nozzleVehicle

	if not vehicle or not DoesEntityExist(vehicle) then return { connected = false } end

	local tank = utils.getTankSize(vehicle)
	local fuelLevel = utils.getFuel(vehicle)

	return {
		connected = true,
		electric = utils.isElectric(vehicle),
		fuel = fuelLevel,
		capacity = tank,
		litres = tank * fuelLevel / 100,
		missing = math.max(0, tank * (100 - fuelLevel) / 100),
	}
end

local function getSessionInfo()
	if not session then return end

	return {
		target = session.target,
		dispensed = session.dispensed,
		price = session.price,
		total = session.total,
		grade = session.grade,
		cost = math.ceil(session.dispensed * session.price),
		fuel = session.startFuel + session.dispensed / session.tank * 100,
		capacity = session.tank,
	}
end

---Everything the pump screen needs when it opens
function pump.getContext()
	return {
		vehicle = getVehicleInfo(),
		session = getSessionInfo(),
		cash = utils.getMoney(),
		petrolCanEquipped = state.petrolCan ~= nil,
	}
end

local function igniteVehicle(vehicle)
	local filler = utils.getFillerPosition(vehicle)

	NetworkRequestControlOfEntity(vehicle)
	StartScriptFire(filler.x, filler.y, filler.z - 0.3, 25, true)
	StartEntityFire(vehicle)
	SetVehiclePetrolTankHealth(vehicle, 300.0)

	lib.notify({ type = 'error', description = locale('engine_fire') })
end

---@param reason 'complete' | 'stopped' | 'removed' | 'snapped' | 'fire' | 'full'
local function finish(reason)
	if not session or not session.active then return end

	session.active = false

	local dispensed = session.dispensed
	local result = lib.callback.await('ox_fuel:pumpFinish', false, dispensed)

	state.isFueling = false

	if result then
		if result.refund > 0 then
			lib.notify({ type = 'inform', description = locale('pump_refund', result.refund) })
		end

		lib.notify({ type = 'success', description = locale('fuel_success', ('%.1f'):format(result.litres), result.cost) })
	end

	screen.send('complete', {
		reason = reason,
		litres = result and result.litres or dispensed,
		cost = result and result.cost or 0,
		refund = result and result.refund or 0,
		fuel = result and result.fuel,
	})

	session = nil
end

nozzle.onDetach = function(reason)
	if session then finish(reason) end
end

local function run()
	local tick = config.pump.tick
	local rate = config.pump.litresPerSecond * tick / 1000
	local engineTime = 0

	while session and session.active do
		Wait(tick)

		if not session or not session.active then break end

		local vehicle = session.vehicle

		if not DoesEntityExist(vehicle) or state.nozzleVehicle ~= vehicle then
			return finish('removed')
		end

		if config.engineFire.enabled and GetIsVehicleEngineRunning(vehicle) then
			engineTime += tick

			if engineTime >= config.engineFire.graceTime then
				igniteVehicle(vehicle)
				return finish('fire')
			end
		else
			engineTime = 0
		end

		session.dispensed = math.min(session.target, session.dispensed + rate)

		local fuelLevel = math.min(100.0, session.startFuel + session.dispensed / session.tank * 100)

		SetVehicleFuelLevel(vehicle, fuelLevel)
		screen.send('progress', getSessionInfo())

		if session.dispensed >= session.target then
			return finish(fuelLevel >= 99.9 and 'full' or 'complete')
		end
	end
end

---Pay at the pump and start fueling. Called from the pump screen.
---@param data { grade: string, litres: number, method: 'cash' | 'card' }
---@return boolean success, string|table result
function pump.start(data)
	if session then return false, locale('pump_already_fueling') end

	local vehicle = state.nozzleVehicle
	local pumpData = state.nozzlePump

	if not vehicle or not DoesEntityExist(vehicle) or not pumpData then
		return false, locale('pump_no_vehicle')
	end

	if utils.isElectric(vehicle) then return false, locale('vehicle_electric') end

	local tank, class = utils.getTankSize(vehicle)
	local fuelLevel = utils.getFuel(vehicle)
	local missing = tank * (100 - fuelLevel) / 100
	local litres = math.min(tonumber(data.litres) or 0, missing)

	if litres < 0.1 then return false, locale('tank_full') end

	if not NetworkGetEntityIsNetworked(vehicle) then return false, locale('pump_no_vehicle') end

	local ok, result = lib.callback.await('ox_fuel:pumpStart', false, {
		netId = NetworkGetNetworkIdFromEntity(vehicle),
		grade = data.grade,
		litres = litres,
		method = data.method,
		class = class,
		pump = pumpData.coords,
	})

	if not ok then return false, result end

	session = {
		vehicle = vehicle,
		target = result.litres,
		dispensed = 0,
		price = result.price,
		total = result.total,
		startFuel = result.fuel,
		tank = result.tank,
		grade = data.grade,
		active = true,
	}

	state.isFueling = true
	CreateThread(run)

	return true, getSessionInfo()
end

function pump.stop()
	if session then CreateThread(function() finish('stopped') end) end
end

---Open the screen on a pump
---@param pumpData PumpData
function pump.openScreen(pumpData)
	if screen.isOpen or cache.vehicle then return end

	if state.nozzlePump and state.nozzlePump.key ~= pumpData.key then
		return lib.notify({ type = 'error', description = locale('pump_wrong_pump') })
	end

	screen.open(pumpData, pump.getContext())
end

-- Pump screen callbacks

RegisterNUICallback('pay', function(data, cb)
	CreateThread(function()
		local ok, result = pump.start(data)

		cb({ ok = ok, error = not ok and result or nil, session = ok and result or nil })
	end)
end)

RegisterNUICallback('stop', function(_, cb)
	pump.stop()
	cb(1)
end)

RegisterNUICallback('exit', function(_, cb)
	screen.close()
	cb(1)
end)

RegisterNUICallback('refresh', function(_, cb)
	cb(pump.getContext())
end)

RegisterNUICallback('petrolCan', function(_, cb)
	cb(1)

	if not config.petrolCan.enabled then return end

	local pumpData = state.screenPump

	screen.close()

	if not pumpData or state.nozzle then
		return lib.notify({ type = 'error', description = locale('petrolcan_hang_up') })
	end

	local hasCan = state.petrolCan ~= nil
	local price = hasCan and config.petrolCan.refillPrice or config.petrolCan.price

	if utils.getMoney() < price then
		return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
	end

	CreateThread(function()
		Wait(600)
		fuel.getPetrolCan(pumpData.coords, hasCan)
	end)
end)

return pump
