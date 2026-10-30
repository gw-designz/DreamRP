



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

































































CREATE TABLE IF NOT EXISTS `buildings` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(250) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `label` VARCHAR(250) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `metadata` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `properties` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `address` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `label` VARCHAR(50) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `type` VARCHAR(50) NULL DEFAULT 'shell' COLLATE 'utf8mb4_unicode_ci',
    `keyholders` MEDIUMTEXT NULL DEFAULT '[]' COLLATE 'utf8mb4_unicode_ci',
    `metadata` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `buildingid` INT(11) NULL DEFAULT NULL,
    `ownerid` INT(11) NULL DEFAULT NULL,
    `renterid` INT(11) NULL DEFAULT NULL,
    `priceid` INT(11) NULL DEFAULT NULL,
    `rentpriceid` INT(11) NULL DEFAULT NULL,
    `last_entered` DATETIME NULL DEFAULT NULL,
    `electricity_last_payment` DATETIME NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'The last time the electricity bill was paid',
    `water_last_payment` DATETIME NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'The last time the water bill was paid',
    `internet_last_payment` DATETIME NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'The last time the internet bill was paid',
    `forsale` INT(11) NULL DEFAULT '0' COMMENT 'Whether the property is for sale',
    `forrent` INT(11) NULL DEFAULT '0' COMMENT 'Whether the property is for rent',
    `formortgage` INT(11) NULL DEFAULT '0' COMMENT 'Whether the property is for mortgage',
    PRIMARY KEY (`id`) USING BTREE,
    INDEX `fk_buildingID` (`buildingid`) USING BTREE,
    INDEX `fk_ownerID` (`ownerid`) USING BTREE,
    INDEX `fk_priceID` (`priceid`) USING BTREE,
    INDEX `fk_renterID` (`renterid`) USING BTREE,
    INDEX `fk_rentpriceID` (`rentpriceid`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `properties_owners` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `property_id` INT(11) NULL DEFAULT NULL,
    `type` ENUM('society', 'user') NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `identifier` VARCHAR(46) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `purchase_date` DATE NULL DEFAULT curdate(),
    `purchase_price` INT(11) NULL DEFAULT NULL,
    `note` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    PRIMARY KEY (`id`) USING BTREE,
    INDEX `properties_owners_ibfk_1` (`property_id`) USING BTREE,
    CONSTRAINT `properties_owners_ibfk_1` FOREIGN KEY (`property_id`) REFERENCES `properties` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `properties_prices` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `property_id` INT(11) NULL DEFAULT NULL,
    `price` DECIMAL(10, 2) NULL DEFAULT NULL,
    `set_by` VARCHAR(255) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `set_on` TIMESTAMP NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`) USING BTREE,
    INDEX `properties_prices_ibfk_1` (`property_id`) USING BTREE,
    CONSTRAINT `properties_prices_ibfk_1` FOREIGN KEY (`property_id`) REFERENCES `properties` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `properties_renters` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `property_id` INT(11) NULL DEFAULT NULL,
    `type` ENUM('user', 'society') NOT NULL COLLATE 'utf8mb4_unicode_ci',
    `identifier` VARCHAR(46) NOT NULL COLLATE 'utf8mb4_unicode_ci',
    `rent_data` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `rented_from` DATE NULL DEFAULT NULL,
    `rented_to` DATE NULL DEFAULT NULL,
    `rented_price` DECIMAL(10, 2) NULL DEFAULT NULL,
    `auto_renew` TINYINT(1) NOT NULL DEFAULT 0,
    `canceled_on` DATE NULL DEFAULT NULL,
    PRIMARY KEY (`id`) USING BTREE,
    INDEX `properties_renters_ibfk_1` (`property_id`) USING BTREE,
    CONSTRAINT `properties_renters_ibfk_1` FOREIGN KEY (`property_id`) REFERENCES `properties` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `properties_rentprices` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `property_id` INT(11) NULL DEFAULT NULL,
    `price` DECIMAL(10, 2) NULL DEFAULT NULL,
    `set_by` VARCHAR(255) NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    `set_on` TIMESTAMP NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`) USING BTREE,
    INDEX `properties_rentprices_ibfk_1` (`property_id`) USING BTREE,
    CONSTRAINT `properties_rentprices_ibfk_1` FOREIGN KEY (`property_id`) REFERENCES `properties` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `properties_doors` (
    `id` int (11) unsigned NOT NULL AUTO_INCREMENT,
    `property_id` INT(11) NULL DEFAULT NULL,
    `name` varchar(50) NOT NULL,
    `data` longtext NOT NULL,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`property_id`) REFERENCES `properties` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `properties_furniture` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `propertyId` INT NOT NULL,
    `furnitureId` INT NOT NULL,
    `environment` VARCHAR(10) NOT NULL,
    `coords_x` FLOAT NOT NULL,
    `coords_y` FLOAT NOT NULL,
    `coords_z` FLOAT NOT NULL,
    `rotation_x` FLOAT NOT NULL,
    `rotation_y` FLOAT NOT NULL,
    `rotation_z` FLOAT NOT NULL,
    `price` DECIMAL(10, 2) NOT NULL,
    `model` VARCHAR(255) NOT NULL,
    `type` VARCHAR(50) NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `stored` VARCHAR(1) DEFAULT NULL,
    `require_keys` VARCHAR(1) DEFAULT NULL,
    `metadata` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_unicode_ci',
    CONSTRAINT `properties_furniture_ibfk_1` FOREIGN KEY (`propertyId`) REFERENCES `properties` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE `properties`
ADD CONSTRAINT `fk_buildingID` FOREIGN KEY (`buildingid`) REFERENCES `buildings` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE,
ADD CONSTRAINT `fk_ownerID` FOREIGN KEY (`ownerid`) REFERENCES `properties_owners` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE,
ADD CONSTRAINT `fk_priceID` FOREIGN KEY (`priceid`) REFERENCES `properties_prices` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE, 
ADD CONSTRAINT `fk_renterID` FOREIGN KEY (`renterid`) REFERENCES `properties_renters` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE,
ADD CONSTRAINT `fk_rentpriceID` FOREIGN KEY (`rentpriceid`) REFERENCES `properties_rentprices` (`id`) ON UPDATE RESTRICT ON DELETE CASCADE;
