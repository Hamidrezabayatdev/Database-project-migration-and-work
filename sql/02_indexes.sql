-- =============================================================
-- Migration & Career Support System
-- File        : 02_indexes.sql
-- Description : Performance indexes — composite, partial, GIN
-- Run after   : 01_schema.sql
-- =============================================================

BEGIN;

-- ---------------------------------------------------------------
-- USERS
-- ---------------------------------------------------------------
CREATE INDEX idx_users_email         ON users (email);
CREATE INDEX idx_users_role_active   ON users (role, is_active);

-- ---------------------------------------------------------------
-- USER PROFILES
-- ---------------------------------------------------------------
CREATE INDEX idx_up_nationality      ON user_profiles (nationality_country_id);
CREATE INDEX idx_up_current_country  ON user_profiles (current_country_id);
CREATE INDEX idx_up_completeness     ON user_profiles (profile_completeness_pct DESC);

-- ---------------------------------------------------------------
-- USER SKILLS
-- ---------------------------------------------------------------
CREATE INDEX idx_user_skills_skill   ON user_skills (skill_id);
CREATE INDEX idx_user_skills_user    ON user_skills (user_id, proficiency);

-- ---------------------------------------------------------------
-- USER LANGUAGES
-- ---------------------------------------------------------------
CREATE INDEX idx_user_lang_lang      ON user_languages (language_id);
CREATE INDEX idx_user_lang_score     ON user_languages (test_type, test_score DESC);

-- ---------------------------------------------------------------
-- USER EDUCATION
-- ---------------------------------------------------------------
CREATE INDEX idx_user_edu_level      ON user_education (user_id, level_id);

-- ---------------------------------------------------------------
-- USER WORK EXPERIENCE
-- ---------------------------------------------------------------
CREATE INDEX idx_work_exp_user       ON user_work_experience (user_id, start_date DESC);

-- ---------------------------------------------------------------
-- JOBS
-- Partial index: only active jobs (most-queried subset)
-- ---------------------------------------------------------------
CREATE INDEX idx_jobs_active         ON jobs (job_id, company_id, industry_id)
    WHERE status = 'active';
CREATE INDEX idx_jobs_status_closes  ON jobs (status, closes_at);
CREATE INDEX idx_jobs_country_city   ON jobs (country_id, city_id);
CREATE INDEX idx_jobs_salary         ON jobs (salary_min, salary_max);

-- ---------------------------------------------------------------
-- JOB SKILLS
-- ---------------------------------------------------------------
CREATE INDEX idx_job_skills_skill    ON job_skills (skill_id, is_required);

-- ---------------------------------------------------------------
-- JOB APPLICATIONS
-- Composite: most common filter pattern
-- ---------------------------------------------------------------
CREATE INDEX idx_app_user_status     ON job_applications (user_id, status);
CREATE INDEX idx_app_job_status      ON job_applications (job_id, status);
CREATE INDEX idx_app_applied_at      ON job_applications (applied_at DESC);

-- ---------------------------------------------------------------
-- VISA APPLICATIONS
-- ---------------------------------------------------------------
CREATE INDEX idx_visa_user_status    ON visa_applications (user_id, status);
CREATE INDEX idx_visa_program        ON visa_applications (program_id, status);
CREATE INDEX idx_visa_score          ON visa_applications (eligibility_score DESC);

-- ---------------------------------------------------------------
-- SKILL GAP ANALYSES
-- GIN index for JSONB missing_skills (supports @>, ?, ?|, ?& operators)
-- ---------------------------------------------------------------
CREATE INDEX idx_gap_missing_gin     ON skill_gap_analyses USING GIN (missing_skills);
CREATE INDEX idx_gap_matched_gin     ON skill_gap_analyses USING GIN (matched_skills);
CREATE INDEX idx_gap_user_score      ON skill_gap_analyses (user_id, match_score DESC);

-- ---------------------------------------------------------------
-- RECOMMENDATIONS
-- ---------------------------------------------------------------
CREATE INDEX idx_rec_user_type       ON recommendations (user_id, entity_type, is_dismissed);

-- ---------------------------------------------------------------
-- ACTIVITY LOGS
-- Designed for time-series queries: latest actions per user
-- ---------------------------------------------------------------
CREATE INDEX idx_log_user_time       ON activity_logs (user_id, created_at DESC);
CREATE INDEX idx_log_action          ON activity_logs (action, created_at DESC);

-- ---------------------------------------------------------------
-- NOTIFICATIONS
-- ---------------------------------------------------------------
CREATE INDEX idx_notif_user_unread   ON notifications (user_id, is_read, created_at DESC);

-- ---------------------------------------------------------------
-- APPOINTMENTS
-- ---------------------------------------------------------------
CREATE INDEX idx_appt_consultant_time ON appointments (consultant_id, scheduled_at)
    WHERE status NOT IN ('cancelled', 'no_show');
CREATE INDEX idx_appt_user           ON appointments (user_id, status);

COMMIT;
