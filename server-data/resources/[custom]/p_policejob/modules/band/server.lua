if not Config.Band.Enabled then return end

Band = {}
Band.tableName = "p_policejob_bands"
Band.playersWithBand = {}
GlobalState.playersWithBand = Band.playersWithBand

-- ============================================================
--  Database
-- ============================================================

function Band.initDatabase(self)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `p_policejob_bands` (
            `identifier` VARCHAR(60) NOT NULL,
            `name`       VARCHAR(50) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

function Band.saveToDatabase(self, identifier, playerName)
    local query = ("INSERT INTO `%s` (`identifier`, `name`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `name` = VALUES(`name`)"):format(self.tableName)
    MySQL.insert(query, { identifier, playerName })
end

function Band.removeFromDatabase(self, identifier)
    local query = ("DELETE FROM `%s` WHERE `identifier` = ?"):format(self.tableName)
    MySQL.query(query, { identifier })
end

function Band.loadFromDatabase(self)
    local query   = ("SELECT `identifier`, `name` FROM `%s`"):format(self.tableName)
    local results = MySQL.query.await(query)
    if not results or #results == 0 then return end

    for _, row in ipairs(results) do
        self.playersWithBand[row.identifier] = {
            coords  = nil,
            heading = nil,
            online  = false,
            name    = row.name,
        }
    end
    GlobalState.playersWithBand = self.playersWithBand
end

-- ============================================================
--  Coord updates
-- ============================================================

function Band.updateCoords(self)
    for identifier, bandData in pairs(self.playersWithBand) do
        local frameworkPlayer = Bridge.Framework.getPlayerByUniqueId(identifier)
        if frameworkPlayer then
            local playerSource = frameworkPlayer.source or (frameworkPlayer.PlayerData and frameworkPlayer.PlayerData.source)
            if playerSource then
                local ped    = GetPlayerPed(playerSource)
                local coords = GetEntityCoords(ped)
                bandData.coords = vector3(coords.x, coords.y, coords.z)

                if Config.Band.Blip.heading then
                    bandData.heading = GetEntityHeading(ped)
                end
                bandData.online = true

                TriggerEvent("p_policejob:OnBandLocationUpdate", {
                    cid    = identifier,
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                })
            end
        else
            bandData.online = false
        end
    end
    GlobalState.playersWithBand = self.playersWithBand
end

-- ============================================================
--  Attach / Remove
-- ============================================================

function Band.attach(self, officerSource, targetSource)
    local officerJob = Bridge.Framework.getPlayerJob(officerSource)

    if not Config.Jobs[officerJob.name] then
        return Bridge.Notify.showNotify(officerSource, locale("no_access"), "error")
    end

    local targetIdentifier = Bridge.Framework.getUniqueId(targetSource)
    if not targetIdentifier then
        return Bridge.Notify.showNotify(officerSource, locale("player_not_found"), "error")
    end

    if self.playersWithBand[targetIdentifier] then
        return Bridge.Notify.showNotify(officerSource, locale("this_player_have_band"), "error")
    end

    local targetPed    = GetPlayerPed(targetSource)
    local targetCoords = GetEntityCoords(targetPed)
    local targetName   = Bridge.Framework.getPlayerName(targetSource)

    local heading = nil
    if Config.Band.Blip.heading then
        heading = GetEntityHeading(targetPed)
    end

    self.playersWithBand[targetIdentifier] = {
        coords  = vector3(targetCoords.x, targetCoords.y, targetCoords.z),
        heading = heading,
        online  = true,
        name    = targetName,
    }
    GlobalState.playersWithBand = self.playersWithBand

    Bridge.Inventory.removeItem(officerSource, "tracking_band", 1)

    SetTimeout(2000, function()
        TriggerClientEvent("p_policejob/client/band/SetPlayerBand", targetSource, true)
    end)

    self:saveToDatabase(targetIdentifier, targetName)

    Bridge.Logs.Send(officerSource, "Band", locale("player_set_band_for_player", targetSource), Config.Webhooks.band)

    if Config.Band.onAttach_Server then
        Config.Band.onAttach_Server(officerSource, targetSource)
    end

    Bridge.Debug(("[Band] Player %s attached band to player %s"):format(officerSource, targetSource))
end

function Band.remove(self, officerSource, targetSource)
    local targetFrameworkPlayer = Bridge.Framework.getPlayerById(targetSource)
    if not targetFrameworkPlayer then
        return Bridge.Notify.showNotify(officerSource, locale("player_not_found"), "error")
    end

    local targetIdentifier = Bridge.Framework.getUniqueId(targetSource)

    if not self.playersWithBand[targetIdentifier] then
        return Bridge.Notify.showNotify(officerSource, locale("this_player_dont_has_band"), "error")
    end

    local officerJob      = Bridge.Framework.getPlayerJob(officerSource)
    local minGrade        = Config.Jobs[officerJob.name]
    local officerGrade    = tonumber(officerJob.grade)

    if minGrade and officerGrade >= minGrade then
        Bridge.Inventory.addItem(officerSource, "tracking_band", 1)
    end

    self.playersWithBand[targetIdentifier] = nil
    GlobalState.playersWithBand = self.playersWithBand

    SetTimeout(2000, function()
        TriggerClientEvent("p_policejob/client/band/SetPlayerBand", targetSource, false)
    end)

    TriggerClientEvent("p_policejob/client/band/RemoveBandBlip", -1, { id = targetIdentifier })

    self:removeFromDatabase(targetIdentifier)

    Bridge.Logs.Send(officerSource, "Band", locale("player_removed_band_from_player", targetSource), Config.Webhooks.band)

    if Config.Band.onRemove_Server then
        Config.Band.onRemove_Server(officerSource, targetSource)
    end

    Bridge.Debug(("[Band] Player %s removed band from player %s"):format(officerSource, targetSource))
end

-- ============================================================
--  Player lifecycle
-- ============================================================

function Band.onPlayerLoaded(self, playerSource)
    Wait(3000)

    local identifier = Bridge.Framework.getUniqueId(playerSource)
    if not identifier then return end

    if not self.playersWithBand[identifier] then return end

    self.playersWithBand[identifier].online = true
    GlobalState.playersWithBand = self.playersWithBand

    Wait(2500)
    TriggerClientEvent("p_policejob/client/band/SetPlayerBand", playerSource, true)

    Bridge.Logs.Send(playerSource, "Band", locale("player_joined_with_band"), Config.Webhooks.band)
    Bridge.Debug(("[Band] Player %s joined with active band"):format(playerSource))
end

function Band.onPlayerDropped(self, playerSource)
    local identifier = Bridge.Framework.getUniqueId(playerSource)
    if not identifier then return end

    if not self.playersWithBand[identifier] then return end

    self.playersWithBand[identifier].online = false
    GlobalState.playersWithBand = self.playersWithBand

    Bridge.Debug(("[Band] Player %s with band disconnected"):format(playerSource))
end

-- ============================================================
--  Helper: resolve a player from a server ID or unique ID
--  Returns: identifier (string), playerSource (number|nil)
-- ============================================================

local function resolvePlayer(input)
    if input == nil then return nil, nil end

    if type(input) == "number" then
        local identifier = Bridge.Framework.getUniqueId(input)
        return identifier, input
    end

    input = tostring(input)
    local frameworkPlayer = Bridge.Framework.getPlayerByUniqueId(input)

    -- Try uppercase variant if not found (e.g. "steam:ABC" vs "steam:abc")
    if not frameworkPlayer then
        local upper = input:upper()
        if upper ~= input then
            frameworkPlayer = Bridge.Framework.getPlayerByUniqueId(upper)
            if frameworkPlayer then input = upper end
        end
    end

    if not frameworkPlayer then return input, nil end

    local playerSource = frameworkPlayer.source
        or (frameworkPlayer.PlayerData and frameworkPlayer.PlayerData.source)
    return input, playerSource
end

-- ============================================================
--  Exports
-- ============================================================

exports("SetPlayerBand", function(source, targetSource, state)
    if state then
        Band:attach(source, targetSource)
    else
        Band:remove(source, targetSource)
    end
end)

exports("HasPlayerBand", function(playerSource)
    local identifier = Bridge.Framework.getUniqueId(playerSource)
    return Band.playersWithBand[identifier] ~= nil
end)

exports("GetPlayersWithBand", function()
    return Band.playersWithBand
end)

exports("GetActiveBandWearers", function()
    local result = {}
    for identifier, bandData in pairs(Band.playersWithBand) do
        local coords = nil
        if bandData.coords then
            coords = { x = bandData.coords.x, y = bandData.coords.y, z = bandData.coords.z }
        end
        result[#result + 1] = {
            cid     = identifier,
            name    = bandData.name,
            coords  = coords,
            heading = bandData.heading,
            online  = bandData.online or false,
        }
    end
    return result
end)

exports("AddTrackingBand", function(officerSource, targetInput)
    local officerJob = officerSource and Bridge.Framework.getPlayerJob(officerSource)
    if not officerJob or not Config.Jobs[officerJob.name] then
        return false, "invalid_officer"
    end

    local identifier, targetSource = resolvePlayer(targetInput)
    if not identifier then return false, "citizen_not_found" end
    if Band.playersWithBand[identifier] then return false, "already_has_band" end
    if not targetSource then return false, "target_offline" end

    Band:attach(officerSource, targetSource)

    if not Band.playersWithBand[identifier] then return false, "failed" end
    return true, "attached"
end)

exports("RemoveTrackingBand", function(officerSource, targetInput)
    local officerJob = officerSource and Bridge.Framework.getPlayerJob(officerSource)
    if not officerJob or not Config.Jobs[officerJob.name] then
        return false, "invalid_officer"
    end

    local identifier, targetSource = resolvePlayer(targetInput)
    if not identifier then return false, "citizen_not_found" end
    if not Band.playersWithBand[identifier] then return false, "no_band" end
    if not targetSource then return false, "target_offline" end

    Band:remove(officerSource, targetSource)

    if Band.playersWithBand[identifier] then return false, "failed" end
    return true, "removed"
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/server/band/SetPlayerBand", function(data)
    local officerSource = source
    if data.state then
        Band:attach(officerSource, data.player)
    else
        Band:remove(officerSource, data.player)
    end
end)

-- ============================================================
--  Global events
-- ============================================================

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Band:initDatabase()

    SetTimeout(500, function()
        Band:loadFromDatabase()

        SetTimeout(1500, function()
            for _, playerSource in pairs(GetPlayers()) do
                playerSource = tonumber(playerSource)
                if playerSource then
                    Band:onPlayerLoaded(playerSource)
                end
                Wait(1)
            end
        end)
    end)
end)

AddEventHandler("p_bridge/server/playerLoaded", function(playerSource)
    Band:onPlayerLoaded(playerSource)
end)

AddEventHandler("playerDropped", function()
    Band:onPlayerDropped(source)
end)

-- ============================================================
--  Coord update loop
-- ============================================================

CreateThread(function()
    while true do
        Wait(Config.Band.UpdateCoordsRate)
        Band:updateCoords()
    end
end)
