import {PairingError} from './errors.js';

export interface SensorReading {
  sensorId: string;
  name: string;
  sourceType: 'Pacific' | 'DOM';
  temperatureC: number | null;
  oxygenMgL: number | null;
  oxygenSaturationPct: number | null;
  timestampUtc: string;
  health: 'ok' | 'degraded' | 'failed';
}

export interface SensorBatch {
  batchId: string;
  collectorVersion: string;
  readings: SensorReading[];
}

export interface SensorMapping {
  sensorId: string;
  sectionId: string;
  sectionName: string;
  tankId: string;
  tankName: string;
}

export interface SensorSnapshot {
  sensors: (SensorReading & {receivedAt: string})[];
  mappings: SensorMapping[];
}

function invalid(): never { throw new PairingError('INVALID_ARGUMENT', 400); }

function record(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return invalid();
  return value as Record<string, unknown>;
}

function text(value: unknown, maximum = 200): string {
  if (typeof value !== 'string' || !value.trim() || value.length > maximum || /[\u0000-\u001f]/u.test(value)) return invalid();
  return value;
}

function measurement(value: unknown, minimum: number, maximum: number): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < minimum || value > maximum) return invalid();
  return value;
}

export function validateSensorBatch(input: unknown, now: Date): SensorBatch {
  const value = record(input);
  const batchId = text(value.batchId, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(batchId)) return invalid();
  if (!Array.isArray(value.readings) || value.readings.length < 1 || value.readings.length > 128) return invalid();
  const ids = new Set<string>();
  const readings = value.readings.map((item): SensorReading => {
    const reading = record(item);
    const sensorId = text(reading.sensorId);
    if (ids.has(sensorId)) return invalid();
    ids.add(sensorId);
    if (reading.sourceType !== 'Pacific' && reading.sourceType !== 'DOM') return invalid();
    if (!['ok', 'degraded', 'failed'].includes(reading.health as string)) return invalid();
    const timestampUtc = text(reading.timestampUtc, 50);
    const timestamp = Date.parse(timestampUtc);
    // A bounded offline queue is accepted; future-dated readings cannot pin latest values.
    if (!Number.isFinite(timestamp) || timestamp > now.getTime() + 60_000 || timestamp < now.getTime() - 7 * 86400_000) return invalid();
    return {
      sensorId, name: text(reading.name), sourceType: reading.sourceType,
      temperatureC: measurement(reading.temperatureC, -50, 100),
      oxygenMgL: measurement(reading.oxygenMgL, 0, 100),
      oxygenSaturationPct: measurement(reading.oxygenSaturationPct, 0, 1000),
      timestampUtc: new Date(timestamp).toISOString(),
      health: reading.health as SensorReading['health'],
    };
  });
  return {batchId, collectorVersion: text(value.collectorVersion, 100), readings};
}

export function validateSensorMappings(input: unknown): SensorMapping[] {
  if (!Array.isArray(input) || input.length > 128) return invalid();
  const sensors = new Set<string>();
  const tanks = new Set<string>();
  return input.map((item) => {
    const value = record(item);
    const mapping = {
      sensorId: text(value.sensorId), sectionId: text(value.sectionId),
      sectionName: text(value.sectionName), tankId: text(value.tankId), tankName: text(value.tankName),
    };
    const tank = JSON.stringify([mapping.sectionId, mapping.tankId]);
    if (sensors.has(mapping.sensorId) || tanks.has(tank)) return invalid();
    sensors.add(mapping.sensorId);
    tanks.add(tank);
    return mapping;
  });
}
