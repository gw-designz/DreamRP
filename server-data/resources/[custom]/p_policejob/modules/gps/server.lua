while true do
    if Config and Config.GPS then break end
    Citizen.Wait(500)
end

if not Config.GPS.enabled then return end

GPS = {}
GPS.players = {}
GlobalState["p_policejob/gpsData"] = GPS.players

-- ============================================================
--  Helpers
-- ============================================================

function GPS.getType(self, ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return "walk" end
    local vtype = GetVehicleType(vehicle)
    if vtype == "boat"  then return "boat"  end
    if vtype == "plane" then return "plane" end
    if vtype == "heli"  then return "heli"  end
    return "car"
end

function GPS.getSpeed(self, ped)
    local vel = GetEntityVelocity(ped)
    local kmh = math.sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z) * 3.6
    return math.floor(kmh)
end

-- ============================================================
--  Update a single player's GPS entry
-- ============================================================

function GPS.update(self, playerSource)
    if not playerSource or playerSource == 0 then return end

    local ok, ped = pcall(GetPlayerPed, playerSource)
    if not (ok and ped and ped ~= 0) then
        self.players[playerSource] = nil
        return
    end

    local vehicle   = GetVehiclePedIsIn(ped, false)
    local name      = Bridge.Framework.getPlayerName(playerSource)
    local job       = Bridge.Framework.getPlayerJob(playerSource)
    local coords    = GetEntityCoords(ped)
    local sirens    = (vehicle ~= 0) and IsVehicleSirenOn(vehicle) or false

    self.players[playerSource] = {
        label   = ("%s - %s"):format(name, job.grade_label),
        job     = job.name,
        heading = GetEntityHeading(ped),
        coords  = coords,
        type    = self:getType(ped),
        speed   = self:getSpeed(ped),
        sirens  = sirens,
    }
end

-- ============================================================
--  Toggle GPS on/off for a player
-- ============================================================

function GPS.toggle(self, playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job or not Config.Jobs[job.name] then
        Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
        return
    end

    if self.players[playerSource] then
        self.players[playerSource] = nil
        Bridge.Debug(("[GPS] Player %s deactivated GPS"):format(playerSource))
        Bridge.Notify.showNotify(playerSource, locale("deactivated_gps"), "inform")
    else
        self:update(playerSource)
        Bridge.Debug(("[GPS] Player %s activated GPS"):format(playerSource))
        Bridge.Notify.showNotify(playerSource, locale("activated_gps"), "inform")
    end
end

-- ============================================================
--  Panic button
-- ============================================================

function GPS.triggerPanic(self, playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job or not Config.Jobs[job.name] then return end

    if not Config.GPS.panic.enabled then return end

    local ok, ped = pcall(GetPlayerPed, playerSource)
    if not (ok and ped and ped ~= 0) then return end

    local name   = Bridge.Framework.getPlayerName(playerSource)
    local coords = GetEntityCoords(ped)
    Bridge.Debug(("[GPS] Panic triggered by %s (%s)"):format(playerSource, name))

    local alertData = { source = playerSource, name = name, coords = coords }

    for otherId in pairs(self.players) do
        if otherId ~= playerSource then
            TriggerClientEvent("p_policejob/client/gps/panic", otherId, alertData)
        end
    end

    Bridge.Notify.showNotify(playerSource, "Panic signal sent!", "error")
end

-- ============================================================
--  Update loop
-- ============================================================

function GPS.init(self)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Config.GPS.updateInterval or 3000)

            for playerSource in pairs(self.players) do
                Citizen.Wait(1)

                if Config.GPS.requiredItem then
                    local count = Bridge.Inventory.getItemCount(playerSource, Config.GPS.requiredItemName)
                    if count < 1 then
                        TriggerClientEvent("p_policejob/client/gps/toggle", playerSource)
                    end
                else
                    self:update(playerSource)
                end
            end

            GlobalState["p_policejob/gpsData"] = self.players
        end
    end)
end

GPS:init()

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/gps/server/toggle", function()
    GPS:toggle(source)
end)

RegisterNetEvent("p_policejob/gps/server/panic", function()
    GPS:triggerPanic(source)
end)

AddEventHandler("playerDropped", function()
    GPS.players[source] = nil
end)

-- ============================================================
--  Exports
-- ============================================================

exports("getGpsPlayers", function()
    return GPS.players
end)

exports("isGpsActive", function(playerSource)
    return GPS.players[playerSource] ~= nil
end)

exports("toggleGps", function(playerSource)
    GPS:toggle(playerSource)
end)

exports("triggerPanic", function(playerSource)
    GPS:triggerPanic(playerSource)
end)
