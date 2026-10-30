if not Config.Mugshot.enabled then return end

Mugshot = {}
Mugshot.records = {}

-- ============================================================
--  Database setup
-- ============================================================

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `police_mugshots` (
            `id`          INT AUTO_INCREMENT PRIMARY KEY,
            `url`         LONGTEXT NOT NULL,
            `suspect`     VARCHAR(100) NOT NULL,
            `dob`         VARCHAR(20) DEFAULT NULL,
            `officer`     VARCHAR(100) NOT NULL,
            `description` TEXT,
            `created_at`  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    Bridge.Debug("[Mugshot] Database table verified")
end)

-- ============================================================
--  Load existing records on resource start
-- ============================================================

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Wait(2000)

    local ok, rows = pcall(MySQL.query.await, "SELECT * FROM police_mugshots")
    if not ok then
        lib.print.error("[Mugshot] Failed to fetch mugshots - import the SQL file from INSTALL folder!")
        return
    end

    for i, row in ipairs(rows) do
        Mugshot.records[i] = {
            id          = i,
            url         = row.url,
            suspect     = row.suspect,
            dob         = row.dob,
            officer     = row.officer,
            description = row.description,
        }
    end

    Bridge.Debug(("[Mugshot] Loaded %d mugshots from database"):format(#Mugshot.records))
end)

-- ============================================================
--  Get mugshots callback (with optional search filter)
-- ============================================================

lib.callback.register("p_policejob/server/mugshot/getMugshots", function(_, searchQuery)
    if not searchQuery then
        return Mugshot.records
    end

    local query   = tostring(searchQuery):lower()
    local results = {}

    for _, record in ipairs(Mugshot.records) do
        local matches = tostring(record.id):find(query)
            or record.suspect:lower():find(query)
            or record.officer:lower():find(query)
            or record.description:lower():find(query)
            or record.dob:lower():find(query)

        if matches then
            results[#results + 1] = record
        end
    end

    return results
end)

-- ============================================================
--  Take photo event
-- ============================================================

RegisterNetEvent("p_policejob/server/mugshot/takePhoto", function(data)
    local officerSource = source

    -- Validate input
    if type(data) ~= "table"
        or not data.name
        or not data.playerId
        or data.playerId < 0
    then return end

    local zoneDef = Config.DepartmentData.mugshots[data.name]
    if not zoneDef then return end

    -- Job access check
    local officerJob = Bridge.Framework.getPlayerJob(officerSource)
    if not Config.Jobs[officerJob.name] then return end

    -- Validate target is online
    local targetPed = GetPlayerPed(data.playerId)
    if not targetPed then
        return Bridge.Notify.showNotify(officerSource, locale("player_is_offline"), "error")
    end

    -- Distance check: target must be near the photo spot
    local targetCoords = GetEntityCoords(GetPlayerPed(data.playerId))
    if #(targetCoords - zoneDef.photoCoords) > 3.0 then
        return Bridge.Notify.showNotify(officerSource, locale("mugshot_player_is_too_far"), "error")
    end

    local suspectName  = Bridge.Framework.getPlayerName(data.playerId)
    local suspectDob   = Bridge.Framework.getPlayerDob(data.playerId) or ""
    local description  = tostring((data.info and data.info.description) or "")

    -- Run the photo capture on the SUSPECT's client, await URL
    local photoUrl = lib.callback.await(
        "p_policejob/client/mugshot/takePhoto",
        data.playerId,
        {
            name = data.name,
            info = { dob = suspectDob, description = description },
        }
    )
    if not photoUrl then return end

    -- Save to in-memory records
    local newId     = #Mugshot.records + 1
    local officerName = Bridge.Framework.getPlayerName(officerSource)

    Mugshot.records[newId] = {
        id          = newId,
        url         = photoUrl,
        suspect     = suspectName,
        dob         = suspectDob,
        officer     = officerName,
        description = description,
    }

    -- Persist to DB (fire-and-forget)
    MySQL.insert(
        "INSERT INTO police_mugshots (url, suspect, dob, officer, description) VALUES (?, ?, ?, ?, ?)",
        { photoUrl, suspectName, suspectDob, officerName, description }
    )

    -- Config callback (e.g. post to Discord)
    Config.Mugshot.SendPhoto({
        url         = photoUrl,
        webhook     = (Config.Webhooks and Config.Webhooks.mugshot) or "",
        id          = newId,
        suspect     = suspectName,
        dob         = suspectDob,
        officer     = officerName,
        description = description,
    })

    -- Webhook log
    Bridge.Logs.Send(officerSource, "Mugshot",
        locale("mugshot_taken", suspectName),
        (Config.Webhooks and Config.Webhooks.mugshot) or "")
end)

-- ============================================================
--  Remove mugshot event
-- ============================================================

RegisterNetEvent("p_policejob/server/mugshot/remove", function(mugshotId)
    local officerSource = source

    local record = Mugshot.records[mugshotId]
    if not record then
        return Bridge.Notify.showNotify(officerSource, locale("mugshot_doesnt_exist", mugshotId), "error")
    end

    local officerJob = Bridge.Framework.getPlayerJob(officerSource)
    if not Config.Jobs[officerJob.name] then return end

    table.remove(Mugshot.records, mugshotId)
    MySQL.update("DELETE FROM police_mugshots WHERE id = ?", { mugshotId })

    Config.Mugshot.onPhotoRemoved(officerSource, mugshotId)
    Bridge.Notify.showNotify(officerSource, locale("mugshot_removed", mugshotId), "success")
end)
