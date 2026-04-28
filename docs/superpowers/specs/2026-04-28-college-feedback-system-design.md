# College Feedback System — Design Spec

**Date:** 2026-04-28
**Status:** Approved (brainstorming complete; ready for implementation plan)
**Project:** CollegeFeedbackSystem
**College:** CSMSS Chh. Shahu College of Engineering, Aurangabad

---

## 1. Problem statement

The college collects four types of student feedback (Ambience, Curriculum, Faculty Performance, Library) using paper / Word / Excel forms today. The college has 7–9 branches, 4 years of study per branch, 1–3 divisions per (branch × year), and runs feedback every semester. Subjects in a given semester have a per-batch teacher assignment that changes year over year. First-year semesters share most subjects across branches but each branch adds its own upskill subjects, and the order of subjects between Sem-1 and Sem-2 may swap from one batch to the next.

The system must:

- Let students submit feedback scoped to their own (branch × year × division × semester).
- Preserve anonymity for the forms that require it (Ambience, Faculty) while still preventing duplicate submissions per student.
- Capture name + roll + PRN on the named forms (Curriculum, Library).
- Let department admins manage their own department's classes, subjects, teachers, offerings, rosters, campaigns, and reports — without ever seeing or touching another department's data.
- Let the super admin manage everything college-wide, including a shared "First Year Common" subject pool.
- Produce reports that mirror the institutional form layout for NAAC / audit filing, plus per-teacher reports, a live dashboard, and raw CSV.

## 2. Goals / non-goals

**Goals (v1):**
- All four feedback forms, with the question/scale schema preserved exactly as in the source documents.
- Two admin tiers (super admin, dept admin) with strict data isolation enforced at the database layer.
- Students submit via shared class access code + PRN (validated against an admin-uploaded class roster).
- Per-batch / per-semester subject + teacher mapping that supports the first-year subject swap and mid-semester teacher changes.
- Four report outputs: per-campaign aggregate PDF, per-teacher PDF/CSV, live dashboard, raw CSV.
- 5-year submission retention; campaigns archived to read-only after 2 academic years.

**Non-goals (v1):**
- No individual faculty login (faculty cannot see their own ratings in v1).
- No multi-language UI (English only).
- No SMS/OTP verification (PRN+roster gating is sufficient; email OTP is a future flag).
- No mobile app (web responsive only).

## 3. Decisions log

Recorded for posterity so future readers know *why* the design looks this way:

| # | Decision | Reason |
|---|---|---|
| Q1 | Backend: Supabase (Postgres) | Relational fit for hierarchy, RLS for dept scoping, free tier covers volume. |
| Q2 | Student auth: shared access code per (offering × campaign) | Matches college's existing operational practice — no per-student account management. |
| Q3a | First year subjects = shared common pool + branch-specific upskill subjects | Matches actual curriculum. |
| Q3b | New offerings created by cloning the previous year's offering | Reduces dept admin workload semester to semester. |
| Q4 | Roles: super_admin, department_admin, anonymous student | No faculty login in v1. |
| Q4b | Dept admin can read open-text remarks verbatim | College wants HoDs to act on feedback directly. |
| Q5 | All four report types in scope (A: campaign PDF, B: teacher PDF, C: dashboard, D: CSV) | All used by different stakeholders. |
| Revision after Q5 | Replaced device fingerprinting with PRN + admin-uploaded roster | Fingerprinting fails when students switch devices; PRN is universally available and verifiable. |
| Anonymity | Anonymous-form duplicate prevention uses `hash(PRN + campaign_id + secret_salt)`, never the raw PRN | Preserves anonymity even from super admin. |
| 6a | Submission retention: 5 years; campaigns archived to read-only after 2 years | NAAC compliance window. |
| 6b | English only | College is comfortable with English-only forms. |
| 6c | First super admin seeded via Supabase migration | Avoids race-condition land grab. |
| 6d | Email notification when a campaign closes | Useful for dept admins to remember to download reports. |
| 6e | Super admin can wipe submissions for an academic year (double-confirm + audit) | Useful for clearing test data. |

## 4. Architecture

**One-line summary:** A single React 19 + Vite SPA (built fresh; the project starts from `docs/` only) backed by **Supabase Cloud** (Postgres + Auth + RLS, no local Docker), using `@react-pdf/renderer` for client-side PDF generation and Recharts for dashboard visualisation. All reads/writes go through the Supabase JS client; the four form templates from the source documents are persisted in the `form_templates` table at migration time.

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Browser (React SPA)                         │
│  ┌─────────────────────┐  ┌──────────────────────────────────────┐   │
│  │ Public student flow │  │ Admin console (login required)       │   │
│  │  /  →  /forms       │  │  Super admin / Department admin      │   │
│  └─────────────────────┘  └──────────────────────────────────────┘   │
└─────────────┬───────────────────────────────────────┬────────────────┘
              │ supabase-js                           │
              │ (anon key for public, JWT for admin)  │
              ▼                                       ▼
┌──────────────────────────────────────────────────────────────────────┐
│                              Supabase                                │
│  Auth (email + password)        Postgres (RLS-enforced)              │
│  RPC: lookup_access_code,       Storage (optional, for CSV exports)  │
│       resolve_offering_for_prn,                                      │
│       submit_feedback,                                               │
│       wipe_submissions_for_year (super admin only),                  │
│       seed_super_admin (migration script)                            │
└──────────────────────────────────────────────────────────────────────┘
```

**Build approach:** The frontend is bootstrapped fresh via `npm create vite@latest` (React + TS template). Styling is hand-rolled CSS with CSS variables (no UI framework in v1, per §11). Lucide icons. Phase 1 builds only the foundation (schema + auth helpers + minimal smoke UI); Phases 2–3 build the actual admin and student UIs. The four form templates' question schema lives in migration `0007_seed_form_templates.sql`, sourced from the original Word/Excel documents in `docs/`.

**Local environment (no Docker):** Development uses a Supabase Cloud project (free tier). Migrations are written under `supabase/migrations/` and applied with `supabase db push`. pgTAP tests are written under `supabase/tests/` and run via `psql "$DB_URL" -f supabase/tests/<file>.sql` against the cloud DB (each test wraps in `BEGIN; … ROLLBACK;` so cloud state isn't mutated). pgTAP extension is enabled in migration 0001.

## 5. Data model

All tables in Postgres. `id` is `uuid` default `gen_random_uuid()` unless noted. `created_at`, `updated_at` (`timestamptz`) on every table. Foreign keys are `ON DELETE RESTRICT` except where noted, since we never hard-delete entities — we use `is_archived BOOLEAN DEFAULT FALSE`.

### 5.1 Tables

**`departments`**
- `id`, `name` (e.g., "Computer Science Engineering"), `code` (e.g., "CSE"), `is_fy_pool BOOLEAN DEFAULT FALSE`
- One row has `is_fy_pool = true` and represents the shared First-Year-Common pool. UNIQUE constraint on `is_fy_pool` where true (only one such row).

**`academic_years`**
- `id`, `label` ("2026-27" UNIQUE), `start_date`, `end_date`, `is_current BOOLEAN`

**`divisions`**
- `id`, `department_id` FK → departments, `year_of_study SMALLINT CHECK (1..4)`, `name` (e.g., "A", "B", "C")
- UNIQUE(department_id, year_of_study, name)

**`subjects`**
- `id`, `owner_department_id` FK → departments, `name`, `code`, `is_fy_common BOOLEAN DEFAULT FALSE`
- For FY common subjects, `owner_department_id` references the FY pool dept; `is_fy_common = true` so dept admins can see them in their first-year offering pickers.

**`teachers`**
- `id`, `department_id` FK → departments, `name`, `email`, `is_archived`

**`offerings`** *(the keystone)*
- `id`, `division_id` FK, `semester SMALLINT CHECK (1..8)`, `academic_year_id` FK, `status ENUM('draft','published','archived') DEFAULT 'draft'`
- UNIQUE(division_id, semester, academic_year_id)
- Convenience computed view: `v_offering_label` = "CSE / Y3 / Div-A / Sem-5 / 2026-27"

**`offering_subjects`**
- `id`, `offering_id` FK, `subject_id` FK, `teacher_id` FK
- UNIQUE(offering_id, subject_id) — a subject appears once per offering.

**`form_templates`**
- `id`, `code` ('ambience' | 'curriculum' | 'faculty' | 'library' UNIQUE), `title`, `anonymous BOOLEAN`, `requires_per_subject BOOLEAN` (true only for 'faculty'), `schema JSONB`
- `schema` carries the question list, scale labels, identity fields required, and remark prompts.

**`campaigns`**
- `id`, `template_id` FK, `name`, `scope_department_id` FK nullable (null = college-wide), `opens_at`, `closes_at`, `status ENUM('draft','open','closed','archived')`, `created_by` FK → auth.users, `archived_at`
- College-wide campaigns can only be created by super admin; per-department by either role.

**`campaign_offerings`**
- `campaign_id` FK, `offering_id` FK, PK(campaign_id, offering_id)

**`access_codes`**
- `id`, `campaign_id` FK, `offering_id` FK, `code TEXT UNIQUE` (short e.g. `CSE-3A-S5-X7Q9`), `expires_at` (mirrors campaign closes_at by default)
- One code per (campaign × offering).

**`class_rosters`**
- `id`, `offering_id` FK, `prn TEXT NOT NULL`, `roll_no TEXT`, `name TEXT`, `email TEXT`, `mobile TEXT`
- UNIQUE(offering_id, prn) — same PRN can appear in different offerings (over years), but only once per offering.
- PRN is normalized on save: `UPPER(TRIM(REGEXP_REPLACE(prn, '\\s+', '', 'g')))`.

**`submissions`** *(append-only)*
- `id`, `campaign_id` FK, `offering_id` FK, `offering_subject_id` FK nullable (set only for the Faculty form), `template_id` FK
- `identity JSONB` (for named forms only — `{name, roll_no, prn}`; null/empty for anonymous)
- `dedup_hash TEXT NOT NULL` — `sha256(prn || campaign_id || coalesce(offering_subject_id::text, '') || secret_salt)`. The hash already discriminates per-subject for the Faculty form, so a single UNIQUE(template_id, dedup_hash) constraint covers both anonymous and named forms.
- `answers JSONB`, `remarks JSONB`, `submitted_at`
- No update/delete allowed via RLS; super admin gets soft-hide via `is_hidden BOOLEAN`.

**`user_profiles`**
- `user_id` FK → auth.users (PK), `role ENUM('super_admin','department_admin')`, `department_id` FK nullable (must be set for dept admin; null for super admin).

**`audit_log`**
- `id`, `actor_user_id`, `action`, `entity_type`, `entity_id`, `before JSONB`, `after JSONB`, `at TIMESTAMPTZ`
- Append-only.

### 5.2 Indexing

- `submissions(campaign_id, offering_id)` — primary report query path.
- `submissions(template_id, dedup_hash)` — duplicate check on insert.
- `class_rosters(offering_id, prn)` — already covered by UNIQUE.
- `access_codes(code)` — already covered by UNIQUE.
- `offerings(academic_year_id, status)` — admin listing.

### 5.3 Row-Level Security (RLS) summary

Every table has RLS enabled. A helper SQL function `current_user_role()` and `current_user_department_id()` read from `user_profiles` for the JWT's `auth.uid()`.

| Table | Super admin | Department admin | Anonymous |
|---|---|---|---|
| `departments` | ALL | SELECT all | none |
| `academic_years`, `form_templates` | ALL | SELECT | none |
| `subjects` | ALL | ALL where `owner_department_id = mine` OR `is_fy_common=true AND` SELECT-only | none |
| `teachers`, `divisions` | ALL | ALL where `department_id = mine` | none |
| `offerings` | ALL | ALL where division belongs to my dept | none |
| `offering_subjects` | ALL | ALL where offering belongs to my dept | none |
| `class_rosters` | ALL | ALL where offering belongs to my dept | none |
| `campaigns` | ALL | ALL where `scope_department_id = mine`; SELECT college-wide | none |
| `campaign_offerings`, `access_codes` | ALL | ALL where campaign in scope | none |
| `submissions` | SELECT all + UPDATE `is_hidden` only | SELECT where campaign in scope | none (insert only via RPC) |
| `user_profiles` | ALL | SELECT self only | none |
| `audit_log` | SELECT | none | none |

### 5.4 RPC functions (Postgres / Supabase)

Public-facing (callable with anon key):

- `lookup_access_code(code text) → jsonb` — returns `{offering_label, campaign, template_codes_open, expires_at}` or error. Does not yet expose offering_id; that comes after PRN check.
- `resolve_offering_for_prn(code text, prn text) → jsonb` — verifies PRN is in roster for the offering tied to that code; returns offering id, identity row (name/roll for autofill on named forms), and per-form submission status.
- `submit_feedback(code text, prn text, template_code text, offering_subject_id uuid|null, identity jsonb, answers jsonb, remarks jsonb) → jsonb` — full server-side validation: code valid, campaign open, PRN in roster, no duplicate, identity matches roster for named forms, answers conform to template schema. Inserts submission and returns confirmation.

Admin-only (require auth):

- `seed_super_admin(email text)` — invoked once during bootstrap migration; creates the auth user and the `user_profiles` row.
- `clone_offering(source_offering_id uuid, target_division_id uuid, target_semester smallint, target_academic_year_id uuid) → uuid` — copies subject list, leaves teacher slots null.
- `wipe_submissions_for_year(academic_year_id uuid, confirm_phrase text)` — super admin only; requires phrase match to a generated token shown in UI.

## 6. Auth & roles

- Super admin and dept admins use Supabase Auth (email + password, magic-link optional). On login, the JWT is used by RLS via `auth.uid()` → `user_profiles` join.
- First super admin: seeded by migration script with the email the college provides.
- Super admin invites dept admins from the Admin Console: an RPC creates the auth user (using Supabase Admin API behind a server-side function) and the `user_profiles` row in one transaction. Dept admin receives an invite email with a password setup link.
- Students: no auth. They hit the public landing, type the access code, type their PRN, and submit. All writes go through `submit_feedback`.

## 7. Student flow

```
/  →  enter access code  →  enter PRN  →  form picker  →  fill form  →  success
```

- The PRN screen comes *after* the access code: an outsider with just a code can't even see the form list.
- The form picker shows all forms in the active campaign that target this offering, with each one's submission status (✓ submitted / pending) for this PRN.
- The Faculty form pages through every `(subject + teacher)` of the offering one screen at a time; each rating is a separate `submissions` row with `offering_subject_id` set. Partial completion is allowed: returning later shows only un-rated subjects.
- Anonymous forms: `identity` field is null; only `dedup_hash` distinguishes submissions for duplicate prevention.
- Named forms (Curriculum, Library): roster's name, roll, PRN are auto-filled into the identity step; student can edit name spelling but not the PRN.
- All errors (invalid code, expired campaign, PRN not in roster, already submitted) return distinct user-friendly messages.

## 8. Admin flow

### 8.1 Sidebar (role-aware)

```
Dashboard
Departments        (super admin)
Academic Years     (super admin)
Form Templates     (super admin)
─────
Subjects           (own dept; FY-common pool: super admin)
Teachers           (own dept)
Divisions          (own dept)
Offerings          (own dept; central screen)
Class Rosters      (attached to offerings)
─────
Campaigns          (own dept / college-wide)
Access Codes       (per campaign — printable list)
─────
Reports            (scope-filtered)
Audit Log          (super admin)
```

### 8.2 Offering Builder (the central admin screen)

Fields: division, semester, academic year, status. Two pickers — FY common pool (only on first-year offerings) and own-dept subjects. Each subject row has a teacher dropdown. Action: "Clone from previous offering" → calls `clone_offering` RPC. Status transitions: draft → published. An offering must be published *and* have a non-empty roster before it can be added to a campaign.

### 8.3 Roster CSV import

Drag-and-drop CSV. Columns auto-detected (PRN, Roll, Name, Email, Mobile). PRN is required and normalized on save. Duplicate PRNs flagged before commit.

### 8.4 Campaign Builder

Pick form template; pick scope (college-wide = super admin only); pick target offerings (multi-select across own dept's offerings); set opens_at and closes_at. On publish, the system generates one access code per (campaign × offering) and shows a printable code sheet.

### 8.5 Audit & immutability

Every admin write goes through a trigger that inserts an `audit_log` row. Submissions are append-only at the DB level (no UPDATE/DELETE policies). Super admin can soft-hide a campaign's submissions but never edit a student's answer.

### 8.6 Mid-semester teacher change

Editing `offering_subjects.teacher_id` only affects future submissions (existing submissions store the immutable `offering_subject_id`, but the teacher swap is recorded in `audit_log`). Reports surface "Teacher A (until date) → Teacher B (from date)" by joining audit log entries.

## 9. Reports & exports

Single Reports screen with global filters (Department, Academic Year, Campaign, Offering) at the top and four output tabs.

- **A. Per-campaign aggregate PDF** (Ambience, Curriculum, Library) — mirrors the source form layout. Generated client-side with `@react-pdf/renderer`. Includes per-question average + distribution; lists all open-text remarks verbatim.
- **B. Per-teacher PDF + CSV** (Faculty form) — one PDF per `(offering_subject)` showing 9-question table + verbatim remarks. ZIP of PDFs + summary CSV when many teachers in scope.
- **C. Live dashboard** — total responses, response rate (= submissions / roster size), per-question bar chart, faculty heatmap (rows=teachers, cols=9 questions, color=avg). Drill-down opens per-teacher view.
- **D. Raw CSV** — flat row per submission with full context columns; for anonymous forms, identity columns blank and only `dedup_hash` present.

Reports are read directly from Postgres views (`v_campaign_question_stats`, `v_teacher_stats`, etc.). RLS applies to views — dept admins never see other depts' rows.

Email notification: Supabase Edge Function fires when a campaign transitions to `closed`, sending dept admin (or super admin for college-wide) a one-line summary + report link via Resend.

## 10. Edge cases handled

| Scenario | Handling |
|---|---|
| Mid-semester teacher change | Edit offering_subjects.teacher_id; audit log records swap; existing submissions stay tied to original via offering_subject_id. |
| Student transfers division | PRN moves to new division's roster. Old submissions stay in old division. Future submissions count under new. |
| Backlog / repeat student in another batch's class | Dept admin manually adds PRN to that offering's roster. |
| Same teacher across multiple divisions | Each division has its own offering_subjects row. Reports offer "Group by division" or "Aggregated" toggle. |
| PRN typo | Normalize: trim, uppercase, strip non-alphanumerics. Friendly error if no match. |
| Campaign published with empty roster | Blocked at "Publish & Open" — every targeted offering must have ≥1 roster row. |
| Concurrent admin edits | Optimistic concurrency via `updated_at`; stale write shows reload prompt. |
| Browser back button mid-form | Form state is in component memory only; back goes to picker; PRN+campaign lock still applies; user re-enters and submits fresh. |
| Department renamed | UPDATE department.name; all FK relationships unaffected; audit log records change. |
| Campaign closed accidentally | Super admin can re-open by editing closes_at; logged in audit. |

## 11. UI / UX direction

Two distinct usage contexts drive the look-and-feel:

- **Students fill forms on mobile** (predominant). Single-handed reach, large tap targets (min 44px), single-column layout, sticky bottom CTA, no horizontal scrolling, minimal typing where avoidable. Keyboard input limited to access code + PRN; everything else is taps. Auto-advance between Faculty form subject pages with a clear progress strip.
- **Admins use PC / laptop** (super admin & dept admin). Multi-column layouts, dense tables (Offerings / Rosters / Campaigns), keyboard-driven editing, drag-and-drop CSV upload. The admin console is *responsive enough* to load on mobile in a pinch but is not the design priority.

**Visual style:**

- **Light theme, modern, restrained.** Off-white background (`#f7f8fa`), generous whitespace, soft shadows on cards, subtle border radius (10–12px), primary accent that matches the original `#174ea6` (CSMSS blue). Avoid heavy gradients, glassmorphism, or dark mode in v1.
- **Typography:** Inter (or system stack fallback) — large readable body (16px+ on mobile), strong hierarchy.
- **Iconography:** Lucide for consistency.
- **Forms:** segmented-button pickers for Likert scales (not radio dots) — much easier to tap accurately on mobile. Tap = select; visible selected state; haptic-feel feedback via brief CSS transition.
- **Charts (admin-only):** Recharts with a single accent color + neutral grays — clarity over decoration.

**Mobile patterns specifically:**

- Bottom-sheet style sticky "Continue / Submit" button.
- Per-question screens for the Faculty form (one question per scroll on small screens, full table on tablets/desktop) — reduces cognitive load and makes the long form less daunting.
- Progress dots showing X of N subjects done in the Faculty form.
- "Already submitted" / errors surfaced inline, never in toasts that disappear before the user reads them.
- Offline-tolerant submit: if the network drops mid-submit, the answer state is held in memory and retried on reconnect (single in-flight retry, not a full PWA).

**Accessibility baseline (v1):**

- WCAG AA color contrast.
- Keyboard navigation for the admin console.
- Form fields with proper `<label>` associations and `aria-describedby` for inline errors.
- No reliance on color alone to convey state (always pair color with icon or text).

**Implementation note:** keep the hand-rolled CSS-variable approach; do not introduce Tailwind or a UI kit in v1.

## 12. Out of scope (v1)

- Faculty self-service login + own-feedback view.
- Multi-language UI.
- Mobile app.
- SMS/OTP verification (email OTP is a future toggle; PRN gating is sufficient for v1).
- Cross-college tenancy (this build is single-college).
- Inline rich-text remarks (plain text only).
- Image / file attachments on remarks.

## 13. Build order (high-level — full plan in next phase)

1. Provision Supabase Cloud project; run schema migration with all 14 tables, indexes, RLS, RPCs, audit triggers.
2. Bootstrap Vite + React + TS scaffold; build a `src/lib/supabase.ts` data layer.
3. Wire admin login (`/admin/login`) using Supabase Auth; gate `/admin` routes by JWT + role.
4. Build admin screens in this order: Departments → Academic Years → Subjects → Teachers → Divisions → Offerings (with clone) → Class Rosters (CSV import) → Campaigns → Access Codes.
5. Wire student flow: access code → PRN → form picker → form fill → submit. All via the three public RPCs.
6. Build Reports: dashboard charts → per-campaign PDF → per-teacher PDF/CSV → raw CSV.
7. Add email notifications via Edge Function + Resend.
8. Seed first super admin via migration. Smoke-test full lifecycle.

(The detailed implementation plan with subagent-friendly task breakdown is the deliverable of the next phase, using the writing-plans skill.)

---

**Approval status:** All sections (1 – 6) approved by user during brainstorming on 2026-04-28. UI/UX direction (§11) added 2026-04-28 per user request.
