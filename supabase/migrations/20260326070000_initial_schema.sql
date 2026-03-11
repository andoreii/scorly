-- =============================================================
-- Golf Statistics App — Initial Schema
-- =============================================================

-- ---------------------------------------------------------------
-- users
-- ---------------------------------------------------------------
CREATE TABLE users (
    id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    handicap_index NUMERIC(4,1),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users: own row only"
    ON users FOR ALL
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- User profile row is created by the iOS app after sign-up (AuthService.signUp).

-- ---------------------------------------------------------------
-- courses
-- ---------------------------------------------------------------
CREATE TABLE courses (
    course_id   SERIAL PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    course_name TEXT NOT NULL,
    location    TEXT,
    notes       TEXT,
    color_theme TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX courses_name_per_user ON courses (user_id, course_name);

ALTER TABLE courses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "courses: own rows only"
    ON courses FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------
-- tees
-- ---------------------------------------------------------------
CREATE TABLE tees (
    tee_id        SERIAL PRIMARY KEY,
    course_id     INT NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    tee_name      TEXT NOT NULL,
    course_rating NUMERIC(4,1),
    slope_rating  NUMERIC(4,1),
    yardage       INT,
    UNIQUE (course_id, tee_name)
);

ALTER TABLE tees ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tees: via course ownership"
    ON tees FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM courses
            WHERE courses.course_id = tees.course_id
              AND courses.user_id = auth.uid()
        )
    );

-- ---------------------------------------------------------------
-- holes
-- ---------------------------------------------------------------
CREATE TABLE holes (
    hole_id             SERIAL PRIMARY KEY,
    course_id           INT NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    hole_number         INT NOT NULL,
    par                 INT NOT NULL,
    hole_handicap_index INT,
    UNIQUE (course_id, hole_number),
    CONSTRAINT holes_number_range    CHECK (hole_number BETWEEN 1 AND 18),
    CONSTRAINT holes_par_range       CHECK (par BETWEEN 3 AND 5),
    CONSTRAINT holes_hcp_range       CHECK (hole_handicap_index BETWEEN 1 AND 18)
);

ALTER TABLE holes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "holes: via course ownership"
    ON holes FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM courses
            WHERE courses.course_id = holes.course_id
              AND courses.user_id = auth.uid()
        )
    );

-- ---------------------------------------------------------------
-- tee_holes  (per-tee, per-hole yardages)
-- ---------------------------------------------------------------
CREATE TABLE tee_holes (
    tee_hole_id SERIAL PRIMARY KEY,
    tee_id      INT NOT NULL REFERENCES tees(tee_id) ON DELETE CASCADE,
    hole_number INT NOT NULL,
    yardage     INT NOT NULL,
    UNIQUE (tee_id, hole_number),
    CONSTRAINT tee_holes_number_range  CHECK (hole_number BETWEEN 1 AND 18),
    CONSTRAINT tee_holes_yardage_range CHECK (yardage BETWEEN 50 AND 800)
);

ALTER TABLE tee_holes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tee_holes: via course ownership"
    ON tee_holes FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM tees
            JOIN courses ON courses.course_id = tees.course_id
            WHERE tees.tee_id = tee_holes.tee_id
              AND courses.user_id = auth.uid()
        )
    );

-- ---------------------------------------------------------------
-- rounds
-- ---------------------------------------------------------------
CREATE TABLE rounds (
    round_id          SERIAL PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    course_id         INT  NOT NULL REFERENCES courses(course_id) ON DELETE RESTRICT,
    tee_id            INT  REFERENCES tees(tee_id) ON DELETE SET NULL,
    date_played       DATE NOT NULL,
    holes_played      TEXT NOT NULL,
    round_type        TEXT,
    round_format      TEXT,
    conditions        TEXT,
    walking_vs_riding TEXT,
    time_of_day       TEXT,
    mental_state      INT,
    round_external_id TEXT UNIQUE,
    notes             TEXT,
    whs_differential  NUMERIC(4,1),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT rounds_holes_played    CHECK (holes_played IN ('Front 9', 'Back 9', '18')),
    CONSTRAINT rounds_round_type      CHECK (round_type IN ('Practice', 'Tournament', 'Casual')),
    CONSTRAINT rounds_round_format    CHECK (round_format IN ('Stroke', 'Match', 'Scramble', 'Other')),
    CONSTRAINT rounds_conditions      CHECK (conditions IN ('Sunny', 'Cloudy', 'Windy', 'Rainy')),
    CONSTRAINT rounds_transport       CHECK (walking_vs_riding IN ('Walking', 'Riding', 'Push Cart', 'Mixed')),
    CONSTRAINT rounds_time_of_day     CHECK (time_of_day IN ('Early Morning', 'Morning', 'Afternoon', 'Evening', 'Twilight')),
    CONSTRAINT rounds_mental_state    CHECK (mental_state BETWEEN 1 AND 10)
);

CREATE INDEX rounds_date_idx    ON rounds (date_played);
CREATE INDEX rounds_user_idx    ON rounds (user_id);
CREATE INDEX rounds_course_idx  ON rounds (course_id);

ALTER TABLE rounds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rounds: own rows only"
    ON rounds FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------
-- hole_stats
-- ---------------------------------------------------------------
CREATE TABLE hole_stats (
    hole_stat_id        SERIAL PRIMARY KEY,
    round_id            INT  NOT NULL REFERENCES rounds(round_id) ON DELETE CASCADE,
    hole_number         INT  NOT NULL,
    strokes             INT  NOT NULL,
    putts               INT  NOT NULL,
    tee_shot            TEXT,
    approach            TEXT,
    tee_club            TEXT,
    approach_club       TEXT,
    out_of_bounds_count INT  NOT NULL DEFAULT 0,
    penalty_strokes     INT  NOT NULL DEFAULT 0,
    hazard_count        INT  NOT NULL DEFAULT 0,
    green_in_reg        BOOLEAN,
    three_putt          BOOLEAN,
    gir_opportunity     BOOLEAN,
    fairway_opportunity BOOLEAN,
    up_and_down_success BOOLEAN,
    sand_save_success   BOOLEAN,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (round_id, hole_number),
    CONSTRAINT hole_stats_hole_number  CHECK (hole_number BETWEEN 1 AND 18),
    CONSTRAINT hole_stats_strokes      CHECK (strokes BETWEEN 1 AND 15),
    CONSTRAINT hole_stats_putts        CHECK (putts BETWEEN 0 AND 6),
    CONSTRAINT hole_stats_oob          CHECK (out_of_bounds_count BETWEEN 0 AND 5),
    CONSTRAINT hole_stats_penalties    CHECK (penalty_strokes BETWEEN 0 AND 10),
    CONSTRAINT hole_stats_hazards      CHECK (hazard_count BETWEEN 0 AND 10),
    CONSTRAINT hole_stats_tee_shot CHECK (tee_shot IN (
        'Fairway', 'Left', 'Right', 'Short', 'Long',
        'Out Left', 'Out Right', 'Out Short', 'Out Long',
        'Bunker Left', 'Bunker Right', 'Bunker Short', 'Bunker Long', 'Green'
    )),
    CONSTRAINT hole_stats_approach CHECK (approach IN (
        'Green', 'Left', 'Right', 'Short', 'Long',
        'Out Left', 'Out Right', 'Out Short', 'Out Long',
        'Bunker Left', 'Bunker Right', 'Bunker Short', 'Bunker Long', 'N/A'
    ))
);

ALTER TABLE hole_stats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "hole_stats: via round ownership"
    ON hole_stats FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM rounds
            WHERE rounds.round_id = hole_stats.round_id
              AND rounds.user_id = auth.uid()
        )
    );
