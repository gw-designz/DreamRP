local config = require 'config'
local state  = require 'client.state'
local utils  = require 'client.utils'
local fuel   = require 'client.fuel'
local pumps  = require 'client.pumps'
local nozzle = require 'client.nozzle'
local pump   = require 'client.pump'
local screen = require 'client.screen'

local function canUse()
	return not (cache.vehicle or screen.isOpen or lib.progressActive())
end

---@param entity integer
local function isNozzlePump(entity)
	return state.nozzlePump and #(GetEntityCoords(entity) - state.nozzlePump.coords) < 1.0
end

---Pump data for an entity, reusing the station's pump when there is one so busy screens line up
---@param entity integer
local function getPump(entity)
	local nearest = state.nearestPump

	if nearest and #(GetEntityCoords(entity) - nearest.coords) < 1.0 then return nearest end

	return pumps.fromEntity(entity)
end

local pumpOptions = {
	{
		distance = 2,
		icon = 'fas fa-gas-pump',
		label = locale('nozzle_take'),
		canInteract = function() return canUse() and not state.nozzle end,
		onSelect = function(data)
			local pumpData = getPump(data.entity)
			if pumpData then nozzle.take(pumpData) end
		end,
	},
	{
		distance = 2,
		icon = 'fas fa-hand',
		label = locale('nozzle_return'),
		canInteract = function(entity) return canUse() and state.isHoldingNozzle() and isNozzlePump(entity) end,
		onSelect = function() nozzle.putBack() end,
	},
	{
		distance = 2,
		icon = 'fas fa-display',
		label = locale('pump_use'),
		canInteract = function(entity)
			return canUse() and not state.isHoldingNozzle() and (not state.nozzlePump or isNozzlePump(entity))
		end,
		onSelect = function(data)
			local pumpData = getPump(data.entity)
			if pumpData then pump.openScreen(pumpData) end
		end,
	},
}

if config.petrolCan.enabled then
	pumpOptions[#pumpOptions + 1] = {
		distance = 2,
		icon = 'fas fa-faucet',
		label = locale('petrolcan_buy_or_refill'),
		canInteract = function() return canUse() and not state.nozzle end,
		onSelect = function(data)
			local hasCan = GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
			local price = hasCan and config.petrolCan.refillPrice or config.petrolCan.price

			if utils.getMoney() < price then
				return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
			end

			return fuel.getPetrolCan(data.coords, hasCan)
		end,
	}
end

exports.ox_target:addModel(config.pumpModels, pumpOptions)

local vehicleOptions = {
	{
		distance = 2,
		icon = 'fas fa-gas-pump',
		label = locale('nozzle_insert'),
		canInteract = function(entity)
			return canUse() and state.isHoldingNozzle() and DoesVehicleUseFuel(entity)
		end,
		onSelect = function(data) nozzle.insert(data.entity) end,
	},
	{
		distance = 2,
		icon = 'fas fa-hand',
		label = locale('nozzle_remove'),
		canInteract = function(entity) return canUse() and state.nozzleVehicle == entity end,
		onSelect = function() nozzle.remove() end,
	},
}

if config.petrolCan.enabled then
	vehicleOptions[#vehicleOptions + 1] = {
		distance = 2,
		icon = 'fas fa-gas-pump',
		label = locale('petrolcan_refuel'),
		canInteract = function(entity)
			if state.isFueling or state.nozzle or not canUse() or not DoesVehicleUseFuel(entity) or utils.isElectric(entity) then
				return false
			end

			return state.petrolCan ~= nil
		end,
		onSelect = function(data)
			if state.petrolCan.metadata.ammo <= config.durabilityTick then
				return lib.notify({ type = 'error', description = locale('petrolcan_not_enough_fuel') })
			end

			fuel.startFueling(data.entity)
		end,
	}
end

exports.ox_target:addGlobalVehicle(vehicleOptions)
