-- Wait for Config.Helicam to be available
while not (Config and Config.Helicam) do Citizen.Wait(500) end

if not Config.Helicam.Enabled then return end

-- activeSpotlights[networkId] = { dir = {x,y,z}, radius = number }
local activeSpotlights = {}

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Returns true if playerSource is inside the helicopter identified by netId
local function PlayerIsInHeli(playerSource, netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not (entity and entity ~= 0 and DoesEntityExist(entity)) then return false end
    if GetEntityType(entity) ~= 2 then return false end           -- must be a vehicle
    if GetVehicleType(entity) ~= "heli" then return false end     -- must be a helicopter

    local ped = GetPlayerPed(playerSource)
    if not (ped and ped ~= 0) then return false end

    return GetVehiclePedIsIn(ped, false) == entity
end

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Client → server: player toggled their spotlight on or off
RegisterNetEvent("p_policejob:heli:setSpotlight", function(netId, isActive, dir, radius)
    if type(netId) ~= "number" then return end

    -- When turning on, verify the player is actually in that heli
    if isActive and not PlayerIsInHeli(source, netId) then return end

    if isActive then
        activeSpotlights[netId] = {
            dir    = dir or { x = 0.0, y = 0.0, z = -1.0 },
            radius = radius,
        }
        TriggerClientEvent("p_policejob:heli:syncSpotlight", -1,
            netId, true, activeSpotlights[netId].dir, activeSpotlights[netId].radius)
    else
        activeSpotlights[netId] = nil
        TriggerClientEvent("p_policejob:heli:syncSpotlight", -1, netId, false)
    end
end)

-- Client → server: player updated their spotlight direction
RegisterNetEvent("p_policejob:heli:updateSpotlightDir", function(netId, dir)
    if type(netId) ~= "number" or not dir then return end
    if not activeSpotlights[netId] then return end
    if not PlayerIsInHeli(source, netId) then return end

    activeSpotlights[netId].dir = dir
    TriggerClientEvent("p_policejob:heli:syncSpotlightDir", -1, netId, dir)
end)

-- Client → server: player updated their spotlight radius
RegisterNetEvent("p_policejob:heli:updateSpotlightRadius", function(netId, radius)
    if type(netId) ~= "number" or type(radius) ~= "number" then return end
    if not activeSpotlights[netId] then return end
    if not PlayerIsInHeli(source, netId) then return end

    activeSpotlights[netId].radius = radius
    TriggerClientEvent("p_policejob:heli:syncSpotlightRadius", -1, netId, radius)
end)

-- Client → server: new player joined, send them all current spotlights
RegisterNetEvent("p_policejob:heli:requestSpotlights", function()
    local requestingSource = source
    for netId, spotData in pairs(activeSpotlights) do
        TriggerClientEvent("p_policejob:heli:syncSpotlight", requestingSource,
            netId, true, spotData.dir, spotData.radius)
    end
end)
