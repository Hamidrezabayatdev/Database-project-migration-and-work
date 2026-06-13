-- =============================================================
-- Migration & Career Support System
-- File        : 01_schema.sql
-- Engine      : PostgreSQL 15+
-- Description : Full DDL — 25 tables, 3NF, with all constraints
-- Execution   : psql -U postgres -d migrationdb -f sql/01_schema.sql
-- =============================================================

BEGIN;
SET client_min_messages = WARNING;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================
-- SECTION 1: ENUM TYPES
-- =============================================================

CREATE TYPE user_role              AS ENUM ('seeker','employer','consultant','admin');
CREATE TYPE language_proficiency   AS ENUM ('basic','conversational','professional','native');
CREATE TYPE language_test_type     AS ENUM ('IELTS','TOEFL','DELF','GOETHE','OTHER');
CREATE TYPE skill_proficiency      AS ENUM ('beginner','intermediate','advanced','expert');
CREATE TYPE document_type          AS ENUM ('passport','degree','transcript','cv','cover_letter','language_test','reference','other');
CREATE TYPE document_status        AS ENUM ('pending','approved','rejected');
CREATE TYPE company_size           AS ENUM ('1-10','11-50','51-200','201-500','500+');
CREATE TYPE job_status             AS ENUM ('draft','active','closed','expired');
CREATE TYPE employment_type        AS ENUM ('full-time','part-time','contract','remote','hybrid');
CREATE TYPE application_status     AS ENUM ('draft','submitted','reviewing','interview','offer','accepted','rejected','withdrawn');
CREATE TYPE program_category       AS ENUM ('work_permit','permanent_residence','student_visa','temporary_worker','entrepreneur');
CREATE TYPE requirement_type       AS ENUM ('education','language','experience','age','funds','job_offer','other');
CREATE TYPE visa_status            AS ENUM ('draft','submitted','under_review','approved','rejected','withdrawn');
CREATE TYPE recommendation_type    AS ENUM ('job','program','skill','consultant','course');
CREATE TYPE consultant_specialization AS ENUM ('immigration','career','both');
CREATE TYPE appointment_status     AS ENUM ('pending','confirmed','completed','cancelled','no_show');

-- =============================================================
-- SECTION 2: REFERENCE / LOOKUP TABLES
-- =============================================================

CREATE TABLE countries (
    country_id  SERIAL      PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    iso_code    CHAR(2)      NOT NULL UNIQUE,
    region      VARCHAR(100),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE cities (
    city_id     SERIAL       PRIMARY KEY,
    country_id  INT          NOT NULL REFERENCES countries(country_id),
    name        VARCHAR(100) NOT NULL,
    is_major    BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (country_id, name)
);

CREATE TABLE languages (
    language_id SERIAL       PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    iso_code    CHAR(3)      NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE education_levels (
    level_id    SERIAL       PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    rank_order  SMALLINT     NOT NULL UNIQUE,   -- 1=High School … 6=PhD
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE industries (
    industry_id SERIAL       PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE skill_categories (
    category_id SERIAL       PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE skills (
    skill_id    SERIAL       PRIMARY KEY,
    category_id INT          NOT NULL REFERENCES skill_categories(category_id),
    name        VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- =============================================================
-- SECTION 3: USER DOMAIN
-- =============================================================

CREATE TABLE users (
    user_id        SERIAL       PRIMARY KEY,
    email          VARCHAR(255) NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    role           user_role    NOT NULL DEFAULT 'seeker',
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    email_verified BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    last_login_at  TIMESTAMPTZ
);

CREATE TABLE user_profiles (
    profile_id               SERIAL      PRIMARY KEY,
    user_id                  INT         NOT NULL UNIQUE REFERENCES users(user_id) ON DELETE CASCADE,
    first_name               VARCHAR(100) NOT NULL,
    last_name                VARCHAR(100) NOT NULL,
    date_of_birth            DATE,
    nationality_country_id   INT          REFERENCES countries(country_id),
    current_country_id       INT          REFERENCES countries(country_id),
    current_city_id          INT          REFERENCES cities(city_id),
    phone                    VARCHAR(30),
    bio                      TEXT,
    linkedin_url             VARCHAR(500),
    portfolio_url            VARCHAR(500),
    profile_completeness_pct SMALLINT    NOT NULL DEFAULT 0
        CONSTRAINT chk_completeness CHECK (profile_completeness_pct BETWEEN 0 AND 100),
    created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE user_languages (
    user_language_id SERIAL              PRIMARY KEY,
    user_id          INT                 NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    language_id      INT                 NOT NULL REFERENCES languages(language_id),
    proficiency      language_proficiency NOT NULL,
    test_type        language_test_type,
    test_score       NUMERIC(5,2),
    created_at       TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, language_id)
);

CREATE TABLE institutions (
    institution_id SERIAL       PRIMARY KEY,
    name           VARCHAR(255) NOT NULL,
    country_id     INT          REFERENCES countries(country_id),
    is_accredited  BOOLEAN      NOT NULL DEFAULT TRUE,
    website        VARCHAR(500),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE user_education (
    edu_id           SERIAL       PRIMARY KEY,
    user_id          INT          NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    level_id         INT          NOT NULL REFERENCES education_levels(level_id),
    institution_name VARCHAR(255) NOT NULL,
    field_of_study   VARCHAR(255) NOT NULL,
    country_id       INT          REFERENCES countries(country_id),
    start_year       SMALLINT     NOT NULL,
    end_year         SMALLINT,
    is_completed     BOOLEAN      NOT NULL DEFAULT TRUE,
    gpa              NUMERIC(3,2),
    is_verified      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE user_skills (
    user_skill_id SERIAL           PRIMARY KEY,
    user_id       INT              NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    skill_id      INT              NOT NULL REFERENCES skills(skill_id),
    proficiency   skill_proficiency NOT NULL DEFAULT 'beginner',
    years_exp     NUMERIC(4,1)     CHECK (years_exp >= 0),
    is_verified   BOOLEAN          NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, skill_id)
);

CREATE TABLE user_work_experience (
    exp_id       SERIAL       PRIMARY KEY,
    user_id      INT          NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    industry_id  INT          REFERENCES industries(industry_id),
    job_title    VARCHAR(255) NOT NULL,
    country_id   INT          REFERENCES countries(country_id),
    start_date   DATE         NOT NULL,
    end_date     DATE,
    is_current   BOOLEAN      NOT NULL DEFAULT FALSE,
    description  TEXT,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_exp_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE documents (
    doc_id         SERIAL          PRIMARY KEY,
    user_id        INT             NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    doc_type       document_type   NOT NULL,
    file_name      VARCHAR(500)    NOT NULL,
    file_path      VARCHAR(1000)   NOT NULL,
    file_size_kb   INT,
    status         document_status NOT NULL DEFAULT 'pending',
    rejection_note TEXT,
    uploaded_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    reviewed_at    TIMESTAMPTZ,
    reviewed_by    INT             REFERENCES users(user_id)
);

-- =============================================================
-- SECTION 4: JOB DOMAIN
-- =============================================================

CREATE TABLE companies (
    company_id  SERIAL       PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    industry_id INT          REFERENCES industries(industry_id),
    country_id  INT          REFERENCES countries(country_id),
    city_id     INT          REFERENCES cities(city_id),
    website     VARCHAR(500),
    size_range  company_size,
    is_verified BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE jobs (
    job_id              SERIAL          PRIMARY KEY,
    company_id          INT             NOT NULL REFERENCES companies(company_id),
    title               VARCHAR(255)    NOT NULL,
    description         TEXT,
    industry_id         INT             REFERENCES industries(industry_id),
    country_id          INT             REFERENCES countries(country_id),
    city_id             INT             REFERENCES cities(city_id),
    employment_type     employment_type NOT NULL DEFAULT 'full-time',
    required_exp_years  SMALLINT        NOT NULL DEFAULT 0,
    min_education_level INT             REFERENCES education_levels(level_id),
    salary_min          NUMERIC(10,2),
    salary_max          NUMERIC(10,2),
    currency            CHAR(3)         NOT NULL DEFAULT 'USD',
    status              job_status      NOT NULL DEFAULT 'draft',
    posted_at           TIMESTAMPTZ,
    closes_at           DATE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_salary CHECK (salary_max IS NULL OR salary_max >= salary_min)
);

CREATE TABLE job_skills (
    job_skill_id    SERIAL           PRIMARY KEY,
    job_id          INT              NOT NULL REFERENCES jobs(job_id) ON DELETE CASCADE,
    skill_id        INT              NOT NULL REFERENCES skills(skill_id),
    is_required     BOOLEAN          NOT NULL DEFAULT TRUE,
    min_proficiency skill_proficiency NOT NULL DEFAULT 'beginner',
    UNIQUE (job_id, skill_id)
);

CREATE TABLE job_applications (
    app_id       SERIAL             PRIMARY KEY,
    user_id      INT                NOT NULL REFERENCES users(user_id),
    job_id       INT                NOT NULL REFERENCES jobs(job_id),
    status       application_status NOT NULL DEFAULT 'draft',
    cover_letter TEXT,
    match_score  NUMERIC(5,2)       CONSTRAINT chk_match CHECK (match_score BETWEEN 0 AND 100),
    applied_at   TIMESTAMPTZ,
    interview_at TIMESTAMPTZ,
    offer_amount NUMERIC(10,2),
    notes        TEXT,
    created_at   TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, job_id)
);

-- =============================================================
-- SECTION 5: IMMIGRATION DOMAIN
-- =============================================================

CREATE TABLE immigration_programs (
    program_id            SERIAL           PRIMARY KEY,
    country_id            INT              NOT NULL REFERENCES countries(country_id),
    name                  VARCHAR(255)     NOT NULL,
    program_code          VARCHAR(50)      NOT NULL UNIQUE,
    category              program_category NOT NULL,
    description           TEXT,
    min_eligibility_score SMALLINT         NOT NULL DEFAULT 60
        CONSTRAINT chk_min_score CHECK (min_eligibility_score BETWEEN 0 AND 100),
    max_score             SMALLINT         NOT NULL DEFAULT 100,
    processing_time_days  INT,
    official_url          VARCHAR(500),
    is_active             BOOLEAN          NOT NULL DEFAULT TRUE,
    created_at            TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE TABLE program_requirements (
    req_id           SERIAL           PRIMARY KEY,
    program_id       INT              NOT NULL REFERENCES immigration_programs(program_id) ON DELETE CASCADE,
    requirement_type requirement_type NOT NULL,
    description      TEXT             NOT NULL,
    min_value        NUMERIC(10,2),
    max_value        NUMERIC(10,2),
    points_weight    SMALLINT         NOT NULL DEFAULT 0
        CONSTRAINT chk_weight CHECK (points_weight BETWEEN 0 AND 100),
    is_mandatory     BOOLEAN          NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW()
);

CREATE TABLE visa_applications (
    visa_app_id       SERIAL      PRIMARY KEY,
    user_id           INT         NOT NULL REFERENCES users(user_id),
    program_id        INT         NOT NULL REFERENCES immigration_programs(program_id),
    status            visa_status NOT NULL DEFAULT 'draft',
    eligibility_score SMALLINT    CONSTRAINT chk_visa_score CHECK (eligibility_score BETWEEN 0 AND 100),
    submitted_at      TIMESTAMPTZ,
    decision_at       TIMESTAMPTZ,
    rejection_reason  TEXT,
    notes             TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =============================================================
-- SECTION 6: SYSTEM / PLATFORM TABLES
-- =============================================================

CREATE TABLE skill_gap_analyses (
    analysis_id    SERIAL      PRIMARY KEY,
    user_id        INT         NOT NULL REFERENCES users(user_id),
    job_id         INT         NOT NULL REFERENCES jobs(job_id),
    match_score    NUMERIC(5,2) NOT NULL
        CONSTRAINT chk_gap_score CHECK (match_score BETWEEN 0 AND 100),
    missing_skills JSONB,
    matched_skills JSONB,
    recommendation TEXT,
    analyzed_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, job_id)
);

CREATE TABLE recommendations (
    rec_id      SERIAL              PRIMARY KEY,
    user_id     INT                 NOT NULL REFERENCES users(user_id),
    entity_type recommendation_type NOT NULL,
    entity_id   INT                 NOT NULL,
    score       NUMERIC(5,2)        CONSTRAINT chk_rec_score CHECK (score BETWEEN 0 AND 100),
    reason      TEXT,
    is_dismissed BOOLEAN            NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

CREATE TABLE activity_logs (
    log_id      BIGSERIAL   PRIMARY KEY,
    user_id     INT         REFERENCES users(user_id),
    action      VARCHAR(100) NOT NULL,
    table_name  VARCHAR(100),
    record_id   INT,
    ip_address  INET,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
    notif_id      SERIAL       PRIMARY KEY,
    user_id       INT          NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title         VARCHAR(200) NOT NULL,
    message       TEXT,
    is_read       BOOLEAN      NOT NULL DEFAULT FALSE,
    related_table VARCHAR(100),
    related_id    INT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    read_at       TIMESTAMPTZ
);

-- =============================================================
-- SECTION 7: CONSULTANT MODULE
-- =============================================================

CREATE TABLE consultants (
    consultant_id  SERIAL                    PRIMARY KEY,
    user_id        INT                       NOT NULL UNIQUE REFERENCES users(user_id),
    specialization consultant_specialization NOT NULL DEFAULT 'both',
    license_number VARCHAR(100),
    hourly_rate    NUMERIC(8,2),
    rating         NUMERIC(3,2)              CONSTRAINT chk_rating CHECK (rating BETWEEN 1.0 AND 5.0),
    total_reviews  INT                       NOT NULL DEFAULT 0,
    bio            TEXT,
    is_available   BOOLEAN                   NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ               NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ               NOT NULL DEFAULT NOW()
);

CREATE TABLE appointments (
    appt_id          SERIAL             PRIMARY KEY,
    user_id          INT                NOT NULL REFERENCES users(user_id),
    consultant_id    INT                NOT NULL REFERENCES consultants(consultant_id),
    visa_app_id      INT                REFERENCES visa_applications(visa_app_id),
    scheduled_at     TIMESTAMPTZ        NOT NULL,
    duration_minutes SMALLINT           NOT NULL DEFAULT 60,
    status           appointment_status NOT NULL DEFAULT 'pending',
    meeting_url      VARCHAR(500),
    notes            TEXT,
    created_at       TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

COMMIT;
