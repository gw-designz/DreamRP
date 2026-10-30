local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local pumps = require 'client.pumps'
local nozzle = {}

---Called when the nozzle leaves the vehicle while fueling; set by client.pump
nozzle.onDetach = nil

local function loadRopeTextures()
	if RopeAreTexturesLoaded() then return end

	RopeLoadTextures()

	local timeout = GetGameTimer() + 5000

	while not RopeAreTexturesLoaded() and GetGameTimer() < timeout do Wait(0) end
end

---@param pumpEntity integer
---@param object integer
---@return integer rope
local function createHose(pumpEntity, object)
	loadRopeTextures()

	local length = config.hose.length
	local from = GetOffsetFromEntityInWorldCoords(pumpEntity, 0.0, 0.0, config.hose.pumpHeight)
	local rope = AddRope(from.x, from.y, from.z, 0.0, 0.0, 0.0, 3.0, config.hose.ropeType, length, 0.0, 1.0, false,
		false, false, 1.0, true)
	local to = GetOffsetFromEntityInWorldCoords(object, 0.0, -0.033, -0.195)

	ActivatePhysics(rope)
	AttachEntitiesToRope(rope, pumpEntity, object, from.x, from.y, from.z, to.x, to.y, to.z, length, false, false, nil, nil)

	return rope
end

local function deleteHose(rope)
	if rope and DoesRopeExist(rope) then DeleteRope(rope) end
end

local function playGrabAnim()
	lib.requestAnimDict('anim@am_hold_up@male')
	TaskPlayAnim(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 2.0, 8.0, 900, 50, 0, false, false, false)
	RemoveAnimDict('anim@am_hold_up@male')
	Wait(450)
end

local function attachToHand(object)
	local hand = config.nozzle.hand

	AttachEntityToEntity(object, cache.ped, GetPedBoneIndex(cache.ped, hand.bone), hand.pos.x, hand.pos.y, hand.pos.z,
		hand.rot.x, hand.rot.y, hand.rot.z, false, true, false, true, 1, true)
end

local function attachToVehicle(object, vehicle)
	local filler = utils.getFillerPosition(vehicle)
	local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, filler.x, filler.y, filler.z)
	local side = offset.x < 0 and 1 or -1 -- left side keeps config values, right side mirrors them
	local cfg = config.nozzle.vehicle
	local pos = vec3(offset.x + cfg.pos.x * side, offset.y + cfg.pos.y, offset.z + cfg.pos.z)
	local rotZ = side == 1 and cfg.rot.z or -cfg.rot.z

	AttachEntityToEntity(object, vehicle, 0, pos.x, pos.y, pos.z, cfg.rot.x, cfg.rot.y, rotZ, false, true, false,
		false, 1, true)
end

local function syncHose(data)
	LocalPlayer.state:set('fuelHose', data, true)
end

local function cleanup()
	deleteHose(state.rope)

	if state.nozzle and DoesEntityExist(state.nozzle) then
		DetachEntity(state.nozzle, true, false)
		DeleteEntity(state.nozzle)
	end

	state.rope = nil
	state.nozzle = nil
	state.nozzlePump = nil
	state.nozzleVehicle = nil

	syncHose(nil)
end

local monitor

local function monitorNozzle()
	local maxLength = config.hose.length

	while state.nozzle do
		local pump = state.nozzlePump

		if not DoesEntityExist(state.nozzle) or not pump then
			cleanup()
			break
		end

		if state.nozzleVehicle then
			local vehicle = state.nozzleVehicle

			if not DoesEntityExist(vehicle) or #(utils.getFillerPosition(vehicle) - pump.coords) > maxLength + 1.0 then
				nozzle.snap()
				break
			end
		else
			if cache.vehicle or IsPedDeadOrDying(cache.ped, true) or IsPedRagdoll(cache.ped) then
				nozzle.putBack(true)
				break
			end

			if #(GetEntityCoords(cache.ped) - pump.coords) > maxLength then
				lib.notify({ type = 'inform', description = locale('hose_too_far') })
				nozzle.putBack(true)
				break
			end

			DisableControlAction(0, 24, true)  -- attack
			DisableControlAction(0, 25, true)  -- aim
			DisableControlAction(0, 22, true)  -- jump
			DisableControlAction(0, 37, true)  -- weapon wheel
		end

		Wait(state.nozzleVehicle and 250 or 0)
	end

	monitor = nil
end

---Take the nozzle off the pump
---@param pump PumpData
function nozzle.take(pump)
	if state.nozzle then return end

	local pumpEntity = pumps.getEntity(pump)

	if not pumpEntity then return end

	SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
	TaskTurnPedToFaceEntity(cache.ped, pumpEntity, 500)
	Wait(300)
	playGrabAnim()

	local model = lib.requestModel(config.nozzle.model)
	local coords = GetEntityCoords(cache.ped)
	local object = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)

	SetModelAsNoLongerNeeded(model)
	SetEntityCollision(object, false, false)
	attachToHand(object)

	state.nozzle = object
	state.nozzlePump = pump
	state.nozzleVehicle = nil
	state.rope = createHose(pumpEntity, object)

	local timeout = GetGameTimer() + 2000

	while not NetworkGetEntityIsNetworked(object) and GetGameTimer() < timeout do Wait(0) end

	if NetworkGetEntityIsNetworked(object) then
		syncHose({ pump = pump.coords, nozzle = ObjToNet(object) })
	end

	if not monitor then monitor = CreateThread(monitorNozzle) end
end

---Hang the nozzle back up on the pump
---@param silent? boolean
function nozzle.putBack(silent)
	if not state.nozzle then return end

	if state.nozzleVehicle and nozzle.onDetach then nozzle.onDetach('removed') end

	if not silent then
		local pumpEntity = state.nozzlePump and pumps.getEntity(state.nozzlePump)

		if pumpEntity then TaskTurnPedToFaceEntity(cache.ped, pumpEntity, 500) Wait(300) end

		playGrabAnim()
	end

	cleanup()
end

---Put the held nozzle into a vehicle's filler
---@param vehicle integer
function nozzle.insert(vehicle)
	if not state.isHoldingNozzle() then return end

	if not DoesVehicleUseFuel(vehicle) or GetVehicleClass(vehicle) == 13 then
		return lib.notify({ type = 'error', description = locale('vehicle_no_fuel') })
	end

	if utils.isElectric(vehicle) then
		return lib.notify({ type = 'error', description = locale('vehicle_electric') })
	end

	local filler = utils.getFillerPosition(vehicle)

	TaskTurnPedToFaceCoord(cache.ped, filler.x, filler.y, filler.z, 500)
	Wait(300)
	playGrabAnim()

	if not state.nozzle then return end

	DetachEntity(state.nozzle, true, false)
	attachToVehicle(state.nozzle, vehicle)
	state.nozzleVehicle = vehicle
	state.lastVehicle = vehicle
end

---Take the nozzle back out of the vehicle, into the player's hand
function nozzle.remove()
	if not state.nozzle or not state.nozzleVehicle then return end

	if nozzle.onDetach then nozzle.onDetach('removed') end

	local filler = utils.getFillerPosition(state.nozzleVehicle)

	TaskTurnPedToFaceCoord(cache.ped, filler.x, filler.y, filler.z, 500)
	Wait(300)
	playGrabAnim()

	if not state.nozzle then return end

	DetachEntity(state.nozzle, true, false)
	attachToHand(state.nozzle)
	state.nozzleVehicle = nil

	if not monitor then monitor = CreateThread(monitorNozzle) end
end

---The vehicle drove off with the nozzle in; the hose breaks and the nozzle returns to the pump
function nozzle.snap()
	if nozzle.onDetach then nozzle.onDetach('snapped') end

	local coords = state.nozzle and DoesEntityExist(state.nozzle) and GetEntityCoords(state.nozzle)

	if coords then
		PlaySoundFromCoord(-1, 'Drill_Pin_Break', coords.x, coords.y, coords.z, 'DLC_HEIST_FLEECA_SOUNDSET', false, 10, false)
	end

	cleanup()
	lib.notify({ type = 'error', description = locale('hose_snapped') })
end

-- Hoses held by other players

---@type table<integer, integer>
local remoteHoses = {}

CreateThread(function()
	while true do
		local seen = {}

		for _, player in ipairs(GetActivePlayers()) do
			if player ~= cache.playerId then
				local serverId = GetPlayerServerId(player)
				local hose = Player(serverId).state.fuelHose

				if hose and hose.nozzle and NetworkDoesEntityExistWithNetworkId(hose.nozzle) then
					seen[serverId] = true

					if not remoteHoses[serverId] or not DoesRopeExist(remoteHoses[serverId]) then
						local object = NetToObj(hose.nozzle)
						local pumpEntity = pumps.getEntity(pumps.new(vec3(hose.pump.x, hose.pump.y, hose.pump.z)))

						if object ~= 0 and pumpEntity then
							remoteHoses[serverId] = createHose(pumpEntity, object)
						end
					end
				end
			end
		end

		for serverId, rope in pairs(remoteHoses) do
			if not seen[serverId] then
				deleteHose(rope)
				remoteHoses[serverId] = nil
			end
		end

		Wait(500)
	end
end)

AddEventHandler('onResourceStop', function(name)
	if name ~= cache.resource then return end

	cleanup()

	for _, rope in pairs(remoteHoses) do deleteHose(rope) end
end)

return nozzle
