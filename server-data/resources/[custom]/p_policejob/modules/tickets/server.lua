if not Config.Tickets.enabled then return end

Tickets = {}
Tickets.records      = {}
Tickets.pendingSigns = {}  -- [targetServerId] = { ticketId, officerId, ticket, expires }

-- ============================================================
--  Database setup + initial load
-- ============================================================

MySQL.ready(function()
    MySQL.query(
        [[CREATE TABLE IF NOT EXISTS `police_tickets` (
            `id`             INT AUTO_INCREMENT PRIMARY KEY,
            `ticket_number`  VARCHAR(20) NOT NULL,
            `citizen_name`   VARCHAR(100) NOT NULL,
            `citizen_id`     VARCHAR(50) NOT NULL,
            `vehicle_plate`  VARCHAR(20) DEFAULT '',
            `vehicle_model`  VARCHAR(50) DEFAULT '',
            `violations`     LONGTEXT NOT NULL,
            `total_fine`     INT NOT NULL DEFAULT 0,
            `total_points`   INT NOT NULL DEFAULT 0,
            `location`       VARCHAR(200) DEFAULT '',
            `notes`          TEXT DEFAULT NULL,
            `status`         VARCHAR(20) NOT NULL DEFAULT 'pending',
            `issued_by`      VARCHAR(100) NOT NULL,
            `officer_id`     VARCHAR(50) NOT NULL,
            `signed`         TINYINT(1) NOT NULL DEFAULT 0,
            `signature`      LONGTEXT DEFAULT NULL,
            `points_applied` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at`     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )]],
        {},
        function()
            -- Migrate: add columns that may be missing in older installs
            MySQL.query("ALTER TABLE `police_tickets` ADD COLUMN IF NOT EXISTS `signature` LONGTEXT DEFAULT NULL", {})
            MySQL.query("ALTER TABLE `police_tickets` ADD COLUMN IF NOT EXISTS `points_applied` TINYINT(1) NOT NULL DEFAULT 0", {})

            -- License points table
            MySQL.query([[CREATE TABLE IF NOT EXISTS `police_license_points` (
                `citizen_id`  VARCHAR(50) PRIMARY KEY,
                `points`      INT NOT NULL DEFAULT 0,
                `updated_at`  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )]], {})

            -- Load all existing tickets
            local rows = MySQL.query.await("SELECT * FROM police_tickets ORDER BY id DESC")
            if rows then
                for _, row in ipairs(rows) do
                    row.violations = json.decode(row.violations) or {}
                    Tickets.records[#Tickets.records + 1] = Tickets:formatRecord(row)
                end
            end

            Bridge.Debug(("[Tickets] Loaded %d ticket records"):format(#Tickets.records))
        end
    )
end)

-- ============================================================
--  formatRecord: DB row → clean Lua table
-- ============================================================

function Tickets.formatRecord(self, row)
    local issuedAt
    if row.created_at then
        issuedAt = tostring(row.created_at)
    else
        issuedAt = tostring(os.time() * 1000)
    end

    return {
        id            = tostring(row.id),
        ticketNumber  = row.ticket_number,
        citizenName   = row.citizen_name,
        citizenId     = row.citizen_id,
        vehiclePlate  = row.vehicle_plate  or "",
        vehicleModel  = row.vehicle_model  or "",
        violations    = row.violations,
        totalFine     = row.total_fine,
        totalPoints   = row.total_points,
        location      = row.location       or "",
        notes         = row.notes          or "",
        status        = row.status,
        issuedBy      = row.issued_by,
        signed        = row.signed == true,
        signature     = row.signature or nil,
        pointsApplied = row.points_applied == true,
        issuedAt      = issuedAt,
    }
end

-- ============================================================
--  generateNumber: "TK-YYYY-NNNN"
-- ============================================================

function Tickets.generateNumber(self)
    local year   = os.date("%Y")
    local seqNum = #self.records + 1
    return ("TK-%s-%04d"):format(year, seqNum)
end

-- ============================================================
--  getCitizenPoints: returns total points for a citizen ID
-- ============================================================

function Tickets.getCitizenPoints(self, citizenId)
    if not citizenId or citizenId == "" then return 0 end
    local row = MySQL.single.await(
        "SELECT points FROM police_license_points WHERE citizen_id = ?",
        { citizenId })
    return (row and row.points) or 0
end

-- ============================================================
--  findPlayerByCitizenId: finds online playerSource for a citizen ID
-- ============================================================

function Tickets.findPlayerByCitizenId(self, citizenId)
    if not citizenId or citizenId == "" then return nil end
    for _, playerStr in ipairs(GetPlayers()) do
        local playerSource = tonumber(playerStr)
        if playerSource then
            local ok, uid = pcall(Bridge.Framework.getUniqueId, playerSource, true)
            if ok and uid and tostring(uid) == tostring(citizenId) then
                return playerSource
            end
        end
    end
    return nil
end

-- ============================================================
--  applyPoints: adds penalty points, suspends license if threshold reached
-- ============================================================

function Tickets.applyPoints(self, record, targetSource)
    local pointsCfg = Config.Tickets.points
    if not (pointsCfg and pointsCfg.enabled) then return end
    if record.pointsApplied or record.totalPoints <= 0 then return end

    record.pointsApplied = true

    -- Mark in DB (tonumber to avoid multi-return compiler artefact)
    MySQL.update(
        "UPDATE police_tickets SET points_applied = 1 WHERE id = ?",
        { tonumber(record.id) })

    -- Accumulate points
    MySQL.query.await(
        "INSERT INTO police_license_points (citizen_id, points) VALUES (?, ?) ON DUPLICATE KEY UPDATE points = points + VALUES(points)",
        { record.citizenId, record.totalPoints })

    local totalPoints = self:getCitizenPoints(record.citizenId)

    -- Resolve online player if not provided
    if not targetSource then
        targetSource = self:findPlayerByCitizenId(record.citizenId)
    end

    if totalPoints >= pointsCfg.suspendThreshold then
        -- Reset points on suspension if configured
        if pointsCfg.resetOnSuspension then
            MySQL.update("UPDATE police_license_points SET points = 0 WHERE citizen_id = ?",
                { record.citizenId })
        end

        Config.Tickets.OnLicenseSuspended(targetSource, record.citizenId, totalPoints)

        if targetSource then
            Bridge.Notify.showNotify(targetSource,
                locale("ticket_license_suspended", totalPoints), "error")
        end

        Bridge.Logs.Send(targetSource, "Tickets",
            ("License suspended for %s (%s) - reached %d/%d penalty points")
                :format(record.citizenName, record.citizenId, totalPoints, pointsCfg.suspendThreshold),
            Config.Webhooks.tickets)
    elseif targetSource then
        Bridge.Notify.showNotify(targetSource,
            locale("ticket_points_added", record.totalPoints, totalPoints, pointsCfg.suspendThreshold),
            "warning")
    end
end

-- ============================================================
--  create: validates, inserts into DB, appends to records
-- ============================================================

function Tickets.create(self, data, officerSource)
    -- Validate required fields
    if not (data and data.citizenName and data.citizenId
            and data.violations and #data.violations ~= 0) then
        return nil
    end

    local citizenId = data.citizenId
    local totalFine = 0
    local totalPoints = 0
    local resolvedViolations = {}

    -- Build a lookup from config violations
    local violationById = {}
    for _, v in ipairs(Config.Tickets.violations) do
        violationById[v.id] = v
    end

    -- Resolve each submitted violation
    for _, submitted in ipairs(data.violations) do
        local vDef = violationById[submitted.id]
        if vDef then
            totalFine   = totalFine   + vDef.fine
            totalPoints = totalPoints + vDef.points
            resolvedViolations[#resolvedViolations + 1] = {
                id       = vDef.id,
                name     = vDef.name,
                fine     = vDef.fine,
                points   = vDef.points,
                category = vDef.category,
            }
        end
    end

    if #resolvedViolations == 0 then return nil end

    -- Cap fine
    if totalFine > Config.Tickets.maxFine then
        totalFine = Config.Tickets.maxFine
    end

    -- Resolve officer name and ID
    local ticketNumber = self:generateNumber()
    local issuedBy  = data.issuedBy
    local officerId = data.officerId

    if officerSource then
        if not issuedBy  then issuedBy  = Bridge.Framework.getPlayerName(officerSource) end
        if not officerId then officerId = Bridge.Framework.getUniqueId(officerSource, true) end
    end
    issuedBy  = issuedBy  or "System"
    officerId = officerId or "system"

    -- Insert into DB
    local newId = MySQL.insert.await(
        "INSERT INTO police_tickets (ticket_number, citizen_name, citizen_id, vehicle_plate, vehicle_model, violations, total_fine, total_points, location, notes, status, issued_by, officer_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        {
            ticketNumber,
            data.citizenName, citizenId,
            data.vehiclePlate or "", data.vehicleModel or "",
            json.encode(resolvedViolations),
            totalFine, totalPoints,
            data.location or "", data.notes or "",
            "pending", issuedBy, officerId,
        }
    )
    if not newId then return nil end

    local record = {
        id            = tostring(newId),
        ticketNumber  = ticketNumber,
        citizenName   = data.citizenName,
        citizenId     = citizenId,
        vehiclePlate  = data.vehiclePlate  or "",
        vehicleModel  = data.vehicleModel  or "",
        violations    = resolvedViolations,
        totalFine     = totalFine,
        totalPoints   = totalPoints,
        location      = data.location or "",
        notes         = data.notes    or "",
        status        = "pending",
        issuedBy      = issuedBy,
        signed        = false,
        pointsApplied = false,
        issuedAt      = tostring(os.time() * 1000),
    }

    Tickets.records[#Tickets.records + 1] = record

    Bridge.Logs.Send(officerSource, "Tickets",
        ("Issued ticket %s to %s - Fine: $%d")
            :format(ticketNumber, data.citizenName, totalFine),
        Config.Webhooks.tickets)

    return record
end

-- ============================================================
--  markPaid: sets status = "paid" and applies points
-- ============================================================

function Tickets.markPaid(self, ticketId, officerSource)
    for i, record in ipairs(self.records) do
        if record.id == tostring(ticketId) then
            record.status = "paid"
            MySQL.update("UPDATE police_tickets SET status = ? WHERE id = ?",
                { "paid", tonumber(ticketId) })
            self:applyPoints(record, nil)
            Bridge.Logs.Send(officerSource, "Tickets",
                ("Marked ticket %s as paid"):format(record.ticketNumber),
                Config.Webhooks.tickets)
            return true
        end
    end
    return false
end

-- ============================================================
--  delete: removes from records and DB (iterates in reverse)
-- ============================================================

function Tickets.delete(self, ticketId, officerSource)
    for i = #self.records, 1, -1 do
        local record = self.records[i]
        if record.id == tostring(ticketId) then
            local ticketNumber = record.ticketNumber
            table.remove(self.records, i)
            MySQL.query("DELETE FROM police_tickets WHERE id = ?", { tonumber(ticketId) })
            Bridge.Logs.Send(officerSource, "Tickets",
                ("Deleted ticket %s"):format(ticketNumber),
                Config.Webhooks.tickets)
            return true
        end
    end
    return false
end

-- ============================================================
--  Callbacks
-- ============================================================

lib.callback.register("p_policejob/server/tickets/getTickets", function(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not (job and Config.Jobs[job.name]) then return {} end
    return Tickets.records
end)

lib.callback.register("p_policejob/server/tickets/getNearbyPlayers", function(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not (job and Config.Jobs[job.name]) then return {} end

    local officerPed    = GetPlayerPed(playerSource)
    local officerCoords = GetEntityCoords(officerPed)

    -- Use configured nearbyDistance, or fall back to max(15, maxDistance * 3)
    local nearbyDist = tonumber(Config.Tickets.nearbyDistance)
    if not nearbyDist then
        local maxDist = tonumber(Config.Tickets.maxDistance) or 5.0
        nearbyDist = math.max(15.0, maxDist * 3)
    end

    local result = {}

    for _, playerStr in ipairs(GetPlayers()) do
        local target = tonumber(playerStr)
        if target and target ~= playerSource then
            local targetPed = GetPlayerPed(target)
            if targetPed and targetPed ~= 0 then
                local dist = #(officerCoords - GetEntityCoords(targetPed))
                if dist <= nearbyDist then
                    -- Get citizen ID (pcall — may fail for NPCs/edge cases)
                    local okId, citizenId = pcall(Bridge.Framework.getUniqueId, target, true)
                    if not okId then citizenId = nil end

                    local points = 0
                    if citizenId then
                        local okPts, pts = pcall(Tickets.getCitizenPoints, Tickets, citizenId)
                        points = (okPts and pts) or 0
                    end

                    result[#result + 1] = {
                        serverId  = target,
                        name      = Bridge.Framework.getPlayerName(target),
                        citizenId = citizenId,
                        dist      = math.floor(dist),
                        points    = points,
                    }
                end
            end
        end
    end

    table.sort(result, function(a, b) return a.dist < b.dist end)
    return result
end)

lib.callback.register("p_policejob/server/tickets/createTicket", function(playerSource, data)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not (job and Config.Jobs[job.name]) then return nil end
    return Tickets:create(data, playerSource)
end)

lib.callback.register("p_policejob/server/tickets/sendForSigning", function(playerSource, data)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not (job and Config.Jobs[job.name]) then return false end
    if not (data and data.ticketId and data.targetId) then return false end

    local targetSource = tonumber(data.targetId)
    if not targetSource then return false end

    local targetPed = GetPlayerPed(targetSource)
    if not targetPed or targetSource == 0 then
        Bridge.Notify.showNotify(playerSource, locale("player_offline"), "error")
        return false
    end

    -- Distance check
    local officerPed   = GetPlayerPed(playerSource)
    local dist = #(vec3(GetEntityCoords(officerPed)) - vec3(GetEntityCoords(targetPed)))
    if dist > Config.Tickets.maxDistance then
        Bridge.Notify.showNotify(playerSource, locale("ticket_player_too_far"), "error")
        return false
    end

    -- Find the ticket record
    local record = nil
    for _, r in ipairs(Tickets.records) do
        if r.id == data.ticketId then record = r; break end
    end
    if not record then return false end

    -- Store pending sign entry
    Tickets.pendingSigns[targetSource] = {
        ticketId  = data.ticketId,
        officerId = playerSource,
        ticket    = record,
        expires   = os.time() + Config.Tickets.signTimeout,
    }

    -- Send sign request to target
    TriggerClientEvent("p_policejob/client/tickets/requestSign", targetSource, {
        ticketId    = record.id,
        ticketNumber = record.ticketNumber,
        violations  = record.violations,
        totalFine   = record.totalFine,
        totalPoints = record.totalPoints,
        officerName = record.issuedBy,
        location    = record.location,
        timeout     = Config.Tickets.signTimeout,
    })

    Bridge.Notify.showNotify(playerSource, locale("ticket_sent_for_signing"), "success")
    return true
end)

-- ============================================================
--  signTicket net event
-- ============================================================

RegisterNetEvent("p_policejob/server/tickets/signTicket", function(data)
    local targetSource = source
    if not (data and data.ticketId) then return end

    local pending = Tickets.pendingSigns[targetSource]
    if not pending or pending.ticketId ~= data.ticketId then return end

    -- Find and update the record
    for i, record in ipairs(Tickets.records) do
        if record.id == data.ticketId then
            record.signed    = true
            record.status    = "paid"
            record.signature = data.signature or nil

            MySQL.update(
                "UPDATE police_tickets SET signed = 1, status = 'paid', signature = ? WHERE id = ?",
                { data.signature or nil, tonumber(data.ticketId) })

            -- Apply fine via config callback
            Config.Tickets.OnPlayerFined(pending.officerId, targetSource, record.totalFine)

            -- Apply penalty points
            Tickets:applyPoints(record, targetSource)

            -- Notify both sides
            TriggerClientEvent("p_policejob/client/tickets/onSigned", pending.officerId, {
                ticketId  = data.ticketId,
                signature = data.signature or nil,
            })

            Bridge.Notify.showNotify(targetSource,
                locale("ticket_signed", record.totalFine), "info")
            Bridge.Notify.showNotify(pending.officerId,
                locale("ticket_was_signed", record.ticketNumber), "success")

            Bridge.Logs.Send(targetSource, "Tickets",
                ("Signed ticket %s - Fine: $%d applied")
                    :format(record.ticketNumber, record.totalFine),
                Config.Webhooks.tickets)
            break
        end
    end

    Tickets.pendingSigns[targetSource] = nil
end)

-- ============================================================
--  refuseTicket net event
-- ============================================================

RegisterNetEvent("p_policejob/server/tickets/refuseTicket", function(data)
    local targetSource = source
    if not (data and data.ticketId) then return end

    local pending = Tickets.pendingSigns[targetSource]
    if not pending or pending.ticketId ~= data.ticketId then return end

    for i, record in ipairs(Tickets.records) do
        if record.id == data.ticketId then
            record.status = "contested"
            MySQL.update("UPDATE police_tickets SET status = ? WHERE id = ?",
                { "contested", tonumber(data.ticketId) })

            Bridge.Notify.showNotify(targetSource,
                locale("ticket_refused"), "warning")
            Bridge.Notify.showNotify(pending.officerId,
                locale("ticket_was_refused", record.ticketNumber), "error")

            Bridge.Logs.Send(targetSource, "Tickets",
                ("Refused to sign ticket %s"):format(record.ticketNumber),
                Config.Webhooks.tickets)
            break
        end
    end

    Tickets.pendingSigns[targetSource] = nil
end)

-- ============================================================
--  markPaid + deleteTicket callbacks
-- ============================================================

lib.callback.register("p_policejob/server/tickets/markPaid", function(playerSource, ticketId)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not (job and Config.Jobs[job.name]) then return false end
    return Tickets:markPaid(ticketId, playerSource)
end)

lib.callback.register("p_policejob/server/tickets/deleteTicket", function(playerSource, ticketId)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not (job and Config.Jobs[job.name]) then return false end
    return Tickets:delete(ticketId, playerSource)
end)

-- ============================================================
--  Cleanup on disconnect
-- ============================================================

AddEventHandler("playerDropped", function()
    Tickets.pendingSigns[source] = nil
end)

-- ============================================================
--  Exports
-- ============================================================

exports("createTicket",    function(data)       return Tickets:create(data, nil) end)
exports("getAllTickets",    function()           return Tickets.records end)
exports("markTicketPaid",  function(ticketId)   return Tickets:markPaid(ticketId, nil) end)
exports("deleteTicket",    function(ticketId)   return Tickets:delete(ticketId, nil) end)
exports("getLicensePoints",function(citizenId)  return Tickets:getCitizenPoints(citizenId) end)

exports("getTicket", function(ticketId)
    for _, record in ipairs(Tickets.records) do
        if record.id == tostring(ticketId) then return record end
    end
    return nil
end)

exports("getPlayerTickets", function(citizenId)
    local result = {}
    for _, record in ipairs(Tickets.records) do
        if record.citizenId == citizenId then
            result[#result + 1] = record
        end
    end
    return result
end)
