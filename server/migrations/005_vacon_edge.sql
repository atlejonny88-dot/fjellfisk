-- A VACON Edge is the only component allowed to reach a facility-local
-- drive. It authenticates outwards to the backend; no Modbus port is exposed
-- by this schema or the backend.

CREATE TABLE IF NOT EXISTS vacon_edges (
  edge_id TEXT PRIMARY KEY CHECK (char_length(edge_id) BETWEEN 1 AND 128),
  facility_id TEXT NOT NULL REFERENCES collector_facilities(facility_id),
  display_name TEXT NOT NULL CHECK (char_length(display_name) BETWEEN 1 AND 120),
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  last_seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS vacon_edges_facility_idx
  ON vacon_edges (facility_id, display_name);

-- Credentials are encrypted with the server-only VACON_EDGE_CREDENTIAL_KEY.
-- A credential id lets an operator rotate an Edge credential with a short
-- overlap, without exposing it to a browser or storing it in plaintext.
CREATE TABLE IF NOT EXISTS vacon_edge_credentials (
  credential_id TEXT PRIMARY KEY CHECK (char_length(credential_id) BETWEEN 1 AND 128),
  edge_id TEXT NOT NULL REFERENCES vacon_edges(edge_id) ON DELETE CASCADE,
  credential_ciphertext TEXT NOT NULL CHECK (char_length(credential_ciphertext) BETWEEN 32 AND 4096),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  rotated_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS vacon_edge_credentials_lookup_idx
  ON vacon_edge_credentials (edge_id, credential_id);

-- A nonce is single-use within the signed request window. Expired nonces are
-- deleted transactionally before each insert by the backend repository.
CREATE TABLE IF NOT EXISTS vacon_edge_request_nonces (
  edge_id TEXT NOT NULL REFERENCES vacon_edges(edge_id) ON DELETE CASCADE,
  nonce TEXT NOT NULL CHECK (char_length(nonce) BETWEEN 16 AND 160),
  expires_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (edge_id, nonce)
);

CREATE INDEX IF NOT EXISTS vacon_edge_request_nonces_expiry_idx
  ON vacon_edge_request_nonces (expires_at);

CREATE TABLE IF NOT EXISTS vacon_edge_commands (
  command_id TEXT PRIMARY KEY CHECK (char_length(command_id) BETWEEN 1 AND 128),
  facility_id TEXT NOT NULL REFERENCES collector_facilities(facility_id),
  edge_id TEXT NOT NULL REFERENCES vacon_edges(edge_id),
  device_id TEXT NOT NULL REFERENCES vacon_devices(device_id),
  command_type TEXT NOT NULL CHECK (command_type IN ('TEST_CONNECTION')),
  state TEXT NOT NULL CHECK (state IN ('PENDING', 'DISPATCHED', 'SUCCEEDED', 'FAILED', 'EXPIRED')),
  requested_by_uid TEXT REFERENCES collector_users(firebase_uid),
  requested_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  completed_at TIMESTAMPTZ,
  result_code TEXT,
  result_detail TEXT
);

CREATE INDEX IF NOT EXISTS vacon_edge_commands_dispatch_idx
  ON vacon_edge_commands (edge_id, state, expires_at, requested_at);
