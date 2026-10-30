local config = require 'config'

if not config then return end

if config.versionCheck then lib.versionCheck('overextended/ox_fuel') end

local ox_inventory = exports.ox_inventory

---@param vehicle number
---@param fuel number
---@param reduceOnly? boolean Don't allow fuel to be increased, unless fuel state has not been initialised.
local function setFuelState(vehicle, fuel, reduceOnly)
	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then
		return
	end

	local state = Entity(vehicle).state
	fuel = math.clamp(fuel, 0, reduceOnly and state.fuel or 100)

	state:set('fuel', fuel, true)
end

---@param playerId number
---@param price number
---@return boolean?
local function defaultPaymentMethod(playerId, price)
	local success = ox_inventory:RemoveItem(playerId, 'money', price)

	if success then return true end

	local money = ox_inventory:GetItemCount(playerId, 'money')

	TriggerClientEvent('ox_lib:notify', playerId, {
		type = 'error',
		description = locale('not_enough_money', price - money)
	})
end

local payMoney = defaultPaymentMethod

exports('setPaymentMethod', function(fn)
	payMoney = fn or defaultPaymentMethod
end)

local function defaultRefundMethod(playerId, amount)
	ox_inventory:AddItem(playerId, 'money', amount)
end

local refundMoney = defaultRefundMethod

exports('setRefundMethod', function(fn)
	refundMoney = fn or defaultRefundMethod
end)

-- Bank (card) payments through the running framework

local bank

if GetResourceState('qbx_core') == 'started' then
	bank = {
		get = function(src) return exports.qbx_core:GetMoney(src, 'bank') or 0 end,
		remove = function(src, amount) return exports.qbx_core:RemoveMoney(src, 'bank', amount, 'fuel-pump') end,
		add = function(src, amount) return exports.qbx_core:AddMoney(src, 'bank', amount, 'fuel-pump-refund') end,
	}
elseif GetResourceState('qb-core') == 'started' then
	local QBCore = exports['qb-core']:GetCoreObject()

	bank = {
		get = function(src)
			local player = QBCore.Functions.GetPlayer(src)
			return player and player.PlayerData.money.bank or 0
		end,
		remove = function(src, amount)
			local player = QBCore.Functions.GetPlayer(src)
			return player and player.Functions.RemoveMoney('bank', amount, 'fuel-pump')
		end,
		add = function(src, amount)
			local player = QBCore.Functions.GetPlayer(src)
			return player and player.Functions.AddMoney('bank', amount, 'fuel-pump-refund')
		end,
	}
elseif GetResourceState('es_extended') == 'started' then
	local ESX = exports.es_extended:getSharedObject()

	bank = {
		get = function(src)
			local player = ESX.GetPlayerFromId(src)
			return player and player.getAccount('bank').money or 0
		end,
		remove = function(src, amount)
			local player = ESX.GetPlayerFromId(src)
			if not player or player.getAccount('bank').money < amount then return false end
			player.removeAccountMoney('bank', amount)
			return true
		end,
		add = function(src, amount)
			local player = ESX.GetPlayerFromId(src)
			if player then player.addAccountMoney('bank', amount) end
		end,
	}
end

---@param source number
---@param method 'cash' | 'card'
---@param amount number
---@return boolean, string?
local function charge(source, method, amount)
	if method == 'card' then
		if not config.payment.card or not bank then return false, locale('pump_card_unavailable') end

		local balance = bank.get(source)

		if balance < amount then return false, locale('pump_card_declined') end

		return bank.remove(source, amount) and true or false, locale('pump_card_declined')
	end

	if not config.payment.cash then return false, locale('pump_cash_unavailable') end

	local money = ox_inventory:GetItemCount(source, 'money')

	if payMoney(source, amount) then return true end

	return false, locale('not_enough_money', math.max(0, amount - money))
end

---@param source number
---@param method 'cash' | 'card'
---@param amount number
local function refund(source, method, amount)
	if amount <= 0 then return end

	if method == 'card' and bank then
		bank.add(source, amount)
	else
		refundMoney(source, amount)
	end
end

-- Pump fueling sessions

local grades = {}

for i = 1, #config.grades do
	grades[config.grades[i].id] = config.grades[i]
end

---@type table<number, table>
local sessions = {}
local busyPumps = {}

GlobalState.ox_fuel_busy = busyPumps

local function setPumpBusy(key, busy)
	busyPumps[key] = busy or nil
	GlobalState.ox_fuel_busy = busyPumps
end

local function pumpKey(coords)
	return ('%.1f,%.1f,%.1f'):format(coords.x, coords.y, coords.z)
end

lib.callback.register('ox_fuel:pumpStart', function(source, data)
	if sessions[source] then return false, locale('pump_already_fueling') end
	if type(data) ~= 'table' then return false end

	local grade = grades[data.grade]
	local litres = tonumber(data.litres)
	local pump = data.pump

	if not grade or not litres or litres <= 0 or type(pump) ~= 'vector3' then return false end
	if data.method ~= 'cash' and data.method ~= 'card' then return false end

	local vehicle = NetworkGetEntityFromNetworkId(tonumber(data.netId) or 0)

	if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
		return false, locale('pump_no_vehicle')
	end

	local playerCoords = GetEntityCoords(GetPlayerPed(source))
	local maxDistance = config.hose.length + 3.0

	if #(playerCoords - pump) > maxDistance or #(GetEntityCoords(vehicle) - pump) > maxDistance + 3.0 then
		return false, locale('vehicle_far')
	end

	local key = pumpKey(pump)

	if busyPumps[key] then return false, locale('pump_in_use') end

	local class = math.floor(tonumber(data.class) or 0)
	local tank = config.tankSizes[class] or 60

	if tank <= 0 then return false, locale('vehicle_no_fuel') end

	local fuel = tonumber(Entity(vehicle).state.fuel) or 0
	local missing = tank * (100 - fuel) / 100

	litres = math.floor(math.min(litres, missing, config.pump.maxLitres) * 100) / 100

	if litres < 0.1 then return false, locale('tank_full') end

	local total = math.ceil(litres * grade.price)
	local paid, err = charge(source, data.method, total)

	if not paid then return false, err end

	sessions[source] = {
		vehicle = vehicle,
		litres = litres,
		price = grade.price,
		total = total,
		method = data.method,
		fuel = fuel,
		tank = tank,
		key = key,
		start = GetGameTimer(),
	}

	setPumpBusy(key, true)

	return true, { litres = litres, total = total, price = grade.price, fuel = fuel, tank = tank }
end)

---@param source number
---@param dispensed? number litres the client reports; nil uses the most the time allows
local function finishSession(source, dispensed)
	local session = sessions[source]

	if not session then return end

	sessions[source] = nil
	setPumpBusy(session.key, false)

	local elapsed = (GetGameTimer() - session.start) / 1000
	local maxByTime = elapsed * config.pump.litresPerSecond * 1.15 + 0.5

	dispensed = math.clamp(tonumber(dispensed) or maxByTime, 0, math.min(session.litres, maxByTime))

	local cost = math.min(session.total, math.ceil(dispensed * session.price))
	local refunded = session.total - cost

	refund(source, session.method, refunded)

	local fuel = math.min(100, session.fuel + dispensed / session.tank * 100)

	if DoesEntityExist(session.vehicle) then setFuelState(session.vehicle, fuel) end

	return { litres = dispensed, cost = cost, refund = refunded, fuel = fuel }
end

lib.callback.register('ox_fuel:pumpFinish', function(source, dispensed)
	return finishSession(source, dispensed)
end)

AddEventHandler('playerDropped', function()
	finishSession(source)
end)

-- Pump screen placements edited in game with /fuelscreen

local screensFile = 'data/screens.json'
local savedScreens = json.decode(LoadResourceFile(cache.resource, screensFile) or '') or {}

GlobalState.ox_fuel_screens = savedScreens

-- same permission check as the Qbox admin panel
local hasPermission

if GetResourceState('qb-core') == 'started' then
	local QBCore = exports['qb-core']:GetCoreObject()
	hasPermission = function(source, perm) return QBCore.Functions.HasPermission(source, perm) end
elseif GetResourceState('qbx_core') == 'started' then
	hasPermission = function(source, perm) return exports.qbx_core:HasPermission(source, perm) end
else
	hasPermission = function(source, perm) return IsPlayerAceAllowed(source, perm) end
end

local function canEditScreens(source)
	return hasPermission(source, config.screen.editPermission) == true
end

lib.callback.register('ox_fuel:canEditScreens', canEditScreens)

RegisterNetEvent('ox_fuel:saveScreen', function(model, settings)
	local source = source

	if not canEditScreens(source) then return end
	if type(model) ~= 'number' or type(settings) ~= 'table' then return end

	local width, z, x, depth = tonumber(settings.width), tonumber(settings.z), tonumber(settings.x), tonumber(settings.depth)

	if not (width and z and x and depth) or (settings.axis ~= 'x' and settings.axis ~= 'y') then return end

	savedScreens[tostring(model)] = {
		axis = settings.axis,
		width = math.clamp(width, 0.1, 3.0),
		z = math.clamp(z, -2.0, 5.0),
		x = math.clamp(x, -3.0, 3.0),
		depth = math.clamp(depth, 0.0, 3.0),
	}

	SaveResourceFile(cache.resource, screensFile, json.encode(savedScreens, { indent = true }), -1)
	GlobalState.ox_fuel_screens = savedScreens

	lib.print.info(('%s saved the pump screen placement for model %s'):format(GetPlayerName(source), model))
end)

-- Petrol cans

RegisterNetEvent('ox_fuel:fuelCan', function(hasCan, price)
	local source = source

	-- never trust the price from the client
	price = hasCan and config.petrolCan.refillPrice or config.petrolCan.price

	if hasCan then
		local item = ox_inventory:GetCurrentWeapon(source)

		if not item or item.name ~= 'WEAPON_PETROLCAN' or not payMoney(source, price) then return end

		item.metadata.durability = 100
		item.metadata.ammo = 100

		ox_inventory:SetMetadata(source, item.slot, item.metadata)

		TriggerClientEvent('ox_lib:notify', source, {
			type = 'success',
			description = locale('petrolcan_refill', price)
		})
	else
		if not ox_inventory:CanCarryItem(source, 'WEAPON_PETROLCAN', 1) then
			return TriggerClientEvent('ox_lib:notify', source, {
				type = 'error',
				description = locale('petrolcan_cannot_carry')
			})
		end

		if not payMoney(source, price) then return end

		ox_inventory:AddItem(source, 'WEAPON_PETROLCAN', 1)

		TriggerClientEvent('ox_lib:notify', source, {
			type = 'success',
			description = locale('petrolcan_buy', price)
		})
	end
end)

RegisterNetEvent('ox_fuel:updateFuelCan', function(durability, netid, fuel)
	local source = source
	local item = ox_inventory:GetCurrentWeapon(source)

	if item and durability > 0 then
		durability = math.floor(item.metadata.durability - durability)
		item.metadata.durability = durability
		item.metadata.ammo = durability

		ox_inventory:SetMetadata(source, item.slot, item.metadata)
		setFuelState(NetworkGetEntityFromNetworkId(netid), fuel)
	end

	-- player is sus?
end)

RegisterNetEvent('ox_fuel:setFuel', function(fuel)
	local playerPed = GetPlayerPed(source)
	local handle = GetVehiclePedIsIn(playerPed, false)

	setFuelState(handle, fuel, true)
end)
