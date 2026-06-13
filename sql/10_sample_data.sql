-- =============================================================
-- Migration & Career Support System
-- File        : 10_sample_data.sql
-- Description : Minimal seed data — Persian/Iranian users
-- Run after   : 01_schema.sql (all other SQL files optional)
-- =============================================================

BEGIN;

-- =============================================================
-- REFERENCE DATA
-- =============================================================

-- Countries
INSERT INTO countries (name, iso_code, region) VALUES
    ('Iran',        'IR', 'Middle East'),
    ('Canada',      'CA', 'North America'),
    ('Germany',     'DE', 'Europe'),
    ('Australia',   'AU', 'Oceania'),
    ('United States','US','North America');

-- Cities
INSERT INTO cities (country_id, name, is_major) VALUES
    (1, 'Tehran',    TRUE),
    (1, 'Isfahan',   TRUE),
    (2, 'Toronto',   TRUE),
    (2, 'Vancouver', TRUE),
    (3, 'Berlin',    TRUE),
    (3, 'Munich',    TRUE),
    (4, 'Sydney',    TRUE),
    (5, 'New York',  TRUE);

-- Languages
INSERT INTO languages (name, iso_code) VALUES
    ('Persian',  'fas'),
    ('English',  'eng'),
    ('German',   'deu'),
    ('French',   'fra'),
    ('Arabic',   'ara');

-- Education levels (rank_order determines scoring weight)
INSERT INTO education_levels (name, rank_order) VALUES
    ('High School Diploma',  1),
    ('Associate Degree',     2),
    ('Bachelor''s Degree',   3),
    ('Master''s Degree',     4),
    ('MBA',                  5),
    ('PhD / Doctorate',      6);

-- Industries
INSERT INTO industries (name) VALUES
    ('Information Technology'),
    ('Finance & Banking'),
    ('Healthcare'),
    ('Engineering'),
    ('Education'),
    ('Data Science & AI');

-- Skill categories
INSERT INTO skill_categories (name) VALUES
    ('Programming'),
    ('Data & Analytics'),
    ('DevOps & Cloud'),
    ('Design'),
    ('Project Management'),
    ('Soft Skills');

-- Skills
INSERT INTO skills (category_id, name) VALUES
    (1, 'Python'),
    (1, 'JavaScript'),
    (1, 'Java'),
    (1, 'SQL'),
    (1, 'Django'),
    (1, 'React'),
    (2, 'Machine Learning'),
    (2, 'Data Analysis'),
    (2, 'Power BI'),
    (3, 'Docker'),
    (3, 'Kubernetes'),
    (3, 'Linux'),
    (4, 'Figma'),
    (4, 'UX Research'),
    (5, 'Project Management'),
    (5, 'Agile / Scrum'),
    (6, 'Communication'),
    (6, 'Problem Solving');

-- =============================================================
-- COMPANIES
-- =============================================================
INSERT INTO companies (name, industry_id, country_id, city_id, website, size_range, is_verified) VALUES
    ('Shopify',       1, 2, 3, 'https://shopify.com',     '500+',   TRUE),
    ('SAP SE',        1, 3, 5, 'https://sap.com',         '500+',   TRUE),
    ('Atlassian',     1, 4, 7, 'https://atlassian.com',   '500+',   TRUE);

-- =============================================================
-- IMMIGRATION PROGRAMS
-- =============================================================
INSERT INTO immigration_programs
    (country_id, name, program_code, category, description, min_eligibility_score, processing_time_days, official_url)
VALUES
    (2, 'Canada Express Entry',
        'CA-EE', 'permanent_residence',
        'Points-based permanent residence pathway for skilled workers.',
        67, 180,
        'https://www.canada.ca/en/immigration-refugees-citizenship/services/immigrate-canada/express-entry.html'),

    (3, 'Germany EU Blue Card',
        'DE-BC', 'work_permit',
        'Work permit for highly qualified non-EU professionals.',
        60, 90,
        'https://www.make-it-in-germany.com/en/visa-residence/types/eu-blue-card');

-- Program requirements
INSERT INTO program_requirements (program_id, requirement_type, description, min_value, points_weight, is_mandatory) VALUES
    (1, 'education',   'Minimum Bachelor''s degree',           3,   40, TRUE),
    (1, 'language',    'IELTS CLB 7+ (band ≥ 6.0)',           6.0, 40, TRUE),
    (1, 'experience',  'At least 1 year skilled work exp',     1,   20, TRUE),
    (2, 'education',   'University degree in relevant field',  3,   40, TRUE),
    (2, 'language',    'B2 German or B2 English',              0,   30, FALSE),
    (2, 'experience',  'Relevant work experience preferred',   0,   30, FALSE);

-- =============================================================
-- USERS — 5 Persian job seekers + 1 consultant + 1 admin
-- =============================================================
-- NOTE: Passwords are bcrypt hashes of 'Password123!' (demo only)
INSERT INTO users (email, password_hash, role) VALUES
    ('ali.rezaei@example.com',      '$2b$12$KIXdemos', 'seeker'),     -- user_id 1
    ('leila.ahmadi@example.com',    '$2b$12$KIXdemos', 'seeker'),     -- user_id 2
    ('mohammad.hosseini@example.com','$2b$12$KIXdemos', 'seeker'),    -- user_id 3
    ('sara.karimi@example.com',     '$2b$12$KIXdemos', 'seeker'),     -- user_id 4
    ('reza.nouri@example.com',      '$2b$12$KIXdemos', 'seeker'),     -- user_id 5
    ('mitra.consultant@example.com','$2b$12$KIXdemos', 'consultant'), -- user_id 6
    ('admin@migrationapp.com',      '$2b$12$KIXdemos', 'admin');      -- user_id 7

-- User profiles
INSERT INTO user_profiles
    (user_id, first_name, last_name, date_of_birth,
     nationality_country_id, current_country_id, current_city_id,
     phone, bio)
VALUES
    (1, 'Ali',      'Rezaei',    '1993-04-15', 1, 1, 1, '+98-912-1234567',
     'نرم‌افزار مهندس با ۷ سال تجربه در توسعه بک‌اند. به دنبال فرصت‌های مهاجرتی به کانادا هستم.'),

    (2, 'Leila',    'Ahmadi',    '1995-09-22', 1, 1, 2, '+98-935-2345678',
     'تحلیل‌گر داده با تخصص در یادگیری ماشین. هدفم دریافت بلوکارت آبی آلمان است.'),

    (3, 'Mohammad', 'Hosseini',  '1988-12-05', 1, 1, 1, '+98-911-3456789',
     'مدیر پروژه چابک با ۱۰ سال تجربه در صنعت فناوری اطلاعات.'),

    (4, 'Sara',     'Karimi',    '1997-06-18', 1, 1, 2, '+98-919-4567890',
     'طراح UX با اشتیاق برای ایجاد تجربه‌های کاربری شهودی. سه سال سابقه در استارتاپ‌ها.'),

    (5, 'Reza',     'Nouri',     '1991-03-30', 1, 1, 1, '+98-912-5678901',
     'مهندس DevOps متخصص در Docker و Kubernetes. پنج سال تجربه در زیرساخت ابری.'),

    (6, 'Mitra',    'Sadeghi',   '1982-07-14', 1, 2, 3, '+1-416-678-9012',
     'مشاور مهاجرت با ۱۵ سال تجربه در پرونده‌های Express Entry و بلوکارت آبی.'),

    (7, 'System',   'Admin',     '1990-01-01', 1, 2, 3, NULL, 'System administrator.');

-- Consultant record
INSERT INTO consultants (user_id, specialization, license_number, hourly_rate, rating, total_reviews, is_available)
VALUES (6, 'immigration', 'ICCRC-R123456', 150.00, 4.8, 42, TRUE);

-- =============================================================
-- USER LANGUAGES
-- =============================================================
INSERT INTO user_languages (user_id, language_id, proficiency, test_type, test_score) VALUES
    -- Ali: IELTS 7.5
    (1, 1, 'native',       NULL,    NULL),
    (1, 2, 'professional', 'IELTS', 7.5),

    -- Leila: IELTS 8.0, some German
    (2, 1, 'native',       NULL,    NULL),
    (2, 2, 'professional', 'IELTS', 8.0),
    (2, 3, 'conversational','GOETHE',70.0),

    -- Mohammad: IELTS 6.5
    (3, 1, 'native',       NULL,    NULL),
    (3, 2, 'professional', 'IELTS', 6.5),

    -- Sara: IELTS 7.0
    (4, 1, 'native',       NULL,    NULL),
    (4, 2, 'professional', 'IELTS', 7.0),

    -- Reza: IELTS 6.5
    (5, 1, 'native',       NULL,    NULL),
    (5, 2, 'professional', 'IELTS', 6.5);

-- =============================================================
-- USER EDUCATION
-- =============================================================
INSERT INTO user_education (user_id, level_id, institution_name, field_of_study, country_id, start_year, end_year, is_completed) VALUES
    (1, 4, 'Sharif University of Technology', 'Computer Science',          1, 2015, 2017, TRUE),
    (2, 4, 'University of Tehran',            'Data Science',              1, 2017, 2019, TRUE),
    (3, 3, 'Amirkabir University',            'Industrial Engineering',    1, 2006, 2010, TRUE),
    (3, 5, 'Tehran Business School',          'MBA',                       1, 2012, 2014, TRUE),
    (4, 3, 'Isfahan University of Technology','Graphic Design',            1, 2015, 2019, TRUE),
    (5, 3, 'Shahid Beheshti University',      'Computer Engineering',      1, 2009, 2013, TRUE);

-- =============================================================
-- USER SKILLS
-- =============================================================
INSERT INTO user_skills (user_id, skill_id, proficiency, years_exp) VALUES
    -- Ali: Python backend developer
    (1,  1, 'expert',       7.0),   -- Python
    (1,  4, 'advanced',     7.0),   -- SQL
    (1,  5, 'advanced',     5.0),   -- Django
    (1, 17, 'advanced',     7.0),   -- Communication
    (1, 18, 'advanced',     7.0),   -- Problem Solving

    -- Leila: Data scientist
    (2,  1, 'advanced',     4.0),   -- Python
    (2,  7, 'expert',       4.0),   -- Machine Learning
    (2,  8, 'expert',       4.0),   -- Data Analysis
    (2,  9, 'intermediate', 2.0),   -- Power BI
    (2,  4, 'intermediate', 4.0),   -- SQL

    -- Mohammad: Project manager
    (3, 15, 'expert',      10.0),   -- Project Management
    (3, 16, 'expert',       8.0),   -- Agile / Scrum
    (3, 17, 'expert',      10.0),   -- Communication
    (3, 18, 'expert',      10.0),   -- Problem Solving

    -- Sara: UX designer
    (4, 13, 'expert',       3.0),   -- Figma
    (4, 14, 'advanced',     3.0),   -- UX Research
    (4, 17, 'advanced',     3.0),   -- Communication

    -- Reza: DevOps engineer
    (5, 10, 'expert',       5.0),   -- Docker
    (5, 11, 'advanced',     3.0),   -- Kubernetes
    (5, 12, 'expert',       7.0),   -- Linux
    (5,  4, 'intermediate', 5.0),   -- SQL
    (5, 18, 'advanced',     5.0);   -- Problem Solving

-- =============================================================
-- USER WORK EXPERIENCE
-- =============================================================
INSERT INTO user_work_experience
    (user_id, company_name, industry_id, job_title, country_id, start_date, end_date)
VALUES
    (1, 'Snapp!',      1, 'Senior Backend Developer', 1, '2017-03-01', '2024-01-01'),
    (2, 'DigiKala',    6, 'Data Scientist',            1, '2019-06-01', NULL),
    (3, 'Tap30',       1, 'Engineering Manager',       1, '2014-09-01', NULL),
    (4, 'CafeBazaar',  1, 'UX Designer',               1, '2020-01-01', NULL),
    (5, 'Asan Pardakht',1,'DevOps Engineer',            1, '2018-05-01', NULL);

-- =============================================================
-- DOCUMENTS
-- =============================================================
INSERT INTO documents (user_id, doc_type, file_name, file_path, status) VALUES
    (1, 'passport', 'ali_passport.pdf',     '/uploads/1/passport.pdf',    'approved'),
    (1, 'cv',       'ali_cv.pdf',           '/uploads/1/cv.pdf',          'approved'),
    (1, 'language_test','ali_ielts.pdf',    '/uploads/1/ielts.pdf',       'approved'),
    (2, 'passport', 'leila_passport.pdf',   '/uploads/2/passport.pdf',    'approved'),
    (2, 'degree',   'leila_degree.pdf',     '/uploads/2/degree.pdf',      'approved'),
    (3, 'passport', 'mohammad_passport.pdf','/uploads/3/passport.pdf',    'pending'),
    (4, 'cv',       'sara_cv.pdf',          '/uploads/4/cv.pdf',          'approved'),
    (5, 'cv',       'reza_cv.pdf',          '/uploads/5/cv.pdf',          'pending');

-- =============================================================
-- JOBS
-- =============================================================
INSERT INTO jobs
    (company_id, title, description, industry_id, country_id, city_id,
     employment_type, required_exp_years, min_education_level,
     salary_min, salary_max, currency, status, posted_at, closes_at)
VALUES
    (1, 'Senior Python Developer',
        'Build scalable e-commerce APIs using Django REST Framework and PostgreSQL.',
        1, 2, 3, 'full-time', 5, 3,
        90000, 130000, 'CAD', 'active', NOW(), '2026-09-30'),

    (2, 'Data Scientist – NLP',
        'Apply machine learning and NLP techniques to enterprise HR datasets.',
        6, 3, 5, 'full-time', 3, 4,
        65000, 90000, 'EUR', 'active', NOW(), '2026-08-31'),

    (3, 'DevOps Engineer',
        'Maintain CI/CD pipelines, manage Kubernetes clusters on AWS.',
        1, 4, 7, 'hybrid', 4, 3,
        100000, 140000, 'AUD', 'active', NOW(), '2026-10-15');

-- Job skills
INSERT INTO job_skills (job_id, skill_id, is_required, min_proficiency) VALUES
    -- Senior Python Developer (job 1)
    (1,  1, TRUE,  'advanced'),     -- Python
    (1,  4, TRUE,  'intermediate'), -- SQL
    (1,  5, TRUE,  'advanced'),     -- Django
    (1,  2, FALSE, 'beginner'),     -- JavaScript
    (1, 17, FALSE, 'intermediate'), -- Communication

    -- Data Scientist (job 2)
    (2,  7, TRUE,  'advanced'),     -- Machine Learning
    (2,  1, TRUE,  'advanced'),     -- Python
    (2,  8, TRUE,  'intermediate'), -- Data Analysis
    (2,  4, FALSE, 'intermediate'), -- SQL
    (2,  9, FALSE, 'beginner'),     -- Power BI

    -- DevOps Engineer (job 3)
    (3, 10, TRUE,  'advanced'),     -- Docker
    (3, 11, TRUE,  'intermediate'), -- Kubernetes
    (3, 12, TRUE,  'advanced'),     -- Linux
    (3,  4, FALSE, 'beginner'),     -- SQL
    (3, 16, FALSE, 'beginner');     -- Agile / Scrum

-- =============================================================
-- JOB APPLICATIONS
-- =============================================================
INSERT INTO job_applications (user_id, job_id, status, cover_letter, match_score, applied_at) VALUES
    (1, 1, 'interview',  'تجربه گسترده‌ای در Django و API RESTful دارم.', 95.00, NOW() - INTERVAL '15 days'),
    (2, 2, 'submitted',  'پنج سال در یادگیری ماشین با داده‌های واقعی کار کرده‌ام.', 90.00, NOW() - INTERVAL '10 days'),
    (5, 3, 'reviewing',  'متخصص Docker و Kubernetes با گواهینامه CKA.', 88.00, NOW() - INTERVAL '5 days'),
    (2, 1, 'submitted',  'Python developer with strong analytics background.', 65.00, NOW() - INTERVAL '8 days');

-- =============================================================
-- SKILL GAP ANALYSES
-- =============================================================
INSERT INTO skill_gap_analyses (user_id, job_id, match_score, missing_skills, matched_skills) VALUES
    (1, 1, 95.00,
     '[]'::jsonb,
     '[{"skill_id":1,"skill_name":"Python"},{"skill_id":4,"skill_name":"SQL"},{"skill_id":5,"skill_name":"Django"}]'::jsonb),

    (2, 2, 90.00,
     '[{"skill_id":9,"skill_name":"Power BI"}]'::jsonb,
     '[{"skill_id":7,"skill_name":"Machine Learning"},{"skill_id":1,"skill_name":"Python"}]'::jsonb),

    (5, 3, 88.00,
     '[{"skill_id":16,"skill_name":"Agile / Scrum"}]'::jsonb,
     '[{"skill_id":10,"skill_name":"Docker"},{"skill_id":11,"skill_name":"Kubernetes"},{"skill_id":12,"skill_name":"Linux"}]'::jsonb);

-- =============================================================
-- VISA APPLICATIONS
-- =============================================================
INSERT INTO visa_applications (user_id, program_id, status, eligibility_score, submitted_at) VALUES
    (1, 1, 'submitted',   82, NOW() - INTERVAL '30 days'),  -- Ali → Canada EE ✓
    (2, 2, 'submitted',   75, NOW() - INTERVAL '20 days'),  -- Leila → Germany BC ✓
    (3, 1, 'draft',       58, NULL),                         -- Mohammad → below threshold
    (5, 2, 'submitted',   68, NOW() - INTERVAL '10 days');  -- Reza → Germany BC ✓

-- =============================================================
-- APPOINTMENTS
-- =============================================================
INSERT INTO appointments
    (user_id, consultant_id, visa_app_id, scheduled_at, status, notes)
VALUES
    (1, 1, 1, NOW() + INTERVAL '7 days',  'confirmed',  'بررسی پرونده Express Entry'),
    (2, 1, 2, NOW() + INTERVAL '14 days', 'pending',    'آماده‌سازی مدارک بلوکارت آلمان'),
    (3, 1, 3, NOW() + INTERVAL '3 days',  'confirmed',  'راهنمایی برای بهبود امتیاز');

-- =============================================================
-- RECOMMENDATIONS
-- =============================================================
INSERT INTO recommendations (user_id, entity_type, entity_id, score, reason) VALUES
    (3, 'job', 1, 45.00, 'تطابق جزئی مهارت‌های فنی — بهبود مهارت‌های برنامه‌نویسی توصیه می‌شود'),
    (4, 'job', 1, 30.00, 'نیاز به مهارت‌های بیشتر در Python و SQL'),
    (3, 'program', 1, 58.00, 'امتیاز نزدیک به آستانه واجد شرایط بودن — بهبود امتیاز IELTS پیشنهاد می‌شود');

COMMIT;
