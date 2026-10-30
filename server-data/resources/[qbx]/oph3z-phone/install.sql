CREATE TABLE IF NOT EXISTS `oph3z_phone_meta` (
    `k` VARCHAR(64) NOT NULL,
    `v` TEXT DEFAULT NULL,
    PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_players` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_contacts` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_recents` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_blocked` (
    `citizenid` VARCHAR(64) NOT NULL,
    `number` VARCHAR(24) NOT NULL,
    `label` VARCHAR(64) DEFAULT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_messages` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_mail` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_photos` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_notifications` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_calc` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `expr` VARCHAR(140) NOT NULL,
    `value` DOUBLE NOT NULL DEFAULT 0,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`citizenid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_blips` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `label` VARCHAR(64) NOT NULL,
    `x` DOUBLE NOT NULL DEFAULT 0,
    `y` DOUBLE NOT NULL DEFAULT 0,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_ringtones` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `url` VARCHAR(512) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_alarms` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `hour` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `minute` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `label` VARCHAR(64) DEFAULT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_alarm_tones` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `url` VARCHAR(512) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_clock` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_timer_recents` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `h` INT UNSIGNED NOT NULL DEFAULT 0,
    `m` INT UNSIGNED NOT NULL DEFAULT 0,
    `s` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`citizenid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_transactions` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_airdrops` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `payload` LONGTEXT NOT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_groups` (
    `gid` VARCHAR(32) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `photo` VARCHAR(512) DEFAULT NULL,
    `owner` VARCHAR(24) DEFAULT NULL,
    `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`gid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_group_members` (
    `gid` VARCHAR(32) NOT NULL,
    `number` VARCHAR(24) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `joined_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`gid`, `number`),
    KEY `idx_number` (`number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_group_messages` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `gid` VARCHAR(32) NOT NULL,
    `from_number` VARCHAR(24) DEFAULT NULL,
    `type` VARCHAR(16) NOT NULL DEFAULT 'text',
    `body` TEXT DEFAULT NULL,
    `meta` LONGTEXT DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_group` (`gid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_group_reactions` (
    `msg_id` INT UNSIGNED NOT NULL,
    `number` VARCHAR(24) NOT NULL,
    `emoji` VARCHAR(32) NOT NULL,
    PRIMARY KEY (`msg_id`, `number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_group_reads` (
    `gid` VARCHAR(32) NOT NULL,
    `number` VARCHAR(24) NOT NULL,
    `last_id` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`gid`, `number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_accounts` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_follows` (
    `follower_id` INT UNSIGNED NOT NULL,
    `target_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`follower_id`, `target_id`),
    KEY `idx_target` (`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_posts` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_likes` (
    `post_id` INT UNSIGNED NOT NULL,
    `account_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`post_id`, `account_id`),
    KEY `idx_account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_reposts` (
    `post_id` INT UNSIGNED NOT NULL,
    `account_id` INT UNSIGNED NOT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`post_id`, `account_id`),
    KEY `idx_account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_notifs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id` INT UNSIGNED NOT NULL,
    `type` VARCHAR(16) NOT NULL,
    `actor` INT UNSIGNED DEFAULT NULL,
    `post_id` INT UNSIGNED DEFAULT NULL,
    `is_read` TINYINT(1) NOT NULL DEFAULT 0,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_account` (`account_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_link` (
    `citizenid` VARCHAR(64) NOT NULL,
    `account_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`citizenid`),
    KEY `idx_account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Socials (NoPixel UI): private bookmarks and unique post viewers
CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_bookmarks` (
    `account_id` INT UNSIGNED NOT NULL,
    `post_id` INT UNSIGNED NOT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`account_id`, `post_id`),
    KEY `idx_post` (`post_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_views` (
    `post_id` INT UNSIGNED NOT NULL,
    `account_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`post_id`, `account_id`),
    KEY `idx_account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_listings` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================================
-- NoPixel-style apps (created automatically on start; listed here for manual installs)
-- ============================================================================

-- server/app/business/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_business` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code` VARCHAR(40) NOT NULL,
    `name` VARCHAR(40) NOT NULL,
    `description` VARCHAR(120) DEFAULT NULL,
    `owner_cid` VARCHAR(64) NOT NULL,
    `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_code` (`code`),
    KEY `idx_owner` (`owner_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_business_members` (
    `business_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `role` VARCHAR(16) NOT NULL DEFAULT 'employee',
    `hired_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`business_id`, `cid`),
    KEY `idx_cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_business_invites` (
    `business_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `invited_by` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`business_id`, `cid`),
    KEY `idx_cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_business_posts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `business_id` INT UNSIGNED NOT NULL,
    `author` VARCHAR(64) DEFAULT NULL,
    `text` VARCHAR(400) NOT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_business` (`business_id`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- server/app/crypto/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_crypto_prices` (
    `coin` VARCHAR(16) NOT NULL,
    `price` DOUBLE NOT NULL DEFAULT 0,
    `history` TEXT DEFAULT NULL,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`coin`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_crypto` (
    `cid` VARCHAR(64) NOT NULL,
    `coin` VARCHAR(16) NOT NULL,
    `amount` DOUBLE NOT NULL DEFAULT 0,
    PRIMARY KEY (`cid`, `coin`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_crypto_tx` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `cid` VARCHAR(64) NOT NULL,
    `coin` VARCHAR(16) NOT NULL,
    `kind` VARCHAR(12) NOT NULL,
    `amount` DOUBLE NOT NULL DEFAULT 0,
    `usd` INT NOT NULL DEFAULT 0,
    `party` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_cid` (`cid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- server/app/calendar/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_calendar` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `cid` VARCHAR(64) NOT NULL,
    `owner_name` VARCHAR(64) DEFAULT NULL,
    `title` VARCHAR(60) NOT NULL,
    `note` VARCHAR(300) DEFAULT NULL,
    `day` CHAR(10) NOT NULL,
    `time` CHAR(5) DEFAULT NULL,
    `shared` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_owner_day` (`cid`, `day`),
    KEY `idx_shared_day` (`shared`, `day`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- server/app/government/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_gov_posts` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `region` VARCHAR(24) NOT NULL,
    `section` VARCHAR(24) NOT NULL,
    `title` VARCHAR(80) NOT NULL,
    `body` TEXT DEFAULT NULL,
    `author` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_section` (`region`, `section`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_gov_ballots` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `region` VARCHAR(24) NOT NULL,
    `title` VARCHAR(80) NOT NULL,
    `description` TEXT DEFAULT NULL,
    `options` TEXT NOT NULL,
    `closes_at` INT UNSIGNED NOT NULL DEFAULT 0,
    `author` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_region` (`region`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_gov_votes` (
    `ballot_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `choice` TINYINT UNSIGNED NOT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`ballot_id`, `cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- server/app/news/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_news` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category` VARCHAR(24) NOT NULL,
    `headline` VARCHAR(120) NOT NULL,
    `image` VARCHAR(512) DEFAULT NULL,
    `body` TEXT DEFAULT NULL,
    `author` VARCHAR(64) DEFAULT NULL,
    `author_cid` VARCHAR(64) DEFAULT NULL,
    `breaking` TINYINT(1) NOT NULL DEFAULT 0,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_category` (`category`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- server/app/events/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_events` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `title` VARCHAR(60) NOT NULL,
    `description` VARCHAR(400) DEFAULT NULL,
    `location` VARCHAR(64) DEFAULT NULL,
    `x` DOUBLE DEFAULT NULL,
    `y` DOUBLE DEFAULT NULL,
    `starts_at` INT UNSIGNED NOT NULL DEFAULT 0,
    `status` VARCHAR(12) NOT NULL DEFAULT 'voting',
    `creator_cid` VARCHAR(64) NOT NULL,
    `creator_name` VARCHAR(64) DEFAULT NULL,
    `created_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_status` (`status`, `starts_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_event_members` (
    `event_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`event_id`, `cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_event_votes` (
    `event_id` INT UNSIGNED NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    PRIMARY KEY (`event_id`, `cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- server/app/property/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_property_owners` (
    `property_id` VARCHAR(48) NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `price` INT UNSIGNED NOT NULL DEFAULT 0,
    `bought_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`property_id`),
    KEY `idx_cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_property_keys` (
    `property_id` VARCHAR(48) NOT NULL,
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`property_id`, `cid`),
    KEY `idx_cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- server/app/guber/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_guber_drivers` (
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) DEFAULT NULL,
    `rides` INT UNSIGNED NOT NULL DEFAULT 0,
    `rating_sum` INT UNSIGNED NOT NULL DEFAULT 0,
    `rating_count` INT UNSIGNED NOT NULL DEFAULT 0,
    `earned` BIGINT NOT NULL DEFAULT 0,
    `joined_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_guber_rides` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `driver_cid` VARCHAR(64) DEFAULT NULL,
    `driver_name` VARCHAR(64) DEFAULT NULL,
    `customer_cid` VARCHAR(64) NOT NULL,
    `customer_name` VARCHAR(64) DEFAULT NULL,
    `pickup` VARCHAR(64) DEFAULT NULL,
    `dropoff` VARCHAR(64) DEFAULT NULL,
    `fare` INT UNSIGNED NOT NULL DEFAULT 0,
    `paid` TINYINT(1) NOT NULL DEFAULT 0,
    `stars` TINYINT UNSIGNED DEFAULT NULL,
    `comment` VARCHAR(160) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_driver` (`driver_cid`, `id`),
    KEY `idx_customer` (`customer_cid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- server/app/misc/main.lua
CREATE TABLE IF NOT EXISTS `oph3z_phone_np_roach` (
    `cid` VARCHAR(64) NOT NULL,
    `bookmarks` TEXT DEFAULT NULL,
    `notes` TEXT DEFAULT NULL,
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_roach_sites` (
    `address` VARCHAR(64) NOT NULL,
    `host` VARCHAR(40) NOT NULL,
    `owner` VARCHAR(64) NOT NULL,
    `owner_name` VARCHAR(64) DEFAULT NULL,
    `title` VARCHAR(40) NOT NULL,
    `body` TEXT DEFAULT NULL,
    `hints` TEXT DEFAULT NULL,
    `created_at` INT NOT NULL DEFAULT 0,
    `updated_at` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`address`),
    KEY `host` (`host`),
    KEY `owner` (`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_np_greybook` (
    `cid` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `title` VARCHAR(48) DEFAULT NULL,
    `bio` VARCHAR(300) DEFAULT NULL,
    `show_number` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`cid`),
    KEY `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_mutes` (
    `account_id` INT UNSIGNED NOT NULL,
    `target_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`account_id`, `target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `oph3z_phone_twexa_blocks` (
    `account_id` INT UNSIGNED NOT NULL,
    `target_id` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`account_id`, `target_id`),
    KEY `idx_target` (`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Gallery > Places (skip if the column already exists)
ALTER TABLE `oph3z_phone_photos` ADD COLUMN `place` VARCHAR(64) DEFAULT NULL;
