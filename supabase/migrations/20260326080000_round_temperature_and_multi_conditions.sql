-- Add round temperature and allow storing multiple conditions from the setup UI.

ALTER TABLE rounds
    ADD COLUMN IF NOT EXISTS temperature INT;

ALTER TABLE rounds
    DROP CONSTRAINT IF EXISTS rounds_conditions;

ALTER TABLE rounds
    ADD CONSTRAINT rounds_temperature
        CHECK (temperature IS NULL OR temperature BETWEEN -50 AND 150);
