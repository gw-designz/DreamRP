-- ============================================================
-- job-permissions.lua  –  bablo-billing  (server)
-- ============================================================

local JobPermissions = {}

-- ── Permission keys ───────────────────────────────────────────
JobPermissions.PERMISSIONS = {
    VIEW_RECEIVED_INVOICES  = "viewReceivedInvoices",
    DELETE_ANY_INVOICE      = "deleteAnyInvoice",
    HANDLE_ALL_SENT_INVOICES = "handleAllSentInvoices",
    CAN_SEND_TO_COMPANIES   = "canSendInvoicesToCompanies",
}

-- ── getMinGrade ───────────────────────────────────────────────
-- Returns the minimum job grade required for a permission.
-- Priority: job-specific config → defaultGrades config → 0 (no restriction).
-- A value of -1 means the permission is explicitly disabled.
function JobPermissions.getMinGrade(jobName, permissionKey)
    if not jobName or not permissionKey then return 0 end

    local jobGrades = Config.JobAccount.jobGrades and Config.JobAccount.jobGrades[jobName]

    if jobGrades then
        local grade = jobGrades[permissionKey]
        if grade ~= nil then return grade end
    end

    local defaultGrades = Config.JobAccount.defaultGrades
    if defaultGrades then
        local grade = defaultGrades[permissionKey]
        if grade ~= nil then return grade end
    end

    return 0
end

-- ── hasPermission ─────────────────────────────────────────────
-- Returns true if the player's job grade meets the minimum required for the permission.
function JobPermissions.hasPermission(jobName, jobGrade, permissionKey)
    if not jobName or jobGrade == nil then
        Debug.debug(Debug, "[hasPermission] early return - jobName:", jobName, "jobGrade:", jobGrade)
        return false
    end

    Debug.debug(Debug,
        "[hasPermission] jobName:", jobName,
        "| jobGrade type:", type(jobGrade), "value:", jobGrade,
        "| permission:", permissionKey)

    local minGrade = JobPermissions.getMinGrade(jobName, permissionKey)

    Debug.debug(Debug, "[hasPermission] minGrade type:", type(minGrade), "value:", minGrade)

    if minGrade == -1 then
        Debug.debug(Debug, "[hasPermission] permission disabled (minGrade = -1)")
        return false
    end

    local result = jobGrade >= minGrade
    Debug.debug(Debug, "[hasPermission] result:", result, "(", jobGrade, ">=", minGrade, ")")
    return result
end

-- ── isJobBlocked ─────────────────────────────────────────────
-- Returns true if jobName appears in Config.JobAccount.blockedJobs.
-- Returns true (pass-through) when no jobName is given (no restriction applies).
function JobPermissions.isJobBlocked(jobName)
    if not jobName then return true end

    local blockedJobs = Config.JobAccount.blockedJobs or {}

    if #blockedJobs == 0 then return false end

    for _, blocked in ipairs(blockedJobs) do
        if blocked == jobName then return true end
    end

    return false
end

-- ── getPlayerPermissions ──────────────────────────────────────
-- Returns a flat table of all permission keys → bool for the given job/grade.
-- All permissions default to false for blocked jobs.
function JobPermissions.getPlayerPermissions(jobName, jobGrade)
    local permissions = {
        viewReceivedInvoices      = false,
        deleteAnyInvoice          = false,
        handleAllSentInvoices     = false,
        canSendInvoicesToCompanies = false,
    }

    if JobPermissions.isJobBlocked(jobName) then
        return permissions
    end

    for _, permKey in pairs(JobPermissions.PERMISSIONS) do
        permissions[permKey] = JobPermissions.hasPermission(jobName, jobGrade, permKey)
    end

    return permissions
end

-- Expose as global (consumed by other server files)
_G.JobPermissions = JobPermissions

return JobPermissions
