CREATE TABLE IF NOT EXISTS collector_users (
  firebase_uid TEXT PRIMARY KEY CHECK (char_length(firebase_uid) BETWEEN 1 AND 128),
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'DISABLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS collector_facilities (
  facility_id TEXT PRIMARY KEY CHECK (char_length(facility_id) BETWEEN 1 AND 200),
  display_name TEXT NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 200),
  organization_id TEXT,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'DISABLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS collector_facility_memberships (
  facility_id TEXT NOT NULL REFERENCES collector_facilities(facility_id),
  firebase_uid TEXT NOT NULL REFERENCES collector_users(firebase_uid),
  role TEXT NOT NULL CHECK (role IN ('ADMIN', 'OPERATOR', 'VIEWER')),
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'DISABLED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (facility_id, firebase_uid)
);

CREATE INDEX IF NOT EXISTS collector_facility_memberships_uid_idx
  ON collector_facility_memberships (firebase_uid, facility_id);

CREATE TABLE IF NOT EXISTS collector_addon_entitlements (
  facility_id TEXT NOT NULL REFERENCES collector_facilities(facility_id),
  addon_key TEXT NOT NULL CHECK (addon_key = 'collector'),
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'INACTIVE')),
  activated_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  updated_by_uid TEXT REFERENCES collector_users(firebase_uid),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (facility_id, addon_key)
);

CREATE TABLE IF NOT EXISTS collector_authority_bootstrap (
  bootstrap_key BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (bootstrap_key),
  firebase_uid TEXT NOT NULL REFERENCES collector_users(firebase_uid),
  facility_id TEXT NOT NULL REFERENCES collector_facilities(facility_id),
  completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
