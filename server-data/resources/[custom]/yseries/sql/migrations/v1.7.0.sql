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