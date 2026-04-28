-- =============================================================================
-- 0004 audit_log + generic insert/update/delete trigger.
--
-- Append-only. Only super_admin can SELECT.
-- The trigger is SECURITY DEFINER so it can write even when the calling user's
-- RLS would otherwise block direct INSERT into audit_log.
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID,
  action        TEXT NOT NULL,
  entity_type   TEXT NOT NULL,
  entity_id     UUID,
  before        JSONB,
  after         JSONB,
  at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS al_super_select ON audit_log;
CREATE POLICY al_super_select ON audit_log FOR SELECT USING (is_super_admin());

GRANT SELECT ON audit_log TO authenticated;
REVOKE ALL ON audit_log FROM anon;

-- Generic audit trigger: writes one row per INSERT/UPDATE/DELETE on audited
-- tables. Captures actor (auth.uid()) and full before/after row JSON.
CREATE OR REPLACE FUNCTION trg_audit() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id      UUID;
  v_before  JSONB;
  v_after   JSONB;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_id    := (row_to_json(NEW)::jsonb ->> 'id')::UUID;
    v_after := row_to_json(NEW)::jsonb;
  ELSIF TG_OP = 'UPDATE' THEN
    v_id     := (row_to_json(NEW)::jsonb ->> 'id')::UUID;
    v_before := row_to_json(OLD)::jsonb;
    v_after  := row_to_json(NEW)::jsonb;
  ELSE -- DELETE
    v_id     := (row_to_json(OLD)::jsonb ->> 'id')::UUID;
    v_before := row_to_json(OLD)::jsonb;
  END IF;
  INSERT INTO audit_log(actor_user_id, action, entity_type, entity_id, before, after)
  VALUES (auth.uid(), TG_OP, TG_TABLE_NAME, v_id, v_before, v_after);
  RETURN COALESCE(NEW, OLD);
END $$;

-- Attach to mutable admin tables. Idempotent.
DO $$
DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'departments','subjects','teachers','divisions','offerings',
    'offering_subjects','class_rosters','campaigns','access_codes','user_profiles'
  ]) LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %1$I_audit ON %1$I', t);
    EXECUTE format(
      'CREATE TRIGGER %1$I_audit AFTER INSERT OR UPDATE OR DELETE ON %1$I FOR EACH ROW EXECUTE FUNCTION trg_audit()',
      t
    );
  END LOOP;
END $$;
