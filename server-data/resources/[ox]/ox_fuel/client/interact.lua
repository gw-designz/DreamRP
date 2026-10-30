local config = require 'config'
local state  = require 'client.state'
local utils  = require 'client.utils'
local fuel   = require 'client.fuel'
local pumps  = require 'client.pumps'
local nozzle = require 'client.nozzle'
local pump   = require 'client.pump'
local screen = require 'client.screen'

local interact = exports.interact

local function canUse()
	return not (cache.vehicle or screen.isOpen or lib.progressActive() or state.busy)
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

local function run(fn)
	if state.busy then return end

	CreateThread(function()
		state.busy = true
		local ok, err = pcall(fn)
		state.busy = false

		if not ok then lib.print.error(err) end
	end)
end

-- Pumps

local pumpOptions = {
	{
		name = 'ox_fuel:nozzle_take',
		label = locale('nozzle_take'),
		canInteract = function() return canUse() and not state.nozzle end,
		action = function(entity)
			local pumpData = getPump(entity)
			if pumpData then run(function() nozzle.take(pumpData) end) end
		end,
	},
	{
		name = 'ox_fuel:nozzle_return',
		label = locale('nozzle_return'),
		canInteract = function(entity) return canUse() and state.isHoldingNozzle() and isNozzlePump(entity) end,
		action = function() run(function() nozzle.putBack() end) end,
	},
	{
		name = 'ox_fuel:pump_use',
		label = locale('pump_use'),
		canInteract = function(entity)
			return canUse() and not state.isHoldingNozzle() and (not state.nozzlePump or isNozzlePump(entity))
		end,
		action = function(entity)
			local pumpData = getPump(entity)
			if pumpData then run(function() pump.openScreen(pumpData) end) end
		end,
	},
}

if config.petrolCan.enabled then
	pumpOptions[#pumpOptions + 1] = {
		name = 'ox_fuel:petrolcan',
		label = locale('petrolcan_buy_or_refill'),
		canInteract = function() return canUse() and not state.nozzle end,
		action = function(entity)
			local hasCan = GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`
			local price = hasCan and config.petrolCan.refillPrice or config.petrolCan.price

			if utils.getMoney() < price then
				return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
			end

			local coords = GetEntityCoords(entity)
			run(function() fuel.getPetrolCan(coords, hasCan) end)
		end,
	}
end

--[[
	Pumps are registered one by one as local entity interactions instead of AddModelInteraction.
	interact's model path sets hidden options to nil inside the options list, leaving holes that
	crash interacts.lua ("attempt to index a nil value (local 'option')") once some pump options
	are hidden, e.g. after the nozzle is put in a car.
]]

local pumpModels = {}

for i = 1, #config.pumpModels do
	pumpModels[config.pumpModels[i]] = true
end

---interact keeps the table it's given and may append to it, so each pump gets its own list
local function copyOptions(options)
	local copy = {}

	for i = 1, #options do copy[i] = options[i] end

	return copy
end

---@type table<integer, any> pump entity -> interaction id
local registeredPumps = {}

local function removePump(entity)
	pcall(function() interact:RemoveInteraction(registeredPumps[entity]) end)
	registeredPumps[entity] = nil
end

CreateThread(function()
	local radius = config.interact.distance + 10.0

	while true do
		local seen = {}

		for _, nearby in ipairs(lib.getNearbyObjects(GetEntityCoords(cache.ped), radius)) do
			local entity = nearby.object

			if pumpModels[GetEntityModel(entity)] then
				seen[entity] = true

				if not registeredPumps[entity] then
					local ok, id = pcall(function()
						return interact:AddLocalEntityInteraction({
							entity = entity,
							name = 'ox_fuel:pump',
							distance = config.interact.distance,
							interactDst = config.interact.pumpDistance,
							offset = vec3(0.0, 0.0, config.interact.pumpHeight),
							options = copyOptions(pumpOptions),
						})
					end)

					if ok and id then registeredPumps[entity] = id end
				end
			end
		end

		for entity in pairs(registeredPumps) do
			if not seen[entity] then removePump(entity) end
		end

		Wait(1000)
	end
end)

-- Vehicle fillers, registered on the closest vehicle while the player has a nozzle or petrol can

local fillerOptions = {
	{
		name = 'ox_fuel:nozzle_insert',
		label = locale('nozzle_insert'),
		canInteract = function(entity) return canUse() and state.isHoldingNozzle() and DoesVehicleUseFuel(entity) end,
		action = function(entity) run(function() nozzle.insert(entity) end) end,
	},
	{
		name = 'ox_fuel:nozzle_remove',
		label = locale('nozzle_remove'),
		canInteract = function(entity) return canUse() and state.nozzleVehicle == entity end,
		action = function() run(nozzle.remove) end,
	},
}

if config.petrolCan.enabled then
	fillerOptions[#fillerOptions + 1] = {
		name = 'ox_fuel:petrolcan_refuel',
		label = locale('petrolcan_refuel'),
		canInteract = function(entity)
			if state.isFueling or state.nozzle or not canUse() or not DoesVehicleUseFuel(entity) or utils.isElectric(entity) then
				return false
			end

			return state.petrolCan ~= nil
		end,
		action = function(entity)
			if state.petrolCan.metadata.ammo <= config.durabilityTick then
				return lib.notify({ type = 'error', description = locale('petrolcan_not_enough_fuel') })
			end

			run(function() fuel.startFueling(entity) end)
		end,
	}
end

---@type { vehicle: integer, id: any }?
local registered

local function unregister()
	if registered then
		pcall(function() interact:RemoveInteraction(registered.id) end)
		registered = nil
	end
end

local function register(vehicle)
	if not NetworkGetEntityIsNetworked(vehicle) then return end

	local filler = utils.getFillerPosition(vehicle)
	local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, filler.x, filler.y, filler.z)
	local ok, id = pcall(function()
		return interact:AddEntityInteraction({
			netId = NetworkGetNetworkIdFromEntity(vehicle),
			name = 'ox_fuel:filler',
			distance = config.interact.distance,
			interactDst = config.nozzle.reach,
			offset = offset,
			options = copyOptions(fillerOptions),
		})
	end)

	if ok and id then registered = { vehicle = vehicle, id = id } end
end

CreateThread(function()
	while true do
		local vehicle

		if not cache.vehicle and (state.nozzle or (config.petrolCan.enabled and state.petrolCan)) then
			vehicle = state.nozzleVehicle or lib.getClosestVehicle(GetEntityCoords(cache.ped), 6.0, false)
		end

		if registered and registered.vehicle ~= vehicle then unregister() end
		if vehicle and not registered then register(vehicle) end

		Wait(500)
	end
end)

AddEventHandler('onResourceStop', function(name)
	if name ~= cache.resource then return end

	unregister()

	for entity in pairs(registeredPumps) do removePump(entity) end
end)
