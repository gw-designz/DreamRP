local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local pumps = require 'client.pumps'
local screen = require 'client.screen'
local stations = lib.load 'data.stations'

if config.showBlips == 2 then
	for station in pairs(stations) do utils.createBlip(station) end
end

---@param point CPoint
local function onEnterStation(point)
	if config.showBlips == 1 and not point.blip then
		point.blip = utils.createBlip(point.coords)
	end

	screen.addStation(point.pumps)
end

---@param point CPoint
local function nearbyStation(point)
	if point.currentDistance > 25 then return end

	local pumpList = point.pumps
	local playerCoords = cache.coords
	local nearest, nearestDistance

	for i = 1, #pumpList do
		local distance = #(playerCoords - pumpList[i].coords)

		if distance <= 3 and (not nearestDistance or distance < nearestDistance) then
			nearest, nearestDistance = pumpList[i], distance
		end
	end

	if nearest then
		state.nearestPump = nearest
	elseif state.nearestPump and state.nearestPump.station == pumpList then
		state.nearestPump = nil
	end
end

---@param point CPoint
local function onExitStation(point)
	if point.blip then
		point.blip = RemoveBlip(point.blip)
	end

	if state.nearestPump and state.nearestPump.station == point.pumps then
		state.nearestPump = nil
	end

	screen.removeStation(point.pumps)
end

for station, pumpCoords in pairs(stations) do
	local pumpList = {}

	for i = 1, #pumpCoords do
		local pump = pumps.new(pumpCoords[i])
		pump.station = pumpList
		pumpList[i] = pump
	end

	lib.points.new({
		coords = station,
		distance = 60,
		onEnter = onEnterStation,
		onExit = onExitStation,
		nearby = nearbyStation,
		pumps = pumpList,
	})
end
