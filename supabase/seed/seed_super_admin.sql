-- =============================================================================
-- Idempotently link a super-admin auth.users row to a user_profiles row.
--
-- Prerequisite: create the auth user via Supabase Dashboard
--   (Authentication → Users → Add user → "Create new user").
--   GoTrue handles password hashing correctly. Direct INSERT INTO auth.users
--   from psql does NOT produce a usable login on Supabase Cloud.
--
-- Then replace the email below and run:
--   psql "$DB_URL" -f supabase/seed/seed_super_admin.sql
-- =============================================================================

DO $$
DECLARE
  v_uid   UUID;
  v_email TEXT := 'super-admin@csmss.edu.in';  -- TODO: replace with real email
BEGIN
  SELECT id INTO v_uid FROM auth.users WHERE email = v_email;
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No auth user with email %; create via Supabase Dashboard first', v_email;
  END IF;
  INSERT INTO user_profiles(user_id, role, department_id)
    VALUES (v_uid, 'super_admin', NULL)
    ON CONFLICT (user_id) DO NOTHING;
  RAISE NOTICE 'super_admin linked: user_id=%, email=%', v_uid, v_email;
END $$;
