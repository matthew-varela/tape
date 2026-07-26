-- Age gating: store each user's date of birth. Nullable so pre-existing
-- accounts remain valid; new signups always provide it (enforced at the API).
ALTER TABLE users ADD COLUMN date_of_birth DATE;
