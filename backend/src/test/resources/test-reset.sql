-- Truncate all tables in FK-safe order for H2 test database.
-- Used by @Sql(scripts = "/test-reset.sql") before each test.
DELETE FROM reports;
DELETE FROM blocks;
DELETE FROM follows;
DELETE FROM saved_athletes;
DELETE FROM athlete_target_schools;
DELETE FROM scouting_board_athletes;
DELETE FROM scouting_boards;
DELETE FROM bookmarks;
DELETE FROM video_tags;
DELETE FROM videos;
DELETE FROM messages;
DELETE FROM conversations;
DELETE FROM profile_views;
DELETE FROM subscriptions;
DELETE FROM users;
