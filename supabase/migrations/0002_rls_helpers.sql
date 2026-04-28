-- =============================================================================
-- 0002 RLS helpers: role/dept lookups + PRN normalizer
-- All marked SECURITY DEFINER where they need to bypass RLS to read user_profiles.
-- =============================================================================

-- Returns the current user's role from user_profiles, or NULL if not an admin.
CREATE OR REPLACE FUNCTION current_user_role() RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT role FROM user_profiles WHERE user_id = auth.uid()
$$;

-- Returns the current user's department_id (NULL for super_admin or non-admin).
CREATE OR REPLACE FUNCTION current_user_department_id() RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT department_id FROM user_profiles WHERE user_id = auth.uid()
$$;

-- Convenience: is the current JWT a super_admin?
CREATE OR REPLACE FUNCTION is_super_admin() RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT current_user_role() = 'super_admin'::user_role
$$;

-- Convenience: is the current JWT a department_admin scoped to dept :dept_id?
CREATE OR REPLACE FUNCTION is_dept_admin_for(dept_id UUID) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT current_user_role() = 'department_admin'::user_role
     AND current_user_department_id() = dept_id
$$;

-- PRN normalization: trim, uppercase, strip non-alphanumerics.
-- Used by both the roster lookup in resolve_offering_for_prn and the dedup hash.
CREATE OR REPLACE FUNCTION normalize_prn(raw TEXT) RETURNS TEXT
LANGUAGE sql IMMUTABLE AS $$
  SELECT UPPER(REGEXP_REPLACE(COALESCE(raw,''), '[^A-Za-z0-9]', '', 'g'))
$$;
