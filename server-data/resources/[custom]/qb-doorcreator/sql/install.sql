-- qb-doorcreator/sql/install.sql
--
-- This file is provided for reference / manual import. In normal
-- operation you do NOT need to run this by hand — server/db.lua runs
-- the same CREATE TABLE IF NOT EXISTS statement automatically via
-- oxmysql on resource start, so the resource "just works" on a fresh
-- database with no config edits or restarts. Kept here so it's easy
-- to inspect the schema, import into a GUI tool, or add to a wider
-- server install script.

CREATE TABLE IF NOT EXISTS `doorlocks` (
    `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `label`       VARCHAR(100) NOT NULL DEFAULT 'Unnamed Door',

    -- Native GTA door system object id, filled in at runtime by
    -- AddDoorToSystem on EACH resource start (it is NOT persisted
    -- across restarts by the game itself — the native call always
    -- happens fresh; door_hash is the hash hashed from a stable
    -- string key we generate so the same DB row maps to the same
    -- door-system key every time. See client/main.lua RegisterDoor()).
    `door_hash`   VARCHAR(64)  NOT NULL,

    `model`       BIGINT NOT NULL,             -- object model hash (joaat)
    `coords`      JSON NOT NULL,               -- {x, y, z, heading}

    `locked`      TINYINT(1) NOT NULL DEFAULT 1,

    `group_id`    VARCHAR(64) NULL DEFAULT NULL,

    `access`      JSON NOT NULL,               -- full access rule object, see shared/doorgroups.lua header
    `dependencies` JSON NOT NULL DEFAULT ('[]'), -- array of {type, id, requiredState}

    `auto_close`  INT UNSIGNED NULL DEFAULT NULL, -- seconds, 0/NULL = never

    `fallback`    TINYINT(1) NOT NULL DEFAULT 0,  -- 1 = non-native prop, use freeze/heading toggle instead of door system

    `created_by`  VARCHAR(64) NOT NULL,        -- citizenid of the creating staff member
    `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_door_hash` (`door_hash`),
    KEY `idx_group_id` (`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
