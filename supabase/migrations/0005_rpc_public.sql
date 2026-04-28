-- =============================================================================
-- 0005 Public RPCs (callable with anon key — students never write to tables
-- directly; everything goes through these SECURITY DEFINER functions).
--
-- Error codes:
--   P0001 — invalid_or_expired_code
--   P0002 — prn_not_in_roster
--   P0003 — duplicate_submission
--   P0004 — app.dedup_salt not configured
--   P0005 — template_mismatch
--   P0006 — offering_subject_required (faculty form)
-- =============================================================================

-- ---------- lookup_access_code ----------
-- Resolves a class access code to a campaign + offering label. Used by the
-- public landing page after the student types the code (before they enter PRN).
-- Does NOT expose PRN-bearing data; that's the next RPC.
CREATE OR REPLACE FUNCTION lookup_access_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ac    RECORD;
  v_camp  RECORD;
  v_label TEXT;
BEGIN
  SELECT * INTO v_ac FROM access_codes WHERE code = p_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_or_expired_code' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_camp FROM campaigns WHERE id = v_ac.campaign_id;
  IF v_camp.status <> 'open'
     OR now() < v_camp.opens_at
     OR now() > v_camp.closes_at
     OR now() > v_ac.expires_at THEN
    RAISE EXCEPTION 'invalid_or_expired_code' USING ERRCODE = 'P0001';
  END IF;

  SELECT format('%s / Y%s / Div-%s / Sem-%s / %s',
                d.code, dv.year_of_study, dv.name, o.semester, ay.label)
  INTO v_label
  FROM offerings o
  JOIN divisions dv      ON dv.id = o.division_id
  JOIN departments d     ON d.id  = dv.department_id
  JOIN academic_years ay ON ay.id = o.academic_year_id
  WHERE o.id = v_ac.offering_id;

  RETURN jsonb_build_object(
    'campaign_id',    v_ac.campaign_id,
    'campaign_name',  v_camp.name,
    'template_code',  (SELECT code FROM form_templates WHERE id = v_camp.template_id),
    'offering_label', v_label,
    'closes_at',      v_camp.closes_at
  );
END $$;

GRANT EXECUTE ON FUNCTION lookup_access_code(TEXT) TO anon, authenticated;
