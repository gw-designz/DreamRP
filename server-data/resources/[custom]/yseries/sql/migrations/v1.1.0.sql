-- Create news accounts table
CREATE TABLE IF NOT EXISTS `yphone_news_accounts` (
    `username` varchar(20) NOT NULL PRIMARY KEY,
    `display_name` varchar(30) NOT NULL,
    `password` varchar(255) NOT NULL,
    `verified` tinyint(1) DEFAULT 0,
    `active` tinyint(1) DEFAULT 1,
    `profile_image` varchar(255) DEFAULT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_seen` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create news articles table
CREATE TABLE IF NOT EXISTS `yphone_news_articles` (
    `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `title` varchar(255) NOT NULL,
    `summary` text NOT NULL,
    `content` longtext NOT NULL,
    `image_urls` json DEFAULT NULL,
    `category_id` varchar(50) NOT NULL,
    `author_id` varchar(20) NOT NULL,
    `views_count` int(11) DEFAULT 0,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (`author_id`) REFERENCES `yphone_news_accounts`(`username`) ON DELETE CASCADE,
    INDEX `idx_category` (`category_id`),
    INDEX `idx_author` (`author_id`),
    INDEX `idx_created` (`created_at`),
    INDEX `idx_views` (`views_count`),
    FULLTEXT INDEX `idx_search` (`title`, `summary`, `content`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create news login tracking table
CREATE TABLE IF NOT EXISTS `yphone_news_loggedin` (
    `phone_imei` varchar(20) NOT NULL,
    `username` varchar(20) NOT NULL,
    `logged_in_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`phone_imei`),
    UNIQUE KEY `username_unique` (`username`),
    FOREIGN KEY (`username`) REFERENCES `yphone_news_accounts`(`username`) ON DELETE CASCADE,
    INDEX `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci; 