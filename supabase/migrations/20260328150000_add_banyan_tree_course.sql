-- =============================================================
-- Add Banyan Tree Golf Course — Kadena Airbase, Okinawa, Japan
-- Par 72 (35 out / 37 in), 4 tee sets, 18 holes
-- =============================================================

DO $$
DECLARE
    v_user_id UUID;
    v_course_id INT;
    v_black_tee_id INT;
    v_gold_tee_id INT;
    v_silver_tee_id INT;
    v_bronze_tee_id INT;
BEGIN
    -- Look up the single app user
    SELECT id INTO v_user_id FROM auth.users LIMIT 1;
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No user found in auth.users';
    END IF;

    -- 1. Course
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Banyan Tree Golf Course', 'Kadena Airbase, Okinawa, Japan')
    RETURNING course_id INTO v_course_id;

    -- 2. Holes
    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index) VALUES
        (v_course_id,  1, 4, 15),
        (v_course_id,  2, 5, 17),
        (v_course_id,  3, 4,  3),
        (v_course_id,  4, 3, 11),
        (v_course_id,  5, 4,  7),
        (v_course_id,  6, 3,  5),
        (v_course_id,  7, 4,  1),
        (v_course_id,  8, 4, 13),
        (v_course_id,  9, 4,  9),
        (v_course_id, 10, 5,  6),
        (v_course_id, 11, 4,  4),
        (v_course_id, 12, 3,  8),
        (v_course_id, 13, 4, 10),
        (v_course_id, 14, 3, 16),
        (v_course_id, 15, 4, 14),
        (v_course_id, 16, 5, 18),
        (v_course_id, 17, 5,  2),
        (v_course_id, 18, 4, 12);

    -- 3. Tees (Men's ratings)
    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Black', 72.6, 130, 6704)
    RETURNING tee_id INTO v_black_tee_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Gold', 70.9, 126, 6341)
    RETURNING tee_id INTO v_gold_tee_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Silver', 67.6, 120, 5640)
    RETURNING tee_id INTO v_silver_tee_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Bronze', 63.7, 104, 4799)
    RETURNING tee_id INTO v_bronze_tee_id;

    -- 4. Tee-hole yardages
    -- Black tees
    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_black_tee_id,  1, 340),
        (v_black_tee_id,  2, 526),
        (v_black_tee_id,  3, 372),
        (v_black_tee_id,  4, 186),
        (v_black_tee_id,  5, 385),
        (v_black_tee_id,  6, 206),
        (v_black_tee_id,  7, 414),
        (v_black_tee_id,  8, 415),
        (v_black_tee_id,  9, 376),
        (v_black_tee_id, 10, 592),
        (v_black_tee_id, 11, 456),
        (v_black_tee_id, 12, 192),
        (v_black_tee_id, 13, 368),
        (v_black_tee_id, 14, 156),
        (v_black_tee_id, 15, 345),
        (v_black_tee_id, 16, 530),
        (v_black_tee_id, 17, 476),
        (v_black_tee_id, 18, 369);

    -- Gold tees
    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_gold_tee_id,  1, 312),
        (v_gold_tee_id,  2, 476),
        (v_gold_tee_id,  3, 353),
        (v_gold_tee_id,  4, 176),
        (v_gold_tee_id,  5, 373),
        (v_gold_tee_id,  6, 190),
        (v_gold_tee_id,  7, 401),
        (v_gold_tee_id,  8, 405),
        (v_gold_tee_id,  9, 363),
        (v_gold_tee_id, 10, 581),
        (v_gold_tee_id, 11, 415),
        (v_gold_tee_id, 12, 180),
        (v_gold_tee_id, 13, 349),
        (v_gold_tee_id, 14, 146),
        (v_gold_tee_id, 15, 338),
        (v_gold_tee_id, 16, 500),
        (v_gold_tee_id, 17, 440),
        (v_gold_tee_id, 18, 343);

    -- Silver tees
    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_silver_tee_id,  1, 293),
        (v_silver_tee_id,  2, 426),
        (v_silver_tee_id,  3, 304),
        (v_silver_tee_id,  4, 118),
        (v_silver_tee_id,  5, 309),
        (v_silver_tee_id,  6, 155),
        (v_silver_tee_id,  7, 358),
        (v_silver_tee_id,  8, 390),
        (v_silver_tee_id,  9, 333),
        (v_silver_tee_id, 10, 503),
        (v_silver_tee_id, 11, 362),
        (v_silver_tee_id, 12, 164),
        (v_silver_tee_id, 13, 320),
        (v_silver_tee_id, 14, 121),
        (v_silver_tee_id, 15, 292),
        (v_silver_tee_id, 16, 455),
        (v_silver_tee_id, 17, 410),
        (v_silver_tee_id, 18, 327);

    -- Bronze tees
    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_bronze_tee_id,  1, 210),
        (v_bronze_tee_id,  2, 405),
        (v_bronze_tee_id,  3, 231),
        (v_bronze_tee_id,  4, 100),
        (v_bronze_tee_id,  5, 246),
        (v_bronze_tee_id,  6, 113),
        (v_bronze_tee_id,  7, 318),
        (v_bronze_tee_id,  8, 370),
        (v_bronze_tee_id,  9, 277),
        (v_bronze_tee_id, 10, 452),
        (v_bronze_tee_id, 11, 317),
        (v_bronze_tee_id, 12, 130),
        (v_bronze_tee_id, 13, 274),
        (v_bronze_tee_id, 14,  93),
        (v_bronze_tee_id, 15, 258),
        (v_bronze_tee_id, 16, 363),
        (v_bronze_tee_id, 17, 350),
        (v_bronze_tee_id, 18, 292);
END $$;
