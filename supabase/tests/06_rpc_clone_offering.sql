-- pgTAP: clone_offering copies subject list, leaves teacher slots NULL.
BEGIN;
SELECT plan(3);

INSERT INTO departments(id,name,code) VALUES
  ('11111111-1111-1111-1111-111111111111','CSE','CSE');
INSERT INTO academic_years(id,label,start_date,end_date) VALUES
  ('aaaaaaaa-1111-1111-1111-111111111111','2025-26','2025-07-01','2026-06-30'),
  ('aaaaaaaa-2222-2222-2222-222222222222','2026-27','2026-07-01','2027-06-30');
INSERT INTO divisions(id,department_id,year_of_study,name) VALUES
  ('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111',3,'A');
INSERT INTO offerings(id,division_id,semester,academic_year_id,status) VALUES
  ('44444444-4444-4444-4444-444444444444',
   '33333333-3333-3333-3333-333333333333', 5,
   'aaaaaaaa-1111-1111-1111-111111111111', 'published');
INSERT INTO subjects(id,owner_department_id,name) VALUES
  ('eeeeeeee-1111-1111-1111-111111111111','11111111-1111-1111-1111-111111111111','DBMS'),
  ('eeeeeeee-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','OS');
INSERT INTO teachers(id,department_id,name) VALUES
  ('dddddddd-1111-1111-1111-111111111111','11111111-1111-1111-1111-111111111111','Prof X');
INSERT INTO offering_subjects(offering_id,subject_id,teacher_id) VALUES
  ('44444444-4444-4444-4444-444444444444','eeeeeeee-1111-1111-1111-111111111111','dddddddd-1111-1111-1111-111111111111'),
  ('44444444-4444-4444-4444-444444444444','eeeeeeee-2222-2222-2222-222222222222', NULL);

-- Act as super admin
INSERT INTO auth.users(id) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
INSERT INTO user_profiles(user_id,role) VALUES ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','super_admin');
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

-- Clone
SELECT lives_ok(
  $$ SELECT clone_offering('44444444-4444-4444-4444-444444444444',
                           '33333333-3333-3333-3333-333333333333',
                           5::SMALLINT,
                           'aaaaaaaa-2222-2222-2222-222222222222') $$,
  'clone runs'
);

-- 2 subjects copied
SELECT is(
  (SELECT count(*) FROM offering_subjects os
   JOIN offerings o ON o.id = os.offering_id
   WHERE o.academic_year_id = 'aaaaaaaa-2222-2222-2222-222222222222')::INT,
  2,
  'two offering_subjects rows copied'
);

-- teacher slots are NULL on the clone
SELECT is(
  (SELECT count(*) FROM offering_subjects os
   JOIN offerings o ON o.id = os.offering_id
   WHERE o.academic_year_id = 'aaaaaaaa-2222-2222-2222-222222222222'
     AND os.teacher_id IS NULL)::INT,
  2,
  'teacher_id is null on clone'
);

SELECT * FROM finish();
ROLLBACK;
