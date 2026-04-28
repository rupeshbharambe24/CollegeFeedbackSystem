# College Feedback System — Phase 4 (Polish + Deploy) Implementation Plan — OUTLINE

> **Status:** Outline only. Expand to bite-sized TDD tasks via brainstorming → writing-plans before execution.

> **For agentic workers:** Do NOT execute as-is. Several tasks (deploy, accessibility audit) need decisions made closer to release time.

**Goal:** Ship the operational and polish work that turns a working system into one a college IT team can confidently run for the next 5 years: campaign-closed email notifications, super-admin wipe utility, accessibility pass, production deployment, and ops documentation.

**Architecture additions:**
- Supabase Edge Function (Deno + TypeScript) for the campaign-closed email notification, triggered by a Postgres `pg_cron` job that polls `campaigns` for status transitions to `closed`.
- Resend (or any SMTP provider) for transactional email — environment variable-driven.
- Production frontend hosting: Vercel or Netlify (free tier handles a college's traffic). Connected to GitHub for CI/CD.
- Production Supabase project separate from the dev project used in Phases 1–3.

**Tech Stack additions:** `pg_cron` extension on cloud DB; Supabase Edge Functions runtime; Resend account.

**Spec:** §6c (super admin seed), §6d (email notification), §6e (data wipe), §11 accessibility baseline.

**Prerequisites:** Phases 1–3 complete and validated end-to-end on the dev Supabase project.

---

## Task list (target: ~12 tasks when expanded)

### Email notifications

- **Task 1: Resend account + secret.** Manual: sign up for Resend, verify the college's domain, create an API key. Store as a Supabase Edge Function secret (`supabase secrets set RESEND_API_KEY=...`).
- **Task 2: Edge Function `notify_campaign_closed`.** Files: new `supabase/functions/notify_campaign_closed/index.ts`. Reads `campaign_id` from request body; loads campaign + dept admin email(s) (or super admin for college-wide); sends an email with summary stats and a deep link to `/admin/reports?campaign=<id>`. Test: invoke locally with `supabase functions serve` (this still requires Docker — fall back to deploying directly to cloud and testing there if user can't run Docker).
- **Task 3: pg_cron trigger.** Files: new migration `supabase/migrations/0010_campaign_close_cron.sql`. Enable `pg_cron`, create a 5-minute cron that finds campaigns where `status='open' AND closes_at <= now()`, sets them to `closed`, and POSTs to the Edge Function. Use `pg_net` for HTTP from inside Postgres (also a Supabase-supported extension).

### Super-admin tools

- **Task 4: Audit log viewer enhancements.** Files: `src/routes/admin/AuditLog.tsx`. Add: detail expansion (before/after diff), CSV export.
- **Task 5: Wipe-submissions-for-year UI.** Files: `src/routes/admin/Danger.tsx` (new "Danger Zone" tab, super admin only). Form: pick academic year, type the confirmation phrase shown by the page, click red button. Calls the existing `wipe_submissions_for_year` RPC. After success, displays "X rows deleted, written to audit_log row Y."
- **Task 6: Settings page — dedup salt rotation.** Files: `src/routes/admin/Settings.tsx`. Super admin can rotate `app.dedup_salt` (with strong warning that this invalidates duplicate-detection for past anonymous submissions). Behind two confirmations.

### Accessibility & UX polish

- **Task 7: WCAG AA accessibility audit.** Manual: run axe DevTools on every page; fix flagged contrast and label issues. Files: `src/styles.css` adjustments, ARIA attributes on form controls.
- **Task 8: Keyboard navigation.** Verify all admin screens are fully keyboard-operable: tab order, focus rings, enter-to-submit, escape-to-close-modals.
- **Task 9: Error-boundary component.** Files: `src/routes/ErrorBoundary.tsx`. Wraps both student and admin sections; on render error, shows a graceful "Something went wrong, contact admin" page with a copy-bug-info button.

### Deployment

- **Task 10: Production Supabase project.** Manual: create a separate "production" Supabase project. `supabase link --project-ref <prod-ref>` in a separate config or via env-switch script. Run all migrations: `supabase db push --linked` against prod. Set `app.dedup_salt` to a long random string (different from dev's). Seed first super admin via Dashboard.
- **Task 11: Frontend hosting on Vercel.** Manual: sign up for Vercel, connect the repo, configure two environments (preview from PRs, production from `main`). Set production env vars: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` (production project's values). Verify a deploy succeeds and the production URL hits the production DB.
- **Task 12: Ops documentation.** Files: new `docs/ops.md`. Covers: how to add a new academic year, how to cut over to a new admin, how to back up the DB (`pg_dump` against `$DB_URL` daily, suggest a cron on the college server), what to do if a student reports they can't submit (debug checklist: code valid? PRN in roster? campaign still open? RLS issue?), how to upgrade the Supabase plan if usage exceeds free tier.

---

## Out of scope (consider Phase 5 if needed)

- Faculty self-service login + own-feedback view (deferred from spec §2 non-goals).
- Multi-language UI (deferred from §6b).
- SMS-based OTP for stronger student verification.
- Multi-college tenancy (this build is single-college only).
- Native mobile apps (web responsive is enough for a college that already uses WhatsApp + browsers).

## Project complete

After Phase 4, the system is production-ready and operational. Hand over to college IT with the ops docs.
