local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local fuel = require 'client.fuel'
local nozzle = require 'client.nozzle'
local pump = require 'client.pump'
local screen = require 'client.screen'

local primaryKey = utils.keyLabel('startfueling')
local secondaryKey = utils.keyLabel('fuelpumpscreen')

---Vehicle whose filler is within reach of the player
---@return integer?
local function getVehicleAtFiller()
	local coords = GetEntityCoords(cache.ped)
	local vehicle = lib.getClosestVehicle(coords, 5.0, false)

	if vehicle and #(utils.getFillerPosition(vehicle) - coords) <= config.nozzle.reach then
		return vehicle
	end
end

---@return { primary?: { label: string, action: function }, secondary?: { label: string, action: function } }?
local function getActions()
	if screen.isOpen or lib.progressActive() then return end

	local nearestPump = state.nearestPump

	if cache.vehicle then
		if nearestPump then return { info = locale('leave_vehicle') } end
		return
	end

	local actions = {}

	if state.isHoldingNozzle() then
		local vehicle = getVehicleAtFiller()

		if vehicle then
			actions.primary = { label = locale('nozzle_insert'), action = function() nozzle.insert(vehicle) end }
		elseif nearestPump and nearestPump.key == state.nozzlePump.key then
			actions.primary = { label = locale('nozzle_return'), action = function() nozzle.putBack() end }
		end

		return actions
	end

	if state.nozzleVehicle then
		local vehicle = getVehicleAtFiller()

		if vehicle == state.nozzleVehicle then
			actions.primary = { label = locale('nozzle_remove'), action = nozzle.remove }
		end
	end

	if nearestPump then
		if not actions.primary and state.petrolCan and config.petrolCan.enabled then
			actions.primary = {
				label = locale('petrolcan_buy_or_refill'),
				action = function()
					if utils.getMoney() < config.petrolCan.refillPrice then
						return lib.notify({ type = 'error', description = locale('petrolcan_cannot_afford') })
					end

					fuel.getPetrolCan(nearestPump.coords, true)
				end
			}
		elseif not actions.primary and not state.nozzle then
			actions.primary = { label = locale('nozzle_take'), action = function() nozzle.take(nearestPump) end }
		end

		if not state.nozzlePump or state.nozzlePump.key == nearestPump.key then
			actions.secondary = { label = locale('pump_use'), action = function() pump.openScreen(nearestPump) end }
		end

		return actions
	end

	if state.petrolCan and config.petrolCan.enabled and not state.nozzle and not state.isFueling then
		local vehicle = getVehicleAtFiller()

		if vehicle and DoesVehicleUseFuel(vehicle) and not utils.isElectric(vehicle) then
			actions.primary = { label = locale('petrolcan_refuel'), action = function() fuel.startFueling(vehicle) end }
		end
	end

	return actions
end

local currentActions

local function runAction(action)
	if not action or state.busy then return end

	state.busy = true
	local ok, err = pcall(action)
	state.busy = false

	if not ok then lib.print.error(err) end
end

RegisterCommand('startfueling', function()
	runAction(currentActions?.primary?.action)
end)

RegisterCommand('fuelpumpscreen', function()
	runAction(currentActions?.secondary?.action)
end)

RegisterKeyMapping('startfueling', 'Fuel: nozzle / petrol can', 'keyboard', 'e')
RegisterKeyMapping('fuelpumpscreen', 'Fuel: use pump screen', 'keyboard', 'g')
TriggerEvent('chat:removeSuggestion', '/startfueling')
TriggerEvent('chat:removeSuggestion', '/fuelpumpscreen')

local lastText

CreateThread(function()
	while true do
		local relevant = state.nearestPump or state.nozzle or state.petrolCan

		if not relevant then
			currentActions = nil
			Wait(500)
		else
			currentActions = getActions()

			local text

			if currentActions then
				if currentActions.info then
					text = currentActions.info
				else
					local lines = {}

					if currentActions.primary then
						lines[#lines + 1] = ('%s %s'):format(primaryKey, currentActions.primary.label)
					end

					if currentActions.secondary then
						lines[#lines + 1] = ('%s %s'):format(secondaryKey, currentActions.secondary.label)
					end

					text = #lines > 0 and table.concat(lines, '~n~') or nil
				end
			end

			if text and not state.busy then
				if text ~= lastText then
					AddTextEntry('ox_fuel_help', text)
					lastText = text
				end

				DisplayHelpTextThisFrame('ox_fuel_help', false)
			end

			Wait(0)
		end
	end
end)
