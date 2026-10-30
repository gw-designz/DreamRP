-- ============================================================
-- contacts.lua  –  bablo-billing  (server)
-- ============================================================

-- Prefer the global MySQL export (oxmysql attaches itself as MySQL);
-- fall back to the oxmysql export table if the global isn't present.
local MySQL = rawget(_G, "MySQL") or exports.oxmysql

-- ── getContacts ───────────────────────────────────────────────
-- Returns all contacts owned by the given identifier, ordered by display name.
function getContacts(ownerIdentifier)
    if not ownerIdentifier then
        Debug.error(Debug, "No identifier provided to getContacts")
        return nil
    end

    local rows = MySQL.query.await([[
        SELECT
            id,
            contact_identifier,
            display_name,
            created_at
        FROM billing_contacts
        WHERE owner_identifier = ?
        ORDER BY display_name ASC
    ]], { ownerIdentifier })

    if not rows then
        Debug.info(Debug, "No contacts found for identifier", ownerIdentifier)
        return {}
    end

    Debug.info(Debug, "Found", #rows, "contacts for identifier", ownerIdentifier)
    return rows
end

-- ── addContact ────────────────────────────────────────────────
-- Adds a new contact for ownerIdentifier.
-- Returns: true on success, or false + errorMessage on failure.
function addContact(ownerIdentifier, contactIdentifier, displayName)
    if not ownerIdentifier or not contactIdentifier or not displayName then
        Debug.error(Debug, "Missing parameters for addContact")
        return false, "Missing required parameters"
    end

    if #contactIdentifier > 64 then
        Debug.warn(Debug, "Contact identifier too long", contactIdentifier)
        return false, "Contact identifier too long (max 64 characters)"
    end

    if #displayName > 100 then
        Debug.warn(Debug, "Display name too long", displayName)
        return false, "Display name too long (max 100 characters)"
    end

    if #displayName < 2 then
        Debug.warn(Debug, "Display name too short", displayName)
        return false, "Display name must be at least 2 characters"
    end

    -- Accept identifiers in "type:value" format (e.g. "license:abc123") or plain alphanumeric
    local validFormat = string.match(contactIdentifier, "^[%w_%-]+:[%w_%-]+$")
                     or string.match(contactIdentifier, "^[%w]+$")

    if not validFormat or #contactIdentifier < 3 then
        Debug.warn(Debug, "Invalid identifier format", contactIdentifier)
        return false, "Invalid identifier format"
    end

    -- Duplicate check
    local existing = MySQL.query.await([[
        SELECT id FROM billing_contacts
        WHERE owner_identifier = ? AND contact_identifier = ?
    ]], { ownerIdentifier, contactIdentifier })

    if existing and #existing > 0 then
        Debug.warn(Debug, "Contact already exists", contactIdentifier)
        return false, "Contact already exists"
    end

    local result = MySQL.query.await([[
        INSERT INTO billing_contacts (owner_identifier, contact_identifier, display_name, created_at)
        VALUES (?, ?, ?, ?)
    ]], { ownerIdentifier, contactIdentifier, displayName, os.time() * 1000 })

    if result and result.affectedRows > 0 then
        Debug.success(Debug, "Contact added successfully", contactIdentifier, "as", displayName)
        return true
    else
        Debug.error(Debug, "Failed to add contact", contactIdentifier)
        return false, "Database error"
    end
end

-- ── updateContact ─────────────────────────────────────────────
-- Updates the display name of an existing contact by ID.
-- Returns: true on success, or false + errorMessage on failure.
function updateContact(ownerIdentifier, contactId, displayName)
    if not ownerIdentifier or not contactId or not displayName then
        Debug.error(Debug, "Missing parameters for updateContact")
        return false, "Missing required parameters"
    end

    if #displayName > 100 then
        Debug.warn(Debug, "Display name too long", displayName)
        return false, "Display name too long (max 100 characters)"
    end

    if #displayName < 2 then
        Debug.warn(Debug, "Display name too short", displayName)
        return false, "Display name must be at least 2 characters"
    end

    local result = MySQL.query.await([[
        UPDATE billing_contacts
        SET display_name = ?
        WHERE id = ? AND owner_identifier = ?
    ]], { displayName, contactId, ownerIdentifier })

    if result and result.affectedRows > 0 then
        Debug.success(Debug, "Contact updated successfully", contactId)
        return true
    else
        Debug.error(Debug, "Failed to update contact", contactId)
        return false, "Contact not found or no changes made"
    end
end

-- ── deleteContact ─────────────────────────────────────────────
-- Deletes a contact by ID, scoped to ownerIdentifier for safety.
-- Returns: true on success, or false + errorMessage on failure.
function deleteContact(ownerIdentifier, contactId)
    if not ownerIdentifier or not contactId then
        Debug.error(Debug, "Missing parameters for deleteContact")
        return false, "Missing required parameters"
    end

    local result = MySQL.query.await([[
        DELETE FROM billing_contacts
        WHERE id = ? AND owner_identifier = ?
    ]], { contactId, ownerIdentifier })

    if result and result.affectedRows > 0 then
        Debug.success(Debug, "Contact deleted successfully", contactId)
        return true
    else
        Debug.error(Debug, "Failed to delete contact", contactId)
        return false, "Contact not found"
    end
end

-- ── getContactByIdentifier ────────────────────────────────────
-- Returns a single contact row matching owner + contactIdentifier, or nil.
function getContactByIdentifier(ownerIdentifier, contactIdentifier)
    if not ownerIdentifier or not contactIdentifier then
        Debug.error(Debug, "Missing parameters for getContactByIdentifier")
        return nil
    end

    local rows = MySQL.query.await([[
        SELECT
            id,
            contact_identifier,
            display_name,
            created_at
        FROM billing_contacts
        WHERE owner_identifier = ? AND contact_identifier = ?
    ]], { ownerIdentifier, contactIdentifier })

    if rows and #rows > 0 then
        return rows[1]
    end

    return nil
end
