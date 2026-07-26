-- Moderation: user blocking and content reporting (App Store UGC compliance).

CREATE TABLE blocks (
    id         VARCHAR(64) PRIMARY KEY,
    blocker_id VARCHAR(64) NOT NULL REFERENCES users (id),
    blocked_id VARCHAR(64) NOT NULL REFERENCES users (id),
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT uk_blocks_blocker_blocked UNIQUE (blocker_id, blocked_id)
);

CREATE INDEX idx_blocks_blocker ON blocks (blocker_id);
CREATE INDEX idx_blocks_blocked ON blocks (blocked_id);

CREATE TABLE reports (
    id          VARCHAR(64)   PRIMARY KEY,
    reporter_id VARCHAR(64)   NOT NULL REFERENCES users (id),
    target_type VARCHAR(16)   NOT NULL,
    target_id   VARCHAR(64)   NOT NULL,
    reason      VARCHAR(255)  NOT NULL,
    details     VARCHAR(2000),
    created_at  TIMESTAMPTZ   NOT NULL
);

CREATE INDEX idx_reports_target ON reports (target_type, target_id);
