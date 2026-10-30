ALTER TABLE `yphone_sim_cards` MODIFY COLUMN `phone_imei` VARCHAR(255);
ALTER TABLE `yphone_sim_cards` ADD COLUMN `slot` INT NOT NULL DEFAULT 1 AFTER `sim_number`;
ALTER TABLE `yphone_sim_cards` ADD COLUMN `primary` BOOLEAN NOT NULL DEFAULT FALSE AFTER `slot`;

CREATE TABLE IF NOT EXISTS `yphone_notifications` (
    `id` VARCHAR(255) NOT NULL,
    `app` VARCHAR(255) NOT NULL,
    `title` VARCHAR(255) NOT NULL,
    `text` VARCHAR(255) NULL,
    `data` LONGTEXT NULL,
    `read` BOOLEAN NOT NULL DEFAULT FALSE,
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `phone_imei` VARCHAR(255) NOT NULL,
    
    PRIMARY KEY (`id`),
    FOREIGN KEY (`phone_imei`) REFERENCES `yphone_devices`(`imei`) ON DELETE CASCADE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;