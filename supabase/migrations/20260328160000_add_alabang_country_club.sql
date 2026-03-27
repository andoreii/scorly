-- =============================================================
-- Add Alabang Country Club — Alabang, Muntinlupa, Philippines
-- Par 72 (36 out / 36 in), 4 tee sets, 18 holes
-- =============================================================

DO $$
DECLARE
    v_user_id UUID;
    v_course_id INT;
    v_gold_tee_id INT;
    v_blue_tee_id INT;
    v_white_tee_id INT;
    v_red_tee_id INT;
BEGIN
    SELECT id INTO v_user_id FROM auth.users LIMIT 1;
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No user found in auth.users';
    END IF;

    -- 1. Course
    INSERT INTO courses (user_id, course_name, location)
    VALUES (v_user_id, 'Alabang Country Club', 'Alabang, Muntinlupa, Philippines')
    RETURNING course_id INTO v_course_id;

    -- 2. Holes (men's handicap index)
    INSERT INTO holes (course_id, hole_number, par, hole_handicap_index) VALUES
        (v_course_id,  1, 4, 17),
        (v_course_id,  2, 4, 13),
        (v_course_id,  3, 5,  5),
        (v_course_id,  4, 4,  1),
        (v_course_id,  5, 4,  7),
        (v_course_id,  6, 3, 15),
        (v_course_id,  7, 5,  3),
        (v_course_id,  8, 3, 11),
        (v_course_id,  9, 4,  9),
        (v_course_id, 10, 4,  2),
        (v_course_id, 11, 4,  8),
        (v_course_id, 12, 3, 18),
        (v_course_id, 13, 5, 16),
        (v_course_id, 14, 4, 12),
        (v_course_id, 15, 3, 14),
        (v_course_id, 16, 4,  4),
        (v_course_id, 17, 4,  6),
        (v_course_id, 18, 5, 10);

    -- 3. Tees (men's ratings)
    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Gold', 73.0, 140, 6932)
    RETURNING tee_id INTO v_gold_tee_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Blue', 71.6, 133, 6454)
    RETURNING tee_id INTO v_blue_tee_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'White', 68.7, 117, 5975)
    RETURNING tee_id INTO v_white_tee_id;

    INSERT INTO tees (course_id, tee_name, course_rating, slope_rating, yardage)
    VALUES (v_course_id, 'Red', 66.1, 109, 5375)
    RETURNING tee_id INTO v_red_tee_id;

    -- 4. Tee-hole yardages
    -- Gold tees
    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_gold_tee_id,  1, 360),
        (v_gold_tee_id,  2, 380),
        (v_gold_tee_id,  3, 521),
        (v_gold_tee_id,  4, 439),
        (v_gold_tee_id,  5, 351),
        (v_gold_tee_id,  6, 185),
        (v_gold_tee_id,  7, 558),
        (v_gold_tee_id,  8, 203),
        (v_gold_tee_id,  9, 402),
        (v_gold_tee_id, 10, 465),
        (v_gold_tee_id, 11, 358),
        (v_gold_tee_id, 12, 162),
        (v_gold_tee_id, 13, 515),
        (v_gold_tee_id, 14, 375),
        (v_gold_tee_id, 15, 210),
        (v_gold_tee_id, 16, 480),
        (v_gold_tee_id, 17, 424),
        (v_gold_tee_id, 18, 544);

    -- Blue tees
    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_blue_tee_id,  1, 330),
        (v_blue_tee_id,  2, 355),
        (v_blue_tee_id,  3, 502),
        (v_blue_tee_id,  4, 419),
        (v_blue_tee_id,  5, 333),
        (v_blue_tee_id,  6, 156),
        (v_blue_tee_id,  7, 531),
        (v_blue_tee_id,  8, 174),
        (v_blue_tee_id,  9, 382),
        (v_blue_tee_id, 10, 432),
        (v_blue_tee_id, 11, 325),
        (v_blue_tee_id, 12, 148),
        (v_blue_tee_id, 13, 497),
        (v_blue_tee_id, 14, 358),
        (v_blue_tee_id, 15, 184),
        (v_blue_tee_id, 16, 437),
        (v_blue_tee_id, 17, 381),
        (v_blue_tee_id, 18, 510);

    -- White tees
    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_white_tee_id,  1, 313),
        (v_white_tee_id,  2, 326),
        (v_white_tee_id,  3, 476),
        (v_white_tee_id,  4, 393),
        (v_white_tee_id,  5, 305),
        (v_white_tee_id,  6, 132),
        (v_white_tee_id,  7, 499),
        (v_white_tee_id,  8, 149),
        (v_white_tee_id,  9, 361),
        (v_white_tee_id, 10, 410),
        (v_white_tee_id, 11, 307),
        (v_white_tee_id, 12, 136),
        (v_white_tee_id, 13, 473),
        (v_white_tee_id, 14, 326),
        (v_white_tee_id, 15, 153),
        (v_white_tee_id, 16, 392),
        (v_white_tee_id, 17, 354),
        (v_white_tee_id, 18, 470);

    -- Red tees
    INSERT INTO tee_holes (tee_id, hole_number, yardage) VALUES
        (v_red_tee_id,  1, 292),
        (v_red_tee_id,  2, 297),
        (v_red_tee_id,  3, 420),
        (v_red_tee_id,  4, 340),
        (v_red_tee_id,  5, 277),
        (v_red_tee_id,  6, 117),
        (v_red_tee_id,  7, 475),
        (v_red_tee_id,  8, 128),
        (v_red_tee_id,  9, 318),
        (v_red_tee_id, 10, 389),
        (v_red_tee_id, 11, 277),
        (v_red_tee_id, 12, 117),
        (v_red_tee_id, 13, 446),
        (v_red_tee_id, 14, 280),
        (v_red_tee_id, 15, 116),
        (v_red_tee_id, 16, 356),
        (v_red_tee_id, 17, 309),
        (v_red_tee_id, 18, 421);
END $$;
