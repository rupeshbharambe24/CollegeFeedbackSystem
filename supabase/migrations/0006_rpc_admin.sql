-- =============================================================================
-- 0006 Admin RPCs (require admin auth context).
--
-- Error codes:
--   42501 — forbidden (caller is not authorized)
--   P0007 — target_division_not_found
--   P0008 — confirmation_mismatch (wipe phrase didn't match)
-- =============================================================================

-- ---------- clone_offering ----------
-- Creates a new offering for (target_division_id, target_semester, target_academic_year_id),
-- copies the subject list from source_offering_id with NULL teacher_id (admin
-- re-assigns teachers post-clone). Returns the new offering's UUID.
CREATE OR REPLACE FUNCTION clone_offering(
  p_source_offering_id      UUID,
  p_target_division_id      UUID,
  p_target_semester         SMALLINT,
  p_target_academic_year_id UUID
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_new_id      UUID;
  v_target_dept UUID;
BEGIN
  SELECT department_id INTO v_target_dept FROM divisions WHERE id = p_target_division_id;
  IF v_target_dept IS NULL THEN
    RAISE EXCEPTION 'target_division_not_found' USING ERRCODE='P0007';
  END IF;
  IF NOT (is_super_admin() OR is_dept_admin_for(v_target_dept)) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
  END IF;

  INSERT INTO offerings(division_id, semester, academic_year_id, status)
    VALUES (p_target_division_id, p_target_semester, p_target_academic_year_id, 'draft')
    RETURNING id INTO v_new_id;

  INSERT INTO offering_subjects(offering_id, subject_id, teacher_id)
  SELECT v_new_id, subject_id, NULL
  FROM offering_subjects WHERE offering_id = p_source_offering_id;

  RETURN v_new_id;
END $$;

GRANT EXECUTE ON FUNCTION clone_offering(UUID, UUID, SMALLINT, UUID) TO authenticated;

-- ---------- wipe_submissions_for_year ----------
-- Super admin only. Confirmation phrase must match `WIPE-<academic_year_id>`
-- to guard against accidental clicks. Returns the number of rows deleted.
CREATE OR REPLACE FUNCTION wipe_submissions_for_year(
  p_academic_year_id UUID,
  p_confirm_phrase   TEXT
)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count INT;
BEGIN
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE='42501';
  END IF;
  IF p_confirm_phrase <> 'WIPE-' || p_academic_year_id::TEXT THEN
    RAISE EXCEPTION 'confirmation_mismatch' USING ERRCODE='P0008';
  END IF;
  WITH d AS (
    DELETE FROM submissions s
    USING campaign_offerings co, offerings o
    WHERE s.campaign_id = co.campaign_id
      AND s.offering_id = co.offering_id
      AND o.id          = co.offering_id
      AND o.academic_year_id = p_academic_year_id
    RETURNING 1
  )
  SELECT count(*)::INT INTO v_count FROM d;
  RETURN v_count;
END $$;

GRANT EXECUTE ON FUNCTION wipe_submissions_for_year(UUID, TEXT) TO authenticated;
