-- =============================================================
-- Migration & Career Support System
-- File        : 03_functions.sql
-- Description : User-Defined Functions (UDFs) — PL/pgSQL
-- Run after   : 01_schema.sql
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- FUNCTION 1: fn_set_updated_at()
-- Purpose   : Shared TRIGGER function that sets updated_at = NOW()
-- Used by   : All updated_at triggers in 05_triggers.sql
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- FUNCTION 2: fn_profile_completeness(p_user_id INT)
-- Returns   : SMALLINT  0–100
-- Purpose   : Scores profile completeness across 5 dimensions.
--             Each dimension = 20 points.
--   Dim 1 (+20): Basic fields — first/last name + nationality + bio
--   Dim 2 (+20): At least one education record
--   Dim 3 (+20): At least one work experience record
--   Dim 4 (+20): At least 3 skills
--   Dim 5 (+20): At least one language with a test score
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_profile_completeness(p_user_id INT)
RETURNS SMALLINT LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_has_basic   BOOLEAN := FALSE;
    v_has_edu     BOOLEAN := FALSE;
    v_has_exp     BOOLEAN := FALSE;
    v_has_skills  BOOLEAN := FALSE;
    v_has_langs   BOOLEAN := FALSE;
    v_score       SMALLINT := 0;
BEGIN
    SELECT (
        first_name IS NOT NULL AND
        last_name  IS NOT NULL AND
        nationality_country_id IS NOT NULL AND
        bio IS NOT NULL
    ) INTO v_has_basic
    FROM user_profiles WHERE user_id = p_user_id;

    SELECT EXISTS(SELECT 1 FROM user_education WHERE user_id = p_user_id AND is_completed = TRUE)
    INTO v_has_edu;

    SELECT EXISTS(SELECT 1 FROM user_work_experience WHERE user_id = p_user_id)
    INTO v_has_exp;

    SELECT COUNT(*) >= 3 INTO v_has_skills
    FROM user_skills WHERE user_id = p_user_id;

    SELECT EXISTS(SELECT 1 FROM user_languages WHERE user_id = p_user_id AND test_score IS NOT NULL)
    INTO v_has_langs;

    v_score :=
        CASE WHEN v_has_basic  THEN 20 ELSE 0 END +
        CASE WHEN v_has_edu    THEN 20 ELSE 0 END +
        CASE WHEN v_has_exp    THEN 20 ELSE 0 END +
        CASE WHEN v_has_skills THEN 20 ELSE 0 END +
        CASE WHEN v_has_langs  THEN 20 ELSE 0 END;

    RETURN v_score;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- FUNCTION 3: fn_calculate_immigration_score(p_user_id, p_program_id)
-- Returns   : SMALLINT  0–100
-- Scoring model (university demonstration):
--   Education   → up to 40 pts  (rank_order × 7, capped at 40)
--   Language    → up to 40 pts  (IELTS band / 9.0 × 40)
--   Work Exp    → up to 20 pts  (years × 4, capped at 20)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_calculate_immigration_score(
    p_user_id    INT,
    p_program_id INT
)
RETURNS SMALLINT LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_edu_rank   SMALLINT := 0;
    v_lang_score NUMERIC  := 0;
    v_work_yrs   NUMERIC  := 0;
    v_edu_pts    SMALLINT := 0;
    v_lang_pts   SMALLINT := 0;
    v_work_pts   SMALLINT := 0;
BEGIN
    -- Highest completed education level
    SELECT COALESCE(MAX(el.rank_order), 0)
    INTO v_edu_rank
    FROM user_education ue
    JOIN education_levels el ON el.level_id = ue.level_id
    WHERE ue.user_id = p_user_id AND ue.is_completed = TRUE;

    v_edu_pts := LEAST((v_edu_rank * 7)::SMALLINT, 40);

    -- Best IELTS score (overall band, max 9.0)
    SELECT COALESCE(MAX(test_score), 0)
    INTO v_lang_score
    FROM user_languages
    WHERE user_id = p_user_id AND test_type = 'IELTS';

    v_lang_pts := LEAST(ROUND(v_lang_score / 9.0 * 40)::SMALLINT, 40);

    -- Total years of work experience
    SELECT COALESCE(SUM(
        EXTRACT(YEAR  FROM AGE(COALESCE(end_date, CURRENT_DATE), start_date)) +
        EXTRACT(MONTH FROM AGE(COALESCE(end_date, CURRENT_DATE), start_date)) / 12.0
    ), 0)
    INTO v_work_yrs
    FROM user_work_experience
    WHERE user_id = p_user_id;

    v_work_pts := LEAST((v_work_yrs * 4)::SMALLINT, 20);

    RETURN LEAST(v_edu_pts + v_lang_pts + v_work_pts, 100);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- FUNCTION 4: fn_get_job_match_score(p_user_id, p_job_id)
-- Returns   : NUMERIC(5,2)  0.00–100.00
-- Logic     : Weighted skill match.
--             Required skill matched  → weight 2
--             Required skill missing  → weight 2 unearned
--             Optional skill matched  → weight 1
--             Optional skill missing  → weight 1 unearned
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_get_job_match_score(
    p_user_id INT,
    p_job_id  INT
)
RETURNS NUMERIC(5,2) LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_total_w   NUMERIC := 0;
    v_matched_w NUMERIC := 0;
BEGIN
    SELECT
        COALESCE(SUM(CASE WHEN js.is_required THEN 2 ELSE 1 END), 0),
        COALESCE(SUM(
            CASE
                WHEN us.skill_id IS NOT NULL AND (
                    CASE us.proficiency
                        WHEN 'expert'       THEN 4
                        WHEN 'advanced'     THEN 3
                        WHEN 'intermediate' THEN 2
                        ELSE 1
                    END
                    >=
                    CASE js.min_proficiency
                        WHEN 'expert'       THEN 4
                        WHEN 'advanced'     THEN 3
                        WHEN 'intermediate' THEN 2
                        ELSE 1
                    END
                ) THEN CASE WHEN js.is_required THEN 2 ELSE 1 END
                ELSE 0
            END
        ), 0)
    INTO v_total_w, v_matched_w
    FROM job_skills js
    LEFT JOIN user_skills us
           ON us.skill_id = js.skill_id AND us.user_id = p_user_id
    WHERE js.job_id = p_job_id;

    IF v_total_w = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND((v_matched_w / v_total_w) * 100, 2);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- FUNCTION 5: fn_check_skill_gap(p_user_id, p_job_id)
-- Returns   : TABLE  — one row per job skill with gap_type:
--             'MET' | 'INSUFFICIENT' | 'MISSING'
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_check_skill_gap(
    p_user_id INT,
    p_job_id  INT
)
RETURNS TABLE (
    skill_name           TEXT,
    is_required          BOOLEAN,
    required_proficiency TEXT,
    user_proficiency     TEXT,
    gap_type             TEXT
) LANGUAGE plpgsql STABLE AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.name::TEXT,
        js.is_required,
        js.min_proficiency::TEXT,
        us.proficiency::TEXT,
        CASE
            WHEN us.skill_id IS NULL THEN 'MISSING'
            WHEN (
                CASE us.proficiency
                    WHEN 'expert'       THEN 4
                    WHEN 'advanced'     THEN 3
                    WHEN 'intermediate' THEN 2
                    ELSE 1 END
                <
                CASE js.min_proficiency
                    WHEN 'expert'       THEN 4
                    WHEN 'advanced'     THEN 3
                    WHEN 'intermediate' THEN 2
                    ELSE 1 END
            ) THEN 'INSUFFICIENT'
            ELSE 'MET'
        END
    FROM job_skills js
    JOIN skills s ON s.skill_id = js.skill_id
    LEFT JOIN user_skills us
           ON us.skill_id = js.skill_id AND us.user_id = p_user_id
    WHERE js.job_id = p_job_id
    ORDER BY js.is_required DESC, s.name;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- FUNCTION 6: fn_calculate_net_salary(p_gross, p_tax_rate)
-- Returns   : NUMERIC — net salary after flat-rate tax
-- Example   : fn_calculate_net_salary(10000, 0.30) → 7000.00
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_calculate_net_salary(
    p_gross    NUMERIC,
    p_tax_rate NUMERIC   -- 0.0–1.0, e.g. 0.30 = 30%
)
RETURNS NUMERIC LANGUAGE sql IMMUTABLE AS $$
    SELECT ROUND(p_gross * (1.0 - p_tax_rate), 2);
$$;

-- ─────────────────────────────────────────────────────────────
-- FUNCTION 7: fn_user_age(p_user_id INT)
-- Returns   : SMALLINT — age in full years
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_user_age(p_user_id INT)
RETURNS SMALLINT LANGUAGE sql STABLE AS $$
    SELECT EXTRACT(YEAR FROM AGE(NOW(), date_of_birth))::SMALLINT
    FROM user_profiles WHERE user_id = p_user_id;
$$;

-- ─────────────────────────────────────────────────────────────
-- FUNCTION 8: fn_format_full_name(p_first, p_last)
-- Returns   : TEXT — properly capitalised full name
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_format_full_name(p_first TEXT, p_last TEXT)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT INITCAP(p_first) || ' ' || INITCAP(p_last);
$$;
