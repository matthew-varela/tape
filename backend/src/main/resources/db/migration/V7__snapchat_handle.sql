-- Optional Snapchat handle shown as a profile link icon.
-- Empty / null means the Snapchat icon is hidden on the client.

ALTER TABLE users ADD COLUMN snapchat_handle VARCHAR(64);
