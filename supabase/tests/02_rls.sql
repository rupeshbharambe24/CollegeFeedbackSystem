-- pgTAP: RLS scoping for super_admin, department_admin, anon.
-- Wrapped in BEGIN/ROLLBACK so cloud state is unaffected.
BEGIN;
SELECT plan(7);

-- Seed: 2 departments
INSERT INTO departments(id, name, code) VALUES
  ('11111111-1111-1111-1111-111111111111', 'CSE',  'CSE'),
  ('22222222-2222-2222-2222-222222222222', 'MECH', 'MECH');

-- Seed: 3 auth users (id is the only NOT NULL column)
INSERT INTO auth.users(id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc');

INSERT INTO user_profiles(user_id, role, department_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'super_admin',      NULL),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'department_admin', '11111111-1111-1111-1111-111111111111'),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'department_admin', '22222222-2222-2222-2222-222222222222');

INSERT INTO teachers(id, department_id, name) VALUES
  ('dddddddd-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'CSE Prof A'),
  ('dddddddd-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 'MECH Prof B');

INSERT INTO subjects(id, owner_department_id, name, is_fy_common) VALUES
  ('eeeeeeee-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 'Math-I',   TRUE),
  ('eeeeeeee-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'OS',       FALSE),
  ('eeeeeeee-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'Workshop', FALSE);

-- ---------- super_admin sees all teachers ---------------------------------
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);
SELECT is((SELECT count(*) FROM teachers)::INT, 2, 'super_admin sees both teachers');

-- ---------- CSE dept_admin sees only CSE teachers -------------------------
SELECT set_config('request.jwt.claim.sub', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', true);
SELECT is((SELECT count(*) FROM teachers)::INT, 1, 'CSE admin sees only CSE teachers');
SELECT is((SELECT name FROM teachers LIMIT 1), 'CSE Prof A', 'CSE admin sees the right teacher');

-- ---------- MECH dept_admin cannot insert teacher into CSE ----------------
SELECT set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
SELECT throws_ok(
  $$ INSERT INTO teachers(department_id, name) VALUES ('11111111-1111-1111-1111-111111111111', 'rogue') $$,
  '42501', NULL,
  'MECH admin cannot insert teacher into CSE'
);

-- ---------- anonymous role blocked from teachers --------------------------
RESET ROLE;
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$ SELECT count(*) FROM teachers $$,
  '42501', NULL,
  'anon cannot read teachers (no grant; RPC-only)'
);

-- ---------- FY-common subject readable by other dept's admin --------------
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'cccccccc-cccc-cccc-cccc-cccccccccccc', true);
SELECT is(
  (SELECT count(*) FROM subjects WHERE name='Math-I')::INT, 1,
  'MECH admin can read FY-common subject owned by CSE');
SELECT is(
  (SELECT count(*) FROM subjects WHERE owner_department_id='11111111-1111-1111-1111-111111111111' AND is_fy_common=FALSE)::INT, 0,
  'MECH admin cannot read non-FY-common CSE subjects');

SELECT * FROM finish();
ROLLBACK;
