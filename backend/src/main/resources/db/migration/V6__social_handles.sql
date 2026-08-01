-- Optional Instagram / TikTok handles shown as profile link icons.
-- Empty / null means the corresponding icon is hidden on the client.

ALTER TABLE users ADD COLUMN instagram_handle VARCHAR(64);
ALTER TABLE users ADD COLUMN tiktok_handle VARCHAR(64);
