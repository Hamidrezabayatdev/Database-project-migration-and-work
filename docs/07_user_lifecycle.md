# User Lifecycle Prototype — Step-by-Step Journey

This document traces a complete user journey for **Ali Rezaei** (user_id = 1), a Senior Python Developer seeking Canadian permanent residence.

---

## Phase 1: Registration

**SQL executed by `sp_register_user`:**

```sql
CALL sp_register_user(
    'ali.rezaei@example.com',
    '$2b$12$hashed_password',
    'Ali',
    'Rezaei',
    1,             -- Iran (country_id)
    NULL           -- INOUT p_user_id
);
-- Returns: p_user_id = 1
```

**What happens internally:**
1. INSERT into `users` → `user_id = 1`, role = `seeker`
2. INSERT into `user_profiles` → blank profile, `profile_completeness_pct = 0`
3. Trigger `trg_completeness_on_profile` fires → calls `fn_profile_completeness(1)` → still 0 (bio missing)
4. INSERT welcome notification in Persian

---

## Phase 2: Profile Completion

```sql
-- Update basic profile
UPDATE user_profiles
SET bio = 'نرم‌افزار مهندس با ۷ سال تجربه در توسعه بک‌اند.',
    nationality_country_id = 1,
    current_city_id = 1,
    date_of_birth = '1993-04-15'
WHERE user_id = 1;
-- Trigger fires → profile_completeness_pct recalculated

-- Add education (Master's in CS)
INSERT INTO user_education (user_id, level_id, institution_name, field_of_study, country_id, start_year, end_year, is_completed)
VALUES (1, 4, 'Sharif University of Technology', 'Computer Science', 1, 2015, 2017, TRUE);
-- Trigger fires → education dimension now ✓ (+20 pts)

-- Add skills
INSERT INTO user_skills (user_id, skill_id, proficiency, years_exp) VALUES
    (1,  1, 'expert',   7.0),  -- Python
    (1,  4, 'advanced', 7.0),  -- SQL
    (1,  5, 'advanced', 5.0);  -- Django
-- Trigger fires → 3 skills ✓ (+20 pts) → completeness = 60%

-- Add English (IELTS 7.5)
INSERT INTO user_languages (user_id, language_id, proficiency, test_type, test_score)
VALUES (1, 2, 'professional', 'IELTS', 7.5);
-- Trigger fires → language dimension ✓ (+20 pts) → completeness = 80%

-- Add work experience
INSERT INTO user_work_experience (user_id, company_name, industry_id, job_title, country_id, start_date)
VALUES (1, 'Snapp!', 1, 'Senior Backend Developer', 1, '2017-03-01');
-- Trigger fires → work exp ✓ (+20 pts) → completeness = 100%
```

**Profile completeness progression:** 0% → 20% → 40% → 60% → 80% → 100%

---

## Phase 3: CV Upload (Document Management)

```sql
INSERT INTO documents (user_id, doc_type, file_name, file_path)
VALUES
    (1, 'cv',           'ali_cv.pdf',    '/uploads/1/cv.pdf'),
    (1, 'language_test','ali_ielts.pdf', '/uploads/1/ielts.pdf'),
    (1, 'passport',     'ali_pass.pdf',  '/uploads/1/passport.pdf');
-- Documents created with status = 'pending'

-- Admin approves
UPDATE documents SET status = 'approved', reviewed_at = NOW(), reviewed_by = 7
WHERE user_id = 1;
```

---

## Phase 4: Skill Gap Analysis

```sql
-- Check gap vs. job 1 (Senior Python Developer at Shopify)
SELECT * FROM fn_check_skill_gap(1, 1);
```

Expected output:

| skill_name | is_required | required_proficiency | user_proficiency | gap_type |
|---|---|---|---|---|
| Python | TRUE | advanced | expert | MET |
| SQL | TRUE | intermediate | advanced | MET |
| Django | TRUE | advanced | advanced | MET |
| JavaScript | FALSE | beginner | NULL | MISSING |
| Communication | FALSE | intermediate | advanced | MET |

```sql
-- Get numeric match score
SELECT fn_get_job_match_score(1, 1);
-- → 95.00 (only optional JavaScript is missing, weight 1 of 9)
```

---

## Phase 5: Job Application

```sql
CALL sp_apply_for_job(
    1,       -- user_id (Ali)
    1,       -- job_id (Senior Python Developer)
    'مهندس ارشد پایتون با ۷ سال تجربه در ساخت APIهای مقیاس‌پذیر...',
    NULL     -- INOUT p_app_id
);
-- Validation chain:
--   ✓ No duplicate application
--   ✓ Job status = 'active'
--   ✓ closes_at = 2026-09-30 (future)
--   ✓ profile_completeness = 100% ≥ 60%
--   ✓ match_score = 95.00% ≥ 30%
-- Returns: p_app_id = 1

-- Status updates (simulated by recruiter)
UPDATE job_applications SET status = 'reviewing' WHERE app_id = 1;
-- → Trigger: notification sent to Ali — "درخواست شما در حال بررسی است"

UPDATE job_applications SET status = 'interview', interview_at = NOW() + INTERVAL '7 days'
WHERE app_id = 1;
-- → Trigger: notification sent — "تبریک! برای مصاحبه دعوت شدید"
```

---

## Phase 6: Immigration Eligibility Assessment

```sql
-- Check eligibility for Canada Express Entry (program_id = 1)
CALL sp_assess_immigration_eligibility(
    1,    -- user_id
    1,    -- program_id (Canada EE)
    NULL, -- INOUT p_score
    NULL  -- INOUT p_status
);
-- fn_calculate_immigration_score(1, 1):
--   Education:  Master's rank_order=4 → 4×7=28 pts
--   IELTS 7.5:  7.5/9.0×40 = 33 pts
--   Work exp:   7 yrs × 4 = 28 → capped at 20 pts
--   TOTAL: 28 + 33 + 20 = 81 pts
--
-- Min threshold = 67 → 81 ≥ 67 → status = 'submitted'
-- INSERT visa_applications (user_id=1, program_id=1, score=81, status='submitted')
```

---

## Phase 7: Immigration Dashboard View

```sql
SELECT * FROM v_immigration_dashboard WHERE user_id = 1;
```

| applicant_name | program_name | destination | eligibility_score | threshold | is_eligible | status |
|---|---|---|---|---|---|---|
| Ali Rezaei | Canada Express Entry | Canada | 81 | 67 | TRUE | submitted |

---

## Phase 8: Consultant Appointment

```sql
-- Find an immigration consultant
SELECT consultant_id, consultant_name, rating, hourly_rate
FROM v_consultant_workload
WHERE specialization = 'immigration' AND is_available = TRUE
ORDER BY rating DESC
LIMIT 1;
-- → consultant_id = 1 (Mitra Sadeghi, rating 4.8)

-- Book appointment
CALL sp_book_appointment(
    1,                            -- user_id (Ali)
    1,                            -- consultant_id (Mitra)
    NOW() + INTERVAL '7 days',    -- scheduled_at
    1,                            -- visa_app_id
    NULL                          -- INOUT p_appt_id
);
-- → appt_id = 1, status = 'pending'
-- → Notification to Ali: "وقت مشاوره رزرو شد"
-- → Notification to Mitra: "درخواست جلسه جدید"
```

---

## Lifecycle Summary

```
Registration ──→ Profile 100% ──→ Documents Uploaded
                                       ↓
               Gap Analysis ←── fn_check_skill_gap(1, 1)
                   ↓
             Job Application ──→ Interview Stage
                   ↓
         Immigration Assessment ──→ Score: 81/100 ✓
                   ↓
         Visa Application Submitted (Canada EE)
                   ↓
         Consultant Appointment Booked
```
