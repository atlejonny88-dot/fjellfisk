CREATE TABLE IF NOT EXISTS collector_sensor_batches (
  collector_id UUID NOT NULL REFERENCES collector_devices(collector_id),
  batch_id UUID NOT NULL,
  received_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (collector_id, batch_id)
);

CREATE INDEX IF NOT EXISTS collector_sensor_batches_retention_idx
  ON collector_sensor_batches (collector_id, received_at);

CREATE TABLE IF NOT EXISTS collector_sensors (
  collector_id UUID NOT NULL REFERENCES collector_devices(collector_id),
  sensor_id TEXT NOT NULL,
  sample_at TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL,
  reading JSONB NOT NULL,
  PRIMARY KEY (collector_id, sensor_id)
);

CREATE TABLE IF NOT EXISTS collector_sensor_mappings (
  collector_id UUID NOT NULL,
  sensor_id TEXT NOT NULL,
  site_id TEXT NOT NULL REFERENCES collector_facilities(facility_id),
  section_id TEXT NOT NULL,
  section_name TEXT NOT NULL,
  tank_id TEXT NOT NULL,
  tank_name TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (collector_id, sensor_id),
  FOREIGN KEY (collector_id, sensor_id) REFERENCES collector_sensors(collector_id, sensor_id),
  UNIQUE (site_id, section_id, tank_id)
);
