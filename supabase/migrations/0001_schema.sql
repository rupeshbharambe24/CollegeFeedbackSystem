-- =============================================================================
-- 0001 Schema: 14 entity tables, ENUMs, indexes, FKs, generic updated_at trigger
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgtap;   -- needed for tests/*.sql

-- -- ENUMs ---------------------------------------------------------------------
DO $$ BEGIN CREATE TYPE offering_status    AS ENUM ('draft','published','archived');         EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE campaign_status    AS ENUM ('draft','open','closed','archived');     EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE form_template_code AS ENUM ('ambience','curriculum','faculty','library'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE user_role          AS ENUM ('super_admin','department_admin');       EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- -- departments ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  code        TEXT NOT NULL UNIQUE,
  is_fy_pool  BOOLEAN NOT NULL DEFAULT FALSE,
  is_archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS departments_one_fy_pool ON departments(is_fy_pool) WHERE is_fy_pool = TRUE;

-- -- academic_years ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS academic_years (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label       TEXT NOT NULL UNIQUE,
  start_date  DATE NOT NULL,
  end_date    DATE NOT NULL,
  is_current  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS academic_years_one_current ON academic_years(is_current) WHERE is_current = TRUE;

-- -- divisions -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS divisions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id),
  year_of_study SMALLINT NOT NULL CHECK (year_of_study BETWEEN 1 AND 4),
  name          TEXT NOT NULL,
  is_archived   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (department_id, year_of_study, name)
);

-- -- subjects ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subjects (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_department_id UUID NOT NULL REFERENCES departments(id),
  name                TEXT NOT NULL,
  code                TEXT,
  is_fy_common        BOOLEAN NOT NULL DEFAULT FALSE,
  is_archived         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS subjects_owner_idx     ON subjects(owner_department_id);
CREATE INDEX IF NOT EXISTS subjects_fy_common_idx ON subjects(is_fy_common) WHERE is_fy_common = TRUE;

-- -- teachers ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teachers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id UUID NOT NULL REFERENCES departments(id),
  name          TEXT NOT NULL,
  email         TEXT,
  is_archived   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -- offerings -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS offerings (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  division_id      UUID NOT NULL REFERENCES divisions(id),
  semester         SMALLINT NOT NULL CHECK (semester BETWEEN 1 AND 8),
  academic_year_id UUID NOT NULL REFERENCES academic_years(id),
  status           offering_status NOT NULL DEFAULT 'draft',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS offerings_division_semester_year_uniq
  ON offerings(division_id, semester, academic_year_id);
CREATE INDEX IF NOT EXISTS offerings_year_status_idx ON offerings(academic_year_id, status);

-- -- offering_subjects ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS offering_subjects (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offering_id UUID NOT NULL REFERENCES offerings(id),
  subject_id  UUID NOT NULL REFERENCES subjects(id),
  teacher_id  UUID REFERENCES teachers(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (offering_id, subject_id)
);

-- -- form_templates ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS form_templates (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                 form_template_code NOT NULL UNIQUE,
  title                TEXT NOT NULL,
  anonymous            BOOLEAN NOT NULL,
  requires_per_subject BOOLEAN NOT NULL DEFAULT FALSE,
  schema               JSONB NOT NULL,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -- campaigns -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaigns (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id         UUID NOT NULL REFERENCES form_templates(id),
  name                TEXT NOT NULL,
  scope_department_id UUID REFERENCES departments(id),
  opens_at            TIMESTAMPTZ NOT NULL,
  closes_at           TIMESTAMPTZ NOT NULL,
  status              campaign_status NOT NULL DEFAULT 'draft',
  created_by          UUID REFERENCES auth.users(id),
  archived_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (closes_at > opens_at)
);
CREATE INDEX IF NOT EXISTS campaigns_status_idx ON campaigns(status);

-- -- campaign_offerings --------------------------------------------------------
CREATE TABLE IF NOT EXISTS campaign_offerings (
  campaign_id UUID NOT NULL REFERENCES campaigns(id),
  offering_id UUID NOT NULL REFERENCES offerings(id),
  PRIMARY KEY (campaign_id, offering_id)
);

-- -- access_codes --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS access_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id),
  offering_id UUID NOT NULL REFERENCES offerings(id),
  code        TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (campaign_id, offering_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS access_codes_code_uniq ON access_codes(code);

-- -- class_rosters -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS class_rosters (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offering_id UUID NOT NULL REFERENCES offerings(id),
  prn         TEXT NOT NULL,
  roll_no     TEXT,
  name        TEXT,
  email       TEXT,
  mobile      TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS class_rosters_offering_prn_uniq ON class_rosters(offering_id, prn);

-- -- submissions (append-only) -------------------------------------------------
CREATE TABLE IF NOT EXISTS submissions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id         UUID NOT NULL REFERENCES campaigns(id),
  offering_id         UUID NOT NULL REFERENCES offerings(id),
  offering_subject_id UUID REFERENCES offering_subjects(id),
  template_id         UUID NOT NULL REFERENCES form_templates(id),
  identity            JSONB,
  dedup_hash          TEXT NOT NULL,
  answers             JSONB NOT NULL,
  remarks             JSONB,
  is_hidden           BOOLEAN NOT NULL DEFAULT FALSE,
  submitted_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS submissions_template_dedup_uniq      ON submissions(template_id, dedup_hash);
CREATE INDEX        IF NOT EXISTS submissions_campaign_offering_idx    ON submissions(campaign_id, offering_id);

-- -- user_profiles -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_profiles (
  user_id       UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role          user_role NOT NULL,
  department_id UUID REFERENCES departments(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((role = 'super_admin'      AND department_id IS NULL)
      OR (role = 'department_admin' AND department_id IS NOT NULL))
);

-- -- generic updated_at trigger ------------------------------------------------
CREATE OR REPLACE FUNCTION trg_set_updated_at() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DO $$
DECLARE t TEXT;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'departments','academic_years','divisions','subjects','teachers',
    'offerings','offering_subjects','form_templates','campaigns','user_profiles'
  ]) LOOP
    -- drop-then-create so re-running migration is idempotent
    EXECUTE format('DROP TRIGGER IF EXISTS %1$I_set_updated_at ON %1$I', t);
    EXECUTE format(
      'CREATE TRIGGER %1$I_set_updated_at BEFORE UPDATE ON %1$I FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at()',
      t
    );
  END LOOP;
END $$;
