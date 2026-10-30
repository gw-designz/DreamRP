local lastUpdate = {}

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

RegisterNetEvent('tactical_anim:setStyles', function(styles)
	local src = source
	local now = GetGameTimer()

	if lastUpdate[src] and now - lastUpdate[src] < 250 then
		return
	end
	lastUpdate[src] = now

	if type(styles) ~= 'table' then
		return
	end

	local clean = {}
	for category in pairs(Config.PlayerCategories) do
		local slug = styles[category]
		if isAllowed(category, slug) then
			clean[category] = slug
		end
	end

	Player(src).state:set('tacticalAnim', clean, true)
end)

AddEventHandler('playerDropped', function()
	lastUpdate[source] = nil
end)
