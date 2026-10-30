-- delete existing tables
DROP TABLE IF EXISTS `meteo_apartment_logs`;
DROP TABLE IF EXISTS `meteo_apartment_members`;
DROP TABLE IF EXISTS `meteo_apartments`;

CREATE TABLE IF NOT EXISTS `meteo_apartments` (
    `id` VARCHAR(100) NOT NULL,
    `complexId` VARCHAR(50) NOT NULL,
    `roomNumber` INT NOT NULL,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `roomType` VARCHAR(50) NOT NULL DEFAULT 'modern',
    `spawnPoint` LONGTEXT DEFAULT NULL,
    `purchasedAt` DATETIME DEFAULT NULL,
    `rentExpiresAt` DATETIME DEFAULT NULL,
    `doorUpgrades` LONGTEXT DEFAULT NULL,
    `memberLimitTier` INT DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_complex_room` (`complexId`, `roomNumber`),
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_complexId` (`complexId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `meteo_apartment_members` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `apartmentId` VARCHAR(100) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `permissions` LONGTEXT NOT NULL,
    `role` VARCHAR(50) DEFAULT 'guest',
    `addedAt` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_apartment_member` (`apartmentId`, `citizenid`),
    INDEX `idx_apartmentId` (`apartmentId`),
    INDEX `idx_citizenid` (`citizenid`),
    FOREIGN KEY (`apartmentId`) REFERENCES `meteo_apartments`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `meteo_apartment_logs` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `apartmentId` VARCHAR(100) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `charName` VARCHAR(100) NOT NULL,
    `action` ENUM('entry', 'exit', 'doorbell', 'lockpick_attempt', 'lockpick_success', 'stormram_attempt', 'stormram_success') NOT NULL,
    `timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_apartmentId` (`apartmentId`),
    INDEX `idx_timestamp` (`timestamp`),
    FOREIGN KEY (`apartmentId`) REFERENCES `meteo_apartments`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `meteo_furnishing` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `property_id` VARCHAR(100) NOT NULL,
    `property_type` VARCHAR(20) NOT NULL,
    `item_id` VARCHAR(100) NOT NULL,
    `model` VARCHAR(255) NOT NULL,
    `coords` JSON NOT NULL,
    `rotation` JSON NOT NULL,
    `placed_by` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_property` (`property_id`)
)