-- =============================================================
-- Migration & Career Support System
-- File        : 06_cursors.sql
-- Description : Cursor-based batch processing procedures
-- Run after   : 04_stored_procedures.sql, 03_functions.sql
-- Usage       : CALL sp_process_batch_recommendations();
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- PROCEDURE 1: sp_process_batch_recommendations
-- Purpose  : Iterates over all active job seekers using an
--            explicit cursor and generates top-3 job
--            recommendations per user based on skill match score.
-- Cursor   : cur_users — all active seekers
-- Inner    : cur_jobs  — top-3 matching active jobs per user
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE sp_process_batch_recommendations()
LANGUAGE plpgsql AS $$
DECLARE
    -- Outer cursor: active job seekers
    cur_users CURSOR FOR
        SELECT user_id
        FROM users
        WHERE is_active = TRUE AND role = 'seeker';

    v_user_id   INT;
    v_job_id    INT;
    v_score     NUMERIC(5,2);
    v_processed INT := 0;
    v_inserted  INT := 0;

    -- Inner cursor: top active jobs for a given user (parameterised)
    cur_jobs CURSOR (p_uid INT) FOR
        SELECT j.job_id,
               fn_get_job_match_score(p_uid, j.job_id) AS match_score
        FROM jobs j
        WHERE j.status = 'active'
          AND NOT EXISTS (
              SELECT 1 FROM job_applications ja
              WHERE ja.user_id = p_uid AND ja.job_id = j.job_id
          )
        ORDER BY match_score DESC
        LIMIT 3;
BEGIN
    OPEN cur_users;

    LOOP
        FETCH cur_users INTO v_user_id;
        EXIT WHEN NOT FOUND;

        v_processed := v_processed + 1;

        -- Remove stale undismissed job recommendations for this user
        DELETE FROM recommendations
        WHERE user_id = v_user_id
          AND entity_type = 'job'
          AND is_dismissed = FALSE;

        -- Open inner cursor for this user
        OPEN cur_jobs(v_user_id);
        LOOP
            FETCH cur_jobs INTO v_job_id, v_score;
            EXIT WHEN NOT FOUND;

            IF v_score >= 30 THEN
                INSERT INTO recommendations
                    (user_id, entity_type, entity_id, score, reason)
                VALUES (
                    v_user_id,
                    'job',
                    v_job_id,
                    v_score,
                    FORMAT('تطابق مهارت: %.0f٪', v_score)
                );
                v_inserted := v_inserted + 1;
            END IF;
        END LOOP;
        CLOSE cur_jobs;

    END LOOP;

    CLOSE cur_users;

    RAISE NOTICE 'پردازش دسته‌ای: % کاربر بررسی شد، % توصیه درج شد.',
                 v_processed, v_inserted;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- PROCEDURE 2: sp_batch_recalculate_eligibility
-- Purpose  : Loops over all draft/submitted visa applications
--            and recalculates their eligibility scores.
--            Promotes 'draft' → 'submitted' if score now passes.
--            Notifies user if score changed by more than 5 pts.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE sp_batch_recalculate_eligibility()
LANGUAGE plpgsql AS $$
DECLARE
    cur_apps CURSOR FOR
        SELECT visa_app_id, user_id, program_id, eligibility_score AS old_score
        FROM visa_applications
        WHERE status IN ('draft', 'submitted');

    v_app_id    INT;
    v_user_id   INT;
    v_prog_id   INT;
    v_old_score SMALLINT;
    v_new_score SMALLINT;
    v_min_score SMALLINT;
    v_updated   INT := 0;
BEGIN
    OPEN cur_apps;
    LOOP
        FETCH cur_apps INTO v_app_id, v_user_id, v_prog_id, v_old_score;
        EXIT WHEN NOT FOUND;

        -- Recalculate
        v_new_score := fn_calculate_immigration_score(v_user_id, v_prog_id);

        SELECT min_eligibility_score INTO v_min_score
        FROM immigration_programs WHERE program_id = v_prog_id;

        IF v_new_score IS DISTINCT FROM v_old_score THEN
            UPDATE visa_applications
            SET eligibility_score = v_new_score,
                status = CASE
                    WHEN v_new_score >= v_min_score AND status = 'draft'
                         THEN 'submitted'::visa_status
                    ELSE status
                END,
                updated_at = NOW()
            WHERE visa_app_id = v_app_id;

            -- Notify if significant change (> 5 points)
            IF ABS(v_new_score - COALESCE(v_old_score, 0)) > 5 THEN
                INSERT INTO notifications (user_id, title, message)
                VALUES (
                    v_user_id,
                    'به‌روزرسانی امتیاز مهاجرت',
                    FORMAT('امتیاز واجد شرایط بودن شما از %s به %s تغییر کرد.',
                           COALESCE(v_old_score::TEXT, '—'), v_new_score)
                );
            END IF;

            v_updated := v_updated + 1;
        END IF;
    END LOOP;
    CLOSE cur_apps;

    RAISE NOTICE 'بازمحاسبه دسته‌ای: % درخواست به‌روزرسانی شد.', v_updated;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- PROCEDURE 3: sp_cursor_send_expiry_notifications
-- Purpose  : Finds jobs expiring within the next 7 days and
--            notifies applicants who still await a decision.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE sp_cursor_send_expiry_notifications()
LANGUAGE plpgsql AS $$
DECLARE
    cur_expiring CURSOR FOR
        SELECT j.job_id,
               j.title,
               j.closes_at,
               ja.user_id,
               ja.app_id
        FROM jobs j
        JOIN job_applications ja ON ja.job_id = j.job_id
        WHERE j.status = 'active'
          AND j.closes_at BETWEEN CURRENT_DATE
                              AND (CURRENT_DATE + INTERVAL '7 days')::DATE
          AND ja.status IN ('submitted', 'reviewing');

    r          RECORD;
    v_notified INT := 0;
BEGIN
    OPEN cur_expiring;
    LOOP
        FETCH cur_expiring INTO r;
        EXIT WHEN NOT FOUND;

        INSERT INTO notifications (user_id, title, message, related_table, related_id)
        VALUES (
            r.user_id,
            'یادآوری: موقعیت شغلی در حال اتمام',
            FORMAT('موقعیت «%s» در تاریخ %s بسته می‌شود. وضعیت درخواست خود را بررسی کنید.',
                   r.title, r.closes_at),
            'jobs', r.job_id
        );

        v_notified := v_notified + 1;
    END LOOP;
    CLOSE cur_expiring;

    RAISE NOTICE '% اطلاعیه انقضای شغل ارسال شد.', v_notified;
END;
$$;
