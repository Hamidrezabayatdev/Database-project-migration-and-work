# Critical SQL Queries — Migration & Career Support System

All queries are in `sql/08_queries.sql`. This document explains the purpose and technique of each.

---

## Q1 — Top 10 In-Demand Skills (CTE + Window RANK)

**Purpose:** Shows which skills employers are looking for most. Used for platform recommendations and skill-gap trend analysis.

**Techniques:** Common Table Expression (CTE), `RANK() OVER`, `COUNT FILTER`

```sql
WITH skill_demand AS (
    SELECT s.skill_id, s.name AS skill_name, sc.name AS category,
           COUNT(js.job_id) AS job_count,
           COUNT(js.job_id) FILTER (WHERE js.is_required) AS required_count
    FROM skills s
    JOIN skill_categories sc ON sc.category_id = s.category_id
    JOIN job_skills js ON js.skill_id = s.skill_id
    JOIN jobs j ON j.job_id = js.job_id AND j.status = 'active'
    GROUP BY s.skill_id, s.name, sc.name
)
SELECT skill_name, category, job_count, required_count,
       RANK() OVER (ORDER BY job_count DESC) AS demand_rank
FROM skill_demand ORDER BY demand_rank LIMIT 10;
```

---

## Q2 — Cumulative Application Count per User (Window Function)

**Purpose:** Tracks job application momentum over time — shows if a user is accelerating or stalling.

**Technique:** `COUNT(*) OVER (PARTITION BY … ORDER BY … ROWS UNBOUNDED PRECEDING)`

---

## Q3 — Users with More Skills Than Platform Average (Correlated Subquery)

**Purpose:** Identifies power users / high-value candidates. Used for premium tier targeting.

**Technique:** Correlated subquery in WHERE clause, scalar subquery in SELECT.

---

## Q4 — Jobs a User Qualifies For But Hasn't Applied To (EXISTS)

**Purpose:** Core recommendation driver — surfaces missed opportunities.

**Technique:** `NOT EXISTS` (exclusion of applied jobs) + `EXISTS` (skill match check)

---

## Q5 — Application Counts by Industry × Employment Type (GROUPING SETS)

**Purpose:** Management analytics — reveals which industry/type combinations attract the most candidates.

**Technique:** `GROUP BY GROUPING SETS(...)` — generates subtotals and grand total in one query.

---

## Q6 — Latest Application per User (LATERAL JOIN)

**Purpose:** Efficient dashboard query — one row per user showing their most recent activity.

**Technique:** `LEFT JOIN LATERAL (SELECT ... LIMIT 1) ON TRUE`

---

## Q7 — Program Ranking by Average Applicant Score (CTE + Multiple Aggregates)

**Purpose:** Shows which immigration programs are most accessible to the current user base.

**Technique:** CTE, `AVG`, `COUNT FILTER`, `ROUND`, `RANK() OVER`

---

## Q8 — Extract Missing Skill Names from JSONB (JSONB + LATERAL)

**Purpose:** Powers the "Skill Gap Heat Map" report — unnests stored JSONB arrays into rows.

**Technique:** `CROSS JOIN LATERAL jsonb_array_elements()`, `->>` text extraction operator

---

## Q9 — Recruitment Pipeline Pivot per Job (CASE + FILTER Aggregates)

**Purpose:** Kanban-style overview of each job's applicant funnel for HR managers.

**Technique:** Multiple `COUNT(*) FILTER (WHERE status = '...')` in a single GROUP BY

---

## Q10 — Consultant Ranking Within Specialization (Partitioned RANK)

**Purpose:** Helps users find the most experienced consultant in their needed specialization.

**Technique:** `RANK() OVER (PARTITION BY specialization ORDER BY completed_sessions DESC)`

---

## Q11 — Batch Expire Past-Deadline Jobs (UPDATE … RETURNING)

**Purpose:** Maintenance query to close all active jobs past their `closes_at` date.

**Technique:** `UPDATE … WHERE … RETURNING` — modifies and returns affected rows atomically

---

## Q12 — Batch Upsert Skill Gap Analyses for Today's Applications (CTE + UPSERT)

**Purpose:** Ensures every new application has a corresponding gap analysis record.

**Technique:** CTE as data source, `INSERT … ON CONFLICT … DO UPDATE SET`
