if not (Config and Config.Wardrobe and Config.Wardrobe.Enabled) then return end

-- ============================================================
--  Database setup
-- ============================================================

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `p_policejob_outfits` (
            `id`         INT NOT NULL AUTO_INCREMENT,
            `name`       VARCHAR(64) NOT NULL,
            `job`        VARCHAR(50) NOT NULL,
            `grades`     JSON NOT NULL,
            `gender`     VARCHAR(10) NOT NULL,
            `licenses`   JSON DEFAULT NULL,
            `skin`       LONGTEXT NOT NULL,
            `created_by` VARCHAR(100) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            INDEX `idx_job_gender` (`job`, `gender`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    Bridge.Debug("[Wardrobe] Database table verified")
end)

-- ============================================================
--  Helpers
-- ============================================================

-- Returns a sorted array of grade options for a given job name.
local function getGradeOptions(jobName)
    local grades = {}
    local jobs   = Bridge.Framework.getJobs()
    local jobDef = jobs and jobs[jobName]
    if not jobDef then return grades end

    for gradeStr, gradeDef in pairs(jobDef) do
        grades[#grades + 1] = {
            value = tostring(gradeStr),
            label = gradeDef.label,
            grade = tonumber(gradeStr),
        }
    end

    table.sort(grades, function(a, b) return a.grade < b.grade end)
    return grades
end

-- Returns true, job if the player has a valid police job; false otherwise.
local function hasAccess(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end
    if not Config.Jobs[job.name] then return false end
    return true, job
end

-- Returns true, job if the player meets the ManageGrade threshold; false otherwise.
local function canManage(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job then return false end
    if not Config.Jobs[job.name] then return false end

    local playerGrade = tonumber(job.grade) or 0
    local manageGrade = tonumber(Config.Wardrobe.ManageGrade) or 0

    if playerGrade < manageGrade then
        Bridge.Debug(("[Wardrobe] Player %s cannot manage outfits: job %s grade %s is below ManageGrade %s (modules/wardrobe/config.lua)")
            :format(playerSource, job.name, playerGrade, manageGrade))
        return false
    end
    return true, job
end

-- Returns true if the player's grade appears in the grades array AND holds all required licenses.
local function isOutfitAllowed(playerSource, job, grades, licenses)
    -- Grade check
    if #grades > 0 then
        local gradeMatch = false
        for _, g in ipairs(grades) do
            if tonumber(g) == tonumber(job.grade) then gradeMatch = true; break end
        end
        if not gradeMatch then return false end
    end

    -- License check
    if licenses then
        for _, license in ipairs(licenses) do
            if not Bridge.Framework.checkPlayerLicense(playerSource, license) then
                return false
            end
        end
    end

    return true
end

-- ============================================================
--  Callbacks
-- ============================================================

-- Returns config the NUI needs (grades list, licenses, canManage flag, job info).
lib.callback.register("p_policejob/wardrobe/getConfig", function(playerSource)
    local ok, job = hasAccess(playerSource)
    if not ok then return nil end

    local playerGrade = tonumber(job.grade) or 0
    local manageGrade = tonumber(Config.Wardrobe.ManageGrade) or 0

    return {
        grades       = getGradeOptions(job.name),
        licenses     = Editable:getWardrobeLicenses(playerSource),
        currentJob   = job.name,
        currentGrade = job.grade,
        canManage    = playerGrade >= manageGrade,
    }
end)

-- Returns all outfits for the player's job + gender (manager view — no grade filtering).
lib.callback.register("p_policejob/wardrobe/getOutfits", function(playerSource, gender)
    local ok, job = hasAccess(playerSource)
    if not ok then return {} end

    local rows = MySQL.query.await([[
        SELECT id, name, job, grades, gender, licenses, created_by, created_at
        FROM p_policejob_outfits
        WHERE job = ? AND gender = ?
        ORDER BY name ASC
    ]], { job.name, gender })

    local outfits = {}
    for _, row in ipairs(rows or {}) do
        outfits[#outfits + 1] = {
            id         = row.id,
            name       = row.name,
            job        = row.job,
            grades     = json.decode(row.grades) or {},
            gender     = row.gender,
            licenses   = row.licenses and json.decode(row.licenses) or nil,
            createdBy  = row.created_by,
            createdAt  = row.created_at,
        }
    end
    return outfits
end)

-- Returns outfits filtered by the player's grade and licenses.
lib.callback.register("p_policejob/wardrobe/getAllowedOutfits", function(playerSource, gender)
    local ok, job = hasAccess(playerSource)
    if not ok then return {} end

    local rows = MySQL.query.await([[
        SELECT id, name, job, grades, gender, licenses, created_by, created_at
        FROM p_policejob_outfits
        WHERE job = ? AND gender = ?
        ORDER BY name ASC
    ]], { job.name, gender })

    local outfits = {}
    for _, row in ipairs(rows or {}) do
        local grades   = json.decode(row.grades)   or {}
        local licenses = row.licenses and json.decode(row.licenses) or nil

        if isOutfitAllowed(playerSource, job, grades, licenses) then
            outfits[#outfits + 1] = {
                id        = row.id,
                name      = row.name,
                job       = row.job,
                grades    = grades,
                gender    = row.gender,
                licenses  = licenses,
                createdBy = row.created_by,
                createdAt = row.created_at,
            }
        end
    end
    return outfits
end)

-- Returns the skin JSON for a specific outfit if the player is allowed to wear it.
lib.callback.register("p_policejob/wardrobe/getOutfitSkin", function(playerSource, outfitId)
    local ok, job = hasAccess(playerSource)
    if not ok then return nil end

    local row = MySQL.single.await(
        "SELECT job, grades, licenses, skin FROM p_policejob_outfits WHERE id = ?",
        { outfitId })

    if not row or row.job ~= job.name then return nil end

    local grades   = json.decode(row.grades) or {}
    local licenses = row.licenses and json.decode(row.licenses) or nil

    if not isOutfitAllowed(playerSource, job, grades, licenses) then return nil end

    return json.decode(row.skin)
end)

-- Creates a new shared outfit (managers only).
lib.callback.register("p_policejob/wardrobe/create", function(playerSource, data)
    local ok, job = canManage(playerSource)
    if not ok then return { success = false, error = "No permission" } end

    if not (data.name and data.grades and data.gender and data.skin) then
        return { success = false, error = "Missing data" }
    end

    local creatorName = Bridge.Framework.getPlayerName(playerSource) or ("Player " .. playerSource)
    local licensesJson = nil
    if data.licenses and #data.licenses > 0 then
        licensesJson = json.encode(data.licenses)
    end

    local insertId = MySQL.insert.await([[
        INSERT INTO p_policejob_outfits (name, job, grades, gender, licenses, skin, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.name,
        job.name,
        json.encode(data.grades),
        data.gender,
        licensesJson,
        json.encode(data.skin),
        creatorName,
    })

    if insertId then
        Bridge.Debug(("[Wardrobe] Player %s created outfit id=%s name=%s job=%s")
            :format(playerSource, insertId, data.name, job.name))
        Bridge.Notify.showNotify(playerSource, locale("outfit_created"), "success")

        return {
            success = true,
            outfit  = {
                id        = insertId,
                name      = data.name,
                job       = job.name,
                grades    = data.grades,
                gender    = data.gender,
                licenses  = (data.licenses and #data.licenses > 0) and data.licenses or nil,
                createdBy = creatorName,
                createdAt = os.date("%Y-%m-%d"),
            },
        }
    end

    return { success = false, error = "Database error" }
end)

-- Deletes an outfit by ID (managers only, and only outfits belonging to their own job).
lib.callback.register("p_policejob/wardrobe/delete", function(playerSource, data)
    local ok, job = canManage(playerSource)
    if not ok then return { success = false } end

    if not data.outfitId then return { success = false } end

    local row = MySQL.single.await(
        "SELECT job FROM p_policejob_outfits WHERE id = ?", { data.outfitId })

    if not row or row.job ~= job.name then return { success = false } end

    MySQL.query.await("DELETE FROM p_policejob_outfits WHERE id = ?", { data.outfitId })
    Bridge.Notify.showNotify(playerSource, locale("outfit_deleted"), "success")
    return { success = true }
end)
