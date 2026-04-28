# College Feedback System — Project Plan Index

**Last updated:** 2026-04-28
**Status:** Brainstorming + planning complete. Ready to begin Phase 1 implementation.

This file is the entry point. It links to the spec and the four phase plans, summarizes the build order, and records the final approved decisions.

---

## Documents

| Document | Purpose |
|---|---|
| [Spec](./specs/2026-04-28-college-feedback-system-design.md) | Full product + technical design. Approved 2026-04-28. |
| [Phase 1 plan](./plans/2026-04-28-college-feedback-phase1-foundation.md) | **Detailed TDD plan.** Bootstrap + Supabase Cloud + schema + RLS + RPCs + form-template seed + smoke UI. Ready to execute. |
| [Phase 2 outline](./plans/2026-04-28-college-feedback-phase2-admin-console.md) | Admin Console UI (login + 17 admin screens). Outline only — expand to TDD plan before execution. |
| [Phase 3 outline](./plans/2026-04-28-college-feedback-phase3-student-flow-and-reports.md) | Mobile-first student flow + four report outputs. Outline only — expand before execution. |
| [Phase 4 outline](./plans/2026-04-28-college-feedback-phase4-polish-and-deploy.md) | Email notifications, super-admin tools, accessibility, deployment. Outline only — expand before execution. |

## Build order

Each phase is its own spec→plan→implementation cycle. Do not jump ahead.

```
Phase 1 (Foundation)   →  Phase 2 (Admin Console)  →  Phase 3 (Student + Reports)  →  Phase 4 (Polish + Deploy)
   ↓                          ↓                         ↓                                ↓
Detailed TDD            Outline → expand          Outline → expand                Outline → expand
~20 tasks                ~17 tasks                 ~18 tasks                       ~12 tasks
```

## Key decisions (locked)

| Area | Decision |
|---|---|
| Backend | Supabase **Cloud** (no Docker, no local stack) |
| Database | Postgres with RLS for dept-scoping; pgTAP for migration tests |
| Frontend | Vite + React 19 + TypeScript, hand-rolled CSS with variables, Lucide icons. **Built fresh** — no existing scaffold to extend. |
| Student auth | Shared class **access code** + **PRN** (validated against admin-uploaded roster); device fingerprint dropped |
| Anonymity | Hashed `(PRN + campaign_id + offering_subject_id + secret_salt)` for dedup; raw PRN never stored on anonymous submissions |
| Roles | Super admin (full), Department admin (own dept only), Students (no account) |
| Reports | Per-campaign aggregate PDF (mirroring source forms), per-teacher PDF/CSV, live dashboard, raw CSV |
| UI direction | Modern light theme, mobile-first **student** flow, desktop-first **admin** console |
| Retention | Submissions kept 5 years; campaigns archived to read-only after 2 academic years |
| Languages | English only in v1 |
| First super admin | Seeded via migration after the user creates the auth user in Supabase Dashboard |
| Notifications | Email on campaign close (Phase 4) |

## What's not happening in v1

- No Docker / local Supabase stack
- No faculty self-service login
- No multi-language UI
- No SMS / OTP verification (PRN gating is the security layer)
- No native mobile app
- No cross-college tenancy

## Next steps

1. User reviews the four plan documents.
2. When ready to start Phase 1: invoke the `subagent-driven-development` flow against the Phase 1 plan.
3. Phase 1 → Phase 2 → Phase 3 → Phase 4, each with its own spec→plan→execute cycle as needed.
