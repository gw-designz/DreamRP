ALTER TABLE `yphone_settings`
ADD COLUMN `lockscreen_widgets` LONGTEXT NULL DEFAULT NULL;

ALTER TABLE `yphone_recents`
ADD COLUMN `removed` TINYINT (1) NOT NULL DEFAULT 0;

ALTER TABLE `yphone_messages_members`
ADD COLUMN `hidden_before` DATETIME (3) NULL DEFAULT NULL;