ALTER TABLE `yphone_darkchat_channels`
CHANGE COLUMN `owner` `ch_owner` VARCHAR(20) NOT NULL;

ALTER TABLE `yphone_recents`
ADD COLUMN `call_duration` INT NOT NULL DEFAULT 0;
