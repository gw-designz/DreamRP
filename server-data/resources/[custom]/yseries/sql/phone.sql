-- DO NOT SEED THE SQL MANUALLY.
-- DO NOT SEED THE SQL MANUALLY.
-- DO NOT SEED THE SQL MANUALLY.
-- DO NOT SEED THE SQL MANUALLY.
-- DO NOT SEED THE SQL MANUALLY.
-- DO NOT SEED THE SQL MANUALLY.
-- THE SQL WILL BE SEEDED AUTOMATICALLY WHEN THE SCRIPT STARTS FIRST TIME.
-- THE SQL WILL BE SEEDED AUTOMATICALLY WHEN THE SCRIPT STARTS FIRST TIME.
-- THE SQL WILL BE SEEDED AUTOMATICALLY WHEN THE SCRIPT STARTS FIRST TIME.
-- THE SQL WILL BE SEEDED AUTOMATICALLY WHEN THE SCRIPT STARTS FIRST TIME.
-- THE SQL WILL BE SEEDED AUTOMATICALLY WHEN THE SCRIPT STARTS FIRST TIME.
-- THE SQL WILL BE SEEDED AUTOMATICALLY WHEN THE SCRIPT STARTS FIRST TIME.
CREATE TABLE
    IF NOT EXISTS `yphone_metadata` (
        -- A table to hold data about the database version and handle automatic migrations during updates.
        `dbVersion` VARCHAR(10) NOT NULL,
        `lastUpdate` TIMESTAMP NOT NULL,
        `createdAt` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY (`dbVersion`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * General
CREATE TABLE
    IF NOT EXISTS `yphone_settings` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `phone_imei` VARCHAR(255) NOT NULL,
        `pin` VARCHAR(4),
        -- Used as identifier for fingerprint and face recognition
        `citizen_id` VARCHAR(255),
        `fingerprint` BOOLEAN NOT NULL DEFAULT 0,
        `face_recognition` BOOLEAN NOT NULL DEFAULT 0,
        `auto_lock_timeout` INT NOT NULL DEFAULT 0,
        `scale` VARCHAR(255) NOT NULL DEFAULT 1,
        `homescreen_wallpaper` VARCHAR(255),
        `lockscreen_wallpaper` VARCHAR(255),
        `type` VARCHAR(255) NOT NULL,
        `theme` VARCHAR(255) NOT NULL DEFAULT 'light',
        `language` VARCHAR(255) NOT NULL DEFAULT 'en',
        `volume` INT NOT NULL DEFAULT 50,
        `brightness` INT NOT NULL DEFAULT 100,
        `sound` VARCHAR(255) NOT NULL DEFAULT 'sound',
        `ringtone` VARCHAR(255) NULL,
        `notification` VARCHAR(255) NULL,
        `streamer_mode` BOOLEAN NOT NULL DEFAULT FALSE,
        `do_not_disturb` BOOLEAN NOT NULL DEFAULT FALSE,
        `airplane` BOOLEAN NOT NULL DEFAULT FALSE,
        `quickshare` BOOLEAN NOT NULL DEFAULT TRUE,
        `hide_caller_id` BOOLEAN NOT NULL DEFAULT FALSE,
        `notifications` LONGTEXT,
        `apps` LONGTEXT,
        `metadata` VARCHAR(4069) NOT NULL DEFAULT '',
        `lockscreen_widgets` LONGTEXT
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_devices` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        -- * A unique identifier of the phone. If Config.Item.UniquePhones is true `imei` will be generated. Otherwise, player identifier will be used.
        `imei` VARCHAR(255) NOT NULL,
        -- * If the phone has any lock method enabled (pin, fingerprint, face recognition).
        `lock` BOOLEAN DEFAULT FALSE,
        -- * The settings id of the phone in `yphone_settings`.
        `settings_id` INT,
        -- * If the phone has been setup.
        `is_setup` BOOLEAN DEFAULT FALSE,
        -- * The phone's battery level.
        `battery_level` INT (3) DEFAULT 100,
        -- * If the phone is charging.
        `battery_charging` TINYINT (1) DEFAULT 0,
        -- * The phone's operating system.
        `os` VARCHAR(255) NOT NULL,
        -- * The phone's screen damage.
        `damage` VARCHAR(255),
        UNIQUE KEY (`imei`),
        FOREIGN KEY (`settings_id`) REFERENCES `yphone_settings` (`id`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_sim_cards` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `phone_imei` VARCHAR(255),
        `sim_number` VARCHAR(20) NOT NULL,
        `slot` INT NOT NULL DEFAULT 1,
        `primary` BOOLEAN NOT NULL DEFAULT FALSE,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_holders` (
        `holder_identifier` VARCHAR(100) NOT NULL,
        `phone_imei` VARCHAR(255) NOT NULL,
        PRIMARY KEY (`holder_identifier`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_social_identifier_bans` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `holder_identifier` VARCHAR(100) NOT NULL,
        `app_id` VARCHAR(32) NOT NULL,
        `active` TINYINT (1) NOT NULL DEFAULT 1,
        `account_username` VARCHAR(255) NULL DEFAULT NULL,
        `reason` VARCHAR(512) NULL DEFAULT NULL,
        `expires_at` TIMESTAMP NULL DEFAULT NULL,
        `revoked_at` TIMESTAMP NULL DEFAULT NULL,
        `created_by` VARCHAR(255) NULL DEFAULT NULL,
        `updated_by` VARCHAR(255) NULL DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uk_social_ban_holder_app` (`holder_identifier`, `app_id`),
        KEY `idx_social_ban_app_active` (`app_id`, `active`),
        KEY `idx_social_ban_expires` (`expires_at`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * General
-- * Gallery
CREATE TABLE
    IF NOT EXISTS `yphone_gallery_albums` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `phone_imei` VARCHAR(255) NOT NULL,
        `name` VARCHAR(255) NOT NULL,
        `type` ENUM ('system', 'user') NOT NULL DEFAULT 'user',
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
        UNIQUE KEY `unique_album_per_phone` (`phone_imei`, `name`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_gallery` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `phone_imei` VARCHAR(255) NOT NULL,
        `image` VARCHAR(4096) NOT NULL,
        `thumbnail` VARCHAR(4096) NULL,
        `album_id` INT NULL,
        `is_favorite` BOOLEAN NOT NULL DEFAULT FALSE,
        `source` ENUM (
            'camera',
            'download',
            'screenshot',
            'other',
            'hidden',
            'private'
        ) NOT NULL DEFAULT 'other',
        `date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
        `deleted` BOOLEAN NOT NULL DEFAULT FALSE,
        `deletedAt` TIMESTAMP NULL DEFAULT NULL,
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        FOREIGN KEY (`album_id`) REFERENCES `yphone_gallery_albums` (`id`) ON DELETE SET NULL
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_gallery_private_lock` (
        `phone_imei` VARCHAR(255) NOT NULL PRIMARY KEY,
        `pin_hash` VARCHAR(255) NOT NULL,
        `failed_attempts` INT NOT NULL DEFAULT 0,
        `locked_until` TIMESTAMP NULL DEFAULT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Gallery
-- * Phone
CREATE TABLE
    IF NOT EXISTS `yphone_contacts` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `phone_imei` VARCHAR(255) NOT NULL,
        `name` VARCHAR(255) NOT NULL,
        `number` VARCHAR(20) NOT NULL,
        `favorite` BOOLEAN NOT NULL DEFAULT 0,
        `avatar` VARCHAR(4096) NULL DEFAULT NULL,
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_blocked_numbers` (
        `phone_imei` VARCHAR(255) NOT NULL,
        -- the phone imei of the person who blocked the number
        `blocked_number` VARCHAR(15) NOT NULL,
        -- the phone number that was blocked
        PRIMARY KEY (`phone_imei`, `blocked_number`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_recents` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `target_number` VARCHAR(255) NULL,
        `phone_imei` VARCHAR(255) NOT NULL,
        `date` TIMESTAMP NULL DEFAULT current_timestamp(),
        `call_type` VARCHAR(255) NOT NULL,
        `call_duration` INT NOT NULL DEFAULT 0,
        `removed` TINYINT (1) NOT NULL DEFAULT 0,
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Phone
-- * Cloud(Backups)
CREATE TABLE
    IF NOT EXISTS `yphone_ycloud_accounts` (
        `phone_imei` VARCHAR(255) NOT NULL,
        `phone_number` VARCHAR(20) NULL,
        `username` VARCHAR(255) NOT NULL,
        `phone_name` VARCHAR(255) NOT NULL,
        `avatar` VARCHAR(4096) NULL,
        `password` VARCHAR(255) NOT NULL,
        `synced_imei` VARCHAR(255) NULL,
        `last_sync` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`username`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_ycloud_loggedin` (
        `phone_imei` VARCHAR(255) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        PRIMARY KEY (`phone_imei`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        FOREIGN KEY (`username`) REFERENCES `yphone_ycloud_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Cloud(Backups)s
-- * Twitter(Y)
CREATE TABLE
    IF NOT EXISTS `yphone_twitter_accounts` (
        `display_name` VARCHAR(30) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        `password` VARCHAR(100) NOT NULL,
        `phone_imei` VARCHAR(255) NOT NULL,
        `bio` VARCHAR(200) DEFAULT NULL,
        `profile_image` VARCHAR(4096) DEFAULT NULL,
        `profile_header` VARCHAR(4096) DEFAULT NULL,
        `pinned_tweet` VARCHAR(50) DEFAULT NULL,
        `verified` BOOLEAN DEFAULT FALSE,
        `follower_count` INT (11) NOT NULL DEFAULT 0,
        `following_count` INT (11) NOT NULL DEFAULT 0,
        `date_joined` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`username`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_twitter_follows` (
        `followed` VARCHAR(20) NOT NULL,
        -- the person followed, matches to `username` in yphone_twitter_accounts
        `follower` VARCHAR(20) NOT NULL,
        -- the person following, matches to `username` in yphone_twitter_accounts
        `notifications` BOOLEAN NOT NULL DEFAULT FALSE,
        -- if the follower gets notifications from the followed
        PRIMARY KEY (`followed`, `follower`),
        FOREIGN KEY (`followed`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`follower`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_twitter_tweets` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `username` VARCHAR(20) NOT NULL,
        -- the person who tweeted, matches to `username` in yphone_twitter_accounts
        `content` VARCHAR(280),
        `attachments` TEXT,
        -- json array of attachments
        `reply_to` VARCHAR(50) DEFAULT NULL,
        -- the tweet / reply this tweet / reply was a reply to
        `like_count` INT (11) DEFAULT 0,
        `reply_count` INT (11) DEFAULT 0,
        `retweet_count` INT (11) DEFAULT 0,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`username`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_twitter_likes` (
        `tweet_id` VARCHAR(50) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        -- the person who liked the tweet / reply, matches to `username` in phone_twitter_accounts
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`tweet_id`, `username`),
        FOREIGN KEY (`username`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_twitter_loggedin` (
        `phone_imei` VARCHAR(255) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        PRIMARY KEY (`phone_imei`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        FOREIGN KEY (`username`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_twitter_hashtags` (
        `hashtag` VARCHAR(50) NOT NULL,
        `amount` INT NOT NULL DEFAULT 0,
        `last_used` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`hashtag`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_twitter_retweets` (
        `tweet_id` VARCHAR(50) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        -- the person who retweeted the tweet / reply, matches to `username` in yphone_twitter_accounts
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`tweet_id`, `username`),
        FOREIGN KEY (`username`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE -- no foreign key on tweet_id as it should still show in the feed, even if the tweet is deleted
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_twitter_messages` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `sender` VARCHAR(20) NOT NULL,
        -- the person who sent the message, matches to `username` in yphone_twitter_accounts
        `recipient` VARCHAR(20) NOT NULL,
        -- the person who received the message, matches to `username` in yphone_twitter_accounts
        `content` VARCHAR(1000),
        `attachments` TEXT,
        -- json array of attachments
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`sender`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`recipient`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_twitter_notifications` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `username` VARCHAR(20) NOT NULL,
        `from` VARCHAR(20) NOT NULL,
        -- like, comment, follow  
        `type` VARCHAR(20) NOT NULL,
        `attachments` LONGTEXT,
        -- the post / comment this notification is about
        `post_id` INT DEFAULT NULL,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`username`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`from`) REFERENCES `yphone_twitter_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Twitter(Y)
-- * Notes
CREATE TABLE
    IF NOT EXISTS `yphone_notes` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `phone_imei` VARCHAR(255) NOT NULL,
        `title` VARCHAR(50) NOT NULL,
        `content` LONGTEXT,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Notes
-- * Companies
CREATE TABLE
    IF NOT EXISTS `yphone_companies_channels` (
        `id` VARCHAR(50) NOT NULL,
        `phone_imei` VARCHAR(255) NOT NULL,
        `company` VARCHAR(50) NOT NULL,
        `phone_number` VARCHAR(20) NULL,
        `last_message` VARCHAR(100) DEFAULT NULL,
        `timestamp` DATETIME (3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
        PRIMARY KEY (`id`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_companies_messages` (
        `id` VARCHAR(50) NOT NULL,
        `channel_id` VARCHAR(50) NOT NULL,
        -- phone_imei or company(job)
        `sender` VARCHAR(255) NOT NULL,
        `message` VARCHAR(1000) NOT NULL,
        `x_pos` INT (11) DEFAULT NULL,
        `y_pos` INT (11) DEFAULT NULL,
        `timestamp` DATETIME (3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
        PRIMARY KEY (`id`),
        FOREIGN KEY (`channel_id`) REFERENCES `yphone_companies_channels` (`id`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Companies
-- * Messages
CREATE TABLE
    IF NOT EXISTS `yphone_messages_channels` (
        `channel_id` VARCHAR(50) NOT NULL,
        `is_group` BOOLEAN NOT NULL DEFAULT FALSE,
        `name` VARCHAR(50) DEFAULT NULL,
        `last_message` VARCHAR(255) NOT NULL DEFAULT '',
        `last_message_timestamp` DATETIME (3) NOT NULL DEFAULT current_timestamp(3) ON UPDATE current_timestamp(3),
        PRIMARY KEY (`channel_id`)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_messages_messages` (
        `id` INT AUTO_INCREMENT,
        `channel_id` VARCHAR(50) NOT NULL,
        `sender_imei` VARCHAR(255) NOT NULL,
        `sender` VARCHAR(15) NOT NULL,
        `content` VARCHAR(1000) DEFAULT NULL,
        `attachments` TEXT DEFAULT NULL,
        `timestamp` DATETIME (3) NOT NULL DEFAULT current_timestamp(3),
        PRIMARY KEY (`id`)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_messages_members` (
        `channel_id` VARCHAR(50) NOT NULL,
        `phone_number` VARCHAR(15) NOT NULL,
        `is_owner` BOOLEAN NOT NULL DEFAULT FALSE,
        `deleted` BOOLEAN NOT NULL DEFAULT FALSE,
        `unread` INT (11) NOT NULL DEFAULT 0,
        `hidden_before` DATETIME (3) NULL DEFAULT NULL,
        PRIMARY KEY (`channel_id`, `phone_number`)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- * Messages
-- * Clock(Alarms)
CREATE TABLE
    IF NOT EXISTS `yphone_clock_alarms` (
        `id` INT AUTO_INCREMENT,
        `phone_imei` VARCHAR(255) NOT NULL,
        `hours` INT (2) NOT NULL DEFAULT 0,
        `minutes` INT (2) NOT NULL DEFAULT 0,
        `name` VARCHAR(50) NULL,
        `repeat` TEXT DEFAULT NULL,
        `local` BOOLEAN NOT NULL DEFAULT FALSE,
        `enabled` BOOLEAN DEFAULT TRUE,
        `created_on` DATETIME (3) NOT NULL DEFAULT current_timestamp(3),
        PRIMARY KEY (`id`, `phone_imei`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Clock(Alarms)
-- * Maps
CREATE TABLE
    IF NOT EXISTS `yphone_maps_locations` (
        `id` INT AUTO_INCREMENT,
        `phone_imei` VARCHAR(255) NOT NULL,
        `name` VARCHAR(50) NOT NULL,
        `x` FLOAT NOT NULL,
        `y` FLOAT NOT NULL,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Maps
-- * Banking
CREATE TABLE
    IF NOT EXISTS `yphone_banking_transactions` (
        `id` INT (11) NOT NULL AUTO_INCREMENT,
        `sender_number` VARCHAR(15) NOT NULL,
        `recipient_number` VARCHAR(15) NOT NULL,
        `amount` INT (11) NOT NULL,
        `reason` VARCHAR(50) NOT NULL,
        -- 'pending', 'completed', 'failed'
        `status` VARCHAR(50) NOT NULL,
        `type` VARCHAR(50) NOT NULL,
        -- 'transfer', 'request'
        `timestamp` DATETIME (3) NOT NULL DEFAULT current_timestamp(3) ON UPDATE current_timestamp(3),
        PRIMARY KEY (`id`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Banking
-- * Email
CREATE TABLE
    IF NOT EXISTS `yphone_mails` (
        `id` INT (11) NOT NULL AUTO_INCREMENT,
        `timestamp` DATETIME (3) NOT NULL DEFAULT current_timestamp(3),
        `title` VARCHAR(255) NOT NULL,
        `content` TEXT NOT NULL,
        `phone_imei` VARCHAR(255) NOT NULL,
        `attachments` LONGTEXT,
        `actions` LONGTEXT,
        `is_read` BOOLEAN DEFAULT FALSE,
        `sender` VARCHAR(255) NOT NULL,
        `sender_display_name` VARCHAR(255),
        PRIMARY KEY (`id`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Email
-- * YBuy
CREATE TABLE
    IF NOT EXISTS `yphone_ybuy_ads` (
        `id` INT (11) NOT NULL AUTO_INCREMENT,
        `timestamp` DATETIME (3) NOT NULL DEFAULT current_timestamp(3),
        `title` VARCHAR(255) NOT NULL,
        `description` VARCHAR(1000),
        `category` VARCHAR(255) NOT NULL,
        `price` VARCHAR(255) NOT NULL,
        `contact_name` VARCHAR(255) NOT NULL,
        `phone_number` VARCHAR(255) NOT NULL,
        `allow_messages` BOOLEAN DEFAULT FALSE,
        `allow_calls` BOOLEAN DEFAULT FALSE,
        `attachments` LONGTEXT,
        `phone_imei` VARCHAR(255) NOT NULL,
        `archived` BOOLEAN DEFAULT FALSE,
        `last_renew` DATETIME (3) NOT NULL DEFAULT current_timestamp(3),
        PRIMARY KEY (`id`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_ybuy_favorites` (
        `ad_id` INT (11) NOT NULL AUTO_INCREMENT,
        `phone_imei` VARCHAR(255) NOT NULL,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`ad_id`, `phone_imei`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * YBuy
-- * Instashots
CREATE TABLE
    IF NOT EXISTS `yphone_instashots_accounts` (
        `display_name` VARCHAR(30) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        `password` VARCHAR(100) NOT NULL,
        -- `phone_imei` VARCHAR(255) NOT NULL,
        `bio` VARCHAR(200) DEFAULT NULL,
        `profile_image` VARCHAR(4096) DEFAULT NULL,
        `verified` BOOLEAN DEFAULT FALSE,
        `private` BOOLEAN DEFAULT FALSE,
        `follower_count` INT (11) NOT NULL DEFAULT 0,
        `following_count` INT (11) NOT NULL DEFAULT 0,
        `story_count` INT (11) NOT NULL DEFAULT 0,
        `posts_count` INT (11) NOT NULL DEFAULT 0,
        PRIMARY KEY (`username`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_follows` (
        `followed` VARCHAR(20) NOT NULL,
        -- the person followed, matches to `username` in yphone_instashots_accounts
        `follower` VARCHAR(20) NOT NULL,
        -- the person following, matches to `username` in yphone_instashots_accounts
        `notifications` BOOLEAN NOT NULL DEFAULT FALSE,
        -- if the follower gets notifications from the followed
        PRIMARY KEY (`followed`, `follower`),
        FOREIGN KEY (`followed`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`follower`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_posts` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        -- the person who posted, matches to `username` in yphone_instashots_accounts
        `username` VARCHAR(20) NOT NULL,
        `caption` VARCHAR(280),
        -- json array of attachments
        `attachments` LONGTEXT,
        `like_count` INT (11) DEFAULT 0,
        `comment_count` INT (11) DEFAULT 0,
        `archived` BOOLEAN NOT NULL DEFAULT FALSE,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`username`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_likes` (
        `post_id` VARCHAR(50) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        `is_comment` BOOLEAN NOT NULL DEFAULT FALSE,
        -- the person who liked the post matches to `username` in phone_instashots_accounts
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`post_id`, `username`),
        FOREIGN KEY (`username`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_loggedin` (
        `phone_imei` VARCHAR(255) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        PRIMARY KEY (`phone_imei`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        FOREIGN KEY (`username`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_hashtags` (
        `hashtag` VARCHAR(50) NOT NULL,
        `amount` INT NOT NULL DEFAULT 0,
        `last_used` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`hashtag`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_comments` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `post_id` INT NOT NULL,
        -- the post this comment was made on, matches to `id` in yphone_instashots_posts
        `username` VARCHAR(20) NOT NULL,
        -- the person who commented, matches to `username` in yphone_instashots_accounts
        `comment` VARCHAR(500) NOT NULL DEFAULT "",
        `like_count` INT (11) NOT NULL DEFAULT 0,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`post_id`) REFERENCES `yphone_instashots_posts` (`id`) ON DELETE CASCADE,
        FOREIGN KEY (`username`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_notifications` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `username` VARCHAR(20) NOT NULL,
        `from` VARCHAR(20) NOT NULL,
        -- like, comment, follow  
        `type` VARCHAR(20) NOT NULL,
        `attachments` LONGTEXT,
        -- the post / comment this notification is about
        `post_id` INT DEFAULT NULL,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`username`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`from`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_stories` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `username` VARCHAR(20) NOT NULL,
        `attachments` LONGTEXT,
        `archived` BOOLEAN NOT NULL DEFAULT FALSE,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`username`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_stories_views` (
        `story_id` INT NOT NULL,
        `viewer` VARCHAR(20) NOT NULL,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`story_id`, `viewer`),
        FOREIGN KEY (`story_id`) REFERENCES `yphone_instashots_stories` (`id`) ON DELETE CASCADE,
        FOREIGN KEY (`viewer`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_instashots_messages` (
        `id` INT AUTO_INCREMENT,
        `sender` VARCHAR(20) NOT NULL,
        -- the person who sent the message, matches to `username` in yphone_instashots_accounts
        `recipient` VARCHAR(20) NOT NULL,
        -- the person who received the message, matches to `username` in phone_instashots_accounts
        `content` VARCHAR(1000),
        `attachments` TEXT,
        -- json array of attachments
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`sender`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`recipient`) REFERENCES `yphone_instashots_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Instashots
-- * DarkChat
CREATE TABLE
    IF NOT EXISTS `yphone_darkchat_accounts` (
        `username` VARCHAR(20) NOT NULL,
        `display_name` VARCHAR(30) NOT NULL,
        `password` VARCHAR(50) NOT NULL,
        `profile_image` VARCHAR(4096) DEFAULT NULL,
        PRIMARY KEY (`username`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_darkchat_loggedin` (
        `phone_imei` VARCHAR(255) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        PRIMARY KEY (`phone_imei`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        FOREIGN KEY (`username`) REFERENCES `yphone_darkchat_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_darkchat_channels` (
        `name` VARCHAR(50) NOT NULL,
        `password` VARCHAR(50) DEFAULT NULL,
        `last_message` VARCHAR(100) DEFAULT NULL,
        `profile_picture` VARCHAR(4096) DEFAULT NULL,
        `anonymous` BOOLEAN DEFAULT FALSE,
        `ch_owner` VARCHAR(20) NOT NULL,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`name`),
        FOREIGN KEY (`ch_owner`) REFERENCES `yphone_darkchat_accounts` (`username`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_darkchat_members` (
        `channel_name` VARCHAR(50) NOT NULL,
        `muted` BOOLEAN DEFAULT FALSE,
        `username` VARCHAR(20) NOT NULL,
        PRIMARY KEY (`channel_name`, `username`),
        FOREIGN KEY (`username`) REFERENCES `yphone_darkchat_accounts` (`username`) ON DELETE CASCADE,
        FOREIGN KEY (`channel_name`) REFERENCES `yphone_darkchat_channels` (`name`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_darkchat_messages` (
        `id` INT (11) NOT NULL AUTO_INCREMENT,
        `channel` VARCHAR(50) NOT NULL,
        `sender` VARCHAR(20) NOT NULL,
        `content` VARCHAR(1000),
        `attachments` TEXT DEFAULT NULL,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`sender`) REFERENCES `yphone_darkchat_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`channel`) REFERENCES `yphone_darkchat_channels` (`name`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Insert the default user for channel ownership
INSERT IGNORE INTO `yphone_darkchat_accounts` (`username`, `display_name`, `password`)
VALUES
    ('darkchat', 'Dark Chat', 'gT00746f&76"');

-- Insert the default channel 'general' with 'darkchat' as the owner
INSERT IGNORE INTO `yphone_darkchat_channels` (`name`, `ch_owner`)
VALUES
    ('general', 'darkchat');

-- * DarkChat
-- * Promo Hub 
CREATE TABLE
    IF NOT EXISTS `yphone_promo_hub_posts` (
        `id` INT (11) NOT NULL AUTO_INCREMENT,
        `phone_imei` VARCHAR(255) NOT NULL,
        `contact_number` VARCHAR(15) NOT NULL,
        `contact_name` VARCHAR(50) NOT NULL,
        `title` VARCHAR(50) NOT NULL,
        `description` VARCHAR(1000) NOT NULL,
        `attachments` TEXT DEFAULT NULL,
        `price` VARCHAR(255) NOT NULL,
        `archived` BOOLEAN NOT NULL DEFAULT FALSE,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Promo Hub
-- * Notifications
CREATE TABLE
    IF NOT EXISTS `yphone_notifications` (
        `id` VARCHAR(255) NOT NULL,
        `app` VARCHAR(255) NOT NULL,
        `title` VARCHAR(255) NOT NULL,
        `text` VARCHAR(255) NULL,
        `data` LONGTEXT NULL,
        `read` BOOLEAN NOT NULL DEFAULT FALSE,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `phone_imei` VARCHAR(255) NOT NULL,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Notifications
-- * Lovr
CREATE TABLE
    IF NOT EXISTS `yphone_lovr_accounts` (
        `display_name` VARCHAR(30) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        `password` VARCHAR(100) NOT NULL,
        `age` INT NOT NULL,
        `bio` VARCHAR(500) DEFAULT NULL,
        `profile_images` LONGTEXT DEFAULT NULL, -- JSON array of image URLs
        `gender` VARCHAR(20) NOT NULL,
        `interested_in` VARCHAR(20) NOT NULL,
        `verified` BOOLEAN DEFAULT FALSE,
        `active` BOOLEAN DEFAULT TRUE,
        `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`username`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_lovr_loggedin` (
        `phone_imei` VARCHAR(255) NOT NULL,
        `username` VARCHAR(20) NOT NULL,
        PRIMARY KEY (`phone_imei`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        FOREIGN KEY (`username`) REFERENCES `yphone_lovr_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_lovr_likes` (
        `liker_username` VARCHAR(20) NOT NULL,
        `liked_username` VARCHAR(20) NOT NULL,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`liker_username`, `liked_username`),
        FOREIGN KEY (`liker_username`) REFERENCES `yphone_lovr_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`liked_username`) REFERENCES `yphone_lovr_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_lovr_passes` (
        `passer_username` VARCHAR(20) NOT NULL,
        `passed_username` VARCHAR(20) NOT NULL,
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`passer_username`, `passed_username`),
        FOREIGN KEY (`passer_username`) REFERENCES `yphone_lovr_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`passed_username`) REFERENCES `yphone_lovr_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_lovr_matches` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `user1_username` VARCHAR(20) NOT NULL,
        `user2_username` VARCHAR(20) NOT NULL,
        `matched_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_match (`user1_username`, `user2_username`),
        FOREIGN KEY (`user1_username`) REFERENCES `yphone_lovr_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (`user2_username`) REFERENCES `yphone_lovr_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_lovr_messages` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `match_id` INT NOT NULL,
        `sender_username` VARCHAR(20) NOT NULL,
        `content` VARCHAR(1000) NOT NULL,
        `attachments` TEXT DEFAULT NULL, -- JSON array of attachments
        `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (`match_id`) REFERENCES `yphone_lovr_matches` (`id`) ON DELETE CASCADE,
        FOREIGN KEY (`sender_username`) REFERENCES `yphone_lovr_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Lovr
-- * Audix
CREATE TABLE
    IF NOT EXISTS `yphone_audix_ringtones` (
        `id` INT (11) NOT NULL AUTO_INCREMENT,
        `display_name` VARCHAR(255) NOT NULL,
        `url` TEXT NOT NULL,
        `author` VARCHAR(255) NOT NULL,
        `phone_imei` VARCHAR(255) NOT NULL,
        `category` ENUM ('ringtone', 'notification') NOT NULL DEFAULT 'ringtone',
        `upvote` INT (11) NOT NULL DEFAULT 0,
        `is_private` BOOLEAN NOT NULL DEFAULT FALSE,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        INDEX `idx_category` (`category`),
        INDEX `idx_author` (`author`),
        INDEX `idx_created_at` (`created_at`),
        INDEX `idx_private` (`is_private`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_audix_votes` (
        `id` INT (11) NOT NULL AUTO_INCREMENT,
        `ringtone_id` INT (11) NOT NULL,
        `phone_imei` VARCHAR(255) NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        FOREIGN KEY (`ringtone_id`) REFERENCES `yphone_audix_ringtones` (`id`) ON DELETE CASCADE,
        FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        UNIQUE KEY `unique_vote` (`ringtone_id`, `phone_imei`),
        INDEX `idx_ringtone_id` (`ringtone_id`),
        INDEX `idx_phone_imei` (`phone_imei`)
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Audix
-- * News
CREATE TABLE
    IF NOT EXISTS `yphone_news_accounts` (
        `username` varchar(20) NOT NULL PRIMARY KEY,
        `display_name` varchar(30) NOT NULL,
        `password` varchar(255) NOT NULL,
        `verified` tinyint (1) DEFAULT 0,
        `active` tinyint (1) DEFAULT 1,
        `profile_image` varchar(255) DEFAULT NULL,
        `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `last_seen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX `idx_active` (`active`)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_news_articles` (
        `id` int (11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
        `title` varchar(255) NOT NULL,
        `summary` text NOT NULL,
        `content` longtext NOT NULL,
        `image_urls` json DEFAULT NULL,
        `category_id` varchar(50) NOT NULL,
        `author_id` varchar(20) NOT NULL,
        `views_count` int (11) DEFAULT 0,
        `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (`author_id`) REFERENCES `yphone_news_accounts` (`username`) ON DELETE CASCADE,
        INDEX `idx_category` (`category_id`),
        INDEX `idx_author` (`author_id`),
        INDEX `idx_created` (`created_at`),
        INDEX `idx_views` (`views_count`),
        FULLTEXT INDEX `idx_search` (`title`, `summary`, `content`)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_news_loggedin` (
        `phone_imei` varchar(20) NOT NULL,
        `username` varchar(20) NOT NULL,
        `logged_in_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`phone_imei`),
        UNIQUE KEY `username_unique` (`username`),
        FOREIGN KEY (`username`) REFERENCES `yphone_news_accounts` (`username`) ON DELETE CASCADE,
        INDEX `idx_username` (`username`)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_spotfinder_accounts` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `phone_imei` VARCHAR(255) NOT NULL,
        `username` VARCHAR(50) NOT NULL,
        `password_salt` CHAR(64) NOT NULL,
        `password_hash` CHAR(64) NOT NULL,
        `password_updated_at` TIMESTAMP NULL DEFAULT NULL,
        `display_name` VARCHAR(50) NOT NULL,
        `total_games_played` INT NOT NULL DEFAULT 0,
        `best_game_score` INT NOT NULL DEFAULT 0,
        `best_round_score` INT NOT NULL DEFAULT 0,
        `total_score` BIGINT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uk_spotfinder_username` (`username`),
        KEY `idx_spotfinder_accounts_phone_imei` (`phone_imei`),
        KEY `idx_spotfinder_accounts_best_game` (`best_game_score` DESC),
        CONSTRAINT `fk_spotfinder_accounts_device` FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_spotfinder_loggedin` (
        `phone_imei` VARCHAR(255) NOT NULL,
        `username` VARCHAR(50) NOT NULL,
        PRIMARY KEY (`phone_imei`),
        KEY `idx_spotfinder_loggedin_username` (`username`),
        CONSTRAINT `fk_spotfinder_loggedin_device` FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        CONSTRAINT `fk_spotfinder_loggedin_user` FOREIGN KEY (`username`) REFERENCES `yphone_spotfinder_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_spotfinder_maps` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `creator_username` VARCHAR(50) NOT NULL,
        `title` VARCHAR(100) NOT NULL,
        `description` TEXT NULL DEFAULT NULL,
        `cover_image_url` TEXT NULL DEFAULT NULL,
        `default_timer_setting` INT NULL DEFAULT NULL,
        `published` TINYINT (1) NOT NULL DEFAULT 0,
        `avg_rating` DECIMAL(3, 2) NULL DEFAULT NULL,
        `rating_count` INT NOT NULL DEFAULT 0,
        `plays_count` INT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_spotfinder_maps_creator` (`creator_username`),
        KEY `idx_spotfinder_maps_published` (`published`),
        CONSTRAINT `fk_spotfinder_maps_creator_user` FOREIGN KEY (`creator_username`) REFERENCES `yphone_spotfinder_accounts` (`username`) ON UPDATE CASCADE ON DELETE RESTRICT
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_spotfinder_map_ratings` (
        `map_id` INT NOT NULL,
        `rater_username` VARCHAR(50) NOT NULL,
        `stars` TINYINT NOT NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`map_id`, `rater_username`),
        CONSTRAINT `fk_spotfinder_map_ratings_map` FOREIGN KEY (`map_id`) REFERENCES `yphone_spotfinder_maps` (`id`) ON DELETE CASCADE,
        CONSTRAINT `fk_spotfinder_map_ratings_rater` FOREIGN KEY (`rater_username`) REFERENCES `yphone_spotfinder_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_spotfinder_locations` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `map_id` INT NOT NULL,
        `sort_order` INT NOT NULL DEFAULT 0,
        `creator_username` VARCHAR(50) NOT NULL,
        `location_x` DOUBLE NOT NULL,
        `location_y` DOUBLE NOT NULL,
        `times_played` INT NOT NULL DEFAULT 0,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_spotfinder_locations_creator` (`creator_username`),
        KEY `idx_spotfinder_locations_map_order` (`map_id`, `sort_order`),
        CONSTRAINT `fk_spotfinder_locations_map` FOREIGN KEY (`map_id`) REFERENCES `yphone_spotfinder_maps` (`id`) ON DELETE RESTRICT
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_spotfinder_location_images` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `location_id` INT NOT NULL,
        `sort_order` INT NOT NULL,
        `image_url` TEXT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_spotfinder_location_images_location_order` (`location_id`, `sort_order`),
        CONSTRAINT `fk_spotfinder_location_images_location` FOREIGN KEY (`location_id`) REFERENCES `yphone_spotfinder_locations` (`id`) ON DELETE CASCADE
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_spotfinder_games` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `phone_imei` VARCHAR(255) NOT NULL,
        `username` VARCHAR(50) NOT NULL,
        `total_score` INT NOT NULL DEFAULT 0,
        `rounds_count` INT NOT NULL DEFAULT 0,
        `map_id` INT NOT NULL,
        `timer_setting` INT NOT NULL,
        `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `completed_at` TIMESTAMP NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_spotfinder_games_username` (`username`),
        KEY `idx_spotfinder_games_phone_imei` (`phone_imei`),
        KEY `idx_spotfinder_games_completed` (`completed_at`),
        KEY `idx_spotfinder_games_map` (`map_id`),
        CONSTRAINT `fk_spotfinder_games_device` FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE,
        CONSTRAINT `fk_spotfinder_games_user` FOREIGN KEY (`username`) REFERENCES `yphone_spotfinder_accounts` (`username`) ON DELETE CASCADE ON UPDATE CASCADE,
        CONSTRAINT `fk_spotfinder_games_map` FOREIGN KEY (`map_id`) REFERENCES `yphone_spotfinder_maps` (`id`) ON DELETE RESTRICT
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE
    IF NOT EXISTS `yphone_spotfinder_rounds` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `game_id` INT NOT NULL,
        `location_id` INT NOT NULL,
        `round_number` INT NOT NULL,
        `guess_x` DOUBLE NULL DEFAULT NULL,
        `guess_y` DOUBLE NULL DEFAULT NULL,
        `distance` DOUBLE NULL DEFAULT NULL,
        `score` INT NULL DEFAULT NULL,
        `time_taken` INT NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `uk_spotfinder_round_game_num` (`game_id`, `round_number`),
        KEY `idx_spotfinder_rounds_game` (`game_id`),
        KEY `idx_spotfinder_rounds_location` (`location_id`),
        CONSTRAINT `fk_spotfinder_rounds_game` FOREIGN KEY (`game_id`) REFERENCES `yphone_spotfinder_games` (`id`) ON DELETE CASCADE,
        CONSTRAINT `fk_spotfinder_rounds_location` FOREIGN KEY (`location_id`) REFERENCES `yphone_spotfinder_locations` (`id`) ON DELETE RESTRICT
    ) CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

-- * Voice Memos
CREATE TABLE
    IF NOT EXISTS `yphone_voice_memos` (
        `id` int (11) NOT NULL AUTO_INCREMENT,
        `phone_imei` varchar(255) NOT NULL,
        `title` varchar(120) NOT NULL,
        `url` varchar(2048) NOT NULL,
        `duration` double NOT NULL DEFAULT 0,
        `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `idx_voice_memos_phone_created` (`phone_imei`, `created_at`),
        CONSTRAINT `fk_voice_memos_phone_imei` FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices` (`imei`) ON DELETE CASCADE
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;