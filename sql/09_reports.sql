-- =============================================================
-- Migration & Career Support System
-- File        : 09_reports.sql
-- Description : Management report queries
-- Run after   : 01_schema.sql, 03_functions.sql, 07_views.sql
-- =============================================================

-- =============================================================
-- REPORT 1: User Progress Report Card
-- Shows each job seeker's lifecycle progress across all modules.
-- =============================================================
SELECT
    u.user_id,
    fn_format_full_name(up.first_name, up.last_name) AS full_name,
    u.email,
    cn.name                            AS nationality,
    up.profile_completeness_pct        AS profile_pct,

    -- Education
    COUNT(DISTINCT ue.edu_id)          AS education_entries,
    MAX(el.name)                       AS highest_degree,

    -- Skills
    COUNT(DISTINCT us.user_skill_id)   AS total_skills,
    COUNT(DISTINCT us.user_skill_id) FILTER (WHERE us.proficiency IN ('advanced','expert'))
                                       AS advanced_skills,

    -- Job Applications
    COUNT(DISTINCT ja.app_id)          AS total_applications,
    COUNT(DISTINCT ja.app_id) FILTER (WHERE ja.status = 'submitted')  AS pending,
    COUNT(DISTINCT ja.app_id) FILTER (WHERE ja.status = 'interview')  AS in_interview,
    COUNT(DISTINCT ja.app_id) FILTER (WHERE ja.status = 'offer')      AS offers_received,
    COUNT(DISTINCT ja.app_id) FILTER (WHERE ja.status = 'accepted')   AS accepted,
    ROUND(AVG(ja.match_score), 1)      AS avg_match_score,

    -- Visa / Immigration
    COUNT(DISTINCT va.visa_app_id)     AS visa_applications,
    COUNT(DISTINCT va.visa_app_id) FILTER (WHERE va.status = 'approved') AS visas_approved,
    MAX(va.eligibility_score)          AS best_immigration_score,

    -- Documents
    COUNT(DISTINCT d.doc_id)           AS documents_uploaded,
    COUNT(DISTINCT d.doc_id) FILTER (WHERE d.status = 'approved') AS docs_approved,

    u.created_at::DATE                 AS member_since

FROM users u
JOIN user_profiles up     ON up.user_id      = u.user_id
LEFT JOIN countries cn    ON cn.country_id   = up.nationality_country_id
LEFT JOIN user_education ue ON ue.user_id    = u.user_id
LEFT JOIN education_levels el ON el.level_id = ue.level_id
LEFT JOIN user_skills us  ON us.user_id      = u.user_id
LEFT JOIN job_applications ja ON ja.user_id  = u.user_id
LEFT JOIN visa_applications va ON va.user_id = u.user_id
LEFT JOIN documents d     ON d.user_id       = u.user_id
WHERE u.role = 'seeker'
GROUP BY u.user_id, up.profile_id, up.profile_completeness_pct, cn.name
ORDER BY up.profile_completeness_pct DESC, total_applications DESC;

-- =============================================================
-- REPORT 2: Immigration Success Probability
-- Score distribution and eligibility rates per program.
-- =============================================================
SELECT
    ip.program_code,
    ip.name                          AS program_name,
    ip.category::TEXT,
    dest.name                        AS destination,
    ip.min_eligibility_score         AS threshold,
    ip.processing_time_days,

    COUNT(va.visa_app_id)            AS total_applicants,
    ROUND(AVG(va.eligibility_score), 1)          AS avg_score,
    MIN(va.eligibility_score)        AS min_score_seen,
    MAX(va.eligibility_score)        AS max_score_seen,

    COUNT(va.visa_app_id) FILTER (WHERE va.eligibility_score >= ip.min_eligibility_score)
                                     AS eligible_count,
    ROUND(
        COUNT(va.visa_app_id) FILTER (WHERE va.eligibility_score >= ip.min_eligibility_score)
        * 100.0 / NULLIF(COUNT(va.visa_app_id), 0), 1
    )                                AS eligibility_rate_pct,

    COUNT(va.visa_app_id) FILTER (WHERE va.status = 'approved')  AS approved,
    COUNT(va.visa_app_id) FILTER (WHERE va.status = 'rejected')  AS rejected,
    COUNT(va.visa_app_id) FILTER (WHERE va.status IN ('submitted','under_review'))
                                     AS in_progress,

    -- Score buckets (histogram)
    COUNT(va.visa_app_id) FILTER (WHERE va.eligibility_score < 40)     AS score_lt_40,
    COUNT(va.visa_app_id) FILTER (WHERE va.eligibility_score BETWEEN 40 AND 59) AS score_40_59,
    COUNT(va.visa_app_id) FILTER (WHERE va.eligibility_score BETWEEN 60 AND 79) AS score_60_79,
    COUNT(va.visa_app_id) FILTER (WHERE va.eligibility_score >= 80)    AS score_ge_80

FROM immigration_programs ip
JOIN countries dest ON dest.country_id = ip.country_id
LEFT JOIN visa_applications va ON va.program_id = ip.program_id
WHERE ip.is_active = TRUE
GROUP BY ip.program_id, ip.program_code, ip.name, ip.category,
         dest.name, ip.min_eligibility_score, ip.processing_time_days
ORDER BY eligibility_rate_pct DESC NULLS LAST;

-- =============================================================
-- REPORT 3: Job Market Demand & Skill Gap Analysis
-- Top skills demanded by employers vs. skills users have.
-- =============================================================
WITH demanded AS (
    SELECT
        s.skill_id,
        s.name                       AS skill_name,
        sc.name                      AS category,
        COUNT(DISTINCT js.job_id)    AS jobs_requiring,
        COUNT(DISTINCT js.job_id) FILTER (WHERE js.is_required) AS jobs_requiring_mandatory
    FROM skills s
    JOIN skill_categories sc ON sc.category_id = s.category_id
    LEFT JOIN job_skills js  ON js.skill_id    = s.skill_id
    LEFT JOIN jobs j         ON j.job_id       = js.job_id AND j.status = 'active'
    GROUP BY s.skill_id, s.name, sc.name
),
supplied AS (
    SELECT
        skill_id,
        COUNT(DISTINCT user_id)      AS users_with_skill,
        COUNT(DISTINCT user_id) FILTER (WHERE proficiency IN ('advanced','expert'))
                                     AS users_advanced
    FROM user_skills
    GROUP BY skill_id
)
SELECT
    d.skill_name,
    d.category,
    d.jobs_requiring,
    d.jobs_requiring_mandatory,
    COALESCE(s.users_with_skill, 0) AS users_with_skill,
    COALESCE(s.users_advanced, 0)   AS users_advanced,
    CASE
        WHEN d.jobs_requiring > 0 AND COALESCE(s.users_with_skill, 0) = 0
            THEN 'CRITICAL GAP'
        WHEN d.jobs_requiring > COALESCE(s.users_with_skill, 0)
            THEN 'UNDERSUPPLY'
        ELSE 'ADEQUATE'
    END                             AS market_status,
    RANK() OVER (ORDER BY d.jobs_requiring DESC) AS demand_rank
FROM demanded d
LEFT JOIN supplied s ON s.skill_id = d.skill_id
WHERE d.jobs_requiring > 0
ORDER BY demand_rank
LIMIT 20;

-- =============================================================
-- REPORT 4: Skill Gap Heat Map
-- Most frequently missing skills across all gap analyses.
-- =============================================================
SELECT
    elem->>'skill_name'   AS missing_skill,
    COUNT(*)              AS times_missing,
    ROUND(AVG((sg.match_score)::NUMERIC), 1) AS avg_match_when_missing,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS gap_rank
FROM skill_gap_analyses sg
CROSS JOIN LATERAL jsonb_array_elements(sg.missing_skills) AS elem
WHERE sg.missing_skills IS NOT NULL
  AND jsonb_array_length(sg.missing_skills) > 0
GROUP BY elem->>'skill_name'
ORDER BY times_missing DESC
LIMIT 15;

-- =============================================================
-- REPORT 5: Recruitment Funnel per Job
-- Shows conversion rates at each stage of the hiring pipeline.
-- =============================================================
SELECT
    j.job_id,
    j.title,
    c.name                                                   AS company,
    i.name                                                   AS industry,
    j.status::TEXT,
    j.closes_at,

    COUNT(ja.app_id)                                         AS total_applications,
    ROUND(AVG(ja.match_score), 1)                            AS avg_match_score,

    COUNT(ja.app_id) FILTER (WHERE ja.status = 'submitted')  AS stage_submitted,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'reviewing')  AS stage_reviewing,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'interview')  AS stage_interview,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'offer')      AS stage_offer,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'accepted')   AS stage_accepted,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'rejected')   AS stage_rejected,

    -- Conversion rates
    ROUND(
        COUNT(ja.app_id) FILTER (WHERE ja.status NOT IN ('withdrawn','draft'))
        * 100.0 / NULLIF(COUNT(ja.app_id), 0), 1
    )                                                        AS submission_rate_pct,
    ROUND(
        COUNT(ja.app_id) FILTER (WHERE ja.status IN ('interview','offer','accepted'))
        * 100.0 / NULLIF(COUNT(ja.app_id) FILTER (WHERE ja.status != 'withdrawn'), 0), 1
    )                                                        AS interview_conversion_pct,
    ROUND(
        COUNT(ja.app_id) FILTER (WHERE ja.status = 'accepted')
        * 100.0 / NULLIF(COUNT(ja.app_id) FILTER (WHERE ja.status = 'offer'), 0), 1
    )                                                        AS offer_acceptance_pct

FROM jobs j
JOIN companies c       ON c.company_id  = j.company_id
LEFT JOIN industries i ON i.industry_id = j.industry_id
LEFT JOIN job_applications ja ON ja.job_id = j.job_id
GROUP BY j.job_id, j.title, c.name, i.name
ORDER BY total_applications DESC;
