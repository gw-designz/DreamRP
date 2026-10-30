-- YSeries v0.99.89 Migration
ALTER TABLE `yphone_devices`
ADD COLUMN `battery_level` INT (3) DEFAULT 100,
ADD COLUMN `battery_charging` TINYINT (1) DEFAULT 0;

UPDATE `yphone_devices`
SET
    `battery_level` = 100,
    `battery_charging` = 0
WHERE
    `battery_level` IS NULL;

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

ALTER TABLE `yphone_gallery`
ADD COLUMN `album_id` INT NULL AFTER `thumbnail`,
ADD COLUMN `is_favorite` BOOLEAN NOT NULL DEFAULT FALSE AFTER `album_id`,
ADD COLUMN `source` ENUM ('camera', 'download', 'screenshot', 'other') NOT NULL DEFAULT 'other' AFTER `is_favorite`;

ALTER TABLE `yphone_gallery` ADD CONSTRAINT `fk_gallery_album` FOREIGN KEY (`album_id`) REFERENCES `yphone_gallery_albums` (`id`) ON DELETE SET NULL;