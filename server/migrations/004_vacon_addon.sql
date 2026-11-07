-- VACON Control is a facility-scoped, read-only monitoring add-on. This
-- migration adds configuration, telemetry and audit storage only. It does not
-- add a Modbus client, write function or external network listener.

ALTER TABLE collector_addon_entitlements
  DROP CONSTRAINT IF EXISTS collector_addon_entitlements_addon_key_check;

ALTER TABLE collector_addon_entitlements
  ADD CONSTRAINT collector_addon_entitlements_addon_key_check
  CHECK (addon_key IN ('collector', 'vacon'));

CREATE TABLE IF NOT EXISTS vacon_devices (
  device_id TEXT PRIMARY KEY CHECK (char_length(device_id) BETWEEN 1 AND 128),
  facility_id TEXT NOT NULL REFERENCES collector_facilities(facility_id),
  display_name TEXT NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 120),
  manufacturer TEXT NOT NULL CHECK (char_length(manufacturer) BETWEEN 1 AND 120),
  model TEXT NOT NULL CHECK (char_length(model) BETWEEN 1 AND 120),
  ip_address TEXT NOT NULL CHECK (char_length(ip_address) BETWEEN 7 AND 45),
  subnet_mask TEXT NOT NULL CHECK (char_length(subnet_mask) BETWEEN 7 AND 45),
  gateway TEXT NOT NULL CHECK (char_length(gateway) BETWEEN 7 AND 45),
  dns TEXT NOT NULL CHECK (char_length(dns) BETWEEN 1 AND 255),
  modbus_tcp_port INTEGER NOT NULL CHECK (modbus_tcp_port BETWEEN 1 AND 65535),
  modbus_unit_id INTEGER NOT NULL CHECK (modbus_unit_id BETWEEN 0 AND 255),
  min_frequency_hz NUMERIC(8, 3) NOT NULL CHECK (min_frequency_hz >= 0),
  max_frequency_hz NUMERIC(8, 3) NOT NULL CHECK (max_frequency_hz > min_frequency_hz),
  edge_server_id TEXT NOT NULL CHECK (char_length(edge_server_id) BETWEEN 1 AND 120),
  monitoring_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS vacon_devices_facility_idx
  ON vacon_devices (facility_id, display_name);

CREATE TABLE IF NOT EXISTS vacon_telemetry (
  telemetry_id BIGSERIAL PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES vacon_devices(device_id),
  measured_at TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  quality TEXT NOT NULL CHECK (quality IN ('LIVE', 'STALE', 'FAILED', 'UNAVAILABLE', 'SIMULATED')),
  actual_frequency_hz NUMERIC(8, 3),
  motor_speed_rpm INTEGER,
  motor_speed_verified BOOLEAN NOT NULL DEFAULT FALSE,
  motor_current_raw INTEGER,
  motor_current_a NUMERIC(10, 4),
  motor_current_verified BOOLEAN NOT NULL DEFAULT FALSE,
  ready BOOLEAN,
  running BOOLEAN,
  fault BOOLEAN,
  alarm BOOLEAN,
  at_reference BOOLEAN,
  active_fault_code TEXT,
  CHECK (motor_current_a IS NULL OR motor_current_a >= 0)
);

CREATE INDEX IF NOT EXISTS vacon_telemetry_device_time_idx
  ON vacon_telemetry (device_id, measured_at DESC);

CREATE TABLE IF NOT EXISTS vacon_audit_events (
  audit_id BIGSERIAL PRIMARY KEY,
  facility_id TEXT NOT NULL REFERENCES collector_facilities(facility_id),
  device_id TEXT REFERENCES vacon_devices(device_id),
  actor_uid TEXT REFERENCES collector_users(firebase_uid),
  event_type TEXT NOT NULL CHECK (char_length(event_type) BETWEEN 1 AND 120),
  changed_fields JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS vacon_audit_facility_time_idx
  ON vacon_audit_events (facility_id, created_at DESC);
