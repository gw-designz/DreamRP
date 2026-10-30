ALTER TABLE `yphone_contacts`
ADD COLUMN `avatar` VARCHAR(4096) NULL DEFAULT NULL AFTER `favorite`;

CREATE INDEX idx_sim_cards_sim_number ON yphone_sim_cards (sim_number);

CREATE INDEX idx_holders_phone_imei ON yphone_holders (phone_imei);

CREATE INDEX idx_notifications_phone_imei_timestamp ON yphone_notifications (phone_imei, timestamp);

CREATE INDEX idx_recents_phone_imei_date ON yphone_recents (phone_imei, date);

CREATE INDEX idx_twitter_likes_username ON yphone_twitter_likes (username);

CREATE INDEX idx_twitter_retweets_username ON yphone_twitter_retweets (username);

CREATE INDEX idx_twitter_follows_follower ON yphone_twitter_follows (follower);

CREATE INDEX idx_instashots_stories_username_timestamp_archived ON yphone_instashots_stories (username, timestamp, archived);

CREATE INDEX idx_instashots_likes_username_comment ON yphone_instashots_likes (username, is_comment);

CREATE INDEX idx_instashots_follows_follower ON yphone_instashots_follows (follower);

CREATE INDEX idx_companies_channels_company_phone ON yphone_companies_channels (company, phone_imei);

CREATE INDEX idx_messages_messages_channel_timestamp ON yphone_messages_messages (channel_id, timestamp);

CREATE INDEX idx_mails_phone_imei_timestamp ON yphone_mails (phone_imei, timestamp);

CREATE INDEX idx_twitter_tweets_username_timestamp ON yphone_twitter_tweets (username, timestamp);

CREATE INDEX idx_ycloud_accounts_phone_imei ON yphone_ycloud_accounts (phone_imei);

CREATE INDEX idx_gallery_phone_album ON yphone_gallery (phone_imei, album_id);

CREATE INDEX idx_ybuy_ads_phone_archived ON yphone_ybuy_ads (phone_imei, archived);