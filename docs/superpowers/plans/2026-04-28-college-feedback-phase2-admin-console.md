# College Feedback System — Phase 2 (Admin Console) Implementation Plan — OUTLINE

> **Status:** Outline only. Before execution, this should be expanded into bite-sized TDD-style tasks via the brainstorming → writing-plans flow, the same way Phase 1 was. Re-validate scope, UI mockups, and any new RLS/RPC needs at that point.

> **For agentic workers:** Do NOT execute this plan as-is. Ask the user to commission a detailed Phase 2 plan first.

**Goal:** Replace the Phase 1 smoke screen with a complete, role-aware admin console covering every entity-management screen the spec calls for. After Phase 2, super admin and dept admins can run the college's feedback operation entirely through the web UI: invite admins, create academic years and divisions, manage subjects/teachers, build offerings (with the clone workflow), upload class rosters, create campaigns, and generate per-class access codes.

**Architecture:**
- React Router added; routes split into `/` (Phase 1 smoke screen, will become public landing in Phase 3), `/admin/login`, and `/admin/*` (everything role-gated).
- Shared `<AdminShell>` layout = top bar + role-aware sidebar + main outlet. Auth guard at the route boundary.
- One screen component per entity, all desktop-first per spec §11 but with a sensible responsive breakpoint at 900px (sidebar collapses to a drawer on tablet; admin screens are not optimized for phone).
- All data access via `src/lib/storage.ts` (Phase 1) — extended where needed.
- New backend RPC: `invite_department_admin(email, department_id)` (creates auth user via Supabase Admin API + `user_profiles` row in one transaction; super admin only).
- CSV import for class rosters uses a tiny client-side parser (no extra dependency); preview-then-commit UX.
- Optimistic concurrency on entity updates via `updated_at` timestamps.

**Tech Stack:** Adds `react-router-dom@^7`. No UI framework. Existing CSS variables.

**Spec:** `docs/superpowers/specs/2026-04-28-college-feedback-system-design.md` §6 (Auth), §8 (Admin flow).

**Prerequisites:** Phase 1 complete; cloud DB live; super admin can log in and reach `/admin/*` with a valid JWT.

---

## Task list (target: ~15 tasks when expanded to bite-sized TDD)

### Routing & shell

- **Task 1: Add React Router + route shell.** Files: `src/main.tsx`, new `src/routes/router.tsx`. Routes: `/`, `/admin/login`, `/admin` (with nested children loaded in later tasks). Verify build.
- **Task 2: Login screen + auth guard.** Files: new `src/routes/admin/Login.tsx`, `src/routes/admin/RequireAuth.tsx`. Uses `auth.signIn` from Phase 1's `src/lib/auth.ts`. On success, push to `/admin/dashboard`. On unauth access to `/admin/*`, redirect to login. Test: try login flow with the seeded super admin from Phase 1; unauthorized navigation redirects.
- **Task 3: Admin shell layout + role-aware sidebar.** Files: new `src/routes/admin/AdminShell.tsx`, `src/routes/admin/Sidebar.tsx`. Reads `getCurrentProfile()` once on mount; hides super-admin-only links from dept admins. Top bar: college logo, role badge, sign-out button.

### Super-admin-only screens

- **Task 4: Departments screen.** Files: `src/routes/admin/Departments.tsx`. List + create/edit form. Includes the FY-common pool toggle. Validation: only one is_fy_pool=true allowed.
- **Task 5: Academic Years screen.** Files: `src/routes/admin/AcademicYears.tsx`. List + create/edit. The `is_current` boolean is a single-select pattern (setting one row clears the others) — implement via a server-side trigger added in this task's migration.
- **Task 6: Form Templates viewer (read-only).** Files: `src/routes/admin/FormTemplates.tsx`. Lists the four seeded templates, shows their question schema. No editing in v1 — schema changes require a migration. (Document this explicitly on the page.)
- **Task 7: Invite Department Admin flow + RPC.** Files: new migration `supabase/migrations/0008_rpc_invite_admin.sql` (the `invite_department_admin` SECURITY DEFINER RPC, super_admin guard, calls Supabase Admin API server-side via Edge Function — alternative: temp-password approach if Edge Function setup deferred). Files: `src/routes/admin/Users.tsx`. UI: list of admins, invite form (email + dept dropdown).

### Dept-admin (and super-admin) screens

- **Task 8: Subjects screen.** Files: `src/routes/admin/Subjects.tsx`. List + create/edit. For dept admins, queryset = subjects where `owner_department_id = me`; FY-common subjects shown read-only in a separate tab. Super admin can edit any.
- **Task 9: Teachers screen.** Files: `src/routes/admin/Teachers.tsx`. Standard list + create/edit, scoped by RLS.
- **Task 10: Divisions screen.** Files: `src/routes/admin/Divisions.tsx`. Grid view: rows = year of study (1–4), cols = divisions A/B/C, cells = "[+ Add]" or existing-name pills.
- **Task 11: Offerings — list view.** Files: `src/routes/admin/Offerings.tsx`. Filterable by academic year + year of study + division. Each row links to the Offering Builder.
- **Task 12: Offering Builder + Clone workflow.** Files: `src/routes/admin/OfferingBuilder.tsx`. The keystone screen described in spec §8.2. Subject pickers (FY common pool tab if first-year offering, plus dept-owned subjects tab), per-row teacher dropdown, "Clone from previous offering" → calls `clone_offering` RPC; status transitions draft→published; published offerings can't be edited until reverted to draft.
- **Task 13: Class Rosters — CSV import.** Files: `src/routes/admin/ClassRosters.tsx`. Drag-and-drop CSV; auto-detect columns by header name (PRN required, others optional); preview table; show duplicate-PRN warnings; commit on confirm. PRN normalization happens server-side in the existing `normalize_prn()` function.
- **Task 14: Campaigns — create / list / open / close.** Files: `src/routes/admin/Campaigns.tsx`, `src/routes/admin/CampaignBuilder.tsx`. Campaign builder lets admin pick form template, scope (college-wide super-admin-only), target offerings (multi-select), opens_at and closes_at. Validation rules from spec §8.4: every targeted offering must be `published` and have ≥1 roster row. On publish, generate one access code per (campaign × offering) — printable list rendered as a separate route `/admin/campaigns/:id/codes`.
- **Task 15: Access Codes — printable view.** Files: `src/routes/admin/AccessCodes.tsx`. List of codes for a campaign, formatted as a one-page printable table (per spec §8.4). Implements browser print stylesheet.

### Final wiring

- **Task 16: Audit log viewer (super admin only).** Files: `src/routes/admin/AuditLog.tsx`. Simple paginated table of `audit_log` rows, filterable by actor, action, entity type, date range. Read-only.
- **Task 17: End-to-end smoke test.** Manual: log in as super admin, create a department, invite a dept admin, log in as that admin in a private window, build an offering with FY-common subjects + a dept-specific subject, upload a 2-row roster CSV, create a campaign with a single offering, capture an access code. No code changes — verifies all screens hang together.

---

## Out of scope for Phase 2

- **Student flow** — public landing, code → PRN → form fill. Phase 3.
- **Reports** — dashboard, PDFs, CSV. Phase 3.
- **Email notifications** — Phase 4.
- **Mobile-optimized admin UI** — desktop-first per spec §11. A breakpoint exists at 900px so screens don't break on a phone, but they're not designed for it.

## Handoff to Phase 3

After Phase 2, the college can fully *configure* a feedback drive but students still cannot submit. Phase 3 builds the public-facing student flow + all four reports.
