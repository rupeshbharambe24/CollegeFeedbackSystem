-- pgTAP: lookup_access_code returns offering label, blocks invalid/expired.
BEGIN;
SELECT plan(4);

-- Seed a campaign + access code
INSERT INTO departments(id, name, code)
  VALUES ('11111111-1111-1111-1111-111111111111','CSE','CSE');
INSERT INTO academic_years(id, label, start_date, end_date, is_current)
  VALUES ('99999999-9999-9999-9999-999999999999', '2026-27', '2026-07-01','2027-06-30', TRUE);
INSERT INTO divisions(id, department_id, year_of_study, name)
  VALUES ('33333333-3333-3333-3333-333333333333',
          '11111111-1111-1111-1111-111111111111', 3, 'A');
INSERT INTO offerings(id, division_id, semester, academic_year_id, status)
  VALUES ('44444444-4444-4444-4444-444444444444',
          '33333333-3333-3333-3333-333333333333', 5,
          '99999999-9999-9999-9999-999999999999', 'published');
INSERT INTO form_templates(id, code, title, anonymous, schema)
  VALUES ('55555555-5555-5555-5555-555555555555',
          'ambience', 'Ambience', TRUE, '{}'::jsonb);
INSERT INTO campaigns(id, template_id, name, opens_at, closes_at, status)
  VALUES ('66666666-6666-6666-6666-666666666666',
          '55555555-5555-5555-5555-555555555555',
          'A camp', now() - interval '1 hour', now() + interval '1 day', 'open');
INSERT INTO campaign_offerings(campaign_id, offering_id)
  VALUES ('66666666-6666-6666-6666-666666666666','44444444-4444-4444-4444-444444444444');
INSERT INTO access_codes(campaign_id, offering_id, code, expires_at)
  VALUES ('66666666-6666-6666-6666-666666666666',
          '44444444-4444-4444-4444-444444444444',
          'CSE-3A-S5-X7Q9', now() + interval '1 day');

-- Valid code
SELECT lives_ok($$ SELECT lookup_access_code('CSE-3A-S5-X7Q9') $$, 'valid code returns ok');
SELECT is(
  (SELECT lookup_access_code('CSE-3A-S5-X7Q9') ->> 'campaign_id'),
  '66666666-6666-6666-6666-666666666666',
  'returns correct campaign_id'
);

-- Invalid code
SELECT throws_ok(
  $$ SELECT lookup_access_code('NOPE') $$,
  'P0001', NULL, 'invalid code throws'
);

-- Expired (closed campaign + expired code)
UPDATE access_codes SET expires_at = now() - interval '1 hour' WHERE code = 'CSE-3A-S5-X7Q9';
UPDATE campaigns    SET closes_at  = now() - interval '30 minutes' WHERE id = '66666666-6666-6666-6666-666666666666';
SELECT throws_ok(
  $$ SELECT lookup_access_code('CSE-3A-S5-X7Q9') $$,
  'P0001', NULL, 'expired code throws'
);

SELECT * FROM finish();
ROLLBACK;
