# Change Log — Migration & Career Support System

All notable changes are documented here in reverse chronological order.

---

## [v2.0.0] — 2026-06-13 *(Current)*

### Added
- Full technical documentation across 8 sections (`docs/` directory)
- Mermaid ER/EER diagram (`docs/02_er_diagram.md`)
- 5 analytical views: `v_user_full_profile`, `v_job_with_skills`, `v_application_summary`, `v_immigration_dashboard`, `v_consultant_workload`
- 12 critical analytical queries demonstrating CTEs, window functions, LATERAL joins, JSONB unnesting, GROUPING SETS, FILTER aggregates
- 5 management report queries (Progress Report, Immigration Probability, Skill Gap Heat Map, Demand Analysis, Recruitment Funnel)
- Cursor procedure `sp_cursor_send_expiry_notifications` — 7-day job expiry alerts

### Changed
- Notification messages are now written in Persian (Farsi)
- `fn_calculate_immigration_score` scoring model finalised: education (40 pts) + IELTS (40 pts) + work experience (20 pts)
- `sp_book_appointment` uses PostgreSQL `tstzrange &&` operator for overlap detection

---

## [v1.5.0] — 2026-05-20

### Added
- Consultant module: `consultants` and `appointments` tables
- `sp_book_appointment` stored procedure with time-slot overlap prevention
- `v_consultant_workload` view
- `trg_notify_visa_status` trigger for visa status change alerts
- `sp_cursor_send_expiry_notifications` batch cursor procedure

### Changed
- `visa_applications.eligibility_score` now stored at time of submission for historical accuracy
- `user_profiles` extended: `date_of_birth`, `portfolio_url`, `current_city_id`

---

## [v1.4.0] — 2026-05-01

### Added
- `skill_gap_analyses` table with `missing_skills JSONB` and `matched_skills JSONB` columns
- `fn_check_skill_gap()` — RETURNS TABLE function for detailed per-skill gap breakdown
- `fn_get_job_match_score()` — weighted 0–100 match score function
- GIN index on `skill_gap_analyses.missing_skills` for fast JSONB queries
- `sp_process_batch_recommendations()` cursor procedure — generates top-3 job recs per user

### Fixed
- `trg_completeness_on_profile` now correctly fires on `user_languages` INSERT (was missing)
- `fn_profile_completeness` COALESCE guard prevents NULL arithmetic error for new users

---

## [v1.3.0] — 2026-04-15

### Added
- `documents` table with full status workflow (`pending → approved / rejected`)
- `notifications` table and trigger-based insertion (`fn_notify_application_status_change`)
- `sp_batch_recalculate_eligibility()` cursor procedure — bulk score refresh for draft applications
- Partial indexes on `jobs(status)` WHERE `status = 'active'` for query acceleration

### Changed
- `immigration_programs.min_eligibility_score` renamed from `threshold` for clarity
- Activity log now records `table_name` and `record_id` (was action-only)

---

## [v1.2.0] — 2026-04-01

### Added
- `job_skills` and `job_applications` tables with `match_score` column
- `sp_apply_for_job` stored procedure with 4-gate validation:
  1. Duplicate check
  2. Job active + not expired
  3. Profile completeness ≥ 60%
  4. Skill match score ≥ 30%
- `trg_prevent_duplicate_application` BEFORE INSERT trigger
- `trg_log_job_applications` activity logging trigger
- `trg_auto_expire_job` BEFORE INSERT/UPDATE trigger
- All `updated_at` triggers using shared `fn_set_updated_at()` function

### Changed
- `users.role` converted from VARCHAR to PostgreSQL ENUM `user_role`
- All CHECK constraints moved from application layer into DDL

---

## [v1.1.0] — 2026-03-15

### Added
- `user_skills`, `user_languages`, `user_education` bridge tables
- `user_work_experience` table
- `fn_profile_completeness()` scalar function (5-dimension, 20 pts each)
- `trg_completeness_on_*` trigger chain across 5 user tables
- `fn_calculate_immigration_score()` — education + IELTS + work experience
- `sp_assess_immigration_eligibility()` stored procedure
- `sp_process_visa_application()` stored procedure with finality guard
- Initial seed data: reference tables (countries, cities, languages, skills)

---

## [v1.0.0] — 2026-03-01

### Added
- Initial schema: `users`, `user_profiles`, `countries`, `cities`, `languages`, `education_levels`, `industries`, `skill_categories`, `skills`, `institutions`
- `companies`, `jobs` base tables
- `immigration_programs`, `program_requirements`, `visa_applications` base tables
- `sp_register_user()` stored procedure
- `activity_logs` table
- `sql/01_schema.sql` with all 16 ENUM type definitions
- `sql/02_indexes.sql` with composite and partial B-tree indexes
- `README.md` with setup instructions
