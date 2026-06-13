-- =============================================================
-- Migration & Career Support System
-- File        : 08_queries.sql
-- Description : Critical analytical SQL queries
--               Demonstrates: CTEs, window functions, subqueries,
--               EXISTS, LATERAL, JSONB, GROUPING SETS, FILTER
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- Q1: CTE — Top 10 most in-demand skills across all active jobs
-- ─────────────────────────────────────────────────────────────
WITH skill_demand AS (
    SELECT
        s.skill_id,
        s.name                       AS skill_name,
        sc.name                      AS category,
        COUNT(js.job_id)             AS job_count,
        COUNT(js.job_id) FILTER (WHERE js.is_required = TRUE) AS required_count
    FROM skills s
    JOIN skill_categories sc ON sc.category_id = s.category_id
    JOIN job_skills js        ON js.skill_id   = s.skill_id
    JOIN jobs j               ON j.job_id      = js.job_id
    WHERE j.status = 'active'
    GROUP BY s.skill_id, s.name, sc.name
)
SELECT
    skill_name,
    category,
    job_count,
    required_count,
    RANK() OVER (ORDER BY job_count DESC) AS demand_rank
FROM skill_demand
ORDER BY demand_rank
LIMIT 10;

-- ─────────────────────────────────────────────────────────────
-- Q2: Window Function — Cumulative job applications per user over time
-- ─────────────────────────────────────────────────────────────
SELECT
    u.user_id,
    fn_format_full_name(up.first_name, up.last_name) AS applicant,
    ja.applied_at::DATE                              AS apply_date,
    COUNT(*) OVER (
        PARTITION BY u.user_id
        ORDER BY ja.applied_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                AS cumulative_applications
FROM users u
JOIN user_profiles up   ON up.user_id = u.user_id
JOIN job_applications ja ON ja.user_id = u.user_id
WHERE ja.applied_at IS NOT NULL
ORDER BY u.user_id, ja.applied_at;

-- ─────────────────────────────────────────────────────────────
-- Q3: Correlated Subquery — Users with more skills than the platform average
-- ─────────────────────────────────────────────────────────────
SELECT
    u.user_id,
    fn_format_full_name(up.first_name, up.last_name) AS full_name,
    (SELECT COUNT(*) FROM user_skills us WHERE us.user_id = u.user_id) AS skill_count
FROM users u
JOIN user_profiles up ON up.user_id = u.user_id
WHERE
    (SELECT COUNT(*) FROM user_skills us WHERE us.user_id = u.user_id)
    >
    (SELECT AVG(cnt) FROM (
         SELECT COUNT(*) AS cnt FROM user_skills GROUP BY user_id
     ) sub)
ORDER BY skill_count DESC;

-- ─────────────────────────────────────────────────────────────
-- Q4: EXISTS — Active jobs a user qualifies for but hasn't applied to
--     Replace :p_user_id with an actual user_id integer.
-- ─────────────────────────────────────────────────────────────
SELECT
    j.job_id,
    j.title,
    c.name  AS company,
    fn_get_job_match_score(1, j.job_id) AS match_score  -- replace 1 with target user_id
FROM jobs j
JOIN companies c ON c.company_id = j.company_id
WHERE j.status = 'active'
  AND NOT EXISTS (
      SELECT 1 FROM job_applications ja
      WHERE ja.job_id = j.job_id AND ja.user_id = 1
  )
  AND EXISTS (
      SELECT 1 FROM job_skills js
      WHERE js.job_id = j.job_id AND js.is_required = TRUE
        AND js.skill_id IN (
            SELECT skill_id FROM user_skills WHERE user_id = 1
        )
  )
ORDER BY match_score DESC;

-- ─────────────────────────────────────────────────────────────
-- Q5: GROUPING SETS — Application counts by industry and employment type
-- ─────────────────────────────────────────────────────────────
SELECT
    COALESCE(i.name, '(ALL INDUSTRIES)')         AS industry,
    COALESCE(j.employment_type::TEXT, '(ALL)')   AS employment_type,
    COUNT(ja.app_id)                             AS applications
FROM job_applications ja
JOIN jobs j        ON j.job_id      = ja.job_id
LEFT JOIN industries i ON i.industry_id = j.industry_id
GROUP BY GROUPING SETS (
    (i.name),
    (j.employment_type),
    (i.name, j.employment_type),
    ()
)
ORDER BY i.name NULLS LAST, j.employment_type NULLS LAST;

-- ─────────────────────────────────────────────────────────────
-- Q6: LATERAL JOIN — Latest application status per user
-- ─────────────────────────────────────────────────────────────
SELECT
    u.user_id,
    u.email,
    latest.status,
    latest.applied_at,
    latest.job_title
FROM users u
LEFT JOIN LATERAL (
    SELECT ja.status, ja.applied_at, j.title AS job_title
    FROM job_applications ja
    JOIN jobs j ON j.job_id = ja.job_id
    WHERE ja.user_id = u.user_id
    ORDER BY ja.created_at DESC
    LIMIT 1
) latest ON TRUE
WHERE u.role = 'seeker'
ORDER BY latest.applied_at DESC NULLS LAST;

-- ─────────────────────────────────────────────────────────────
-- Q7: CTE + Window — Immigration program ranking by average applicant score
-- ─────────────────────────────────────────────────────────────
WITH program_scores AS (
    SELECT
        ip.program_id,
        ip.name                    AS program_name,
        ip.min_eligibility_score,
        dest.name                  AS destination_country,
        va.eligibility_score,
        va.status
    FROM visa_applications va
    JOIN immigration_programs ip ON ip.program_id = va.program_id
    JOIN countries dest           ON dest.country_id = ip.country_id
)
SELECT
    program_name,
    destination_country,
    min_eligibility_score,
    COUNT(*)                              AS total_applicants,
    ROUND(AVG(eligibility_score), 1)      AS avg_score,
    COUNT(*) FILTER (WHERE eligibility_score >= min_eligibility_score) AS eligible_count,
    ROUND(
        COUNT(*) FILTER (WHERE eligibility_score >= min_eligibility_score)
        * 100.0 / NULLIF(COUNT(*), 0), 1
    )                                     AS eligibility_rate_pct,
    RANK() OVER (ORDER BY AVG(eligibility_score) DESC) AS rank_by_avg_score
FROM program_scores
GROUP BY program_name, destination_country, min_eligibility_score
ORDER BY rank_by_avg_score;

-- ─────────────────────────────────────────────────────────────
-- Q8: JSONB unnest — Missing skills extracted from gap analyses
-- ─────────────────────────────────────────────────────────────
SELECT
    fn_format_full_name(up.first_name, up.last_name) AS applicant,
    j.title                                          AS job_title,
    sg.match_score,
    elem->>'skill_name'                              AS missing_skill
FROM skill_gap_analyses sg
JOIN users u          ON u.user_id    = sg.user_id
JOIN user_profiles up ON up.user_id  = sg.user_id
JOIN jobs j           ON j.job_id    = sg.job_id
CROSS JOIN LATERAL jsonb_array_elements(sg.missing_skills) AS elem
WHERE sg.missing_skills IS NOT NULL
ORDER BY sg.match_score DESC;

-- ─────────────────────────────────────────────────────────────
-- Q9: CASE + FILTER aggregate — Recruitment pipeline pivot per job
-- ─────────────────────────────────────────────────────────────
SELECT
    j.job_id,
    j.title,
    c.name                                                          AS company,
    COUNT(ja.app_id)                                                AS total,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'submitted')         AS submitted,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'reviewing')         AS reviewing,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'interview')         AS interview,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'offer')             AS offer,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'accepted')          AS accepted,
    COUNT(ja.app_id) FILTER (WHERE ja.status = 'rejected')          AS rejected,
    ROUND(AVG(ja.match_score), 1)                                   AS avg_match_score
FROM jobs j
JOIN companies c ON c.company_id = j.company_id
LEFT JOIN job_applications ja ON ja.job_id = j.job_id
GROUP BY j.job_id, j.title, c.name
ORDER BY total DESC;

-- ─────────────────────────────────────────────────────────────
-- Q10: Window RANK — Consultants ranked by completed sessions within specialization
-- ─────────────────────────────────────────────────────────────
SELECT
    c.specialization::TEXT,
    fn_format_full_name(up.first_name, up.last_name) AS consultant_name,
    c.rating,
    COUNT(a.appt_id) FILTER (WHERE a.status = 'completed') AS completed_sessions,
    RANK() OVER (
        PARTITION BY c.specialization
        ORDER BY COUNT(a.appt_id) FILTER (WHERE a.status = 'completed') DESC
    )                                                       AS rank_in_specialty
FROM consultants c
JOIN users u        ON u.user_id  = c.user_id
JOIN user_profiles up ON up.user_id = c.user_id
LEFT JOIN appointments a ON a.consultant_id = c.consultant_id
GROUP BY c.consultant_id, c.specialization, up.first_name, up.last_name, c.rating
ORDER BY c.specialization, rank_in_specialty;

-- ─────────────────────────────────────────────────────────────
-- Q11: Multi-table UPDATE — Close all expired active jobs
-- ─────────────────────────────────────────────────────────────
UPDATE jobs
SET    status     = 'expired',
       updated_at = NOW()
WHERE  status    = 'active'
  AND  closes_at < CURRENT_DATE
RETURNING job_id, title, company_id, closes_at;

-- ─────────────────────────────────────────────────────────────
-- Q12: CTE + UPSERT — Batch skill gap analyses for today's new applications
-- ─────────────────────────────────────────────────────────────
WITH new_apps AS (
    SELECT user_id, job_id
    FROM job_applications
    WHERE applied_at::DATE = CURRENT_DATE
      AND status = 'submitted'
)
INSERT INTO skill_gap_analyses (user_id, job_id, match_score, analyzed_at)
SELECT
    n.user_id,
    n.job_id,
    fn_get_job_match_score(n.user_id, n.job_id),
    NOW()
FROM new_apps n
ON CONFLICT (user_id, job_id)
DO UPDATE SET
    match_score = EXCLUDED.match_score,
    analyzed_at = NOW();
