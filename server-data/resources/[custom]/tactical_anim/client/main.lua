local KVP_KEY = 'tactical_anim:styles'

local styles = {}
local menuOpen = false

local function isAllowed(category, slug)
	if not Config.PlayerCategories[category] or type(slug) ~= 'string' then
		return false
	end

	local allowed = Config.AvailableStyles[category]
	for i = 1, #allowed do
		if allowed[i] == slug then
			return true
		end
	end

	return false
end

local function loadStyles()
	local raw = GetResourceKvpString(KVP_KEY)
	local ok, data = pcall(json.decode, raw or '{}')
	styles = {}

	if ok and type(data) == 'table' then
		for category, slug in pairs(data) do
			if isAllowed(category, slug) then
				styles[category] = slug
			end
		end
	end
end

local syncQueued = false

local function saveStyles()
	SetResourceKvp(KVP_KEY, json.encode(styles))

	-- Batch rapid clicks so the server's rate limit never drops the last one
	if syncQueued then
		return
	end
	syncQueued = true

	SetTimeout(400, function()
		syncQueued = false
		TriggerServerEvent('tactical_anim:setStyles', styles)
	end)
end

local function setMenuOpen(open)
	menuOpen = open
	SetNuiFocus(open, open)

	if not open then
		SendNUIMessage({ action = 'close' })
		return
	end

	local categories = {}
	for i = 1, #Config.CategoryOrder do
		local key = Config.CategoryOrder[i]
		categories[#categories + 1] = {
			key = key,
			label = Config.CategoryLabels[key] or key,
			styles = Config.AvailableStyles[key],
			serverStyle = Config.DefaultStyles[key],
			locked = not Config.PlayerCategories[key],
		}
	end

	SendNUIMessage({
		action = 'open',
		accent = Config.AccentColor,
		categories = categories,
		selected = styles,
	})
end

RegisterNUICallback('select', function(data, cb)
	local category, slug = data.category, data.style

	if slug == false or slug == nil then
		styles[category] = nil
		saveStyles()
	elseif isAllowed(category, slug) then
		styles[category] = slug
		saveStyles()
	end

	cb({ selected = styles })
end)

RegisterNUICallback('reset', function(_, cb)
	styles = {}
	saveStyles()
	cb({ selected = styles })
end)

RegisterNUICallback('close', function(_, cb)
	setMenuOpen(false)
	cb('ok')
end)

RegisterCommand(Config.MenuCommand, function()
	setMenuOpen(not menuOpen)
end, false)

if Config.MenuKey ~= '' then
	RegisterKeyMapping(Config.MenuCommand, 'Tactical animation styles', 'keyboard', Config.MenuKey)
end

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and menuOpen then
		SetNuiFocus(false, false)
	end
end)

CreateThread(function()
	loadStyles()

	-- Clear the movement clip set an earlier version of this script forced on, which
	-- stretched limbs; it survives resource restarts
	ResetPedWeaponMovementClipset(PlayerPedId())

	while not NetworkIsPlayerActive(PlayerId()) do
		Wait(500)
	end

	TriggerServerEvent('tactical_anim:setStyles', styles)
end)
