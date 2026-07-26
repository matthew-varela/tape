-- School affiliations and recruiter "saved players" lists.
--
-- School identity lives in a static catalog shipped with the clients (ESPN
-- team ids), so the database stores only the selected ids. That keeps the
-- picker instant and means adding or renaming a school never needs a
-- migration.

-- The program a recruiter coaches for. Null for athletes and brands.
ALTER TABLE users ADD COLUMN school_id VARCHAR(16);

-- An athlete's ranked shortlist of programs they want to play for.
-- sort_order is the @OrderColumn; "rank" and "position" are reserved words.
CREATE TABLE athlete_target_schools (
    user_id    VARCHAR(64) NOT NULL REFERENCES users (id),
    school_id  VARCHAR(16) NOT NULL,
    sort_order INTEGER     NOT NULL,
    PRIMARY KEY (user_id, sort_order)
);

CREATE INDEX idx_athlete_target_schools_user ON athlete_target_schools (user_id);

-- Recruiters and brands saving athletes for later, independent of the richer
-- named scouting boards.
CREATE TABLE saved_athletes (
    id         VARCHAR(64) PRIMARY KEY,
    scout_id   VARCHAR(64) NOT NULL REFERENCES users (id),
    athlete_id VARCHAR(64) NOT NULL REFERENCES users (id),
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT uk_saved_athletes_scout_athlete UNIQUE (scout_id, athlete_id)
);

CREATE INDEX idx_saved_athletes_scout ON saved_athletes (scout_id);
