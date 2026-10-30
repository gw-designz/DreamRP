Schema = Schema or {}

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_meta` (
        `k` VARCHAR(64) NOT NULL,
        `v` TEXT DEFAULT NULL,
        PRIMARY KEY (`k`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_players` (
        `citizenid` VARCHAR(64) NOT NULL,
        `number` VARCHAR(16) DEFAULT NULL,
        `mail` VARCHAR(160) DEFAULT NULL,
        `name` VARCHAR(64) DEFAULT NULL,
        `avatar` VARCHAR(512) DEFAULT NULL,
        `settings` LONGTEXT DEFAULT NULL,
        `home` LONGTEXT DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
        `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`),
        UNIQUE KEY `uq_number` (`number`),
        UNIQUE KEY `uq_mail` (`mail`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_contacts` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `number` VARCHAR(24) NOT NULL,
        `notes` VARCHAR(300) DEFAULT NULL,
        `img` VARCHAR(512) DEFAULT NULL,
        `favorite` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`),
        KEY `idx_lookup` (`citizenid`, `number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_recents` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `number` VARCHAR(24) DEFAULT NULL,
        `name` VARCHAR(64) DEFAULT NULL,
        `img` VARCHAR(512) DEFAULT NULL,
        `direction` VARCHAR(4) NOT NULL DEFAULT 'in',
        `missed` TINYINT(1) NOT NULL DEFAULT 0,
        `video` TINYINT(1) NOT NULL DEFAULT 0,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_blocked` (
        `citizenid` VARCHAR(64) NOT NULL,
        `number` VARCHAR(24) NOT NULL,
        `label` VARCHAR(64) DEFAULT NULL,
        `name` VARCHAR(64) DEFAULT NULL,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`, `number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_messages` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `thread` VARCHAR(24) NOT NULL,
        `msg_id` VARCHAR(32) DEFAULT NULL,
        `direction` VARCHAR(4) NOT NULL DEFAULT 'in',
        `type` VARCHAR(16) NOT NULL DEFAULT 'text',
        `body` TEXT DEFAULT NULL,
        `meta` LONGTEXT DEFAULT NULL,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        `is_read` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_thread` (`citizenid`, `thread`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_mail` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `folder` VARCHAR(8) NOT NULL DEFAULT 'inbox',
        `addr` VARCHAR(160) DEFAULT NULL,
        `addr_name` VARCHAR(64) DEFAULT NULL,
        `subject` VARCHAR(160) DEFAULT NULL,
        `body` TEXT DEFAULT NULL,
        `attachments` LONGTEXT DEFAULT NULL,
        `is_system` TINYINT(1) NOT NULL DEFAULT 0,
        `is_read` TINYINT(1) NOT NULL DEFAULT 0,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_folder` (`citizenid`, `folder`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_photos` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `url` VARCHAR(512) NOT NULL,
        `type` VARCHAR(8) NOT NULL DEFAULT 'image',
        `thumb` VARCHAR(512) DEFAULT NULL,
        `duration` INT UNSIGNED DEFAULT NULL,
        `favorite` TINYINT(1) NOT NULL DEFAULT 0,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_notifications` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `app` VARCHAR(32) NOT NULL DEFAULT 'system',
        `title` VARCHAR(160) DEFAULT NULL,
        `body` TEXT DEFAULT NULL,
        `icon` VARCHAR(512) DEFAULT NULL,
        `route` LONGTEXT DEFAULT NULL,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        `is_read` TINYINT(1) NOT NULL DEFAULT 0,
        `queued` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_calc` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `expr` VARCHAR(140) NOT NULL,
        `value` DOUBLE NOT NULL DEFAULT 0,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_blips` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `label` VARCHAR(64) NOT NULL,
        `x` DOUBLE NOT NULL DEFAULT 0,
        `y` DOUBLE NOT NULL DEFAULT 0,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_ringtones` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `url` VARCHAR(512) NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_alarms` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `hour` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `minute` TINYINT UNSIGNED NOT NULL DEFAULT 0,
        `label` VARCHAR(64) DEFAULT NULL,
        `enabled` TINYINT(1) NOT NULL DEFAULT 1,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_alarm_tones` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `url` VARCHAR(512) NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_clock` (
        `citizenid` VARCHAR(64) NOT NULL,
        `alarm_ringtone` VARCHAR(512) DEFAULT NULL,
        `timer_ends_at` INT UNSIGNED DEFAULT NULL,
        `timer_total` INT UNSIGNED DEFAULT NULL,
        `timer_remaining` INT UNSIGNED DEFAULT NULL,
        `timer_paused` TINYINT(1) NOT NULL DEFAULT 0,
        `timer_label` VARCHAR(64) DEFAULT NULL,
        `timer_from_recent` TINYINT(1) NOT NULL DEFAULT 0,
        `timer_active` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_timer_recents` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `h` INT UNSIGNED NOT NULL DEFAULT 0,
        `m` INT UNSIGNED NOT NULL DEFAULT 0,
        `s` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_transactions` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `kind` VARCHAR(16) NOT NULL DEFAULT 'sent',
        `amount` BIGINT NOT NULL DEFAULT 0,
        `party` VARCHAR(64) DEFAULT NULL,
        `number` VARCHAR(24) DEFAULT NULL,
        `note` VARCHAR(120) DEFAULT NULL,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_airdrops` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(64) NOT NULL,
        `payload` LONGTEXT NOT NULL,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_owner` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_groups` (
        `gid` VARCHAR(32) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `photo` VARCHAR(512) DEFAULT NULL,
        `owner` VARCHAR(24) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`gid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_group_members` (
        `gid` VARCHAR(32) NOT NULL,
        `number` VARCHAR(24) NOT NULL,
        `name` VARCHAR(64) DEFAULT NULL,
        `joined_at` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`gid`, `number`),
        KEY `idx_number` (`number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_group_messages` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `gid` VARCHAR(32) NOT NULL,
        `from_number` VARCHAR(24) DEFAULT NULL,
        `type` VARCHAR(16) NOT NULL DEFAULT 'text',
        `body` TEXT DEFAULT NULL,
        `meta` LONGTEXT DEFAULT NULL,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_group` (`gid`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_group_reactions` (
        `msg_id` INT UNSIGNED NOT NULL,
        `number` VARCHAR(24) NOT NULL,
        `emoji` VARCHAR(32) NOT NULL,
        PRIMARY KEY (`msg_id`, `number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_group_reads` (
        `gid` VARCHAR(32) NOT NULL,
        `number` VARCHAR(24) NOT NULL,
        `last_id` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`gid`, `number`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_accounts` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `handle` VARCHAR(32) NOT NULL,
        `name` VARCHAR(64) DEFAULT NULL,
        `email` VARCHAR(160) DEFAULT NULL,
        `pass_salt` VARCHAR(32) DEFAULT NULL,
        `pass_hash` VARCHAR(64) DEFAULT NULL,
        `bio` VARCHAR(400) DEFAULT NULL,
        `avatar` VARCHAR(512) DEFAULT NULL,
        `banner` VARCHAR(512) DEFAULT NULL,
        `badge` VARCHAR(8) DEFAULT NULL,
        `last_cid` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uq_handle` (`handle`),
        KEY `idx_email` (`email`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_follows` (
        `follower_id` INT UNSIGNED NOT NULL,
        `target_id` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`follower_id`, `target_id`),
        KEY `idx_target` (`target_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_posts` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `author` INT UNSIGNED NOT NULL,
        `text` VARCHAR(800) DEFAULT NULL,
        `media` LONGTEXT DEFAULT NULL,
        `parent_id` INT UNSIGNED DEFAULT NULL,
        `root_id` INT UNSIGNED DEFAULT NULL,
        `reply_count` INT UNSIGNED NOT NULL DEFAULT 0,
        `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_author` (`author`),
        KEY `idx_parent` (`parent_id`),
        KEY `idx_created` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_likes` (
        `post_id` INT UNSIGNED NOT NULL,
        `account_id` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`post_id`, `account_id`),
        KEY `idx_account` (`account_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_reposts` (
        `post_id` INT UNSIGNED NOT NULL,
        `account_id` INT UNSIGNED NOT NULL,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`post_id`, `account_id`),
        KEY `idx_account` (`account_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_notifs` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `account_id` INT UNSIGNED NOT NULL,
        `type` VARCHAR(16) NOT NULL,
        `actor` INT UNSIGNED DEFAULT NULL,
        `post_id` INT UNSIGNED DEFAULT NULL,
        `is_read` TINYINT(1) NOT NULL DEFAULT 0,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_account` (`account_id`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_link` (
        `citizenid` VARCHAR(64) NOT NULL,
        `account_id` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`citizenid`),
        KEY `idx_account` (`account_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    -- Socials: bookmarks (private saves) and unique post viewers.
    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_bookmarks` (
        `account_id` INT UNSIGNED NOT NULL,
        `post_id` INT UNSIGNED NOT NULL,
        `ts` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`account_id`, `post_id`),
        KEY `idx_post` (`post_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_mutes` (
        `account_id` INT UNSIGNED NOT NULL,
        `target_id` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`account_id`, `target_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_blocks` (
        `account_id` INT UNSIGNED NOT NULL,
        `target_id` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`account_id`, `target_id`),
        KEY `idx_target` (`target_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_views` (
        `post_id` INT UNSIGNED NOT NULL,
        `account_id` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`post_id`, `account_id`),
        KEY `idx_account` (`account_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `oph3z_phone_listings` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `seller_cid` VARCHAR(64) NOT NULL,
        `category` VARCHAR(16) NOT NULL DEFAULT 'other',
        `title` VARCHAR(100) NOT NULL,
        `description` VARCHAR(1400) DEFAULT NULL,
        `price` BIGINT NOT NULL DEFAULT 0,
        `media` LONGTEXT DEFAULT NULL,
        `seller` LONGTEXT DEFAULT NULL,
        `allow_calls` TINYINT(1) NOT NULL DEFAULT 0,
        `allow_msg` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
        `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_seller` (`seller_cid`),
        KEY `idx_category` (`category`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

-- Tables added by feature modules (server/app/**) via Schema.Register before start-up.
Schema.Extra = Schema.Extra or {}
-- Columns added to existing tables: { table, column, definition }.
Schema.Columns = Schema.Columns or {
    { 'oph3z_phone_photos', 'place', 'VARCHAR(64) DEFAULT NULL' },
}

function Schema.Register(statement)
    Schema.Extra[#Schema.Extra + 1] = statement
    -- registered after start-up (module loaded late): create it right away
    if Sql.ready then Sql.Execute(statement) end
end

function Schema.AddColumn(tbl, column, definition)
    Schema.Columns[#Schema.Columns + 1] = { tbl, column, definition }
end

local function ensureColumns()
    for _, c in ipairs(Schema.Columns) do
        local n = Sql.Scalar(
            'SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
            { c[1], c[2] }
        )
        if (tonumber(n) or 0) == 0 then
            Sql.Execute(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(c[1], c[2], c[3]))
        end
    end
end

function Schema.Create()
    for _, statement in ipairs(TABLES) do
        Sql.Execute(statement)
    end
    for _, statement in ipairs(Schema.Extra) do
        Sql.Execute(statement)
    end
    ensureColumns()
end

function Schema.GetMeta(key)
    local row = Sql.Single('SELECT `v` FROM `oph3z_phone_meta` WHERE `k` = ?', { key })
    return row and row.v or nil
end

function Schema.SetMeta(key, value)
    Sql.Execute(
        'INSERT INTO `oph3z_phone_meta` (`k`, `v`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `v` = VALUES(`v`)',
        { key, tostring(value) }
    )
end

CreateThread(function()
    Wait(500)

    local ok = pcall(Schema.Create)
    if not ok then
        print('^1[oph3z-phone] could not create the database tables. Check that ' ..
            tostring(Config.MySQL) .. ' is running and that the phone is started after it.^0')
        return
    end

    if Migrate and Migrate.Run then
        pcall(Migrate.Run)
    end

    Sql.ready = true

    if Config.Debug then
        print('^2[oph3z-phone] database ready (' .. tostring(Config.MySQL) .. ').^0')
    end
end)