---@class PumpData
---@field coords vector3
---@field key string
---@field entity? integer

---@class State
---@field petrolCan SlotWithItem?
---@field isFueling boolean
---@field nearestPump PumpData?
---@field lastVehicle number?
---@field nozzle integer? nozzle object owned by this player
---@field nozzlePump PumpData? pump the nozzle was taken from
---@field nozzleVehicle integer? vehicle the nozzle is inserted into
---@field rope integer?
---@field screenPump PumpData? pump whose screen is being used
local state = {
	isFueling = false,
	lastVehicle = cache.vehicle or GetPlayersLastVehicle()
}

if state.lastVehicle == 0 then state.lastVehicle = nil end

---@param data? SlotWithItem
local function setPetrolCan(data)
	state.petrolCan = data?.name == 'WEAPON_PETROLCAN' and data or nil
end

setPetrolCan(exports.ox_inventory:getCurrentWeapon())

AddEventHandler('ox_inventory:currentWeapon', setPetrolCan)

---Holding the nozzle in hand (taken but not inserted)
function state.isHoldingNozzle()
	return state.nozzle ~= nil and state.nozzleVehicle == nil
end

---The pump whose screen shows this player's interactive display
---@return PumpData?
function state.activePump()
	return state.screenPump or state.nozzlePump
end

return state
