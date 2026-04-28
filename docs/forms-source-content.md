# Feedback Forms — Source Content (text-only reconstruction)

> **NOTE:** The original `.docx` and `.xlsx` source files were lost on 2026-04-28 due to a destructive `--overwrite` flag in a scaffold step. This file preserves the question content extracted from those originals earlier in the same session, so the form schemas in migration `0007_seed_form_templates.sql` can be reproduced or audited. See `MEMORY.md` for incident details.

---

## 1. Ambience Feedback (Anonymous)

**College header:** CSMSS Chh. Shahu College of Engineering, Kanchanwadi, Paithan Road, Aurangabad 431 011 (M.S)
**Form title:** Student Feedback on Facilities/Ambience of Institute. (Anonymous)
**Header fields:** Academic Year, Class & Department, Date
**Scale:** Strongly agree / Agree / Disagree

**Questions:**
1. Availability and maintenance of green campus.
2. Availability of RO drinking water and water cooling systems.
3. Availability of well ventilated and shiny classrooms / laboratory.
4. Availability of Wi-Fi & CCTV camera in classroom & campus.
5. Sufficient and hygienic sanitary arrangement for students.
6. Availability of fire safety devices in campus.
7. Availability of ramp and lift for Divyang person.
8. Availability of Canteen, Bank, Post office, first-aid in campus.
9. Availability of well-maintained playground, Gym.
10. Availability of well-maintained separate boys and girls hostels.

**Open-text:** Suggestions if any (single field)

---

## 2. Curriculum Feedback (Named)

**Form title:** Students Feedback on Curriculum
**Header fields:** Academic Year, Class & Department, Date, Name of Students
**Scale:** Good / Average / Poor
**Anonymous:** No (has Name of Students field)

**Questions:**
1. How challenging is the syllabus offered by the courses.
2. Appropriateness of the sequence of the subjects in curriculum.
3. Depth of the syllabus of the courses according to the competencies expected by Industry / current global scenario.
4. Sequence of the unit modules in the courses.
5. Adequateness of the books mentioned for the courses.
6. Content of the courses in terms of burden on the students.
7. Design of the courses are promoting the self-learning approach.
8. Flexibility in choosing the electives related to technological trends.
9. Percentage of the courses offering Laboratory components.
10. Composition of the courses in terms of Basic science, Engineering, Humanities, electives, projects, etc.

**Open-text:** Any suggestions (single field)

---

## 3. Faculty Performance Feedback (Anonymous, per subject)

**Form title:** Student Feed-back Form (Faculty Performance)
**Form code:** F / CDFP / 01 (issue date 01-07-2018)
**Header fields:** Department, Academic Year, Class, Sem
**Anonymous:** Yes (explicitly stated: "This evaluation is to be totally anonymous.")
**Per-subject:** Yes — students rate each (Course + Course Teacher) pair separately
**Scale:** 1–4 numeric, with question-specific option labels per row

**Questions (each on a 4-point scale with question-specific options):**

1. **How are the classes engaged?** — 1.Irregularly / 2.Sometimes irregular / 3.Generally regular / 4.Always regular
2. **Are you satisfied with the progress of the syllabus?** — 1.Totally unsatisfied / 2.Satisfied to some extent / 3.Satisfied / 4.Totally satisfied
3. **Do you understand the subject?** — 1.Not at all / 2.To some extent / 3.Good enough / 4.In all respect
4. **Is the teacher capable of controlling the class?** — 1.Poor control / 2.Fair control / 3.Adequate control / 4.Good control
5. **Does the teacher involve the students during lectures?** — 1.Never / 2.Rarely / 3.Usually / 4.Always
6. **Is your teacher proficient in English?** — 1.Poor / 2.Average / 3.Good / 4.Excellent
7. **Is the teacher audible?** — 1.Poor / 2.Average / 3.Good / 4.Excellent
8. **How is his teaching generally?** — 1.Boring / 2.Monotonous / 3.Good / 4.Interesting
9. **How do you rate the overall performance of your teacher?** — 1.Poor / 2.Fair / 3.Good / 4.Excellent

**Open-text remarks (per subject):**
- What are the specific expectations from your teacher for the improvement of result in the subjects?
- Any additional comments on the performance of your teacher.

---

## 4. Library Feedback (Named)

**Form code:** F / LIBR / 04 (issue date 01-07-2018)
**Form title:** Library Feedback Form
**Header fields:** Name of Student, Roll No, Year, Department, Academic Year
**Anonymous:** No (has Name of Student + Signature of Student)
**Scale:** Excellent / Very Good / Good / Satisfactory

**Special question (preceding the Likert items):**
- **How often do you visit the library:** Daily / Twice in a week / Once in a week / Once in a month / Other (with text)

**Questions (4-point Likert):**
1. Regarding the college library time (8:30 am to 12:00 midnight)
2. Library infrastructure
3. The available reading space in the library
4. Course books received from the library
5. Available number of journals / magazines in your branch
6. Library services — Such as book circulation, Reference Service, Back volume of journals / magazines etc.
7. Availability of reprographic facility, Internet facility
8. Behaviour of the library staff
9. Overall facilities provided by library

**Open-text:** Please give your suggestions for any improvement in the library (single multi-line field)
**Footer:** "We appreciate of your valuable feedback on the each of the question." — Signature of Student
