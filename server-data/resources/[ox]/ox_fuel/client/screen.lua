local config = require 'config'
local state = require 'client.state'
local pumps = require 'client.pumps'
local screen = {}

local resource = GetCurrentResourceName()
local resX, resY = config.screen.resolution[1], config.screen.resolution[2]

---@type table<string, { dui: integer, txd: string, txn: string, ready: boolean }>
local displays = {}

---@type table<PumpData, true>
local activeStations = {}

-- renamed from DrawSpritePoly in newer native docs
local DrawTexturedPoly = DrawTexturedPoly or DrawSpritePoly

local busyPumps = GlobalState.ox_fuel_busy or {}

AddStateBagChangeHandler('ox_fuel_busy', 'global', function(_, _, value)
	busyPumps = value or {}
end)

local function sendToDisplay(display, action, data)
	if display and display.ready then
		SendDuiMessage(display.dui, json.encode({ action = action, data = data }))
	end
end

local function initData()
	return {
		grades = config.grades,
		payment = config.payment,
		presets = config.pump.presets,
		blocks = config.pump.blocks,
		maxLitres = config.pump.maxLitres,
		petrolCan = config.petrolCan,
		locale = {
			-- the screen is english only by design, but labels can be translated here
		},
	}
end

---@param mode 'idle' | 'busy' | 'interactive'
local function getDisplay(mode)
	local display = displays[mode]

	if display then return display end

	local url = ('nui://%s/web/index.html?mode=%s&res=%s'):format(resource, mode, resource)
	local dui = CreateDui(url, resX, resY)
	local txdName = ('ox_fuel_%s'):format(mode)
	local txd = CreateRuntimeTxd(txdName)

	CreateRuntimeTextureFromDuiHandle(txd, 'screen', GetDuiHandle(dui))

	display = { dui = dui, txd = txdName, txn = 'screen', ready = false }
	displays[mode] = display

	CreateThread(function()
		while not IsDuiAvailable(dui) do Wait(100) end
		Wait(250)
		display.ready = true
		sendToDisplay(display, 'init', initData())
	end)

	return display
end

RegisterNUICallback('ready', function(data, cb)
	local display = displays[data?.mode]

	if display then
		display.ready = true
		sendToDisplay(display, 'init', initData())
	end

	cb(1)
end)

---Send a message to this player's interactive pump screen
function screen.send(action, data)
	sendToDisplay(displays.interactive, action, data)
end

local function drawFace(display, face)
	local tl, tr, br, bl = face[1], face[2], face[3], face[4]
	local txd, txn = display.txd, display.txn

	-- both windings, so the screen shows regardless of face culling
	DrawTexturedPoly(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, br.x, br.y, br.z, 255, 255, 255, 255, txd, txn,
		0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0)
	DrawTexturedPoly(tl.x, tl.y, tl.z, br.x, br.y, br.z, bl.x, bl.y, bl.z, 255, 255, 255, 255, txd, txn,
		0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0)
	DrawTexturedPoly(tl.x, tl.y, tl.z, br.x, br.y, br.z, tr.x, tr.y, tr.z, 255, 255, 255, 255, txd, txn,
		0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0)
	DrawTexturedPoly(tl.x, tl.y, tl.z, bl.x, bl.y, bl.z, br.x, br.y, br.z, 255, 255, 255, 255, txd, txn,
		0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0)

	if config.screen.debug then
		DrawLine(tl.x, tl.y, tl.z, tr.x, tr.y, tr.z, 255, 0, 0, 255)
		DrawLine(tr.x, tr.y, tr.z, br.x, br.y, br.z, 255, 0, 0, 255)
		DrawLine(br.x, br.y, br.z, bl.x, bl.y, bl.z, 255, 0, 0, 255)
		DrawLine(bl.x, bl.y, bl.z, tl.x, tl.y, tl.z, 255, 0, 0, 255)
	end
end

local renderThread

local function render()
	local idle, busy, interactive = getDisplay('idle'), getDisplay('busy'), getDisplay('interactive')
	local renderDistance = config.screen.renderDistance

	while next(activeStations) do
		local playerCoords = GetEntityCoords(cache.ped)
		local myPump = state.activePump()
		local myKey = myPump and myPump.key

		local camCoords = GetFinalRenderedCamCoord()
		local queue, count = {}, 0

		for station in pairs(activeStations) do
			for i = 1, #station do
				local pump = station[i]

				if #(playerCoords - pump.coords) < renderDistance then
					local entity = pumps.getEntity(pump)

					if entity then
						local display = (pump.key == myKey and interactive) or (busyPumps[pump.key] and busy) or idle

						if display.ready then
							local faces = pumps.getScreenFaces(entity)

							for f = 1, #faces do
								local face = faces[f]
								local toCam = camCoords - face[5]

								-- only faces pointing at the camera; the back one is hidden inside the pump
								if face[6].x * toCam.x + face[6].y * toCam.y + face[6].z * toCam.z > 0 then
									count += 1
									queue[count] = { display, face, #toCam }
								end
							end
						end
					end
				end
			end
		end

		-- screens don't depth test against each other, so draw the furthest first
		table.sort(queue, function(a, b) return a[3] > b[3] end)

		for i = 1, count do drawFace(queue[i][1], queue[i][2]) end

		Wait(0)
	end

	renderThread = nil
end

---@param station PumpData[]
function screen.addStation(station)
	activeStations[station] = true

	if not renderThread then renderThread = CreateThread(render) end
end

---@param station PumpData[]
function screen.removeStation(station)
	activeStations[station] = nil
end

-- Camera and mouse interaction

local cam
screen.isOpen = false

---Map a screen cursor position onto the face, returning DUI pixel coordinates.
local function cursorToDui(face, cx, cy)
	local ok1, ax, ay = GetScreenCoordFromWorldCoord(face[1].x, face[1].y, face[1].z)
	local ok2, bx, by = GetScreenCoordFromWorldCoord(face[2].x, face[2].y, face[2].z)
	local ok3, dx, dy = GetScreenCoordFromWorldCoord(face[4].x, face[4].y, face[4].z)

	if not (ok1 and ok2 and ok3) then return end

	local e1x, e1y = bx - ax, by - ay
	local e2x, e2y = dx - ax, dy - ay
	local px, py = cx - ax, cy - ay
	local det = e1x * e2y - e1y * e2x

	if math.abs(det) < 1e-6 then return end

	local u = (px * e2y - py * e2x) / det
	local v = (e1x * py - e1y * px) / det

	if u < 0 or u > 1 or v < 0 or v > 1 then return end

	return math.floor(u * resX), math.floor(v * resY)
end

---@param pump PumpData
---@param context table data sent to the screen on open
function screen.open(pump, context)
	if screen.isOpen then return end

	local entity = pumps.getEntity(pump)

	if not entity then return end

	local display = getDisplay('interactive')
	local timeout = GetGameTimer() + 3000

	while not display.ready and GetGameTimer() < timeout do Wait(50) end

	local faces = pumps.getScreenFaces(entity)
	local playerCoords = GetEntityCoords(cache.ped)
	local face = faces[1]

	for i = 2, #faces do
		if #(playerCoords - faces[i][5]) < #(playerCoords - face[5]) then face = faces[i] end
	end

	state.screenPump = pump
	screen.isOpen = true

	local centre, normal = face[5], face[6]
	local halfFov = math.tan(math.rad(config.screen.cameraFov / 2))
	local distance = math.max(face[8] / 2 / halfFov, face[7] / 2 / (halfFov * GetAspectRatio(false)))
	local camPos = centre + normal * distance * config.screen.cameraPadding

	TaskTurnPedToFaceCoord(cache.ped, centre.x, centre.y, centre.z, 1000)

	cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0,
		config.screen.cameraFov, false, 2)
	PointCamAtCoord(cam, centre.x, centre.y, centre.z)
	SetCamActive(cam, true)
	RenderScriptCams(true, true, 600, true, true)

	screen.send('open', context)

	CreateThread(function()
		local lastX, lastY
		local dui = display.dui

		Wait(600)

		while screen.isOpen do
			-- the camera sits behind the player's head
			SetEntityLocallyInvisible(cache.ped)
			DisableAllControlActions(0)
			EnableControlAction(0, 249, true) -- push to talk
			SetMouseCursorActiveThisFrame()

			local x, y = cursorToDui(face, GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240))

			if x and (x ~= lastX or y ~= lastY) then
				lastX, lastY = x, y
				SendDuiMouseMove(dui, x, y)
			end

			SetMouseCursorSprite(x and 5 or 1)

			if x and IsDisabledControlJustPressed(0, 24) then SendDuiMouseDown(dui, 'left') end
			if IsDisabledControlJustReleased(0, 24) then SendDuiMouseUp(dui, 'left') end
			if IsDisabledControlJustPressed(0, 241) then SendDuiMouseWheel(dui, 50, 0) end
			if IsDisabledControlJustPressed(0, 242) then SendDuiMouseWheel(dui, -50, 0) end

			if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
				screen.close()
			end

			Wait(0)
		end
	end)
end

function screen.close()
	if not screen.isOpen then return end

	screen.isOpen = false
	state.screenPump = nil

	-- stop the pause menu opening from the same escape press
	CreateThread(function()
		local timeout = GetGameTimer() + 300

		while GetGameTimer() < timeout do
			DisableControlAction(0, 200, true)
			Wait(0)
		end
	end)

	RenderScriptCams(false, true, 600, true, true)

	if cam then
		DestroyCam(cam, false)
		cam = nil
	end

	screen.send('close')
end

AddEventHandler('onResourceStop', function(name)
	if name ~= resource then return end

	if cam then
		RenderScriptCams(false, false, 0, true, true)
		DestroyCam(cam, false)
	end

	for _, display in pairs(displays) do DestroyDui(display.dui) end
end)

return screen
