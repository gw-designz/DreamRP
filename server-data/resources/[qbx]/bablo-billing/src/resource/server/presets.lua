-- ============================================================
-- presets.lua  –  bablo-billing  (server)
-- ============================================================

local MySQL = rawget(_G, "MySQL") or exports.oxmysql

-- ── Shared validators ─────────────────────────────────────────

-- Validates a string field against min/max length rules.
-- Returns nil on pass, or an error message string on failure.
local function validateLength(value, fieldLabel, minLen, maxLen)
    if #value > maxLen then
        return fieldLabel .. " too long (max " .. maxLen .. " characters)"
    end
    if minLen and #value < minLen then
        return fieldLabel .. " must be at least " .. minLen .. " characters"
    end
    return nil
end

-- ── getPresets ────────────────────────────────────────────────
-- Returns all presets owned by ownerIdentifier plus any system defaults,
-- with system presets listed first, then alphabetically by name.
function getPresets(ownerIdentifier)
    if not ownerIdentifier then
        Debug.error(Debug, "No identifier provided to getPresets")
        return nil
    end

    local rows = MySQL.query.await([[
        SELECT
            id,
            name,
            title,
            description,
            amount,
            category,
            created_at,
            updated_at,
            (owner_identifier = '__SYSTEM__') AS is_default
        FROM bablo_billing_presets
        WHERE owner_identifier = ? OR owner_identifier = '__SYSTEM__'
        ORDER BY is_default DESC, name ASC
    ]], { ownerIdentifier })

    if not rows then
        Debug.info(Debug, "No presets found for identifier", ownerIdentifier)
        return {}
    end

    Debug.info(Debug, "Found", #rows, "presets for identifier", ownerIdentifier)
    return rows
end

-- ── createPreset ──────────────────────────────────────────────
-- Creates a new preset for ownerIdentifier.
-- Returns: true, nil, insertId  on success
--          false, errorMessage  on failure
function createPreset(ownerIdentifier, presetData)
    if not ownerIdentifier then
        Debug.error(Debug, "Missing owner identifier for createPreset")
        return false, "Missing owner identifier"
    end

    if not presetData or not presetData.name or not presetData.title or not presetData.description then
        Debug.error(Debug, "Missing required preset data")
        return false, "Missing required preset data (name, title, description)"
    end

    local amount = tonumber(presetData.amount)
    if not amount or amount <= 0 then
        Debug.warn(Debug, "Invalid preset amount", presetData.amount)
        return false, "Amount must be a positive number"
    end

    local nameErr = validateLength(presetData.name, "Preset name", 2, 100)
    if nameErr then
        Debug.warn(Debug, "Preset name too long/short", presetData.name)
        return false, nameErr
    end

    local titleErr = validateLength(presetData.title, "Preset title", nil, 100)
    if titleErr then
        Debug.warn(Debug, "Preset title too long", presetData.title)
        return false, titleErr
    end

    local category = presetData.category or "custom"
    if #category < 1 or #category > 50 then
        Debug.warn(Debug, "Invalid preset category", category)
        return false, "Category must be between 1 and 50 characters"
    end

    local now = os.time() * 1000

    local result = MySQL.query.await([[
        INSERT INTO bablo_billing_presets (owner_identifier, name, title, description, amount, category, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { ownerIdentifier, presetData.name, presetData.title, presetData.description, amount, category, now, now })

    if result and result.affectedRows > 0 then
        Debug.success(Debug, "Preset created successfully", presetData.name)
        return true, nil, result.insertId
    else
        Debug.error(Debug, "Failed to create preset", presetData.name)
        return false, "Database error"
    end
end

-- ── updatePreset ──────────────────────────────────────────────
-- Partially updates a preset (only supplied fields are changed via COALESCE).
-- Returns: true on success, or false + errorMessage on failure.
function updatePreset(ownerIdentifier, presetId, presetData)
    if not ownerIdentifier or not presetId then
        Debug.error(Debug, "Missing parameters for updatePreset")
        return false, "Missing required parameters"
    end

    if not presetData then
        Debug.error(Debug, "Missing preset data for updatePreset")
        return false, "Missing preset data"
    end

    -- Validate optional fields only when provided
    if presetData.name then
        local err = validateLength(presetData.name, "Preset name", 2, 100)
        if err then
            Debug.warn(Debug, "Preset name too long/short", presetData.name)
            return false, err
        end
    end

    if presetData.title then
        local err = validateLength(presetData.title, "Preset title", nil, 100)
        if err then
            Debug.warn(Debug, "Preset title too long", presetData.title)
            return false, err
        end
    end

    local amount = nil
    if presetData.amount then
        amount = tonumber(presetData.amount)
        if not amount or amount <= 0 then
            Debug.warn(Debug, "Invalid preset amount", presetData.amount)
            return false, "Amount must be a positive number"
        end
    end

    if presetData.category then
        if #presetData.category < 1 or #presetData.category > 50 then
            Debug.warn(Debug, "Invalid preset category", presetData.category)
            return false, "Category must be between 1 and 50 characters"
        end
    end

    local result = MySQL.query.await([[
        UPDATE bablo_billing_presets
        SET name        = COALESCE(?, name),
            title       = COALESCE(?, title),
            description = COALESCE(?, description),
            amount      = COALESCE(?, amount),
            category    = COALESCE(?, category),
            updated_at  = ?
        WHERE id = ? AND owner_identifier = ?
    ]], {
        presetData.name,
        presetData.title,
        presetData.description,
        amount,
        presetData.category,
        os.time() * 1000,
        presetId,
        ownerIdentifier,
    })

    if result and result.affectedRows > 0 then
        Debug.success(Debug, "Preset updated successfully", presetId)
        return true
    else
        Debug.error(Debug, "Failed to update preset", presetId)
        return false, "Preset not found or no changes made"
    end
end

-- ── deletePreset ──────────────────────────────────────────────
-- Deletes a preset by ID, scoped to ownerIdentifier.
-- Returns: true on success, or false + errorMessage on failure.
function deletePreset(ownerIdentifier, presetId)
    if not ownerIdentifier or not presetId then
        Debug.error(Debug, "Missing parameters for deletePreset")
        return false, "Missing required parameters"
    end

    local result = MySQL.query.await([[
        DELETE FROM bablo_billing_presets
        WHERE id = ? AND owner_identifier = ?
    ]], { presetId, ownerIdentifier })

    if result and result.affectedRows > 0 then
        Debug.success(Debug, "Preset deleted successfully", presetId)
        return true
    else
        Debug.error(Debug, "Failed to delete preset", presetId)
        return false, "Preset not found"
    end
end

-- ── getPresetById ─────────────────────────────────────────────
-- Returns a single preset row by ID scoped to ownerIdentifier, or nil.
function getPresetById(ownerIdentifier, presetId)
    if not ownerIdentifier or not presetId then
        Debug.error(Debug, "Missing parameters for getPresetById")
        return nil
    end

    local rows = MySQL.query.await([[
        SELECT
            id,
            name,
            title,
            description,
            amount,
            category,
            created_at,
            updated_at
        FROM bablo_billing_presets
        WHERE id = ? AND owner_identifier = ?
    ]], { presetId, ownerIdentifier })

    if rows and #rows > 0 then
        return rows[1]
    end

    return nil
end
