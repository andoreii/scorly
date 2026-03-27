-- =============================================================
-- Add total_score column to rounds + import historical rounds
-- =============================================================

-- 1. Add total_score column (used for rounds imported without hole stats)
ALTER TABLE rounds ADD COLUMN IF NOT EXISTS total_score INT;

-- 2. Insert historical rounds
DO $$
DECLARE
    v_user_id       UUID;
    v_banyan_id     INT;
    v_taiyo_id      INT;
    v_gold_tee_id   INT;  -- Banyan Tree Gold (70.9 / 126)
    v_white_tee_id  INT;  -- Taiyo White (68.2 / 122)
BEGIN
    SELECT id INTO v_user_id FROM auth.users LIMIT 1;
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No user found in auth.users';
    END IF;

    -- Look up course IDs
    SELECT course_id INTO v_banyan_id
        FROM courses WHERE user_id = v_user_id AND course_name = 'Banyan Tree Golf Course' LIMIT 1;
    IF v_banyan_id IS NULL THEN
        RAISE EXCEPTION 'Banyan Tree Golf Course not found — run the course migration first';
    END IF;

    SELECT course_id INTO v_taiyo_id
        FROM courses WHERE user_id = v_user_id AND course_name ILIKE 'Taiyo%' LIMIT 1;
    IF v_taiyo_id IS NULL THEN
        RAISE EXCEPTION 'Taiyo Golf Club not found in courses';
    END IF;

    -- Look up tee IDs
    SELECT tee_id INTO v_gold_tee_id
        FROM tees WHERE course_id = v_banyan_id AND tee_name = 'Gold' LIMIT 1;

    SELECT tee_id INTO v_white_tee_id
        FROM tees WHERE course_id = v_taiyo_id AND tee_name = 'White' LIMIT 1;

    -- ---------------------------------------------------------------
    -- Banyan Tree — Gold tees (70.9 / 126)
    -- ---------------------------------------------------------------
    INSERT INTO rounds (user_id, course_id, tee_id, date_played, holes_played, round_type, round_format, total_score, whs_differential)
    VALUES
        (v_user_id, v_banyan_id, v_gold_tee_id, '2026-03-08', '18', 'Casual',     'Stroke', 95, 21.6),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2026-02-21', '18', 'Casual',     'Stroke', 84, 11.7),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2026-02-01', '18', 'Casual',     'Stroke', 81,  9.1),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2026-01-19', '18', 'Casual',     'Stroke', 88, 15.3),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2026-01-18', '18', 'Casual',     'Stroke', 83, 10.9),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2026-01-11', '18', 'Casual',     'Stroke', 85, 12.6),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2026-01-04', '18', 'Casual',     'Stroke', 88, 15.3),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2025-12-07', '18', 'Casual',     'Stroke', 83, 10.9),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2025-12-06', '18', 'Tournament', 'Stroke', 78,  6.4),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2025-11-30', '18', 'Casual',     'Stroke', 93, 19.8),
        (v_user_id, v_banyan_id, v_gold_tee_id, '2025-10-30', '18', 'Casual',     'Stroke', 83, 10.9)
    ON CONFLICT (round_external_id) DO NOTHING;

    -- ---------------------------------------------------------------
    -- Taiyo Golf Club — White tees (68.2 / 122)
    -- ---------------------------------------------------------------
    INSERT INTO rounds (user_id, course_id, tee_id, date_played, holes_played, round_type, round_format, total_score, whs_differential)
    VALUES
        (v_user_id, v_taiyo_id, v_white_tee_id, '2026-01-03', '18', 'Casual', 'Stroke', 86, 16.5),
        (v_user_id, v_taiyo_id, v_white_tee_id, '2025-12-27', '18', 'Casual', 'Stroke', 82, 12.8),
        (v_user_id, v_taiyo_id, v_white_tee_id, '2025-12-20', '18', 'Casual', 'Stroke', 84, 14.6),
        (v_user_id, v_taiyo_id, v_white_tee_id, '2025-11-01', '18', 'Casual', 'Stroke', 85, 13.7)
    ON CONFLICT (round_external_id) DO NOTHING;

END $$;
