# Advanced SQL — Procedures, Triggers, Cursors, Functions

Full source code is in `sql/03_functions.sql`, `sql/04_stored_procedures.sql`, `sql/05_triggers.sql`, and `sql/06_cursors.sql`.

---

## User-Defined Functions

### `fn_set_updated_at()` → TRIGGER
Shared trigger function used by all `updated_at` triggers. Sets `NEW.updated_at = NOW()` and returns `NEW`. Defined once, reused nine times.

### `fn_profile_completeness(p_user_id INT)` → SMALLINT
Scores a user's profile on 5 dimensions × 20 points each = 0–100:
1. Basic fields (first name, last name, nationality, bio)
2. At least one completed education entry
3. At least one work experience entry
4. At least 3 skills
5. At least one language with a test score

This function is called both by the stored procedures (as a guard) and by the trigger chain (to auto-update `user_profiles.profile_completeness_pct`).

### `fn_calculate_immigration_score(user_id, program_id)` → SMALLINT
Three-factor scoring (0–100):
- **Education (max 40 pts):** `rank_order × 7` capped at 40. PhD = 42 → capped to 40.
- **Language (max 40 pts):** `(IELTS band / 9.0) × 40`. Band 7.5 → 33 pts.
- **Work experience (max 20 pts):** `total_years × 4` capped at 20. 5+ years → 20 pts.

### `fn_get_job_match_score(user_id, job_id)` → NUMERIC(5,2)
Weighted skill match: required skills contribute weight 2, optional skills weight 1. Proficiency levels are compared ordinally (beginner=1, intermediate=2, advanced=3, expert=4). A matched skill must meet or exceed the job's minimum proficiency to count. Returns 0.00–100.00.

### `fn_check_skill_gap(user_id, job_id)` → TABLE
Returns one row per job skill with columns: `skill_name`, `is_required`, `required_proficiency`, `user_proficiency`, `gap_type` (MET / INSUFFICIENT / MISSING). Powers the detailed skill gap UI.

### `fn_calculate_net_salary(gross, tax_rate)` → NUMERIC
`ROUND(gross × (1 − tax_rate), 2)`. Pure SQL function marked `IMMUTABLE` for potential index use. Example: `fn_calculate_net_salary(10000, 0.30)` → `7000.00`.

### `fn_user_age(user_id)` → SMALLINT
`EXTRACT(YEAR FROM AGE(NOW(), date_of_birth))`. Returns NULL if no `date_of_birth` on profile.

### `fn_format_full_name(first, last)` → TEXT
`INITCAP(first) || ' ' || INITCAP(last)`. Marked `IMMUTABLE` — safe for use in computed expressions.

---

## Stored Procedures

### `sp_register_user`
**Parameters:** `p_email`, `p_password_hash`, `p_first_name`, `p_last_name`, `p_nationality_id`, `INOUT p_user_id`

Guards: email uniqueness check with `RAISE EXCEPTION`.

Side effects:
1. INSERT into `users`
2. INSERT into `user_profiles` (blank)
3. INSERT welcome notification (Persian)
4. INSERT activity log

Returns `p_user_id` via `INOUT` parameter (PostgreSQL procedure pattern).

---

### `sp_apply_for_job`
**Parameters:** `p_user_id`, `p_job_id`, `p_cover_letter`, `INOUT p_app_id`

Validation chain (each raises a descriptive Persian exception on failure):
1. No existing non-withdrawn application for this job
2. Job `status = 'active'`
3. `closes_at` not in the past
4. `fn_profile_completeness ≥ 60`
5. `fn_get_job_match_score ≥ 30`

Side effects: INSERT application, UPSERT skill gap analysis, INSERT notification, INSERT activity log.

---

### `sp_assess_immigration_eligibility`
**Parameters:** `p_user_id`, `p_program_id`, `INOUT p_score`, `INOUT p_status`

Calls `fn_calculate_immigration_score()`. If score ≥ program threshold → status = `submitted`, else `draft`. Uses `INSERT … ON CONFLICT DO NOTHING` + fallback `UPDATE` for idempotent upsert.

---

### `sp_process_visa_application`
**Parameters:** `p_visa_app_id`, `p_new_status`, `p_notes`

Enforces finality: raises exception if current status is `approved`, `rejected`, or `withdrawn`. Updates `decision_at` on final status transitions. Notifies user and logs.

---

### `sp_book_appointment`
**Parameters:** `p_user_id`, `p_consultant_id`, `p_scheduled_at`, `p_visa_app_id`, `INOUT p_appt_id`

Overlap detection using PostgreSQL range type: `tstzrange(scheduled_at, scheduled_at + duration) && tstzrange(...)`. Notifies both the user and the consultant's user account.

---

## Triggers

| Trigger | Event | Table(s) | Action |
|---|---|---|---|
| `trg_*_updated_at` (×9) | BEFORE UPDATE | users, user_profiles, companies, jobs, job_applications, visa_applications, appointments, consultants, immigration_programs | Set `updated_at = NOW()` |
| `trg_log_job_applications` | AFTER INSERT/UPDATE/DELETE | job_applications | INSERT into activity_logs |
| `trg_log_visa_applications` | AFTER INSERT/UPDATE/DELETE | visa_applications | INSERT into activity_logs |
| `trg_log_appointments` | AFTER INSERT/UPDATE/DELETE | appointments | INSERT into activity_logs |
| `trg_notify_application_status` | AFTER UPDATE | job_applications | INSERT notification when status changes |
| `trg_completeness_on_profile` | AFTER INSERT/UPDATE | user_profiles | Recalculate profile completeness |
| `trg_completeness_on_education` | AFTER INSERT/UPDATE/DELETE | user_education | Recalculate profile completeness |
| `trg_completeness_on_skills` | AFTER INSERT/UPDATE/DELETE | user_skills | Recalculate profile completeness |
| `trg_completeness_on_languages` | AFTER INSERT/UPDATE/DELETE | user_languages | Recalculate profile completeness |
| `trg_completeness_on_experience` | AFTER INSERT/UPDATE/DELETE | user_work_experience | Recalculate profile completeness |
| `trg_prevent_duplicate_application` | BEFORE INSERT | job_applications | RAISE EXCEPTION on duplicate |
| `trg_auto_expire_job` | BEFORE INSERT/UPDATE | jobs | Set status = 'expired' if past closes_at |
| `trg_notify_visa_status` | AFTER UPDATE | visa_applications | INSERT notification when status changes |

---

## Cursors

### `sp_process_batch_recommendations()`
Uses two nested explicit cursors:
- **`cur_users`** — iterates all active seekers
- **`cur_jobs(p_uid)`** — parameterised cursor returning top-3 matching active jobs per user, ordered by `fn_get_job_match_score`

Deletes stale recommendations before inserting fresh ones. Logs processed/inserted counts with `RAISE NOTICE`.

### `sp_batch_recalculate_eligibility()`
**`cur_apps`** iterates all `draft` and `submitted` visa applications. Recalculates score with `fn_calculate_immigration_score`. Promotes `draft → submitted` if score now passes. Notifies user if delta > 5 points.

### `sp_cursor_send_expiry_notifications()`
Joins `jobs` and `job_applications` to find active jobs expiring within 7 days with pending applicants. Sends one notification per affected user-job pair.
