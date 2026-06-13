# Migration & Career Support System

A university-level database project demonstrating advanced PostgreSQL design for a platform that helps skilled migrants navigate job markets and immigration pathways.

---

## Quick Start

```bash
# 1. Create the database
createdb migrationdb

# 2. Run in order
psql -U postgres -d migrationdb -f sql/01_schema.sql
psql -U postgres -d migrationdb -f sql/02_indexes.sql
psql -U postgres -d migrationdb -f sql/03_functions.sql
psql -U postgres -d migrationdb -f sql/04_stored_procedures.sql
psql -U postgres -d migrationdb -f sql/05_triggers.sql
psql -U postgres -d migrationdb -f sql/06_cursors.sql
psql -U postgres -d migrationdb -f sql/07_views.sql
psql -U postgres -d migrationdb -f sql/08_queries.sql
psql -U postgres -d migrationdb -f sql/09_reports.sql
psql -U postgres -d migrationdb -f sql/10_sample_data.sql
```

---

## Repository Structure

```
/
├── README.md
├── sql/
│   ├── 01_schema.sql              ← 25 tables, 16 ENUM types, all constraints
│   ├── 02_indexes.sql             ← Composite, partial, and GIN indexes
│   ├── 03_functions.sql           ← 8 user-defined functions
│   ├── 04_stored_procedures.sql   ← 5 stored procedures
│   ├── 05_triggers.sql            ← 7 trigger groups (14+ triggers)
│   ├── 06_cursors.sql             ← 3 cursor-based batch procedures
│   ├── 07_views.sql               ← 5 analytical views
│   ├── 08_queries.sql             ← 12 critical analytical queries
│   ├── 09_reports.sql             ← 5 management reports
│   └── 10_sample_data.sql         ← Seed data (Persian users)
└── docs/
    ├── 01_domain_description.md   ← Business logic & value proposition
    ├── 02_er_diagram.md           ← Mermaid ER diagram
    ├── 03_changelog.md            ← Version history
    ├── 04_queries.md              ← Query documentation
    ├── 05_advanced_sql.md         ← Procedures/Triggers/Cursors/Functions
    ├── 06_reports.md              ← Report documentation
    ├── 07_user_lifecycle.md       ← User journey prototype
    └── 08_crud_operations.md      ← CRUD scripts
```

---

## Database at a Glance

| Module | Tables |
|---|---|
| Reference / Lookup | countries, cities, languages, education_levels, industries, skill_categories, skills |
| User Domain | users, user_profiles, user_languages, user_education, user_skills, user_work_experience, documents |
| Job Domain | companies, jobs, job_skills, job_applications |
| Immigration | immigration_programs, program_requirements, visa_applications |
| Platform | skill_gap_analyses, recommendations, activity_logs, notifications |
| Consultants | consultants, appointments |

**Total: 25 tables · 16 ENUM types · 8 UDFs · 5 procedures · 14+ triggers · 5 views**

---

## Key Features Demonstrated

- **Stored Procedures** — `sp_register_user`, `sp_apply_for_job`, `sp_assess_immigration_eligibility`, `sp_process_visa_application`, `sp_book_appointment`
- **User-Defined Functions** — Immigration scoring, skill gap analysis, match score, profile completeness, net salary
- **Triggers** — Auto `updated_at`, activity logging, status-change notifications, profile completeness recalculation, duplicate prevention, auto job expiry
- **Explicit Cursors** — Batch recommendation generation, bulk eligibility recalculation, expiry notification sweep
- **Advanced SQL** — CTEs, window functions, LATERAL joins, GROUPING SETS, JSONB operators, GIN indexes, FILTER aggregates

---

## Sample Users (Persian/Iranian)

| Name | Role | Target |
|---|---|---|
| علی رضایی (Ali Rezaei) | Senior Python Dev | Canada Express Entry |
| لیلا احمدی (Leila Ahmadi) | Data Scientist | Germany Blue Card |
| محمد حسینی (Mohammad Hosseini) | Project Manager | Canada Express Entry |
| سارا کریمی (Sara Karimi) | UX Designer | — |
| رضا نوری (Reza Nouri) | DevOps Engineer | Germany Blue Card |

---

## Documentation

See the `docs/` directory for full coverage of all 8 project requirements.
