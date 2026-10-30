-- npv_admin schema. Requires MySQL 5.7.8+ / MariaDB 10.2.7+ (JSON-compatible LONGTEXT is used, so any recent version works).
-- The resource also runs these statements on start (server/database.lua), so importing manually is optional.

CREATE TABLE IF NOT EXISTS `npv_admin_audit` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `staff_license` VARCHAR(60) NOT NULL,
    `staff_name` VARCHAR(80) NOT NULL,
    `action` VARCHAR(60) NOT NULL,
    `target_citizenid` VARCHAR(50) NULL,
    `target_name` VARCHAR(80) NULL,
    `outcome` VARCHAR(20) NOT NULL,
    `details` TEXT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_audit_created` (`created_at`),
    KEY `idx_audit_staff` (`staff_license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `npv_admin_notes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `citizenid` VARCHAR(50) NOT NULL,
    `kind` VARCHAR(10) NOT NULL DEFAULT 'note', -- note | warn | kick
    `staff_name` VARCHAR(80) NOT NULL,
    `text` VARCHAR(400) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_notes_cid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `npv_admin_bans` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `name` VARCHAR(80) NOT NULL,
    `license` VARCHAR(60) NOT NULL,
    `identifiers` TEXT NOT NULL,
    `reason` VARCHAR(250) NOT NULL,
    `expires` INT NULL,                       -- unix seconds, NULL = permanent
    `banned_by` VARCHAR(80) NOT NULL,
    `lifted` TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_bans_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `npv_dm_scenarios` (
    `id` VARCHAR(50) NOT NULL,
    `number` INT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE,
    `name` VARCHAR(80) NOT NULL,
    `owner_license` VARCHAR(60) NOT NULL,
    `owner_name` VARCHAR(80) NOT NULL,
    `category` VARCHAR(40) NULL,
    `status` VARCHAR(10) NOT NULL DEFAULT 'draft', -- draft | live
    `scope` VARCHAR(10) NOT NULL DEFAULT 'local',  -- local | global
    `version` INT UNSIGNED NOT NULL DEFAULT 1,
    `definition` LONGTEXT NOT NULL,                -- JSON: objects, scripts, dialogues
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_dm_owner` (`owner_license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `npv_dm_scenario_versions` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `scenario_id` VARCHAR(50) NOT NULL,
    `version` INT UNSIGNED NOT NULL,
    `definition` LONGTEXT NOT NULL,
    `saved_by` VARCHAR(80) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_dm_ver` (`scenario_id`, `version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `npv_dm_script_library` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(60) NOT NULL,
    `owner_name` VARCHAR(80) NOT NULL,
    `script` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
