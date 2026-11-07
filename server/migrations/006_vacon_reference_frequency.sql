-- A nullable reference is retained separately from actual frequency. The
-- current VACON 100 FLOW profile does not claim this value is verified until
-- a site's process-data mapping has been commissioned.
ALTER TABLE vacon_telemetry
  ADD COLUMN IF NOT EXISTS reference_frequency_hz NUMERIC(8, 3),
  ADD COLUMN IF NOT EXISTS reference_frequency_verified BOOLEAN NOT NULL DEFAULT FALSE;
