-- pgTAP: submit_feedback validates code/PRN, hashes for dedup, blocks duplicates.
BEGIN;
SELECT plan(6);

-- Seed
INSERT INTO departments(id, name, code)
  VALUES ('11111111-1111-1111-1111-111111111111','CSE','CSE');
INSERT INTO academic_years(id, label, start_date, end_date)
  VALUES ('99999999-9999-9999-9999-999999999999', '2026-27', '2026-07-01','2027-06-30');
INSERT INTO divisions(id, department_id, year_of_study, name)
  VALUES ('33333333-3333-3333-3333-333333333333',
          '11111111-1111-1111-1111-111111111111', 3, 'A');
INSERT INTO offerings(id, division_id, semester, academic_year_id, status)
  VALUES ('44444444-4444-4444-4444-444444444444',
          '33333333-3333-3333-3333-333333333333', 5,
          '99999999-9999-9999-9999-999999999999', 'published');
INSERT INTO form_templates(id, code, title, anonymous, schema)
  VALUES ('55555555-5555-5555-5555-555555555555',
          'ambience', 'Ambience', TRUE,
          '{"questions":[{"id":"q1","scale":"agree3"}]}'::jsonb);
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
INSERT INTO class_rosters(offering_id, prn, name)
  VALUES ('44444444-4444-4444-4444-444444444444','CSMSS2024001','Rohan');

-- Valid anonymous submit
SELECT lives_ok(
  $$ SELECT submit_feedback('CSE-3A-S5-X7Q9','CSMSS2024001','ambience',NULL,
                            NULL,'{"q1":"agree"}'::jsonb,'{"suggestion":"more wifi"}'::jsonb) $$,
  'anonymous submit lives'
);

SELECT is((SELECT count(*) FROM submissions)::INT, 1, 'one submission row');
SELECT is((SELECT identity FROM submissions LIMIT 1), NULL, 'anonymous: identity not stored');

-- Duplicate blocked
SELECT throws_ok(
  $$ SELECT submit_feedback('CSE-3A-S5-X7Q9','CSMSS2024001','ambience',NULL,
                            NULL,'{"q1":"agree"}'::jsonb,'{}'::jsonb) $$,
  'P0003', NULL, 'duplicate blocked'
);

-- Unknown PRN
SELECT throws_ok(
  $$ SELECT submit_feedback('CSE-3A-S5-X7Q9','UNKNOWN','ambience',NULL,
                            NULL,'{"q1":"agree"}'::jsonb,'{}'::jsonb) $$,
  'P0002', NULL, 'unknown PRN blocked'
);

-- Closed campaign
UPDATE campaigns SET status = 'closed' WHERE id='66666666-6666-6666-6666-666666666666';
SELECT throws_ok(
  $$ SELECT submit_feedback('CSE-3A-S5-X7Q9','CSMSS2024001','ambience',NULL,
                            NULL,'{"q1":"agree"}'::jsonb,'{}'::jsonb) $$,
  'P0001', NULL, 'closed campaign blocked'
);

SELECT * FROM finish();
ROLLBACK;
