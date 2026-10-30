--[[
	/fuelscreen - move and resize the pump faceplate with object_gizmo (v3+, with scale support).
	The placement is per pump model and mirrored onto both sides of the pump.
	Saved placements are written to data/screens.json by the server and synced to everyone.
]]

local config = require 'config'
local state = require 'client.state'
local pumps = require 'client.pumps'
local screen = require 'client.screen'

local PROXY_MODEL = `prop_golf_ball`
local editing = false

---Store a faceplate centre (world space) as the model's local placement
local function setCentre(entity, settings, face, world)
	local offset = config.screen.surfaceOffset
	local l = GetOffsetFromEntityGivenWorldCoords(entity, world.x, world.y, world.z)
	local side, axis = face[9], face[10]

	settings.axis = axis
	settings.z = l.z

	if axis == 'y' then
		settings.depth = math.max(0.0, math.abs(l.y) - offset)
		settings.x = -l.x * side
	else
		settings.depth = math.max(0.0, math.abs(l.x) - offset)
		settings.x = l.y * side
	end
end

---The gizmo stores scale in the entity matrix: right = x, up = y
local function readScale(proxy)
	local _, right, up = GetEntityMatrix(proxy)
	local sx, sy = #right, #up

	-- height follows the faceplate's aspect ratio, so use whichever axis was dragged
	return math.abs(sx - 1.0) >= math.abs(sy - 1.0) and sx or sy
end

local function round(n)
	return math.floor(n * 1000 + 0.5) / 1000
end

local function edit()
	if editing or screen.isOpen then return end

	if GetResourceState('object_gizmo') ~= 'started' then
		return lib.notify({ type = 'error', description = locale('screen_editor_no_gizmo') })
	end

	local pump = state.nearestPump
	local entity = pump and pumps.getEntity(pump)

	if not entity then
		return lib.notify({ type = 'error', description = locale('screen_editor_no_pump') })
	end

	if not lib.callback.await('ox_fuel:canEditScreens', false) then
		return lib.notify({ type = 'error', description = locale('screen_editor_denied') })
	end

	local model = GetEntityModel(entity)
	local original = config.screen.models[model]
	local settings = {}

	for k, v in pairs(original or {}) do settings[k] = v end

	-- edit the side of the pump the camera is looking at
	local camCoords = GetFinalRenderedCamCoord()
	local faces = pumps.getScreenFaces(entity)
	local index = #(camCoords - faces[1][5]) <= #(camCoords - faces[2][5]) and 1 or 2
	local face = faces[index]
	local baseWidth = face[7]

	settings.width = baseWidth
	setCentre(entity, settings, face, face[5])
	config.screen.models[model] = settings
	pumps.clearCache()

	-- object_gizmo edits an entity, so the faceplate follows an invisible proxy at its centre,
	-- facing out of the pump so local axes line up with the faceplate
	lib.requestModel(PROXY_MODEL)

	local centre = face[5]
	local proxy = CreateObjectNoOffset(PROXY_MODEL, centre.x, centre.y, centre.z, false, false, false)

	SetModelAsNoLongerNeeded(PROXY_MODEL)
	SetEntityCollision(proxy, false, false)
	SetEntityAlpha(proxy, 0, false)
	SetEntityHeading(proxy, GetHeadingFromVector_2d(-face[6].x, -face[6].y))

	local function update()
		if not DoesEntityExist(proxy) then return end

		settings.width = math.clamp(baseWidth * readScale(proxy), 0.1, 3.0)
		setCentre(entity, settings, face, GetEntityCoords(proxy))
		pumps.clearCache()
		face = pumps.getScreenFaces(entity)[index]
	end

	editing = true

	local ok, result = pcall(function()
		return exports.object_gizmo:useGizmo(proxy, {
			mode = 'translate',
			space = 'local',
			pivot = 'origin',
			enableScale = true,
			enableRotate = false,
			enableCopy = false,
			snapToGround = false,
			outline = false,
			disableCollision = true,
			freezeEntity = true,
			requestControl = false,
			distanceLimit = 3.0,
			onChange = update,
		})
	end)

	editing = false

	if ok and result and result.confirmed then update() end

	DeleteEntity(proxy)

	if not ok then lib.print.error(result) end

	if not (ok and result and result.confirmed) then
		config.screen.models[model] = original
		pumps.clearCache()
		return lib.notify({ type = 'inform', description = locale('screen_editor_cancelled') })
	end

	local placement = {
		axis = settings.axis,
		width = round(settings.width),
		z = round(settings.z),
		x = round(settings.x),
		depth = round(settings.depth),
	}

	config.screen.models[model] = placement
	pumps.clearCache()
	TriggerServerEvent('ox_fuel:saveScreen', model, placement)

	lib.notify({ type = 'success', description = locale('screen_editor_saved') })
end

RegisterCommand('fuelscreen', function()
	CreateThread(edit)
end)
