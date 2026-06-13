-- =============================================================
-- Migration & Career Support System
-- File        : 07_views.sql
-- Description : Analytical views for reporting and dashboards
-- Run after   : 03_functions.sql, 01_schema.sql
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- VIEW 1: v_user_full_profile
-- Summary of each user with aggregated profile stats
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_user_full_profile AS
SELECT
    u.user_id,
    fn_format_full_name(up.first_name, up.last_name) AS full_name,
    u.email,
    u.role::TEXT,
    u.is_active,
    cn.name                         AS nationality,
    cc.name                         AS current_country,
    up.date_of_birth,
    fn_user_age(u.user_id)          AS age,
    up.bio,
    up.linkedin_url,
    up.portfolio_url,
    up.profile_completeness_pct,
    COUNT(DISTINCT us.user_skill_id)    AS skills_count,
    COUNT(DISTINCT ue.edu_id)           AS education_entries,
    COUNT(DISTINCT ul.user_language_id) AS languages_count,
    COUNT(DISTINCT uwe.exp_id)          AS work_experience_entries,
    u.created_at
FROM users u
JOIN user_profiles up    ON up.user_id = u.user_id
LEFT JOIN countries cn   ON cn.country_id = up.nationality_country_id
LEFT JOIN countries cc   ON cc.country_id = up.current_country_id
LEFT JOIN user_skills us ON us.user_id = u.user_id
LEFT JOIN user_education ue ON ue.user_id = u.user_id
LEFT JOIN user_languages ul ON ul.user_id = u.user_id
LEFT JOIN user_work_experience uwe ON uwe.user_id = u.user_id
GROUP BY
    u.user_id, up.profile_id, up.bio, up.linkedin_url,
    up.portfolio_url, cn.name, cc.name, up.date_of_birth;

-- ─────────────────────────────────────────────────────────────
-- VIEW 2: v_job_with_skills
-- Each active job with its required/preferred skill lists
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_job_with_skills AS
SELECT
    j.job_id,
    j.title,
    c.name              AS company,
    i.name              AS industry,
    co.name             AS country,
    ci.name             AS city,
    j.employment_type::TEXT,
    j.required_exp_years,
    j.salary_min,
    j.salary_max,
    j.currency,
    j.status::TEXT,
    j.closes_at,
    COUNT(js.job_skill_id)                                   AS total_skills,
    ARRAY_AGG(s.name ORDER BY s.name)
        FILTER (WHERE js.is_required = TRUE)                 AS required_skills,
    ARRAY_AGG(s.name ORDER BY s.name)
        FILTER (WHERE js.is_required = FALSE)                AS preferred_skills,
    j.created_at
FROM jobs j
JOIN companies c       ON c.company_id   = j.company_id
LEFT JOIN industries i ON i.industry_id  = j.industry_id
LEFT JOIN countries co ON co.country_id  = j.country_id
LEFT JOIN cities ci    ON ci.city_id     = j.city_id
LEFT JOIN job_skills js ON js.job_id     = j.job_id
LEFT JOIN skills s     ON s.skill_id     = js.skill_id
GROUP BY j.job_id, c.name, i.name, co.name, ci.name;

-- ─────────────────────────────────────────────────────────────
-- VIEW 3: v_application_summary
-- All applications enriched with user, job, and company data
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_application_summary AS
SELECT
    ja.app_id,
    fn_format_full_name(up.first_name, up.last_name) AS applicant_name,
    u.email                         AS applicant_email,
    j.title                         AS job_title,
    c.name                          AS company,
    i.name                          AS industry,
    ja.status::TEXT,
    ja.match_score,
    ja.applied_at,
    ja.interview_at,
    ja.offer_amount,
    EXTRACT(DAY FROM (NOW() - ja.applied_at))::INT AS days_since_applied
FROM job_applications ja
JOIN users u             ON u.user_id      = ja.user_id
JOIN user_profiles up    ON up.user_id     = ja.user_id
JOIN jobs j              ON j.job_id       = ja.job_id
JOIN companies c         ON c.company_id   = j.company_id
LEFT JOIN industries i   ON i.industry_id  = j.industry_id;

-- ─────────────────────────────────────────────────────────────
-- VIEW 4: v_immigration_dashboard
-- Visa applications with eligibility comparison
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_immigration_dashboard AS
SELECT
    va.visa_app_id,
    fn_format_full_name(up.first_name, up.last_name) AS applicant_name,
    u.email,
    cn.name                         AS nationality,
    ip.name                         AS program_name,
    ip.program_code,
    ip.category::TEXT,
    dest.name                       AS destination_country,
    va.eligibility_score,
    ip.min_eligibility_score,
    va.eligibility_score - ip.min_eligibility_score AS score_gap,
    CASE
        WHEN va.eligibility_score >= ip.min_eligibility_score THEN TRUE
        ELSE FALSE
    END                             AS is_eligible,
    va.status::TEXT,
    va.submitted_at,
    va.decision_at,
    ip.processing_time_days
FROM visa_applications va
JOIN users u                 ON u.user_id      = va.user_id
JOIN user_profiles up        ON up.user_id     = va.user_id
LEFT JOIN countries cn       ON cn.country_id  = up.nationality_country_id
JOIN immigration_programs ip ON ip.program_id  = va.program_id
JOIN countries dest          ON dest.country_id = ip.country_id;

-- ─────────────────────────────────────────────────────────────
-- VIEW 5: v_consultant_workload
-- Consultant summary with appointment stats
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_consultant_workload AS
SELECT
    c.consultant_id,
    fn_format_full_name(up.first_name, up.last_name) AS consultant_name,
    u.email,
    c.specialization::TEXT,
    c.license_number,
    c.hourly_rate,
    c.rating,
    c.total_reviews,
    c.is_available,
    COUNT(a.appt_id) FILTER (
        WHERE a.status IN ('pending','confirmed') AND a.scheduled_at > NOW()
    )                               AS upcoming_appointments,
    COUNT(a.appt_id) FILTER (
        WHERE a.status = 'completed'
    )                               AS completed_sessions,
    COUNT(DISTINCT a.user_id)       AS unique_clients
FROM consultants c
JOIN users u        ON u.user_id  = c.user_id
JOIN user_profiles up ON up.user_id = c.user_id
LEFT JOIN appointments a ON a.consultant_id = c.consultant_id
GROUP BY c.consultant_id, up.first_name, up.last_name, u.email;
