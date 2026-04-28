# College Feedback System — Phase 3 (Student Flow + Reports) Implementation Plan — OUTLINE

> **Status:** Outline only. Before execution, expand to bite-sized TDD tasks via brainstorming → writing-plans, the same way Phase 1 was. Visual mockups for the mobile student flow should be reviewed before implementation begins.

> **For agentic workers:** Do NOT execute this plan as-is. Ask the user to commission a detailed Phase 3 plan first — the UI is the part of the project that benefits most from explicit design review.

**Goal:** Deliver the two user-facing experiences that make the system actually useful: (1) a mobile-first public student flow that lets a student enter an access code + PRN, see all open forms, and submit them; and (2) all four report outputs (per-campaign aggregate PDF, per-teacher PDF/CSV, live dashboard, raw CSV) wired into the admin Reports tab.

**Architecture:**
- Public student route at `/` (replacing Phase 1's smoke screen) and nested `/forms/*` for code/PRN/picker/form pages. No auth required; all writes via the public RPCs from Phase 1.
- Admin Reports route at `/admin/reports` with the global filter bar (Department, Academic Year, Campaign, Offering) and four output tabs (Dashboard / Campaign PDF / Teacher PDF / CSV).
- PDFs generated client-side with `@react-pdf/renderer` — no server PDF service.
- Charts via `recharts`.
- New Postgres views for report aggregations (`v_campaign_question_stats`, `v_teacher_stats`) — RLS applies, super admin / dept admin scoping inherited.

**Tech Stack additions:** `@react-pdf/renderer@^4`, `recharts@^2`. Both small, well-maintained, no peer-dep conflicts with React 19.

**Spec:** §7 (Student flow), §9 (Reports), §11 (UI/UX direction — mobile-first segmented buttons, 16px+ body, single-column).

**Prerequisites:** Phase 1 + Phase 2 complete. At least one campaign has been opened and at least one submission exists via the seeded data, so reports have something to display.

---

## Task list (target: ~18 tasks when expanded)

### Student flow (mobile-first)

- **Task 1: Public landing + access-code entry.** Files: new `src/routes/student/Landing.tsx`. Single input + Continue. Calls `lookupAccessCode(code)`; on success stores result in route state and pushes to `/forms/prn`. Friendly inline errors for invalid/expired codes.
- **Task 2: PRN entry screen.** Files: `src/routes/student/Prn.tsx`. After code, asks for PRN. Calls `resolveOfferingForPrn(code, prn)`. Returns identity (for autofill on named forms) and per-form already-submitted status. Pushes to `/forms/picker`.
- **Task 3: Form picker.** Files: `src/routes/student/Picker.tsx`. Lists each form in the campaign with a status pill (✓ submitted / pending). Tapping a form pushes to `/forms/fill/:templateCode`.
- **Task 4: Form rendering — Ambience / Curriculum / Library.** Files: new `src/routes/student/forms/StandardForm.tsx`, generic component driven by `form_templates.schema`. Segmented-button Likert pickers (no radio dots — better for mobile taps). One question per screen on small viewports; full table on tablet+. Sticky bottom Submit. Calls `submitFeedback(...)`. On success: success toast + back to picker.
- **Task 5: Faculty form — multi-subject pagination.** Files: `src/routes/student/forms/FacultyForm.tsx`. Iterates through every `(subject + teacher)` for the offering; one screen per pair; progress strip ("3 of 6"). Each rating becomes one `submissions` row via `submitFeedback`. Resume support: re-entering after partial completion shows only un-rated subjects.
- **Task 6: Identity step for named forms.** Files: `src/routes/student/forms/IdentityStep.tsx`. Shows roster's name/roll prefilled (read-only PRN, editable name). Captures additional library-form fields (year, department) per template's `identityFields`.
- **Task 7: Visit-frequency special question on Library form.** Single segmented-choice question rendered ahead of the standard Likert questions, per template's `specialQuestions`.
- **Task 8: Network-resilient submit.** Files: tweak `src/lib/storage.ts`. Single retry on 5xx / network error before surfacing failure to user. Persistent localStorage queue is out of scope (would invite "submit later" footguns).
- **Task 9: Mobile design polish.** Files: `src/styles.css` additions for breakpoints. 44px tap targets, 16px+ body, sticky CTAs, no horizontal scroll, bottom-sheet pattern for the success modal. Visual regression: open Chrome DevTools mobile-emulation (iPhone SE + Pixel 7) and walk every screen.
- **Task 10: Student flow smoke test.** Manual: open `/` on a phone (or DevTools mobile mode), submit each of the four forms against a real test campaign. Verify dedup blocks resubmission and PRN-not-in-roster gives a friendly error.

### Reports

- **Task 11: Postgres aggregation views.** Files: new migration `supabase/migrations/0009_report_views.sql`. Views: `v_campaign_question_stats` (per-campaign × per-question avg + distribution + count), `v_teacher_stats` (per-offering_subject × per-question avg + count), `v_response_rate` (submissions / roster_size per offering). RLS inherited from underlying tables. pgTAP test in `supabase/tests/07_report_views.sql`.
- **Task 12: Reports route shell + filters.** Files: `src/routes/admin/Reports.tsx`. Filter bar: Department (super admin only), Academic Year, Campaign, Offering (or "All"). State held in URL query params for shareable links. Below the filter, four tabs.
- **Task 13: Dashboard tab.** Files: `src/routes/admin/reports/Dashboard.tsx`. Cards (response count, avg score, response rate) + per-question bar chart + Faculty-only heatmap (rows=teachers, cols=questions, color-coded avg). Drill-down on heatmap row opens per-teacher view.
- **Task 14: Per-campaign aggregate PDF.** Files: `src/routes/admin/reports/CampaignPdf.tsx` + `src/lib/pdf/CampaignPdfDoc.tsx` (`@react-pdf/renderer` document). Layout mirrors the original Word/Excel form; per-question table; verbatim suggestions list. Download button.
- **Task 15: Per-teacher PDF + summary CSV.** Files: `src/routes/admin/reports/TeacherPdf.tsx` + `src/lib/pdf/TeacherPdfDoc.tsx`. One PDF per `(offering_subject)`; bulk download = ZIP via `jszip` (small, focused dep). CSV summary parallel to the ZIP.
- **Task 16: Raw CSV export.** Files: `src/routes/admin/reports/RawCsv.tsx`. Streams flat per-submission rows; identity columns blank for anonymous forms; includes `dedup_hash` so external analysts can verify dedup. No new lib needed (vanilla string building).

### Final wiring

- **Task 17: Reports smoke test.** Manual: with seed data covering at least one Faculty campaign, exercise each tab; download each output; verify content is correct and RLS-scoped (dept admin sees only their dept).
- **Task 18: Phase 3 release notes + screenshot pack.** Update `README.md` with student-flow + reports walkthrough; capture mobile-emulator screenshots for the docs.

---

## Out of scope

- Email notifications when campaigns close — Phase 4.
- Audit-log UI improvements — already covered in Phase 2.
- Faculty self-service login — explicitly out of v1 (spec §2 non-goals).

## Handoff to Phase 4

After Phase 3, the system is fully functional end-to-end: students submit, admins manage and report. Phase 4 adds the operational and polish features (notifications, wipe utility, accessibility, deploy guide).
