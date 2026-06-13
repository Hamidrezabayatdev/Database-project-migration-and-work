-- =============================================================
-- Migration & Career Support System
-- File        : 05_triggers.sql
-- Description : Triggers & trigger functions — automation layer
-- Run after   : 03_functions.sql
-- =============================================================

-- =============================================================
-- TRIGGER GROUP 1: Auto-update updated_at
-- Shared function fn_set_updated_at() defined in 03_functions.sql
-- =============================================================

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_companies_updated_at
    BEFORE UPDATE ON companies
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_jobs_updated_at
    BEFORE UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_job_applications_updated_at
    BEFORE UPDATE ON job_applications
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_visa_applications_updated_at
    BEFORE UPDATE ON visa_applications
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_appointments_updated_at
    BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_consultants_updated_at
    BEFORE UPDATE ON consultants
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_immigration_programs_updated_at
    BEFORE UPDATE ON immigration_programs
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- =============================================================
-- TRIGGER GROUP 2: Activity logging
-- Records INSERT / UPDATE / DELETE on key business tables.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_log_activity()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_user_id   INT;
    v_record_id INT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_record_id := CASE TG_TABLE_NAME
            WHEN 'job_applications'  THEN OLD.app_id
            WHEN 'visa_applications' THEN OLD.visa_app_id
            WHEN 'appointments'      THEN OLD.appt_id
            ELSE NULL
        END;
        v_user_id := CASE TG_TABLE_NAME
            WHEN 'job_applications'  THEN OLD.user_id
            WHEN 'visa_applications' THEN OLD.user_id
            WHEN 'appointments'      THEN OLD.user_id
            ELSE NULL
        END;
    ELSE
        v_record_id := CASE TG_TABLE_NAME
            WHEN 'job_applications'  THEN NEW.app_id
            WHEN 'visa_applications' THEN NEW.visa_app_id
            WHEN 'appointments'      THEN NEW.appt_id
            ELSE NULL
        END;
        v_user_id := CASE TG_TABLE_NAME
            WHEN 'job_applications'  THEN NEW.user_id
            WHEN 'visa_applications' THEN NEW.user_id
            WHEN 'appointments'      THEN NEW.user_id
            ELSE NULL
        END;
    END IF;

    INSERT INTO activity_logs (user_id, action, table_name, record_id)
    VALUES (v_user_id, TG_OP, TG_TABLE_NAME, v_record_id);

    RETURN NULL; -- AFTER trigger; return value is ignored
END;
$$;

CREATE TRIGGER trg_log_job_applications
    AFTER INSERT OR UPDATE OR DELETE ON job_applications
    FOR EACH ROW EXECUTE FUNCTION fn_log_activity();

CREATE TRIGGER trg_log_visa_applications
    AFTER INSERT OR UPDATE OR DELETE ON visa_applications
    FOR EACH ROW EXECUTE FUNCTION fn_log_activity();

CREATE TRIGGER trg_log_appointments
    AFTER INSERT OR UPDATE OR DELETE ON appointments
    FOR EACH ROW EXECUTE FUNCTION fn_log_activity();

-- =============================================================
-- TRIGGER GROUP 3: Job application status-change notification
-- Fires AFTER an update and only when status actually changes.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_notify_application_status_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_job_title TEXT;
    v_msg       TEXT;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        SELECT title INTO v_job_title FROM jobs WHERE job_id = NEW.job_id;

        v_msg := CASE NEW.status
            WHEN 'reviewing' THEN FORMAT('درخواست شما برای «%s» در حال بررسی است.',     v_job_title)
            WHEN 'interview' THEN FORMAT('تبریک! برای مصاحبه «%s» دعوت شدید.',          v_job_title)
            WHEN 'offer'     THEN FORMAT('پیشنهاد شغلی برای «%s» ارائه شده است!',       v_job_title)
            WHEN 'accepted'  THEN FORMAT('پیشنهاد «%s» پذیرفته شد. موفق باشید!',        v_job_title)
            WHEN 'rejected'  THEN FORMAT('متأسفیم، درخواست «%s» در این مرحله رد شد.',   v_job_title)
            ELSE FORMAT('وضعیت درخواست «%s» به «%s» تغییر یافت.', v_job_title, NEW.status)
        END;

        INSERT INTO notifications (user_id, title, message, related_table, related_id)
        VALUES (NEW.user_id, 'به‌روزرسانی درخواست شغلی', v_msg, 'job_applications', NEW.app_id);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_application_status
    AFTER UPDATE ON job_applications
    FOR EACH ROW EXECUTE FUNCTION fn_notify_application_status_change();

-- =============================================================
-- TRIGGER GROUP 4: Profile completeness auto-recalculation
-- Fires on any change to user_profiles, user_education,
-- user_skills, user_languages, or user_work_experience.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_refresh_profile_completeness()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_user_id INT;
BEGIN
    v_user_id := COALESCE(
        CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END,
        OLD.user_id
    );

    UPDATE user_profiles
    SET profile_completeness_pct = fn_profile_completeness(v_user_id)
    WHERE user_id = v_user_id;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_completeness_on_profile
    AFTER INSERT OR UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION fn_refresh_profile_completeness();

CREATE TRIGGER trg_completeness_on_education
    AFTER INSERT OR UPDATE OR DELETE ON user_education
    FOR EACH ROW EXECUTE FUNCTION fn_refresh_profile_completeness();

CREATE TRIGGER trg_completeness_on_skills
    AFTER INSERT OR UPDATE OR DELETE ON user_skills
    FOR EACH ROW EXECUTE FUNCTION fn_refresh_profile_completeness();

CREATE TRIGGER trg_completeness_on_languages
    AFTER INSERT OR UPDATE OR DELETE ON user_languages
    FOR EACH ROW EXECUTE FUNCTION fn_refresh_profile_completeness();

CREATE TRIGGER trg_completeness_on_experience
    AFTER INSERT OR UPDATE OR DELETE ON user_work_experience
    FOR EACH ROW EXECUTE FUNCTION fn_refresh_profile_completeness();

-- =============================================================
-- TRIGGER GROUP 5: Prevent duplicate job applications
-- Belt-and-suspenders guard on top of the UNIQUE constraint.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_prevent_duplicate_application()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM job_applications
        WHERE user_id = NEW.user_id
          AND job_id  = NEW.job_id
          AND status != 'withdrawn'
          AND app_id != COALESCE(NEW.app_id, -1)
    ) THEN
        RAISE EXCEPTION
            'درخواست تکراری: کاربر % قبلاً برای شغل % درخواست فعال دارد.',
            NEW.user_id, NEW.job_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prevent_duplicate_application
    BEFORE INSERT ON job_applications
    FOR EACH ROW EXECUTE FUNCTION fn_prevent_duplicate_application();

-- =============================================================
-- TRIGGER GROUP 6: Auto-expire jobs past their closing date
-- Intercepts every INSERT/UPDATE and flips status → 'expired'.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_auto_expire_job()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.closes_at IS NOT NULL
       AND NEW.closes_at < CURRENT_DATE
       AND NEW.status = 'active'
    THEN
        NEW.status := 'expired';
        RAISE NOTICE 'شغل % منقضی شد.', NEW.job_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auto_expire_job
    BEFORE INSERT OR UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION fn_auto_expire_job();

-- =============================================================
-- TRIGGER GROUP 7: Visa application status-change notification
-- =============================================================

CREATE OR REPLACE FUNCTION fn_notify_visa_status_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_program_name TEXT;
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        SELECT name INTO v_program_name
        FROM immigration_programs WHERE program_id = NEW.program_id;

        INSERT INTO notifications (user_id, title, message, related_table, related_id)
        VALUES (
            NEW.user_id,
            'وضعیت درخواست ویزا تغییر کرد',
            FORMAT('وضعیت درخواست «%s» به «%s» تغییر کرد.', v_program_name, NEW.status),
            'visa_applications', NEW.visa_app_id
        );
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_visa_status
    AFTER UPDATE ON visa_applications
    FOR EACH ROW EXECUTE FUNCTION fn_notify_visa_status_change();
