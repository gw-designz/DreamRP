ALTER TABLE `yphone_gallery`
ADD COLUMN `deleted` BOOLEAN NOT NULL DEFAULT FALSE AFTER `date`,
ADD COLUMN `deletedAt` TIMESTAMP NULL DEFAULT NULL AFTER `deleted`;

CREATE INDEX idx_gallery_phone_deleted_deletedAt ON yphone_gallery (phone_imei, deleted, deletedAt);

ALTER TABLE `yphone_gallery` MODIFY COLUMN `source` ENUM (
    'camera',
    'download',
    'screenshot',
    'other',
    'hidden',
    'private'
) NOT NULL DEFAULT 'other';

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