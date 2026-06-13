# CRUD Operations — Migration & Career Support System

Complete Create, Read, Update, Delete scripts for all major entities.

---

## Users

### CREATE
```sql
-- Via stored procedure (recommended — adds profile + notification)
CALL sp_register_user(
    'new.user@example.com',
    '$2b$12$hashedpassword',
    'Dariush',
    'Mohammadi',
    1,    -- Iran (country_id)
    NULL  -- INOUT p_user_id
);

-- Direct INSERT (bypass procedure — no profile created)
INSERT INTO users (email, password_hash, role)
VALUES ('direct@example.com', '$2b$12$hash', 'seeker');
```

### READ
```sql
-- By ID
SELECT * FROM users WHERE user_id = 1;

-- By email
SELECT * FROM users WHERE email = 'ali.rezaei@example.com';

-- Full profile view
SELECT * FROM v_user_full_profile WHERE user_id = 1;

-- Paginated list (page 2, 10 per page)
SELECT * FROM v_user_full_profile
ORDER BY created_at DESC
LIMIT 10 OFFSET 10;

-- Active seekers with profile completeness >= 80%
SELECT user_id, full_name, profile_completeness_pct
FROM v_user_full_profile
WHERE role = 'seeker' AND profile_completeness_pct >= 80
ORDER BY profile_completeness_pct DESC;
```

### UPDATE
```sql
-- Update profile bio and LinkedIn
UPDATE user_profiles
SET bio = 'توسعه‌دهنده ارشد نرم‌افزار با ۸ سال سابقه', linkedin_url = 'https://linkedin.com/in/ali'
WHERE user_id = 1;

-- Record last login
UPDATE users SET last_login_at = NOW() WHERE user_id = 1;

-- Deactivate account (soft delete)
UPDATE users SET is_active = FALSE, updated_at = NOW() WHERE user_id = 1;

-- Reactivate
UPDATE users SET is_active = TRUE, updated_at = NOW() WHERE user_id = 1;
```

### DELETE
```sql
-- Soft delete (preferred — preserves history)
UPDATE users SET is_active = FALSE WHERE user_id = 1;

-- Hard delete (cascades to user_profiles, user_skills, documents, etc.)
DELETE FROM users WHERE user_id = 1;
```

---

## Skills & User Skills

### CREATE
```sql
-- Add a new skill to the catalog (admin only)
INSERT INTO skills (category_id, name, description)
VALUES (1, 'FastAPI', 'Modern Python async web framework');

-- Link skill to user
INSERT INTO user_skills (user_id, skill_id, proficiency, years_exp)
VALUES (1, 19, 'intermediate', 1.0);
```

### READ
```sql
-- All skills for a user
SELECT s.name, sc.name AS category, us.proficiency, us.years_exp
FROM user_skills us
JOIN skills s ON s.skill_id = us.skill_id
JOIN skill_categories sc ON sc.category_id = s.category_id
WHERE us.user_id = 1
ORDER BY sc.name, s.name;

-- Users who have a specific skill at advanced+ level
SELECT u.user_id, fn_format_full_name(up.first_name, up.last_name) AS name
FROM user_skills us
JOIN users u ON u.user_id = us.user_id
JOIN user_profiles up ON up.user_id = us.user_id
WHERE us.skill_id = 1 AND us.proficiency IN ('advanced', 'expert');
```

### UPDATE
```sql
-- Upgrade proficiency
UPDATE user_skills
SET proficiency = 'expert', years_exp = 8.0
WHERE user_id = 1 AND skill_id = 1;
-- → Triggers: trg_completeness_on_skills fires, profile completeness recalculated
```

### DELETE
```sql
-- Remove a skill from user profile
DELETE FROM user_skills WHERE user_id = 1 AND skill_id = 2;
-- → Trigger: completeness recalculated (may drop below threshold)
```

---

## Jobs

### CREATE
```sql
INSERT INTO jobs
    (company_id, title, description, industry_id, country_id, city_id,
     employment_type, required_exp_years, min_education_level,
     salary_min, salary_max, currency, status, posted_at, closes_at)
VALUES
    (1, 'Full Stack Developer',
     'Build modern web applications with React and Django.',
     1, 2, 3, 'remote', 3, 3,
     75000, 110000, 'CAD', 'active', NOW(), '2026-12-31');

-- Add required skills
INSERT INTO job_skills (job_id, skill_id, is_required, min_proficiency) VALUES
    (4, 1, TRUE, 'intermediate'),  -- Python
    (4, 6, TRUE, 'intermediate'),  -- React
    (4, 4, FALSE,'beginner');      -- SQL
```

### READ
```sql
-- All active jobs with skills
SELECT * FROM v_job_with_skills WHERE status = 'active';

-- Jobs in a specific country
SELECT * FROM v_job_with_skills WHERE country = 'Canada' AND status = 'active';

-- Jobs matching a user's skills (with score)
SELECT job_id, title, company, fn_get_job_match_score(1, job_id) AS match_score
FROM jobs WHERE status = 'active'
ORDER BY match_score DESC;
```

### UPDATE
```sql
-- Close a job
UPDATE jobs SET status = 'closed', updated_at = NOW() WHERE job_id = 1;

-- Extend deadline
UPDATE jobs SET closes_at = '2026-12-31', updated_at = NOW() WHERE job_id = 1;

-- Update salary range
UPDATE jobs SET salary_min = 95000, salary_max = 140000 WHERE job_id = 1;
```

### DELETE
```sql
-- Remove a job (cascades to job_skills and job_applications)
DELETE FROM jobs WHERE job_id = 4;
```

---

## Job Applications

### CREATE
```sql
-- Via stored procedure (recommended — validates + logs)
CALL sp_apply_for_job(3, 1, 'درخواست با انگیزه برای این موقعیت', NULL);

-- Direct INSERT (bypass all validation)
INSERT INTO job_applications (user_id, job_id, status, cover_letter, applied_at)
VALUES (3, 1, 'submitted', 'Cover letter text', NOW());
```

### READ
```sql
-- All applications for a user
SELECT * FROM v_application_summary WHERE applicant_email = 'ali.rezaei@example.com';

-- Applications for a specific job (recruitment pipeline)
SELECT applicant_name, applicant_email, status, match_score, applied_at
FROM v_application_summary WHERE job_title = 'Senior Python Developer'
ORDER BY match_score DESC;

-- Applications in interview stage
SELECT * FROM v_application_summary WHERE status = 'interview';
```

### UPDATE
```sql
-- Advance to interview
UPDATE job_applications
SET status = 'interview', interview_at = NOW() + INTERVAL '5 days', updated_at = NOW()
WHERE app_id = 1;
-- → Trigger: notification sent to applicant

-- Make offer
UPDATE job_applications
SET status = 'offer', offer_amount = 120000, updated_at = NOW()
WHERE app_id = 1;
```

### DELETE
```sql
-- Withdraw application (preferred over hard delete)
UPDATE job_applications SET status = 'withdrawn', updated_at = NOW() WHERE app_id = 1;

-- Hard delete (removes history)
DELETE FROM job_applications WHERE app_id = 1;
```

---

## Immigration Programs & Visa Applications

### CREATE
```sql
-- New program (admin)
INSERT INTO immigration_programs
    (country_id, name, program_code, category, description, min_eligibility_score, processing_time_days)
VALUES
    (4, 'Australia Skilled Independent 189', 'AU-189', 'permanent_residence',
     'Points-based stream for skilled workers not sponsored by an employer or family member.',
     65, 365);

-- Assess and create visa application
CALL sp_assess_immigration_eligibility(2, 1, NULL, NULL);
```

### READ
```sql
-- All visa applications for a user
SELECT * FROM v_immigration_dashboard WHERE user_id = 2;

-- Eligible users for a specific program
SELECT applicant_name, eligibility_score, score_gap
FROM v_immigration_dashboard
WHERE program_code = 'CA-EE' AND is_eligible = TRUE
ORDER BY eligibility_score DESC;
```

### UPDATE
```sql
-- Process visa application (consultant/admin)
CALL sp_process_visa_application(1, 'under_review', 'Documents received and being reviewed.');
CALL sp_process_visa_application(1, 'approved', 'All requirements met. PR granted.');
```

### DELETE
```sql
-- Withdraw visa application
CALL sp_process_visa_application(1, 'withdrawn', 'Applicant withdrew the application.');

-- Hard delete (admin only)
DELETE FROM visa_applications WHERE visa_app_id = 1;
```

---

## Documents

### CREATE
```sql
INSERT INTO documents (user_id, doc_type, file_name, file_path, file_size_kb)
VALUES (1, 'degree', 'masters_certificate.pdf', '/uploads/1/degree.pdf', 1024);
```

### READ
```sql
-- All documents for a user
SELECT doc_type, file_name, status, uploaded_at
FROM documents WHERE user_id = 1 ORDER BY uploaded_at DESC;

-- Pending documents awaiting review
SELECT u.email, d.doc_type, d.file_name, d.uploaded_at
FROM documents d
JOIN users u ON u.user_id = d.user_id
WHERE d.status = 'pending'
ORDER BY d.uploaded_at;
```

### UPDATE
```sql
-- Admin approves a document
UPDATE documents
SET status = 'approved', reviewed_at = NOW(), reviewed_by = 7
WHERE doc_id = 1;

-- Admin rejects with reason
UPDATE documents
SET status = 'rejected',
    rejection_note = 'Document is expired. Please upload a valid copy.',
    reviewed_at = NOW(),
    reviewed_by = 7
WHERE doc_id = 2;
```

### DELETE
```sql
-- Remove document (cascade from user delete, or manual)
DELETE FROM documents WHERE doc_id = 1;
```

---

## Notifications (Read & Mark)

### READ
```sql
-- Unread notifications for a user
SELECT notif_id, title, message, created_at
FROM notifications
WHERE user_id = 1 AND is_read = FALSE
ORDER BY created_at DESC;
```

### UPDATE
```sql
-- Mark single notification as read
UPDATE notifications SET is_read = TRUE, read_at = NOW() WHERE notif_id = 5;

-- Mark all as read
UPDATE notifications SET is_read = TRUE, read_at = NOW()
WHERE user_id = 1 AND is_read = FALSE;
```

### DELETE
```sql
-- Delete old read notifications (housekeeping)
DELETE FROM notifications
WHERE user_id = 1 AND is_read = TRUE AND created_at < NOW() - INTERVAL '90 days';
```
