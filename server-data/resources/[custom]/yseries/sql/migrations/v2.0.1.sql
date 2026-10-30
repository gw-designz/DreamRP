-- v2.0.1 — ensure voice memos table exists (upserts from v1.7.0 may have been skipped on some DBs)
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
