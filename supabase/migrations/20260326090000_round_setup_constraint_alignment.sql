-- Align round setup constraints with the values currently saved by the app.

ALTER TABLE rounds
    DROP CONSTRAINT IF EXISTS rounds_round_type;

ALTER TABLE rounds
    ADD CONSTRAINT rounds_round_type
        CHECK (round_type IS NULL OR round_type IN ('Practice', 'Tournament', 'Casual', 'Competitive'));

ALTER TABLE rounds
    DROP CONSTRAINT IF EXISTS rounds_round_format;

ALTER TABLE rounds
    ADD CONSTRAINT rounds_round_format
        CHECK (
            round_format IS NULL
            OR round_format IN ('Stroke', 'Stroke Play', 'Match', 'Match Play', 'Scramble', 'Stableford', 'Other')
        );
