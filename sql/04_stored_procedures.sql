-- =============================================================
-- Migration & Career Support System
-- File        : 04_stored_procedures.sql
-- Description : Stored Procedures (PL/pgSQL) — business workflows
-- Run after   : 03_functions.sql
-- Usage       : CALL sp_name(args);
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- PROCEDURE 1: sp_register_user
-- Purpose : Creates a new user account with a blank profile
--           and sends a welcome notification.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE sp_register_user(
    p_email          TEXT,
    p_password_hash  TEXT,
    p_first_name     TEXT,
    p_last_name      TEXT,
    p_nationality_id INT  DEFAULT NULL,
    INOUT p_user_id  INT  DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    -- Guard: email must be unique
    IF EXISTS (SELECT 1 FROM users WHERE email = LOWER(TRIM(p_email))) THEN
        RAISE EXCEPTION 'ایمیل «%» قبلاً ثبت شده است.', p_email;
    END IF;

    -- Insert user account
    INSERT INTO users (email, password_hash, role)
    VALUES (LOWER(TRIM(p_email)), p_password_hash, 'seeker')
    RETURNING user_id INTO p_user_id;

    -- Create blank profile (completeness starts at 0)
    INSERT INTO user_profiles (user_id, first_name, last_name, nationality_country_id)
    VALUES (p_user_id, p_first_name, p_last_name, p_nationality_id);

    -- Welcome notification (in Persian)
    INSERT INTO notifications (user_id, title, message)
    VALUES (
        p_user_id,
        'خوش آمدید!',
        'حساب کاربری شما ایجاد شد. برای استفاده از امکانات کامل، پروفایل خود را تکمیل کنید.'
    );

    -- Audit
    INSERT INTO activity_logs (user_id, action, table_name, record_id)
    VALUES (p_user_id, 'USER_REGISTERED', 'users', p_user_id);

    RAISE NOTICE 'ثبت‌نام موفق — user_id: %', p_user_id;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- PROCEDURE 2: sp_apply_for_job
-- Purpose : Submits a job application after validating:
--             1. No duplicate active application
--             2. Job is active and not past deadline
--             3. Profile completeness >= 60%
--             4. Skill match score >= 30%
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE sp_apply_for_job(
    p_user_id      INT,
    p_job_id       INT,
    p_cover_letter TEXT DEFAULT NULL,
    INOUT p_app_id INT  DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_job_status   job_status;
    v_closes_at    DATE;
    v_completeness SMALLINT;
    v_match_score  NUMERIC(5,2);
BEGIN
    -- 1. Duplicate check
    IF EXISTS (
        SELECT 1 FROM job_applications
        WHERE user_id = p_user_id AND job_id = p_job_id
          AND status != 'withdrawn'
    ) THEN
        RAISE EXCEPTION 'شما قبلاً برای این موقعیت شغلی درخواست داده‌اید.';
    END IF;

    -- 2. Job status check
    SELECT status, closes_at INTO v_job_status, v_closes_at
    FROM jobs WHERE job_id = p_job_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'موقعیت شغلی با شناسه % یافت نشد.', p_job_id;
    END IF;

    IF v_job_status != 'active' THEN
        RAISE EXCEPTION 'این موقعیت شغلی فعال نیست (وضعیت: %).', v_job_status;
    END IF;

    IF v_closes_at IS NOT NULL AND v_closes_at < CURRENT_DATE THEN
        RAISE EXCEPTION 'مهلت ثبت درخواست برای این شغل به پایان رسیده است (%).', v_closes_at;
    END IF;

    -- 3. Profile completeness check
    v_completeness := fn_profile_completeness(p_user_id);
    IF v_completeness < 60 THEN
        RAISE EXCEPTION 'پروفایل شما باید حداقل ۶۰٪ تکمیل شده باشد. (فعلی: %٪)', v_completeness;
    END IF;

    -- 4. Skill match threshold
    v_match_score := fn_get_job_match_score(p_user_id, p_job_id);
    IF v_match_score < 30 THEN
        RAISE EXCEPTION 'امتیاز تطابق مهارت شما (%.0f٪) کمتر از حداقل مجاز ۳۰٪ است.', v_match_score;
    END IF;

    -- 5. Submit application
    INSERT INTO job_applications (user_id, job_id, status, cover_letter, match_score, applied_at)
    VALUES (p_user_id, p_job_id, 'submitted', p_cover_letter, v_match_score, NOW())
    RETURNING app_id INTO p_app_id;

    -- 6. Upsert skill gap analysis snapshot
    INSERT INTO skill_gap_analyses (user_id, job_id, match_score, analyzed_at)
    VALUES (p_user_id, p_job_id, v_match_score, NOW())
    ON CONFLICT (user_id, job_id)
    DO UPDATE SET match_score = EXCLUDED.match_score, analyzed_at = NOW();

    -- 7. Notify applicant
    INSERT INTO notifications (user_id, title, message, related_table, related_id)
    VALUES (
        p_user_id,
        'درخواست شغلی ثبت شد ✓',
        FORMAT('درخواست شما با امتیاز تطابق %.0f٪ با موفقیت ثبت شد.', v_match_score),
        'job_applications', p_app_id
    );

    -- 8. Audit
    INSERT INTO activity_logs (user_id, action, table_name, record_id)
    VALUES (p_user_id, 'JOB_APPLICATION_SUBMITTED', 'job_applications', p_app_id);

    RAISE NOTICE 'درخواست ثبت شد — app_id: %, match: %.0f%%', p_app_id, v_match_score;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- PROCEDURE 3: sp_assess_immigration_eligibility
-- Purpose : Calculates user's eligibility score for a given
--           immigration program and creates/updates a visa
--           application record accordingly.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE sp_assess_immigration_eligibility(
    p_user_id     INT,
    p_program_id  INT,
    INOUT p_score SMALLINT DEFAULT NULL,
    INOUT p_status TEXT    DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_min_score    SMALLINT;
    v_program_name TEXT;
    v_visa_app_id  INT;
BEGIN
    -- Validate program exists and is active
    SELECT min_eligibility_score, name
    INTO v_min_score, v_program_name
    FROM immigration_programs
    WHERE program_id = p_program_id AND is_active = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'برنامه مهاجرتی % یافت نشد یا غیرفعال است.', p_program_id;
    END IF;

    -- Calculate score using UDF
    p_score  := fn_calculate_immigration_score(p_user_id, p_program_id);
    p_status := CASE WHEN p_score >= v_min_score THEN 'submitted' ELSE 'draft' END;

    -- Upsert visa application
    INSERT INTO visa_applications (user_id, program_id, eligibility_score, status)
    VALUES (p_user_id, p_program_id, p_score, p_status::visa_status)
    ON CONFLICT DO NOTHING
    RETURNING visa_app_id INTO v_visa_app_id;

    IF v_visa_app_id IS NULL THEN
        UPDATE visa_applications
        SET eligibility_score = p_score,
            status            = p_status::visa_status,
            updated_at        = NOW()
        WHERE user_id = p_user_id AND program_id = p_program_id
        RETURNING visa_app_id INTO v_visa_app_id;
    END IF;

    -- Notify user
    INSERT INTO notifications (user_id, title, message, related_table, related_id)
    VALUES (
        p_user_id,
        'نتیجه ارزیابی مهاجرت',
        FORMAT('امتیاز شما برای برنامه «%s»: %s/۱۰۰. وضعیت: %s',
               v_program_name, p_score, p_status),
        'visa_applications', v_visa_app_id
    );

    -- Audit
    INSERT INTO activity_logs (user_id, action, table_name, record_id)
    VALUES (p_user_id, 'IMMIGRATION_ELIGIBILITY_ASSESSED', 'visa_applications', v_visa_app_id);

    RAISE NOTICE 'ارزیابی انجام شد — score: %, status: %', p_score, p_status;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- PROCEDURE 4: sp_process_visa_application
-- Purpose : Transitions a visa application to a new status.
--           Prevents backward transitions on finalized records.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE sp_process_visa_application(
    p_visa_app_id INT,
    p_new_status  TEXT,
    p_notes       TEXT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_user_id       INT;
    v_current_status visa_status;
    v_program_name  TEXT;
BEGIN
    SELECT va.user_id, va.status, ip.name
    INTO v_user_id, v_current_status, v_program_name
    FROM visa_applications va
    JOIN immigration_programs ip ON ip.program_id = va.program_id
    WHERE va.visa_app_id = p_visa_app_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'درخواست ویزا با شناسه % یافت نشد.', p_visa_app_id;
    END IF;

    -- Finality guard
    IF v_current_status IN ('approved', 'rejected', 'withdrawn') THEN
        RAISE EXCEPTION 'وضعیت این درخواست نهایی شده و قابل تغییر نیست (وضعیت فعلی: %).', v_current_status;
    END IF;

    -- Apply update
    UPDATE visa_applications
    SET status       = p_new_status::visa_status,
        notes        = COALESCE(p_notes, notes),
        decision_at  = CASE WHEN p_new_status IN ('approved','rejected') THEN NOW() ELSE decision_at END,
        submitted_at = CASE WHEN p_new_status = 'submitted' AND submitted_at IS NULL THEN NOW() ELSE submitted_at END,
        updated_at   = NOW()
    WHERE visa_app_id = p_visa_app_id;

    -- Notify user
    INSERT INTO notifications (user_id, title, message, related_table, related_id)
    VALUES (
        v_user_id,
        'به‌روزرسانی درخواست ویزا',
        FORMAT('وضعیت درخواست «%s» به «%s» تغییر کرد.', v_program_name, p_new_status),
        'visa_applications', p_visa_app_id
    );

    -- Audit
    INSERT INTO activity_logs (user_id, action, table_name, record_id)
    VALUES (v_user_id,
            'VISA_STATUS_' || UPPER(p_new_status),
            'visa_applications', p_visa_app_id);

    RAISE NOTICE 'وضعیت درخواست ویزا % به % تغییر کرد.', p_visa_app_id, p_new_status;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- PROCEDURE 5: sp_book_appointment
-- Purpose : Schedules a consultation appointment after checking
--           consultant availability and time-slot conflicts.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE sp_book_appointment(
    p_user_id       INT,
    p_consultant_id INT,
    p_scheduled_at  TIMESTAMPTZ,
    p_visa_app_id   INT DEFAULT NULL,
    INOUT p_appt_id INT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_consultant_user_id INT;
    v_is_available       BOOLEAN;
    v_duration           SMALLINT := 60;
BEGIN
    -- Validate consultant
    SELECT c.is_available, u.user_id
    INTO v_is_available, v_consultant_user_id
    FROM consultants c
    JOIN users u ON u.user_id = c.user_id
    WHERE c.consultant_id = p_consultant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'مشاور با شناسه % یافت نشد.', p_consultant_id;
    END IF;

    IF NOT v_is_available THEN
        RAISE EXCEPTION 'این مشاور در حال حاضر در دسترس نیست.';
    END IF;

    -- Time-slot overlap check using range overlap operator &&
    IF EXISTS (
        SELECT 1 FROM appointments
        WHERE consultant_id = p_consultant_id
          AND status NOT IN ('cancelled', 'no_show')
          AND tstzrange(scheduled_at,
                        scheduled_at + (duration_minutes || ' minutes')::INTERVAL)
              &&
              tstzrange(p_scheduled_at,
                        p_scheduled_at + (v_duration || ' minutes')::INTERVAL)
    ) THEN
        RAISE EXCEPTION 'این زمان قبلاً رزرو شده است. لطفاً زمان دیگری انتخاب کنید.';
    END IF;

    -- Insert appointment
    INSERT INTO appointments
        (user_id, consultant_id, visa_app_id, scheduled_at, duration_minutes)
    VALUES
        (p_user_id, p_consultant_id, p_visa_app_id, p_scheduled_at, v_duration)
    RETURNING appt_id INTO p_appt_id;

    -- Notify user
    INSERT INTO notifications (user_id, title, message, related_table, related_id)
    VALUES (
        p_user_id,
        'وقت مشاوره رزرو شد',
        FORMAT('جلسه مشاوره شما در تاریخ %s رزرو شد.', p_scheduled_at::DATE),
        'appointments', p_appt_id
    );

    -- Notify consultant
    INSERT INTO notifications (user_id, title, message, related_table, related_id)
    VALUES (
        v_consultant_user_id,
        'درخواست جلسه جدید',
        FORMAT('یک جلسه مشاوره برای تاریخ %s رزرو شد.', p_scheduled_at::DATE),
        'appointments', p_appt_id
    );

    -- Audit
    INSERT INTO activity_logs (user_id, action, table_name, record_id)
    VALUES (p_user_id, 'APPOINTMENT_BOOKED', 'appointments', p_appt_id);

    RAISE NOTICE 'جلسه رزرو شد — appt_id: %', p_appt_id;
END;
$$;
