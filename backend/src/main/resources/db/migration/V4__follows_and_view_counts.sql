-- Social graph (follows) and per-video view counters.

CREATE TABLE follows (
    id          VARCHAR(64) PRIMARY KEY,
    follower_id VARCHAR(64) NOT NULL REFERENCES users (id),
    followee_id VARCHAR(64) NOT NULL REFERENCES users (id),
    created_at  TIMESTAMPTZ NOT NULL,
    CONSTRAINT uk_follows_follower_followee UNIQUE (follower_id, followee_id)
);

CREATE INDEX idx_follows_follower ON follows (follower_id);
CREATE INDEX idx_follows_followee ON follows (followee_id);

-- Existing rows start at zero; the column is NOT NULL so the entity can map it
-- as a primitive long.
ALTER TABLE videos ADD COLUMN view_count BIGINT NOT NULL DEFAULT 0;
