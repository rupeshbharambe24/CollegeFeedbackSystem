-- =============================================================================
-- 0007 Seed the four form templates from the source documents in `docs/`.
-- Idempotent upsert by `code` — re-running updates the schema in place.
-- Schemas reproduce the questions, scales, and identity fields verbatim.
-- =============================================================================

INSERT INTO form_templates (code, title, anonymous, requires_per_subject, schema)
VALUES

-- 1. Ambience (anonymous, 10 questions, 3-point Likert)
('ambience', 'Student Feedback on Facilities/Ambience of Institute', TRUE, FALSE,
'{
  "scaleLabels": ["Strongly agree","Agree","Disagree"],
  "questions": [
    {"id":"a1","text":"Availability and maintenance of green campus."},
    {"id":"a2","text":"Availability of RO drinking water and water cooling systems."},
    {"id":"a3","text":"Availability of well ventilated and shiny classrooms / laboratory."},
    {"id":"a4","text":"Availability of Wi-Fi and CCTV camera in classroom and campus."},
    {"id":"a5","text":"Sufficient and hygienic sanitary arrangement for students."},
    {"id":"a6","text":"Availability of fire safety devices in campus."},
    {"id":"a7","text":"Availability of ramp and lift for Divyang person."},
    {"id":"a8","text":"Availability of Canteen, Bank, Post office, first-aid in campus."},
    {"id":"a9","text":"Availability of well-maintained playground, Gym."},
    {"id":"a10","text":"Availability of well-maintained separate boys and girls hostels."}
  ],
  "remarkPrompts": [{"id":"suggestions","label":"Suggestions if any"}],
  "identityFields": []
}'::jsonb),

-- 2. Curriculum (named, 10 questions, 3-point Likert)
('curriculum', 'Students Feedback on Curriculum', FALSE, FALSE,
'{
  "scaleLabels": ["Good","Average","Poor"],
  "questions": [
    {"id":"c1","text":"How challenging is the syllabus offered by the courses."},
    {"id":"c2","text":"Appropriateness of the sequence of the subjects in curriculum."},
    {"id":"c3","text":"Depth of the syllabus of the courses according to the competencies expected by Industry / current global scenario."},
    {"id":"c4","text":"Sequence of the unit modules in the courses."},
    {"id":"c5","text":"Adequateness of the books mentioned for the courses."},
    {"id":"c6","text":"Content of the courses in terms of burden on the students."},
    {"id":"c7","text":"Design of the courses are promoting the self-learning approach."},
    {"id":"c8","text":"Flexibility in choosing the electives related to technological trends."},
    {"id":"c9","text":"Percentage of the courses offering Laboratory components."},
    {"id":"c10","text":"Composition of the courses in terms of Basic science, Engineering, Humanities, electives, projects, etc."}
  ],
  "remarkPrompts": [{"id":"suggestions","label":"Any suggestions"}],
  "identityFields": ["name"]
}'::jsonb),

-- 3. Faculty Performance (anonymous, per-subject, 9 questions, 4-point per-question)
('faculty', 'Student Feed-back Form (Faculty Performance)', TRUE, TRUE,
'{
  "scaleLabels": ["1","2","3","4"],
  "questions": [
    {"id":"f1","text":"How are the classes engaged?","options":["Irregularly","Sometimes irregular","Generally regular","Always regular"]},
    {"id":"f2","text":"Are you satisfied with the progress of the syllabus?","options":["Totally unsatisfied","Satisfied to some extent","Satisfied","Totally satisfied"]},
    {"id":"f3","text":"Do you understand the subject?","options":["Not at all","To some extent","Good enough","In all respect"]},
    {"id":"f4","text":"Is the teacher capable of controlling the class?","options":["Poor control","Fair control","Adequate control","Good control"]},
    {"id":"f5","text":"Does the teacher involve the students during lectures?","options":["Never","Rarely","Usually","Always"]},
    {"id":"f6","text":"Is your teacher proficient in English?","options":["Poor","Average","Good","Excellent"]},
    {"id":"f7","text":"Is the teacher audible?","options":["Poor","Average","Good","Excellent"]},
    {"id":"f8","text":"How is his teaching generally?","options":["Boring","Monotonous","Good","Interesting"]},
    {"id":"f9","text":"How do you rate the overall performance of your teacher?","options":["Poor","Fair","Good","Excellent"]}
  ],
  "remarkPrompts": [
    {"id":"expectations","label":"What are the specific expectations from your teacher for the improvement of result in the subjects?"},
    {"id":"comments","label":"Any additional comments on the performance of your teacher."}
  ],
  "identityFields": []
}'::jsonb),

-- 4. Library (named, 9 questions + 1 special, 4-point Likert)
('library', 'Library Feedback Form', FALSE, FALSE,
'{
  "scaleLabels": ["Excellent","Very Good","Good","Satisfactory"],
  "questions": [
    {"id":"l1","text":"Regarding the college library time (8:30 am to 12:00 midnight)"},
    {"id":"l2","text":"Library infrastructure"},
    {"id":"l3","text":"The available reading space in the library"},
    {"id":"l4","text":"Course books received from the library"},
    {"id":"l5","text":"Available number of journals / magazines in your branch"},
    {"id":"l6","text":"Library services - Such as book circulation, Reference Service, Back volume of journals / magazines etc."},
    {"id":"l7","text":"Availability of reprographic facility, Internet facility"},
    {"id":"l8","text":"Behaviour of the library staff"},
    {"id":"l9","text":"Overall facilities provided by library"}
  ],
  "specialQuestions": [
    {"id":"visitFrequency","label":"How often do you visit the library","type":"choice","options":["Daily","Twice in a week","Once in a week","Once in a month","Other"]}
  ],
  "remarkPrompts": [{"id":"suggestions","label":"Please give your suggestions for any improvement in the library"}],
  "identityFields": ["name","roll_no","year","department"]
}'::jsonb)

ON CONFLICT (code) DO UPDATE SET
  title                = EXCLUDED.title,
  anonymous            = EXCLUDED.anonymous,
  requires_per_subject = EXCLUDED.requires_per_subject,
  schema               = EXCLUDED.schema,
  updated_at           = now();
