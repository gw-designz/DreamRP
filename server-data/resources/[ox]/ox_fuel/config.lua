if not lib.checkDependency('ox_lib', '3.22.0', true) then return end
if not lib.checkDependency('ox_inventory', '2.30.0', true) then return end

return {
	-- Get notified when a new version releases
	versionCheck = false,

	/*
	* How players interact with pumps and vehicles
	* 'interact'  - floating prompts from the interact resource
	* 'ox_target' - ox_target options
	* 'helptext'  - E / G keybinds with GTA help text
	*/
	interaction = 'interact',

	interact = {
		-- Distance the prompt shows at
		distance = 6.0,

		-- Distance the prompt can be used at on a pump
		pumpDistance = 1.8,

		-- Height of the prompt on the pump
		pumpHeight = 1.0,
	},

	/*
	* Show or hide gas stations blips
	* 0 - Hide all
	* 1 - Show nearest (5000ms interval check)
	* 2 - Show all
	*/
	showBlips = 2,

	-- Petrol can refill rate (every refillTick msec add refillValue %)
	refillValue = 0.50,
	refillTick = 250,

	-- Can durability loss per refillTick
	durabilityTick = 1.3,

	-- Enables fuel can (bought or refilled from the pump screen)
	petrolCan = {
		enabled = true,
		duration = 5000,
		price = 1000,
		refillPrice = 800,
	},

	-- Fuel grades shown on the pump screen (price is per litre)
	grades = {
		{ id = 'regular', label = 'Regular', octane = '87', price = 3.10 },
		{ id = 'midgrade', label = 'Mid Grade', octane = '89', price = 3.45 },
		{ id = 'premium', label = 'Premium', octane = '93', price = 3.85 },
		{ id = 'diesel', label = 'Diesel', octane = 'D', price = 3.60 },
	},

	-- Payment methods offered on the pump screen ('card' needs ESX, QBCore or Qbox)
	payment = {
		cash = true,
		card = true,
	},

	pump = {
		-- Litres dispensed per second
		litresPerSecond = 1.5,

		-- Progress update interval (msec)
		tick = 250,

		-- Most litres that can be typed on the keypad
		maxLitres = 999,

		-- Quick select buttons on the keypad page (FULL is always added)
		presets = { 10, 20 },

		-- Number of blocks in the filling progress bar
		blocks = 11,
	},

	hose = {
		-- How far (metres) the hose reaches from the pump before the nozzle returns / snaps
		length = 6.0,

		-- Height on the pump the hose comes out of
		pumpHeight = 1.3,

		-- GTA rope type (1 = thick, 4 = thin)
		ropeType = 1,
	},

	nozzle = {
		model = `prop_cs_fuel_nozle`,

		-- Held in hand
		hand = { bone = 18905, pos = vec3(0.13, 0.04, 0.01), rot = vec3(-42.0, -115.0, -63.42) },

		-- Inserted into the filler, relative to the filler position (x is mirrored for the right side)
		vehicle = { pos = vec3(-0.08, 0.0, 0.06), rot = vec3(-125.0, -90.0, -90.0) },

		-- Max distance (metres) from the vehicle filler to insert / remove the nozzle
		reach = 1.8,
	},

	-- Fueling with the engine running sets the vehicle on fire
	engineFire = {
		enabled = true,

		-- Milliseconds the engine can run while fueling before it ignites
		graceTime = 2000,
	},

	screen = {
		-- Distance pump screens are drawn at
		renderDistance = 30.0,

		-- DUI resolution; the faceplate is drawn at 1400 x 650, keep the same aspect ratio
		resolution = { 1400, 650 },

		/*
		* The faceplate covers the pump's dark front panel (above the Regular / Plus / Premium stripe).
		* Defaults are relative to the pump model's bounding box; height follows the resolution's aspect ratio.
		*/
		widthRatio = 0.9, -- faceplate width, as a share of the pump face width
		heightRatio = 0.72, -- faceplate centre, 0 = bottom of the pump, 1 = top
		surfaceOffset = 0.012, -- push out from the pump face so it doesn't z-fight

		/*
		* Per model overrides, all in metres in the model's local space:
		* { width, z (centre height), x (sideways shift), depth (centre to face), axis = 'x' | 'y' }
		* Easier: stand at a pump and use /fuelscreen to place it with object_gizmo.
		*/
		models = {
			-- [`prop_gas_pump_1b`] = { width = 0.95, z = 1.42, x = 0.0, depth = 0.31, axis = 'y' },
		},

		-- Camera when using the pump; distance is worked out to frame the whole faceplate
		cameraFov = 40.0,
		cameraPadding = 1.06,

		-- Qbox permission group allowed to use /fuelscreen (move / resize the faceplate with object_gizmo)
		editPermission = 'admin',

		-- Outlines each screen
		debug = false,
	},

	-- Percent of the tank used per second, indexed by rpm (0.0, 0.1 ... 1.0)
	fuelUsage = { 0.0, 0.1, 0.2, 0.4, 0.5, 0.7, 0.8, 0.9, 1.0, 1.2, 1.4 },

	-- Fuel usage multiplier per vehicle class
	classUsage = {
		[0] = 1.0, [1] = 1.0, [2] = 1.0, [3] = 1.0, [4] = 1.0, [5] = 1.0, [6] = 1.0, [7] = 1.0,
		[8] = 1.0, [9] = 1.0, [10] = 1.0, [11] = 1.0, [12] = 1.0, [13] = 0.0, [14] = 1.0, [15] = 1.0,
		[16] = 1.0, [17] = 1.0, [18] = 1.0, [19] = 1.0, [20] = 1.0, [21] = 1.0, [22] = 1.0,
	},

	-- Global multiplier on top of fuelUsage / classUsage
	consumptionMultiplier = 1.0,

	-- Tank size in litres per vehicle class
	tankSizes = {
		[0] = 45,   -- Compacts
		[1] = 60,   -- Sedans
		[2] = 80,   -- SUVs
		[3] = 55,   -- Coupes
		[4] = 70,   -- Muscle
		[5] = 60,   -- Sports Classics
		[6] = 65,   -- Sports
		[7] = 75,   -- Super
		[8] = 15,   -- Motorcycles
		[9] = 80,   -- Off-road
		[10] = 200, -- Industrial
		[11] = 90,  -- Utility
		[12] = 80,  -- Vans
		[13] = 0,   -- Cycles
		[14] = 120, -- Boats
		[15] = 300, -- Helicopters
		[16] = 500, -- Planes
		[17] = 90,  -- Service
		[18] = 80,  -- Emergency
		[19] = 150, -- Military
		[20] = 250, -- Commercial
		[21] = 500, -- Trains
		[22] = 50,  -- Open wheel
	},

	-- Electric vehicles never use fuel and can't be fueled
	electricVehicles = {
		`airtug`, `caddy`, `caddy2`, `caddy3`, `cyclone`, `cyclone2`, `dilettante`, `dilettante2`,
		`imorgon`, `iwagen`, `khamelion`, `minitank`, `neon`, `omnisegt`, `powersurge`, `raiden`,
		`rcbandito`, `surge`, `tezeract`, `virtue`, `voltic`, `voltic2`, `inductor`, `inductor2`,
		`coureur`, `buffalo5`, `envisage`, `iwagen`, `vivanite`, `zeno`,
	},

	-- Gas pump models
	pumpModels = {
		`prop_gas_pump_old2`,
		`prop_gas_pump_1a`,
		`prop_vintage_pump`,
		`prop_gas_pump_old3`,
		`prop_gas_pump_1c`,
		`prop_gas_pump_1b`,
		`prop_gas_pump_1d`,
	}
}
