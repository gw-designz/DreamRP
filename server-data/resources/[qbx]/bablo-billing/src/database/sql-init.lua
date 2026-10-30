local CREATE_INVOICES_TABLE = [[
    CREATE TABLE IF NOT EXISTS `bablo_invoices` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `uuid` VARCHAR(64) NOT NULL UNIQUE,
        `issuer_identifier` VARCHAR(64) NOT NULL,
        `issuer_display_name` VARCHAR(100) NULL,
        `recipient_identifier` VARCHAR(64) NOT NULL,
        `issuer_account_type` VARCHAR(20) NOT NULL DEFAULT 'personal',
        `issuer_job_name` VARCHAR(50) NULL,
        `recipient_account_type` VARCHAR(20) NOT NULL DEFAULT 'personal',
        `recipient_job_name` VARCHAR(50) NULL,
        `amount` DECIMAL(15,2) NOT NULL,
        `title` VARCHAR(100) NOT NULL,
        `description` TEXT,
        `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
        `created_at` BIGINT NOT NULL,
        `due_date` BIGINT NULL,
        `paid_at` BIGINT NULL
    );
]]

local CREATE_CONTACTS_TABLE = [[
    CREATE TABLE IF NOT EXISTS `billing_contacts` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `owner_identifier` VARCHAR(64) NOT NULL,
        `contact_identifier` VARCHAR(64) NOT NULL,
        `display_name` VARCHAR(100) NOT NULL,
        `created_at` BIGINT NOT NULL,
        INDEX `idx_owner` (`owner_identifier`),
        UNIQUE KEY `unique_contact` (`owner_identifier`, `contact_identifier`)
    );
]]

local CREATE_PRESETS_TABLE = [[
    CREATE TABLE IF NOT EXISTS `bablo_billing_presets` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `owner_identifier` VARCHAR(64) NOT NULL,
        `name` VARCHAR(100) NOT NULL,
        `title` VARCHAR(100) NOT NULL,
        `description` TEXT NOT NULL,
        `amount` DECIMAL(15,2) NOT NULL,
        `category` VARCHAR(50) NOT NULL DEFAULT 'custom',
        `created_at` BIGINT NOT NULL,
        `updated_at` BIGINT NOT NULL,
        INDEX `idx_owner` (`owner_identifier`),
        INDEX `idx_category` (`category`)
    );
]]

local ALTER_INVOICES_SCHEMA = [[
    ALTER TABLE `bablo_invoices`
    ADD COLUMN IF NOT EXISTS `uuid` VARCHAR(64) NOT NULL UNIQUE AFTER `id`,
    ADD COLUMN IF NOT EXISTS `issuer_display_name` VARCHAR(100) NULL AFTER `issuer_identifier`,
    ADD COLUMN IF NOT EXISTS `issuer_account_type` VARCHAR(20) NOT NULL DEFAULT 'personal' AFTER `recipient_identifier`,
    ADD COLUMN IF NOT EXISTS `issuer_job_name` VARCHAR(50) NULL AFTER `issuer_account_type`,
    ADD COLUMN IF NOT EXISTS `recipient_account_type` VARCHAR(20) NOT NULL DEFAULT 'personal' AFTER `issuer_job_name`,
    ADD COLUMN IF NOT EXISTS `recipient_job_name` VARCHAR(50) NULL AFTER `recipient_account_type`,
    ADD COLUMN IF NOT EXISTS `due_date` BIGINT NULL AFTER `created_at`,
    MODIFY COLUMN `amount` DECIMAL(15,2) NOT NULL,
    MODIFY COLUMN `created_at` BIGINT NOT NULL,
    MODIFY COLUMN `paid_at` BIGINT NULL
]]

-- ─────────────────────────────────────────────────────────────────────────────

local function tableExists(tableName)
    local result = MySQL.query.await(string.format("SHOW TABLES LIKE '%s'", tableName), {})
    if result then
        Debug.info(Debug, "Table check for", tableName, "returned", #result, "results")
        return #result > 0
    else
        Debug.error(Debug, "Failed to check if table", tableName, "exists")
        return false
    end
end

local function seedSystemPresets()
    if not DefaultSystemPresets or #DefaultSystemPresets == 0 then
        Debug.warn(Debug, "No DefaultSystemPresets data found, skipping preset seed")
        return
    end

    local countResult = MySQL.query.await("SELECT COUNT(*) AS count FROM bablo_billing_presets WHERE owner_identifier = '__SYSTEM__'", {})
    if countResult and countResult[1] and tonumber(countResult[1].count) > 0 then
        Debug.info(Debug, "System presets already present, skipping seed")
        return
    end

    local nowMs      = os.time() * 1000
    local rowPlaceholders = {}
    local params     = {}

    for _, preset in ipairs(DefaultSystemPresets) do
        table.insert(rowPlaceholders, "(?, ?, ?, ?, ?, ?, ?, ?)")
        table.insert(params, "__SYSTEM__")
        table.insert(params, preset.name)
        table.insert(params, preset.title)
        table.insert(params, preset.description)
        table.insert(params, preset.amount)
        table.insert(params, preset.category)
        table.insert(params, nowMs)
        table.insert(params, nowMs)
    end

    local query = "INSERT INTO bablo_billing_presets "
        .. "(owner_identifier, name, title, description, amount, category, created_at, updated_at) VALUES "
        .. table.concat(rowPlaceholders, ", ")

    local result = MySQL.query.await(query, params)
    if result then
        Debug.success(Debug, "Seeded " .. #DefaultSystemPresets .. " default (__SYSTEM__) billing presets")
    else
        Debug.error(Debug, "Failed to seed default billing presets")
    end
end

-- ─────────────────────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    -- bablo_invoices
    if tableExists("bablo_invoices") then
        Debug.warn(Debug, "Invoices table already exists, checking for schema updates.")
        MySQL.query(ALTER_INVOICES_SCHEMA, {}, function()
            Debug.info(Debug, "Updated invoices table schema with account type support")
        end)
    else
        MySQL.query(CREATE_INVOICES_TABLE, {}, function(result)
            Debug.info(Debug, "Creating invoices table...", result)
            if result and result.affectedRows > 0 then
                Debug.success(Debug, "Invoices table created successfully.")
            end
        end)
    end

    -- billing_contacts
    Debug.info(Debug, "Checking if billing_contacts table exists...")
    local contactsExists = tableExists("billing_contacts")
    Debug.info(Debug, "billing_contacts table exists:", contactsExists)

    if not contactsExists then
        Debug.info(Debug, "Creating billing_contacts table...")
        MySQL.query(CREATE_CONTACTS_TABLE, {}, function(result)
            Debug.info(Debug, "Creating billing_contacts table...", result)
            if result then
                Debug.success(Debug, "Billing contacts table created successfully.")
            else
                Debug.error(Debug, "Failed to create billing_contacts table")
            end
        end)
    else
        Debug.warn(Debug, "Billing contacts table already exists.")
    end

    -- bablo_billing_presets
    Debug.info(Debug, "Checking if bablo_billing_presets table exists...")
    local presetsExists = tableExists("bablo_billing_presets")
    Debug.info(Debug, "bablo_billing_presets table exists:", presetsExists)

    if not presetsExists then
        Debug.info(Debug, "Creating bablo_billing_presets table...")
        local result = MySQL.query.await(CREATE_PRESETS_TABLE, {})
        if result then
            Debug.success(Debug, "Billing presets table created successfully.")
            seedSystemPresets()
        else
            Debug.error(Debug, "Failed to create bablo_billing_presets table")
        end
    else
        Debug.warn(Debug, "Billing presets table already exists, checking for schema updates.")
        MySQL.query("ALTER TABLE `bablo_billing_presets` MODIFY COLUMN `amount` DECIMAL(15,2) NOT NULL", {}, function()
            Debug.info(Debug, "Ensured bablo_billing_presets.amount is DECIMAL(15,2)")
        end)
    end
end)
