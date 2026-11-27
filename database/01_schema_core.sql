-- 01_schema_core.sql
-- Core tables for packages, policyholders, dependants, barcodes, waiting periods, and appointments.
-- Compatible with PostgreSQL / Supabase SQL.

CREATE TABLE IF NOT EXISTS cover_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  monthly_premium_zar NUMERIC(10, 2) NOT NULL CHECK (monthly_premium_zar >= 0),
  cover_amount_zar NUMERIC(12, 2) NOT NULL CHECK (cover_amount_zar >= 0),
  waiting_period_months INTEGER NOT NULL DEFAULT 6 CHECK (waiting_period_months >= 0),
  accidental_waiting_days INTEGER NOT NULL DEFAULT 0 CHECK (accidental_waiting_days >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_number TEXT UNIQUE NOT NULL, -- e.g. GF-001042
  barcode_value TEXT UNIQUE NOT NULL, -- Scanned by barcode scanner / printed on thermal slip
  package_id UUID NOT NULL REFERENCES cover_packages(id),
  branch_code TEXT NOT NULL DEFAULT 'MAIN',

  -- Main member details
  full_name TEXT NOT NULL,
  id_or_passport TEXT,
  phone_e164 TEXT NOT NULL,
  whatsapp_e164 TEXT,
  email TEXT,
  physical_address TEXT,

  -- Preferences & consent
  preferred_receipt_channel TEXT NOT NULL DEFAULT 'email'
    CHECK (preferred_receipt_channel IN ('email', 'whatsapp', 'sms', 'print')),
  preferred_reminder_channel TEXT NOT NULL DEFAULT 'sms'
    CHECK (preferred_reminder_channel IN ('sms', 'email', 'whatsapp', 'none')),
  billing_day INTEGER NOT NULL DEFAULT 1 CHECK (billing_day BETWEEN 1 AND 28),
  popia_consent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  marketing_consent BOOLEAN NOT NULL DEFAULT FALSE,

  -- Policy lifecycle & waiting period tracking
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'active', 'grace_period', 'in_arrears', 'lapsed', 'suspended', 'claimed', 'closed')),
  inception_date DATE NOT NULL,
  waiting_period_end_date DATE NOT NULL,
  next_due_date DATE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_policies_policy_number ON policies(policy_number);
CREATE INDEX IF NOT EXISTS idx_policies_barcode_value ON policies(barcode_value);
CREATE INDEX IF NOT EXISTS idx_policies_full_name ON policies(full_name);
CREATE INDEX IF NOT EXISTS idx_policies_status ON policies(status);

CREATE TABLE IF NOT EXISTS dependants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id UUID NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
  relationship TEXT NOT NULL CHECK (relationship IN ('spouse', 'child', 'parent', 'extended_family')),
  full_name TEXT NOT NULL,
  date_of_birth DATE,
  id_or_birth_cert TEXT,
  cover_amount_zar NUMERIC(12, 2) CHECK (cover_amount_zar >= 0),
  waiting_period_end_date DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'in_waiting', 'removed', 'deceased')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dependants_policy_id ON dependants(policy_id);

CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id UUID REFERENCES policies(id) ON DELETE SET NULL,
  requester_name TEXT NOT NULL,
  requester_phone TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK (purpose IN ('new_cover', 'consultation', 'claim_arrangement', 'document_help', 'branch_visit')),
  preferred_date DATE NOT NULL,
  preferred_time_slot TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'confirmed', 'completed', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_appointments_date_status ON appointments(preferred_date, status);
