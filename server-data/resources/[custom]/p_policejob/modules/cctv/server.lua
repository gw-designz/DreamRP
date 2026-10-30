-- Wait for Config.CCTV to be available
while true do
    if Config and Config.CCTV then break end
    Citizen.Wait(1)
end

if not Config.CCTV.enabled then return end

-- Global CCTV object shared across the resource
CCTV = {}
CCTV.cameras      = {}   -- [id] = camData
CCTV.repairTimers = {}   -- [id] = timerGeneration (used to cancel stale timers)

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Returns true if playerSource's job name is in Config.CCTV.creatorAccess
function PlayerHasCreatorAccess(playerJob)
    for _, jobName in ipairs(Config.CCTV.creatorAccess) do
        if playerJob.name == jobName then return true end
    end
    return false
end

-- ─── Database Init ───────────────────────────────────────────────────────────

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `p_policejob_cctv` (
            `id`         INT AUTO_INCREMENT PRIMARY KEY,
            `name`       VARCHAR(50)  NOT NULL,
            `model`      VARCHAR(50)  NOT NULL,
            `coords`     LONGTEXT     NOT NULL,
            `rotation`   LONGTEXT     NOT NULL,
            `jobs`       LONGTEXT     NOT NULL,
            `broken`     TINYINT(1)   DEFAULT 0,
            `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    Citizen.Wait(1000)
    CCTV:LoadCameras()

    Bridge.Debug(string.format("[CCTV] Database verified, loaded %d cameras",
        #(CCTV.cameras or {})))
end)

-- ─── CCTV Methods ────────────────────────────────────────────────────────────

-- Loads all cameras from the database into CCTV.cameras.
-- Schedules auto-repair for any that are already broken.
function CCTV:LoadCameras()
    local rows = MySQL.query.await("SELECT * FROM `p_policejob_cctv`")
    if not rows then return end

    for _, row in ipairs(rows) do
        self.cameras[row.id] = {
            id       = row.id,
            name     = row.name,
            model    = row.model,
            coords   = json.decode(row.coords),
            rotation = json.decode(row.rotation),
            jobs     = json.decode(row.jobs),
            broken   = (row.broken == 1),
        }

        if self.cameras[row.id].broken then
            self:ScheduleAutoRepair(row.id)
        end
    end
end

-- Returns the raw cameras table
function CCTV:GetAllCameras()
    return self.cameras
end

-- Inserts a new camera into the database, registers it in CCTV.cameras, and returns it.
-- Returns nil if the insert failed.
function CCTV:CreateCamera(camData)
    local insertId = MySQL.insert.await(
        "INSERT INTO `p_policejob_cctv` (`name`, `model`, `coords`, `rotation`, `jobs`) VALUES (?, ?, ?, ?, ?)",
        {
            camData.name,
            camData.model,
            json.encode(camData.coords),
            json.encode(camData.rotation),
            json.encode(camData.jobs),
        }
    )

    if not insertId then return nil end

    local newCam = {
        id       = insertId,
        name     = camData.name,
        model    = camData.model,
        coords   = camData.coords,
        rotation = camData.rotation,
        jobs     = camData.jobs,
        broken   = false,
    }

    self.cameras[insertId] = newCam
    return newCam
end

-- Deletes a camera from the database and removes it from the local tables
function CCTV:DeleteCamera(cameraId)
    MySQL.query.await("DELETE FROM `p_policejob_cctv` WHERE `id` = ?", { cameraId })
    self.cameras[cameraId]      = nil
    self.repairTimers[cameraId] = nil
end

-- Updates the broken column in the database and the local camera record
function CCTV:SetBroken(cameraId, isBroken)
    MySQL.update.await(
        "UPDATE `p_policejob_cctv` SET `broken` = ? WHERE `id` = ?",
        { isBroken and 1 or 0, cameraId }
    )

    if self.cameras[cameraId] then
        self.cameras[cameraId].broken = isBroken
    end
end

-- Repairs a broken camera: clears the repair timer, marks it not-broken in DB,
-- and broadcasts the restored state to all clients
function CCTV:Repair(cameraId)
    self.repairTimers[cameraId] = nil
    self:SetBroken(cameraId, false)
    TriggerClientEvent("p_policejob/client/cctv/broken", -1, cameraId, false)
end

-- Schedules an automatic repair after Config.CCTV.damage.autoRepairTime ms.
-- Uses a generation counter per camera so that only the most recent timer fires
-- (cancels stale timers set before another damage event on the same camera).
function CCTV:ScheduleAutoRepair(cameraId)
    local autoRepairTime = Config.CCTV.damage and Config.CCTV.damage.autoRepairTime or 0
    if not autoRepairTime or autoRepairTime <= 0 then return end

    local currentGeneration = (self.repairTimers[cameraId] or 0) + 1
    self.repairTimers[cameraId] = currentGeneration

    SetTimeout(autoRepairTime, function()
        -- Only fire if this is still the most recent timer for this camera
        if self.repairTimers[cameraId] ~= currentGeneration then return end

        local cam = self.cameras[cameraId]
        if cam then
            if cam.broken then
                self:Repair(cameraId)
                Bridge.Debug(string.format("[CCTV] Camera id=%s auto-repaired", cameraId))
            end
        else
            -- Camera was deleted while the timer was pending
            self.repairTimers[cameraId] = nil
        end
    end)
end

-- ─── Net Events ──────────────────────────────────────────────────────────────

-- Client → server: player joined, send them the full camera list
RegisterNetEvent("p_policejob/server/cctv/request", function()
    local playerSource = source
    TriggerClientEvent("p_policejob/client/cctv/load", playerSource, CCTV:GetAllCameras())
end)

-- Client → server: player confirmed camera placement in the creator dialog
RegisterNetEvent("p_policejob/server/cctv/create", function(camData)
    local playerSource = source
    local playerJob    = Bridge.Framework.getPlayerJob(playerSource)
    if not playerJob then return end

    if not PlayerHasCreatorAccess(playerJob) then return end

    local newCam = CCTV:CreateCamera(camData)
    if newCam then
        TriggerClientEvent("p_policejob/client/cctv/add", -1, newCam)
        lib.notify(playerSource, { title = locale("cctv_created"), type = "success" })
        Bridge.Debug(string.format("[CCTV] Player %s created camera id=%s name=%s",
            playerSource, newCam.id, newCam.name))
    else
        Bridge.Debug(string.format("[CCTV] Player %s create failed", playerSource))
    end
end)

-- Client → server: player confirmed deletion of a camera
RegisterNetEvent("p_policejob/server/cctv/delete", function(cameraId)
    local playerSource = source
    local playerJob    = Bridge.Framework.getPlayerJob(playerSource)
    if not playerJob then return end

    if not PlayerHasCreatorAccess(playerJob) then return end

    local cam = CCTV.cameras[cameraId]
    if not cam then return end

    CCTV:DeleteCamera(cameraId)
    TriggerClientEvent("p_policejob/client/cctv/remove", -1, cameraId)
    lib.notify(playerSource, { title = locale("camera_removed", cam.name), type = "success" })
    Bridge.Debug(string.format("[CCTV] Player %s deleted camera id=%s", playerSource, cameraId))
end)

-- Client → server: player shot a camera prop; validate distance then mark broken
RegisterNetEvent("p_policejob/server/cctv/damage", function(cameraId)
    local playerSource = source
    local cam          = CCTV.cameras[cameraId]

    -- Camera must exist and not already be broken
    if not (cam and not cam.broken) then return end

    local playerPed = GetPlayerPed(playerSource)
    if not (playerPed and playerPed ~= 0) then return end
    if not cam.coords then return end

    local breakDistance = (Config.CCTV.damage and Config.CCTV.damage.breakDistance) or 10.0
    local playerPos     = GetEntityCoords(playerPed)
    local camPos        = vec3(cam.coords.x, cam.coords.y, cam.coords.z)
    local distance      = #(playerPos - camPos)

    if distance > breakDistance then
        Bridge.Debug(string.format("[CCTV] Player %s denied breaking camera id=%s (too far)",
            playerSource, cameraId))
        return
    end

    CCTV:SetBroken(cameraId, true)
    TriggerClientEvent("p_policejob/client/cctv/broken", -1, cameraId, true)
    CCTV:ScheduleAutoRepair(cameraId)

    Bridge.Debug(string.format("[CCTV] Camera id=%s damaged by %s", cameraId, playerSource))
end)

-- ─── Admin Commands ───────────────────────────────────────────────────────────

lib.addCommand("repaircctv", {
    help       = "Repair a broken CCTV camera",
    params     = { { name = "id", type = "number", help = "Camera ID" } },
    restricted = "group.admin",
}, function(playerSource, args)
    local cameraId = args.id
    if not CCTV.cameras[cameraId] then
        lib.notify(playerSource, { title = locale("cctv_not_found"), type = "error" })
        return
    end
    CCTV:Repair(cameraId)
    lib.notify(playerSource, { title = locale("cctv_repaired"), type = "success" })
end)

lib.addCommand("deletecctv", {
    help       = "Delete a CCTV camera",
    params     = { { name = "id", type = "number", help = "Camera ID" } },
    restricted = "group.admin",
}, function(playerSource, args)
    local cameraId = args.id
    local cam      = CCTV.cameras[cameraId]
    if not cam then
        lib.notify(playerSource, { title = locale("cctv_not_found"), type = "error" })
        return
    end

    CCTV:DeleteCamera(cameraId)
    TriggerClientEvent("p_policejob/client/cctv/remove", -1, cameraId)
    lib.notify(playerSource, { title = locale("camera_removed", cam.name), type = "success" })
end)

lib.addCommand("createcctv", {
    help       = "Open CCTV camera creator",
    params     = {},
    restricted = false,
}, function(playerSource)
    local playerJob = Bridge.Framework.getPlayerJob(playerSource)
    if not playerJob then return end

    if not PlayerHasCreatorAccess(playerJob) then
        lib.notify(playerSource, { title = locale("camera_no_access"), type = "error" })
        return
    end

    TriggerClientEvent("p_policejob/client/cctv/creator", playerSource)
end)

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("getCCTVCameras", function()
    return CCTV:GetAllCameras()
end)

-- Alias kept for backwards compatibility
exports("GetCameras", function()
    return CCTV:GetAllCameras()
end)

exports("repairCCTV", function(cameraId)
    CCTV:Repair(cameraId)
end)
