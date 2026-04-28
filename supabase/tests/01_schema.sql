-- pgTAP: schema sanity (tables, FKs, key unique indexes)
-- Wrapped in BEGIN/ROLLBACK so cloud state is unaffected.
BEGIN;
SELECT plan(20);

-- 14 tables exist
SELECT has_table('public', 'departments',       'departments table exists');
SELECT has_table('public', 'academic_years',    'academic_years table exists');
SELECT has_table('public', 'divisions',         'divisions table exists');
SELECT has_table('public', 'subjects',          'subjects table exists');
SELECT has_table('public', 'teachers',          'teachers table exists');
SELECT has_table('public', 'offerings',         'offerings table exists');
SELECT has_table('public', 'offering_subjects', 'offering_subjects table exists');
SELECT has_table('public', 'form_templates',    'form_templates table exists');
SELECT has_table('public', 'campaigns',         'campaigns table exists');
SELECT has_table('public', 'campaign_offerings','campaign_offerings table exists');
SELECT has_table('public', 'access_codes',      'access_codes table exists');
SELECT has_table('public', 'class_rosters',     'class_rosters table exists');
SELECT has_table('public', 'submissions',       'submissions table exists');
SELECT has_table('public', 'user_profiles',     'user_profiles table exists');

-- Critical unique indexes
SELECT has_index('public', 'offerings',     'offerings_division_semester_year_uniq', 'unique offering per division/sem/year');
SELECT has_index('public', 'class_rosters', 'class_rosters_offering_prn_uniq',       'unique PRN per offering');
SELECT has_index('public', 'access_codes',  'access_codes_code_uniq',                'unique access code');
SELECT has_index('public', 'submissions',   'submissions_template_dedup_uniq',       'submission dedup unique');

-- Critical foreign keys
SELECT col_is_fk('public', 'offering_subjects', 'offering_id',  'offering_subjects.offering_id is FK');
SELECT col_is_fk('public', 'submissions',       'campaign_id',  'submissions.campaign_id is FK');

SELECT * FROM finish();
ROLLBACK;
