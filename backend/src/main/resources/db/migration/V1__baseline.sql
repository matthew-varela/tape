-- Baseline schema for the Tape API (PostgreSQL).
--
-- This mirrors the JPA entities under com.tape.api.entity as of the first
-- production release. Column names follow Hibernate's default
-- CamelCaseToUnderscores physical naming strategy, and java.time.Instant
-- fields map to timestamptz (Hibernate 6 TIMESTAMP_UTC), so the app can run
-- with spring.jpa.hibernate.ddl-auto=validate against this schema.
--
-- All subsequent schema changes MUST be added as new V2__*, V3__*, ...
-- migrations rather than editing this file.

CREATE TABLE users (
    id                   VARCHAR(64)  PRIMARY KEY,
    email                VARCHAR(255) UNIQUE,
    display_name         VARCHAR(255) NOT NULL,
    role                 VARCHAR(16)  NOT NULL,
    tier                 VARCHAR(8)   NOT NULL,
    profile_image_url    VARCHAR(255),
    high_school          VARCHAR(255),
    grad_year            INTEGER,
    sport                VARCHAR(255),
    position             VARCHAR(255),
    state                VARCHAR(255),
    height               VARCHAR(255),
    weight               VARCHAR(255),
    forty_yard_dash      VARCHAR(255),
    gpa                  FLOAT8,
    organization         VARCHAR(255),
    title                VARCHAR(255),
    dms_sent_this_month  INTEGER      NOT NULL,
    created_at           TIMESTAMPTZ  NOT NULL
);

CREATE TABLE videos (
    id            VARCHAR(64)  PRIMARY KEY,
    athlete_id    VARCHAR(64)  NOT NULL REFERENCES users (id),
    video_url     VARCHAR(255) NOT NULL,
    thumbnail_url VARCHAR(255),
    category      VARCHAR(16)  NOT NULL,
    caption       VARCHAR(255),
    created_at    TIMESTAMPTZ  NOT NULL,
    is_pinned     BOOLEAN      NOT NULL
);

CREATE TABLE video_tags (
    video_id VARCHAR(64) NOT NULL REFERENCES videos (id),
    tag      VARCHAR(255)
);

CREATE TABLE bookmarks (
    id         VARCHAR(64) PRIMARY KEY,
    user_id    VARCHAR(64) NOT NULL REFERENCES users (id),
    video_id   VARCHAR(64) NOT NULL REFERENCES videos (id),
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT uk_bookmarks_user_video UNIQUE (user_id, video_id)
);

CREATE TABLE conversations (
    id                VARCHAR(64)   PRIMARY KEY,
    participant1_id   VARCHAR(64)   NOT NULL REFERENCES users (id),
    participant2_id   VARCHAR(64)   NOT NULL REFERENCES users (id),
    last_message      VARCHAR(1000),
    last_message_date TIMESTAMPTZ,
    initiated_by_role VARCHAR(16)   NOT NULL,
    created_at        TIMESTAMPTZ   NOT NULL
);

CREATE TABLE messages (
    id              VARCHAR(64)   PRIMARY KEY,
    conversation_id VARCHAR(64)   NOT NULL REFERENCES conversations (id),
    sender_id       VARCHAR(64)   NOT NULL REFERENCES users (id),
    text            VARCHAR(2000) NOT NULL,
    sent_at         TIMESTAMPTZ   NOT NULL,
    is_read         BOOLEAN       NOT NULL
);

CREATE TABLE profile_views (
    id             VARCHAR(64) PRIMARY KEY,
    viewed_user_id VARCHAR(64) NOT NULL REFERENCES users (id),
    viewer_user_id VARCHAR(64) NOT NULL REFERENCES users (id),
    viewed_at      TIMESTAMPTZ NOT NULL
);

CREATE TABLE scouting_boards (
    id         VARCHAR(64)  PRIMARY KEY,
    owner_id   VARCHAR(64)  NOT NULL REFERENCES users (id),
    name       VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL
);

CREATE TABLE scouting_board_athletes (
    board_id   VARCHAR(64) NOT NULL REFERENCES scouting_boards (id),
    athlete_id VARCHAR(64) NOT NULL REFERENCES users (id)
);

CREATE TABLE subscriptions (
    id         VARCHAR(64)  PRIMARY KEY,
    user_id    VARCHAR(64)  NOT NULL UNIQUE REFERENCES users (id),
    platform   VARCHAR(255),
    provider   VARCHAR(255),
    active     BOOLEAN      NOT NULL,
    updated_at TIMESTAMPTZ  NOT NULL
);

-- Helpful indexes for the most common lookups (feed, search, messaging).
CREATE INDEX idx_videos_athlete       ON videos (athlete_id);
CREATE INDEX idx_videos_created_at    ON videos (created_at);
CREATE INDEX idx_bookmarks_user       ON bookmarks (user_id);
CREATE INDEX idx_messages_conversation ON messages (conversation_id);
CREATE INDEX idx_conversations_p1     ON conversations (participant1_id);
CREATE INDEX idx_conversations_p2     ON conversations (participant2_id);
CREATE INDEX idx_profile_views_viewed ON profile_views (viewed_user_id);
