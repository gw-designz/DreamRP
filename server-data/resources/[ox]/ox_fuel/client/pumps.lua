local config = require 'config'
local pumps = {}

local pumpModels = {}

for i = 1, #config.pumpModels do
	pumpModels[config.pumpModels[i]] = true
end

---Unique key shared with the server, used to mark pumps as busy.
---@param coords vector3
function pumps.key(coords)
	return ('%.1f,%.1f,%.1f'):format(coords.x, coords.y, coords.z)
end

---@param coords vector3
---@return integer?
local function findPumpEntity(coords)
	for i = 1, #config.pumpModels do
		local entity = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.5, config.pumpModels[i], false, false, false)

		if entity ~= 0 then return entity end
	end
end

---@param pump PumpData
---@return integer?
function pumps.getEntity(pump)
	if pump.entity and DoesEntityExist(pump.entity) then return pump.entity end

	pump.entity = findPumpEntity(pump.coords)

	return pump.entity
end

---@param coords vector3
---@return PumpData
function pumps.new(coords)
	return { coords = coords, key = pumps.key(coords) }
end

---@param entity integer
---@return PumpData?
function pumps.fromEntity(entity)
	if not pumpModels[GetEntityModel(entity)] then return end

	local pump = pumps.new(GetEntityCoords(entity))
	pump.entity = entity

	return pump
end

local faceCache = {}
local aspect = config.screen.resolution[2] / config.screen.resolution[1]

function pumps.clearCache()
	table.wipe(faceCache)
end

-- Placements saved in game with /fuelscreen override config.screen.models
local function applySaved(saved)
	for model, settings in pairs(saved or {}) do
		config.screen.models[tonumber(model)] = settings
	end

	pumps.clearCache()
end

applySaved(GlobalState.ox_fuel_screens)

AddStateBagChangeHandler('ox_fuel_screens', 'global', function(_, _, value)
	applySaved(value)
end)

---Corners of each screen on the pump, in world space: { tl, tr, br, bl, centre, normal, width, height, side, axis }[]
---@param entity integer
function pumps.getScreenFaces(entity)
	local cached = faceCache[entity]
	local coords = GetEntityCoords(entity)

	if cached and #(cached.coords - coords) < 0.01 then return cached.faces end

	local model = GetEntityModel(entity)
	local min, max = GetModelDimensions(model)
	local settings = config.screen.models[model] or {}
	local axis = settings.axis or ((max.x - min.x) >= (max.y - min.y) and 'y' or 'x')
	local faceWidth = axis == 'y' and (max.x - min.x) or (max.y - min.y)
	local width = settings.width or faceWidth * config.screen.widthRatio
	local height = width * aspect
	local z = settings.z or (min.z + (max.z - min.z) * config.screen.heightRatio)
	local shift = settings.x or 0.0
	local offset = config.screen.surfaceOffset
	local halfW, halfH = width / 2, height / 2
	local faces = {}

	for side = -1, 1, 2 do
		local tl, tr, br, bl, normal
		-- shift is towards the viewer's right on both faces
		local s = shift * -side

		if axis == 'y' then
			local depth = (settings.depth or (side > 0 and max.y or -min.y)) + offset
			local y = depth * side
			-- viewer looking towards the pump along -side*y has their right at -side*x
			tl = vec3(halfW * side + s, y, z + halfH)
			tr = vec3(-halfW * side + s, y, z + halfH)
			br = vec3(-halfW * side + s, y, z - halfH)
			bl = vec3(halfW * side + s, y, z - halfH)
			normal = vec3(0.0, side, 0.0)
		else
			local depth = (settings.depth or (side > 0 and max.x or -min.x)) + offset
			local x = depth * side
			s = -s
			tl = vec3(x, -halfW * side + s, z + halfH)
			tr = vec3(x, halfW * side + s, z + halfH)
			br = vec3(x, halfW * side + s, z - halfH)
			bl = vec3(x, -halfW * side + s, z - halfH)
			normal = vec3(side, 0.0, 0.0)
		end

		local centre = vec3((tl.x + br.x) / 2, (tl.y + br.y) / 2, z)
		local worldCentre = GetOffsetFromEntityInWorldCoords(entity, centre.x, centre.y, centre.z)

		faces[#faces + 1] = {
			GetOffsetFromEntityInWorldCoords(entity, tl.x, tl.y, tl.z),
			GetOffsetFromEntityInWorldCoords(entity, tr.x, tr.y, tr.z),
			GetOffsetFromEntityInWorldCoords(entity, br.x, br.y, br.z),
			GetOffsetFromEntityInWorldCoords(entity, bl.x, bl.y, bl.z),
			worldCentre,
			GetOffsetFromEntityInWorldCoords(entity, centre.x + normal.x, centre.y + normal.y, centre.z) - worldCentre,
			width,
			height,
			side,
			axis,
		}
	end

	faceCache[entity] = { coords = coords, faces = faces }

	return faces
end

return pumps
