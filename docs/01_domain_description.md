# Domain Description — Migration & Career Support System

## 1. Platform Overview

**MigrateUp** is a digital platform designed to bridge the gap between skilled immigrants and their professional goals abroad. The system integrates three tightly coupled domains:

1. **Career Support** — matching job seekers to open positions based on verified skills
2. **Immigration Assessment** — scoring users' eligibility for structured visa programs
3. **Consultation Management** — connecting users with licensed immigration and career advisors

The core value proposition is that a single data model serves all three needs: a user's education, language proficiency, and skill profile simultaneously determines their job match scores *and* their immigration eligibility scores — no redundant data entry.

---

## 2. Target Users

| Role | Description |
|---|---|
| **Job Seeker / Migrant** | Registers profile, uploads credentials, applies for jobs, tracks visa status |
| **Employer / Recruiter** | Posts job listings, reviews applicants through a match-score-sorted pipeline |
| **Immigration Consultant** | Reviews visa applications, books advisory sessions, validates user eligibility |
| **Platform Admin** | Manages reference data (skill catalog, immigration programs), monitors analytics |

---

## 3. Core Business Problems Solved

### 3.1 Skill Gap Bridging
Immigrants often possess skills that are *not recognised* or *not named correctly* in a new country's job market. The platform uses a canonical skill taxonomy (the `skills` table with `skill_categories`) to normalise all skill data. When a user's skills don't fully match a job's requirements, the **Skill Gap Analysis** module identifies each missing/insufficient skill and quantifies the shortfall as a 0–100 match score.

### 3.2 Immigration Eligibility Assessment
Most points-based immigration programs (Canada Express Entry, Germany Blue Card) evaluate candidates on the same factors: education level, language proficiency, and work experience. The `fn_calculate_immigration_score()` function models this scoring logic in SQL, enabling real-time eligibility calculation without external API calls.

### 3.3 Centralised Document Management
Migrants must submit documents to both employers (CV, cover letter) and immigration authorities (passport, degree certificates, language test results). The `documents` table with its `status` workflow (`pending → approved / rejected`) provides a single source of truth for all user credentials.

### 3.4 Advisor Marketplace
The `consultants` and `appointments` tables enable an in-platform consulting marketplace. Availability and scheduling conflicts are enforced at the database level (via the `sp_book_appointment` stored procedure), preventing double-bookings without application-level logic.

---

## 4. Business Rules & Constraints

| Rule | Enforcement |
|---|---|
| No duplicate applications for the same job | `UNIQUE(user_id, job_id)` on `job_applications` + BEFORE trigger |
| Applications require ≥60% profile completeness | `sp_apply_for_job` validates via `fn_profile_completeness()` |
| Minimum skill match ≥30% to apply | `sp_apply_for_job` checks `fn_get_job_match_score()` |
| Expired jobs cannot receive new applications | `closes_at < CURRENT_DATE` check in procedure + BEFORE trigger |
| Finalized visa applications cannot change status | `sp_process_visa_application` blocks transitions from approved/rejected |
| Consultant time slots cannot overlap | `tstzrange &&` operator in `sp_book_appointment` |
| Profile completeness updates automatically | AFTER INSERT/UPDATE triggers on 5 user tables |

---

## 5. Latest System Updates (v2.0)

- **Scoring model** now weights education (40 pts) + language/IELTS (40 pts) + work experience (20 pts)
- **JSONB skill snapshots** stored in `skill_gap_analyses` for historical gap tracking
- **Persian-language notifications** — all system messages stored in Farsi
- **Batch processing cursors** — weekly recommendation refresh and bulk eligibility recalculation
- **GIN indexes** on JSONB columns for sub-millisecond skill gap queries
- **Auto-expiry trigger** closes job postings when `closes_at` passes

---

## 6. Data Flow Summary

```
User Registers
    ↓
Profile Completion (education + skills + languages + work exp)
    ↓ (triggers profile_completeness_pct recalculation)
Gap Analysis (fn_check_skill_gap → job match scores)
    ↓
Job Application (sp_apply_for_job — validates + inserts)
    ↓ (trigger logs activity, sends notification)
Immigration Assessment (sp_assess_immigration_eligibility)
    ↓
Visa Application (sp_process_visa_application — status transitions)
    ↓
Consultant Appointment (sp_book_appointment — overlap-safe booking)
```
