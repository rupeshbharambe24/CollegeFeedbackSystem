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

-- ---------- app_dedup_salt ----------
-- Returns the salt used in dedup_hash. Hardcoded for dev; rotate before prod
-- via a fresh CREATE OR REPLACE migration. Supabase Cloud's `postgres` role
-- can't `ALTER DATABASE postgres SET app.dedup_salt`, so we use a function.
CREATE OR REPLACE FUNCTION app_dedup_salt() RETURNS TEXT
LANGUAGE sql IMMUTABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT 'phase1-dev-salt-rotate-before-prod'::TEXT
$$;
REVOKE EXECUTE ON FUNCTION app_dedup_salt() FROM PUBLIC, anon;
-- only nested SECURITY DEFINER calls (from submit_feedback / resolve_*) need it

-- ---------- resolve_offering_for_prn ----------
-- After a student supplies a code + PRN, this verifies the PRN is in the
-- offering's roster and returns identity for autofill on named forms, plus
-- which template_codes have already been submitted (for the picker UI).
CREATE OR REPLACE FUNCTION resolve_offering_for_prn(p_code TEXT, p_prn TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  v_ac      RECORD;
  v_camp    RECORD;
  v_norm    TEXT := normalize_prn(p_prn);
  v_roster  RECORD;
  v_submitted_template_codes TEXT[];
  v_salt    TEXT := app_dedup_salt();
BEGIN
  SELECT * INTO v_ac FROM access_codes WHERE code = p_code;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_or_expired_code' USING ERRCODE='P0001'; END IF;

  SELECT * INTO v_camp FROM campaigns WHERE id = v_ac.campaign_id;
  IF v_camp.status <> 'open'
     OR now() < v_camp.opens_at OR now() > v_camp.closes_at
     OR now() > v_ac.expires_at THEN
    RAISE EXCEPTION 'invalid_or_expired_code' USING ERRCODE='P0001';
  END IF;

  SELECT * INTO v_roster
  FROM class_rosters
  WHERE offering_id = v_ac.offering_id AND normalize_prn(prn) = v_norm;
  IF NOT FOUND THEN RAISE EXCEPTION 'prn_not_in_roster' USING ERRCODE='P0002'; END IF;

  -- Which templates has this PRN already submitted under this campaign?
  SELECT array_agg(DISTINCT ft.code::TEXT) INTO v_submitted_template_codes
  FROM submissions s JOIN form_templates ft ON ft.id = s.template_id
  WHERE s.campaign_id = v_ac.campaign_id
    AND s.dedup_hash = encode(digest(
          v_norm || s.campaign_id::TEXT
                 || COALESCE(s.offering_subject_id::TEXT,'')
                 || v_salt,
          'sha256'), 'hex');

  RETURN jsonb_build_object(
    'campaign_id',                    v_ac.campaign_id,
    'offering_id',                    v_ac.offering_id,
    'template_code',                  (SELECT code FROM form_templates WHERE id = v_camp.template_id),
    'name',                           v_roster.name,
    'roll_no',                        v_roster.roll_no,
    'prn_normalized',                 v_norm,
    'already_submitted_template_codes', COALESCE(v_submitted_template_codes, ARRAY[]::TEXT[])
  );
END $$;

GRANT EXECUTE ON FUNCTION resolve_offering_for_prn(TEXT, TEXT) TO anon, authenticated;

-- ---------- submit_feedback ----------
-- The single write path for student feedback. Validates code → campaign → PRN
-- → roster → template → dedup, then INSERTs. Anonymous templates have their
-- identity stripped before persistence.
CREATE OR REPLACE FUNCTION submit_feedback(
  p_code                TEXT,
  p_prn                 TEXT,
  p_template_code       form_template_code,
  p_offering_subject_id UUID,
  p_identity            JSONB,
  p_answers             JSONB,
  p_remarks             JSONB
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  v_ac       RECORD;
  v_camp     RECORD;
  v_norm     TEXT := normalize_prn(p_prn);
  v_template RECORD;
  v_hash     TEXT;
  v_id       UUID;
  v_salt     TEXT := app_dedup_salt();
BEGIN
  SELECT * INTO v_ac FROM access_codes WHERE code = p_code;
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid_or_expired_code' USING ERRCODE='P0001'; END IF;

  SELECT * INTO v_camp FROM campaigns WHERE id = v_ac.campaign_id;
  IF v_camp.status <> 'open'
     OR now() < v_camp.opens_at OR now() > v_camp.closes_at
     OR now() > v_ac.expires_at THEN
    RAISE EXCEPTION 'invalid_or_expired_code' USING ERRCODE='P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM class_rosters
                 WHERE offering_id = v_ac.offering_id
                   AND normalize_prn(prn) = v_norm) THEN
    RAISE EXCEPTION 'prn_not_in_roster' USING ERRCODE='P0002';
  END IF;

  SELECT * INTO v_template FROM form_templates
   WHERE id = v_camp.template_id AND code = p_template_code;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'template_mismatch' USING ERRCODE='P0005';
  END IF;

  -- per-subject required only for faculty
  IF v_template.requires_per_subject AND p_offering_subject_id IS NULL THEN
    RAISE EXCEPTION 'offering_subject_required' USING ERRCODE='P0006';
  END IF;

  v_hash := encode(digest(
    v_norm || v_ac.campaign_id::TEXT
           || COALESCE(p_offering_subject_id::TEXT,'')
           || v_salt,
    'sha256'), 'hex');

  BEGIN
    INSERT INTO submissions(campaign_id, offering_id, offering_subject_id, template_id,
                            identity, dedup_hash, answers, remarks)
    VALUES (v_ac.campaign_id, v_ac.offering_id, p_offering_subject_id, v_template.id,
            CASE WHEN v_template.anonymous THEN NULL ELSE p_identity END,
            v_hash, p_answers, p_remarks)
    RETURNING id INTO v_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'duplicate_submission' USING ERRCODE='P0003';
  END;

  RETURN v_id;
END $$;

GRANT EXECUTE ON FUNCTION submit_feedback(TEXT, TEXT, form_template_code, UUID, JSONB, JSONB, JSONB)
  TO anon, authenticated;
