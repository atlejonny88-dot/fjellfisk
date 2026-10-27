CREATE TABLE IF NOT EXISTS schema_migrations (
  version TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS collector_devices (
  collector_id UUID PRIMARY KEY,
  state TEXT NOT NULL CHECK (state IN ('UNPAIRED', 'PAIRED', 'REVOKED')),
  credential_digest TEXT NOT NULL UNIQUE,
  collector_version TEXT,
  platform TEXT,
  organization_id TEXT,
  site_id TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL,
  paired_at TIMESTAMPTZ,
  paired_by_uid TEXT,
  revoked_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS collector_devices_site_id_idx
  ON collector_devices (site_id);

CREATE TABLE IF NOT EXISTS collector_pairing_codes (
  code_digest TEXT PRIMARY KEY,
  collector_id UUID NOT NULL REFERENCES collector_devices(collector_id),
  state TEXT NOT NULL CHECK (state IN ('ACTIVE', 'USED', 'SUPERSEDED', 'EXPIRED')),
  issued_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  claimed_by_uid TEXT
);

CREATE INDEX IF NOT EXISTS collector_pairing_codes_collector_idx
  ON collector_pairing_codes (collector_id);

CREATE UNIQUE INDEX IF NOT EXISTS collector_pairing_codes_one_active_idx
  ON collector_pairing_codes (collector_id)
  WHERE state = 'ACTIVE';

CREATE TABLE IF NOT EXISTS collector_audit_events (
  event_id UUID PRIMARY KEY,
  event_type TEXT NOT NULL,
  collector_id UUID NOT NULL,
  organization_id TEXT,
  site_id TEXT,
  actor_uid TEXT,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS collector_audit_events_collector_idx
  ON collector_audit_events (collector_id, created_at DESC);

CREATE TABLE IF NOT EXISTS collector_rate_limits (
  scope TEXT NOT NULL,
  subject_digest TEXT NOT NULL,
  window_started_at TIMESTAMPTZ NOT NULL,
  request_count INTEGER NOT NULL CHECK (request_count >= 0),
  updated_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (scope, subject_digest)
);
