-- 02_schema_finance.sql
-- Financial ledger, digital receipts, daily cash-ups, claims, payment reminders,
-- funeral updates/media, and staging/archive review support.

-- Add archive & review columns to policies (idempotent if 01_schema_core.sql already ran)
ALTER TABLE IF EXISTS policies
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS archive_reason TEXT,
  ADD COLUMN IF NOT EXISTS needs_review BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS review_reason TEXT;

-- Staging table for imported spreadsheet rows (keeps raw rows & flags unlinked/weird rows for staff)
CREATE TABLE IF NOT EXISTS staging_member_imports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id TEXT NOT NULL,
  raw_mku TEXT,
  raw_first_name TEXT,
  raw_last_name TEXT,
  raw_id_number TEXT,
  raw_passport TEXT,
  raw_dob TEXT,
  raw_plan TEXT,
  raw_policy_number TEXT,
  raw_parent_policy_number TEXT,
  raw_relation TEXT,
  raw_contact_number TEXT,
  raw_address TEXT,
  raw_branch TEXT,
  raw_date_joined TEXT,
  raw_status TEXT,
  raw_premium NUMERIC(10, 2),
  raw_cover NUMERIC(12, 2),
  review_status TEXT NOT NULL DEFAULT 'pending_review'
    CHECK (review_status IN ('pending_review', 'linked_imported', 'archived', 'deleted_rejected')),
  review_reason TEXT,
  reviewed_by TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Append-only payment ledger (payments, reversals, adjustments, credits)
CREATE TABLE IF NOT EXISTS payment_ledger (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id UUID NOT NULL REFERENCES policies(id) ON DELETE RESTRICT,
  entry_type TEXT NOT NULL CHECK (entry_type IN ('payment', 'reversal', 'adjustment', 'credit')),
  amount_zar NUMERIC(12, 2) NOT NULL CHECK (amount_zar > 0),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'eft', 'card', 'debit_order', 'mobile_money')),
  period_covered TEXT, -- e.g. '2026-12'
  payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
  recorded_by TEXT NOT NULL,
  reference_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_ledger_policy_id ON payment_ledger(policy_id);
CREATE INDEX IF NOT EXISTS idx_payment_ledger_payment_date ON payment_ledger(payment_date);

-- Digital receipts linked to ledger entries
CREATE TABLE IF NOT EXISTS digital_receipts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receipt_number TEXT UNIQUE NOT NULL, -- e.g. RCP-000001
  ledger_entry_id UUID NOT NULL REFERENCES payment_ledger(id) ON DELETE RESTRICT,
  policy_id UUID NOT NULL REFERENCES policies(id) ON DELETE RESTRICT,
  amount_zar NUMERIC(12, 2) NOT NULL,
  payment_method TEXT NOT NULL,
  delivery_channel TEXT NOT NULL DEFAULT 'print'
    CHECK (delivery_channel IN ('email', 'whatsapp', 'sms', 'print')),
  delivered_at TIMESTAMPTZ,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Daily cash-up verification (expected vs physically counted cash + variance)
CREATE TABLE IF NOT EXISTS daily_cashups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cashup_date DATE NOT NULL,
  branch_code TEXT NOT NULL DEFAULT 'MAIN',
  expected_cash_zar NUMERIC(12, 2) NOT NULL CHECK (expected_cash_zar >= 0),
  counted_cash_zar NUMERIC(12, 2) NOT NULL CHECK (counted_cash_zar >= 0),
  variance_zar NUMERIC(12, 2) NOT NULL, -- counted_cash_zar - expected_cash_zar
  variance_reason TEXT,
  status TEXT NOT NULL DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted', 'approved', 'locked')),
  collected_by TEXT NOT NULL,
  verified_by TEXT,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (cashup_date, branch_code, collected_by)
);

-- Claims workflow & waiting/arrears checks
CREATE TABLE IF NOT EXISTS claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_number TEXT UNIQUE NOT NULL, -- e.g. CLM-000101
  policy_id UUID NOT NULL REFERENCES policies(id) ON DELETE RESTRICT,
  dependant_id UUID REFERENCES dependants(id) ON DELETE SET NULL, -- NULL means main member
  date_of_death DATE NOT NULL,
  cause_type TEXT NOT NULL CHECK (cause_type IN ('natural', 'accidental')),
  claimant_name TEXT NOT NULL,
  claimant_phone TEXT NOT NULL,
  inside_waiting_period BOOLEAN NOT NULL DEFAULT FALSE,
  policy_in_arrears_or_lapsed BOOLEAN NOT NULL DEFAULT FALSE,
  checklist_complete BOOLEAN NOT NULL DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'under_review', 'docs_pending', 'approved', 'rejected', 'partially_approved', 'service_scheduled', 'payout_processed', 'closed')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_claims_policy_id ON claims(policy_id);
CREATE INDEX IF NOT EXISTS idx_claims_status ON claims(status);

-- Payment reminder delivery log
CREATE TABLE IF NOT EXISTS payment_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id UUID NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
  reminder_stage TEXT NOT NULL CHECK (reminder_stage IN ('upcoming_due', 'due_or_grace', 'pre_lapse_arrears')),
  channel TEXT NOT NULL CHECK (channel IN ('sms', 'email', 'whatsapp')),
  status TEXT NOT NULL CHECK (status IN ('queued', 'sent', 'skipped', 'failed')),
  error_message TEXT,
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Funeral / case service folders & media updates (with consent/visibility flag)
CREATE TABLE IF NOT EXISTS funeral_service_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id UUID REFERENCES claims(id) ON DELETE CASCADE,
  policy_id UUID NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
  folder_name TEXT NOT NULL DEFAULT 'General Service',
  media_url TEXT NOT NULL,
  caption TEXT,
  visibility TEXT NOT NULL DEFAULT 'family_shared'
    CHECK (visibility IN ('staff_only', 'family_shared', 'approved_public')),
  consent_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
  uploaded_by TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
