# Management Reports — Migration & Career Support System

All report queries are in `sql/09_reports.sql`.

---

## Report 1: User Progress Report Card

**Purpose:** Per-user lifecycle summary for platform administrators and the users themselves.

**Output columns:**

| Column | Description |
|---|---|
| `full_name`, `email` | Identity |
| `nationality` | Country of origin |
| `profile_pct` | Profile completeness (0–100) |
| `highest_degree` | Highest completed education level |
| `total_skills`, `advanced_skills` | Skill inventory counts |
| `total_applications` | All-time job applications |
| `pending`, `in_interview`, `offers_received`, `accepted` | Application pipeline breakdown |
| `avg_match_score` | Average skill match across all applications |
| `visa_applications`, `visas_approved` | Immigration module activity |
| `best_immigration_score` | Highest eligibility score achieved |
| `documents_uploaded`, `docs_approved` | Document verification status |
| `member_since` | Registration date |

**SQL Technique:** Multiple `LEFT JOIN` with `COUNT DISTINCT`, `COUNT FILTER`, `MAX` aggregates in a single GROUP BY query.

---

## Report 2: Immigration Success Probability

**Purpose:** Per-program eligibility analysis for immigration advisors.

**Output columns:**

| Column | Description |
|---|---|
| `program_code`, `program_name`, `category` | Program identity |
| `destination`, `threshold`, `processing_time_days` | Program parameters |
| `total_applicants`, `avg_score`, `min/max_score_seen` | Score distribution |
| `eligible_count`, `eligibility_rate_pct` | Proportion of users above threshold |
| `approved`, `rejected`, `in_progress` | Decision outcomes |
| `score_lt_40 … score_ge_80` | Score histogram buckets (4 bands) |

**SQL Technique:** Multiple `COUNT FILTER` in one GROUP BY, `NULLIF` guard for division-by-zero in rate calculation.

**Sample output interpretation:**

| Program | Threshold | Avg Score | Eligible % |
|---|---|---|---|
| Canada Express Entry | 67 | 74 | 75% |
| Germany EU Blue Card | 60 | 71 | 80% |

---

## Report 3: Job Market Demand & Skill Gap Analysis

**Purpose:** Strategic insights for platform operators — which skills are most demanded versus most available among users.

**Output columns:**

| Column | Description |
|---|---|
| `skill_name`, `category` | Skill identity |
| `jobs_requiring`, `jobs_requiring_mandatory` | Employer demand |
| `users_with_skill`, `users_advanced` | Platform supply |
| `market_status` | CRITICAL GAP / UNDERSUPPLY / ADEQUATE |
| `demand_rank` | Rank by employer demand |

---

## Report 4: Skill Gap Heat Map

**Purpose:** Aggregates JSONB `missing_skills` arrays across all gap analyses to find the most commonly missing skills platform-wide.

**Output columns:** `missing_skill`, `times_missing`, `avg_match_when_missing`, `gap_rank`

**SQL Technique:** `CROSS JOIN LATERAL jsonb_array_elements()` to unnest JSONB arrays from every gap analysis row, then aggregate with `COUNT(*)` and `RANK()`.

---

## Report 5: Recruitment Funnel per Job

**Purpose:** Shows HR managers how applicants move through the hiring pipeline for each job posting.

**Output columns:**

| Column | Description |
|---|---|
| `job_id`, `title`, `company`, `industry` | Job identity |
| `total_applications`, `avg_match_score` | Volume and quality |
| `stage_submitted … stage_accepted` | Count at each pipeline stage |
| `submission_rate_pct` | % of non-withdrawn applications |
| `interview_conversion_pct` | % of submissions that reached interview |
| `offer_acceptance_pct` | % of offers accepted |

**SQL Technique:** Multiple `COUNT FILTER`, `ROUND`, `NULLIF` for zero-safe division.
