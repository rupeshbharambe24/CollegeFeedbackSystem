-- =============================================================================
-- 0003 RLS policies + role grants
--
-- Pattern:
--   1. ENABLE ROW LEVEL SECURITY on the table (default-deny).
--   2. GRANT base CRUD on the table to `authenticated` (admin role).
--      `anon` gets NO direct table access — student writes go through SECURITY
--      DEFINER RPCs which bypass RLS but enforce their own checks.
--   3. CREATE POLICY rows that match either super_admin or department-scoped
--      ownership.
-- =============================================================================

-- -- Enable RLS ---------------------------------------------------------------
ALTER TABLE departments        ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_years     ENABLE ROW LEVEL SECURITY;
ALTER TABLE divisions          ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects           ENABLE ROW LEVEL SECURITY;
ALTER TABLE teachers           ENABLE ROW LEVEL SECURITY;
ALTER TABLE offerings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE offering_subjects  ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_templates     ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaigns          ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_offerings ENABLE ROW LEVEL SECURITY;
ALTER TABLE access_codes       ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_rosters      ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles      ENABLE ROW LEVEL SECURITY;

-- -- Base table grants to admin role ------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON
  departments, academic_years, divisions, subjects, teachers,
  offerings, offering_subjects, form_templates, campaigns,
  campaign_offerings, access_codes, class_rosters, user_profiles
  TO authenticated;
GRANT SELECT, UPDATE ON submissions TO authenticated;  -- no DELETE / INSERT
GRANT USAGE ON SCHEMA public TO authenticated, anon;

-- Revoke Supabase's default grants from `anon`. Students never touch tables
-- directly — they call SECURITY DEFINER RPCs (lookup_access_code, etc.).
REVOKE ALL ON
  departments, academic_years, divisions, subjects, teachers,
  offerings, offering_subjects, form_templates, campaigns,
  campaign_offerings, access_codes, class_rosters, submissions, user_profiles
  FROM anon;

-- =============================================================================
-- Drop-then-create so re-running the migration is idempotent.
-- =============================================================================

-- ---------- departments ----------
DROP POLICY IF EXISTS dept_super_all      ON departments;
DROP POLICY IF EXISTS dept_admin_select   ON departments;
CREATE POLICY dept_super_all    ON departments FOR ALL    USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY dept_admin_select ON departments FOR SELECT USING (current_user_role() = 'department_admin'::user_role);

-- ---------- academic_years, form_templates ----------
DROP POLICY IF EXISTS ay_super_all    ON academic_years;
DROP POLICY IF EXISTS ay_admin_select ON academic_years;
CREATE POLICY ay_super_all    ON academic_years FOR ALL    USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY ay_admin_select ON academic_years FOR SELECT USING (current_user_role() IS NOT NULL);

DROP POLICY IF EXISTS ft_super_all    ON form_templates;
DROP POLICY IF EXISTS ft_admin_select ON form_templates;
CREATE POLICY ft_super_all    ON form_templates FOR ALL    USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY ft_admin_select ON form_templates FOR SELECT USING (current_user_role() IS NOT NULL);

-- ---------- subjects ----------
DROP POLICY IF EXISTS subj_super_all      ON subjects;
DROP POLICY IF EXISTS subj_dept_own       ON subjects;
DROP POLICY IF EXISTS subj_dept_fy_select ON subjects;
CREATE POLICY subj_super_all      ON subjects FOR ALL    USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY subj_dept_own       ON subjects FOR ALL
  USING       (is_dept_admin_for(owner_department_id))
  WITH CHECK  (is_dept_admin_for(owner_department_id));
CREATE POLICY subj_dept_fy_select ON subjects FOR SELECT
  USING (is_fy_common = TRUE AND current_user_role() = 'department_admin'::user_role);

-- ---------- teachers, divisions ----------
DROP POLICY IF EXISTS tch_super_all ON teachers;
DROP POLICY IF EXISTS tch_dept      ON teachers;
CREATE POLICY tch_super_all ON teachers FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY tch_dept      ON teachers FOR ALL
  USING       (is_dept_admin_for(department_id))
  WITH CHECK  (is_dept_admin_for(department_id));

DROP POLICY IF EXISTS div_super_all ON divisions;
DROP POLICY IF EXISTS div_dept      ON divisions;
CREATE POLICY div_super_all ON divisions FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY div_dept      ON divisions FOR ALL
  USING       (is_dept_admin_for(department_id))
  WITH CHECK  (is_dept_admin_for(department_id));

-- ---------- offerings (scoped via division → dept) ----------
DROP POLICY IF EXISTS off_super_all ON offerings;
DROP POLICY IF EXISTS off_dept      ON offerings;
CREATE POLICY off_super_all ON offerings FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY off_dept ON offerings FOR ALL
  USING       (EXISTS (SELECT 1 FROM divisions d WHERE d.id = division_id AND is_dept_admin_for(d.department_id)))
  WITH CHECK  (EXISTS (SELECT 1 FROM divisions d WHERE d.id = division_id AND is_dept_admin_for(d.department_id)));

-- ---------- offering_subjects (scoped via offering → division → dept) ----------
DROP POLICY IF EXISTS os_super_all ON offering_subjects;
DROP POLICY IF EXISTS os_dept      ON offering_subjects;
CREATE POLICY os_super_all ON offering_subjects FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY os_dept ON offering_subjects FOR ALL
  USING       (EXISTS (SELECT 1 FROM offerings o JOIN divisions d ON d.id = o.division_id
                       WHERE o.id = offering_id AND is_dept_admin_for(d.department_id)))
  WITH CHECK  (EXISTS (SELECT 1 FROM offerings o JOIN divisions d ON d.id = o.division_id
                       WHERE o.id = offering_id AND is_dept_admin_for(d.department_id)));

-- ---------- class_rosters (same scoping) ----------
DROP POLICY IF EXISTS cr_super_all ON class_rosters;
DROP POLICY IF EXISTS cr_dept      ON class_rosters;
CREATE POLICY cr_super_all ON class_rosters FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY cr_dept ON class_rosters FOR ALL
  USING       (EXISTS (SELECT 1 FROM offerings o JOIN divisions d ON d.id = o.division_id
                       WHERE o.id = offering_id AND is_dept_admin_for(d.department_id)))
  WITH CHECK  (EXISTS (SELECT 1 FROM offerings o JOIN divisions d ON d.id = o.division_id
                       WHERE o.id = offering_id AND is_dept_admin_for(d.department_id)));

-- ---------- campaigns ----------
DROP POLICY IF EXISTS camp_super_all                ON campaigns;
DROP POLICY IF EXISTS camp_dept                     ON campaigns;
DROP POLICY IF EXISTS camp_dept_select_collegewide  ON campaigns;
CREATE POLICY camp_super_all ON campaigns FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY camp_dept ON campaigns FOR ALL
  USING       (scope_department_id = current_user_department_id())
  WITH CHECK  (scope_department_id = current_user_department_id());
CREATE POLICY camp_dept_select_collegewide ON campaigns FOR SELECT
  USING (scope_department_id IS NULL AND current_user_role() = 'department_admin'::user_role);

-- ---------- campaign_offerings, access_codes (scoped via campaign) ----------
DROP POLICY IF EXISTS co_super_all ON campaign_offerings;
DROP POLICY IF EXISTS co_dept      ON campaign_offerings;
CREATE POLICY co_super_all ON campaign_offerings FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY co_dept ON campaign_offerings FOR ALL
  USING       (EXISTS (SELECT 1 FROM campaigns c WHERE c.id = campaign_id AND c.scope_department_id = current_user_department_id()))
  WITH CHECK  (EXISTS (SELECT 1 FROM campaigns c WHERE c.id = campaign_id AND c.scope_department_id = current_user_department_id()));

DROP POLICY IF EXISTS ac_super_all ON access_codes;
DROP POLICY IF EXISTS ac_dept      ON access_codes;
CREATE POLICY ac_super_all ON access_codes FOR ALL USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY ac_dept ON access_codes FOR ALL
  USING       (EXISTS (SELECT 1 FROM campaigns c WHERE c.id = campaign_id AND c.scope_department_id = current_user_department_id()))
  WITH CHECK  (EXISTS (SELECT 1 FROM campaigns c WHERE c.id = campaign_id AND c.scope_department_id = current_user_department_id()));

-- ---------- submissions (read scoped; never updated/deleted by anyone except super_admin's is_hidden) ----------
DROP POLICY IF EXISTS sub_super_select ON submissions;
DROP POLICY IF EXISTS sub_super_hide   ON submissions;
DROP POLICY IF EXISTS sub_dept_select  ON submissions;
CREATE POLICY sub_super_select ON submissions FOR SELECT USING (is_super_admin());
CREATE POLICY sub_super_hide   ON submissions FOR UPDATE USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY sub_dept_select  ON submissions FOR SELECT
  USING (EXISTS (SELECT 1 FROM campaigns c WHERE c.id = campaign_id AND c.scope_department_id = current_user_department_id()));
-- INSERT into submissions only via SECURITY DEFINER RPC (no insert policy here)

-- ---------- user_profiles ----------
DROP POLICY IF EXISTS up_super_all   ON user_profiles;
DROP POLICY IF EXISTS up_self_select ON user_profiles;
CREATE POLICY up_super_all   ON user_profiles FOR ALL    USING (is_super_admin()) WITH CHECK (is_super_admin());
CREATE POLICY up_self_select ON user_profiles FOR SELECT USING (user_id = auth.uid());
