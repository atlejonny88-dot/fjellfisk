import {Pool, type PoolClient, type QueryResultRow} from 'pg';

import type {VaconRepository, VaconTransaction} from './vacon/repository.js';
import type {VaconAuditEvent, VaconDevice, VaconTelemetry, VaconTelemetryQuality} from './vacon/types.js';

interface DeviceRow extends QueryResultRow {
  device_id: string;
  facility_id: string;
  display_name: string;
  manufacturer: string;
  model: string;
  ip_address: string;
  subnet_mask: string;
  gateway: string;
  dns: string;
  modbus_tcp_port: number;
  modbus_unit_id: number;
  min_frequency_hz: string | number;
  max_frequency_hz: string | number;
  edge_server_id: string;
  monitoring_enabled: boolean;
  created_at: Date;
  updated_at: Date;
}

interface TelemetryRow extends QueryResultRow {
  device_id: string;
  measured_at: Date;
  received_at: Date;
  quality: VaconTelemetryQuality;
  actual_frequency_hz: string | number | null;
  motor_speed_rpm: number | null;
  motor_speed_verified: boolean;
  motor_current_raw: number | null;
  motor_current_a: string | number | null;
  motor_current_verified: boolean;
  ready: boolean | null;
  running: boolean | null;
  fault: boolean | null;
  alarm: boolean | null;
  at_reference: boolean | null;
  active_fault_code: string | null;
}

function numberOrNull(value: string | number | null): number | null {
  return value === null ? null : Number(value);
}

function asDevice(row: DeviceRow): VaconDevice {
  return {
    deviceId: row.device_id,
    facilityId: row.facility_id,
    displayName: row.display_name,
    manufacturer: row.manufacturer,
    model: row.model,
    ipAddress: row.ip_address,
    subnetMask: row.subnet_mask,
    gateway: row.gateway,
    dns: row.dns,
    modbusTcpPort: row.modbus_tcp_port,
    modbusUnitId: row.modbus_unit_id,
    minFrequencyHz: Number(row.min_frequency_hz),
    maxFrequencyHz: Number(row.max_frequency_hz),
    edgeServerId: row.edge_server_id,
    monitoringEnabled: row.monitoring_enabled,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function asTelemetry(row: TelemetryRow): VaconTelemetry {
  return {
    deviceId: row.device_id,
    measuredAt: row.measured_at,
    receivedAt: row.received_at,
    quality: row.quality,
    actualFrequencyHz: numberOrNull(row.actual_frequency_hz),
    motorSpeedRpm: row.motor_speed_rpm,
    motorSpeedVerified: row.motor_speed_verified,
    motorCurrentRaw: row.motor_current_raw,
    motorCurrentA: numberOrNull(row.motor_current_a),
    motorCurrentVerified: row.motor_current_verified,
    ready: row.ready,
    running: row.running,
    fault: row.fault,
    alarm: row.alarm,
    atReference: row.at_reference,
    activeFaultCode: row.active_fault_code,
  };
}

class PostgresVaconTransaction implements VaconTransaction {
  constructor(private readonly client: PoolClient) {}

  async listDevices(facilityId: string): Promise<VaconDevice[]> {
    const result = await this.client.query<DeviceRow>(
      'SELECT * FROM vacon_devices WHERE facility_id = $1 ORDER BY display_name, device_id',
      [facilityId],
    );
    return result.rows.map(asDevice);
  }

  async getDevice(deviceId: string): Promise<VaconDevice | null> {
    const result = await this.client.query<DeviceRow>(
      'SELECT * FROM vacon_devices WHERE device_id = $1 FOR UPDATE',
      [deviceId],
    );
    return result.rows[0] ? asDevice(result.rows[0]) : null;
  }

  async insertDevice(device: VaconDevice): Promise<void> {
    await this.client.query(
      `INSERT INTO vacon_devices (
        device_id, facility_id, display_name, manufacturer, model, ip_address,
        subnet_mask, gateway, dns, modbus_tcp_port, modbus_unit_id,
        min_frequency_hz, max_frequency_hz, edge_server_id, monitoring_enabled,
        created_at, updated_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
      [
        device.deviceId, device.facilityId, device.displayName, device.manufacturer,
        device.model, device.ipAddress, device.subnetMask, device.gateway,
        device.dns, device.modbusTcpPort, device.modbusUnitId,
        device.minFrequencyHz, device.maxFrequencyHz, device.edgeServerId,
        device.monitoringEnabled, device.createdAt, device.updatedAt,
      ],
    );
  }

  async updateDevice(device: VaconDevice): Promise<void> {
    await this.client.query(
      `UPDATE vacon_devices SET
        display_name = $2, manufacturer = $3, model = $4, ip_address = $5,
        subnet_mask = $6, gateway = $7, dns = $8, modbus_tcp_port = $9,
        modbus_unit_id = $10, min_frequency_hz = $11, max_frequency_hz = $12,
        edge_server_id = $13, monitoring_enabled = $14, updated_at = $15
       WHERE device_id = $1`,
      [
        device.deviceId, device.displayName, device.manufacturer, device.model,
        device.ipAddress, device.subnetMask, device.gateway, device.dns,
        device.modbusTcpPort, device.modbusUnitId, device.minFrequencyHz,
        device.maxFrequencyHz, device.edgeServerId, device.monitoringEnabled,
        device.updatedAt,
      ],
    );
  }

  async latestTelemetry(deviceId: string): Promise<VaconTelemetry | null> {
    const result = await this.client.query<TelemetryRow>(
      'SELECT * FROM vacon_telemetry WHERE device_id = $1 ORDER BY measured_at DESC, telemetry_id DESC LIMIT 1',
      [deviceId],
    );
    return result.rows[0] ? asTelemetry(result.rows[0]) : null;
  }

  async listTelemetry(deviceId: string, limit: number): Promise<VaconTelemetry[]> {
    const result = await this.client.query<TelemetryRow>(
      `SELECT * FROM vacon_telemetry WHERE device_id = $1
       ORDER BY measured_at DESC, telemetry_id DESC LIMIT $2`,
      [deviceId, limit],
    );
    return result.rows.map(asTelemetry);
  }

  async appendAudit(event: VaconAuditEvent): Promise<void> {
    await this.client.query(
      `INSERT INTO vacon_audit_events (
        facility_id, device_id, actor_uid, event_type, changed_fields, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6)`,
      [
        event.facilityId, event.deviceId, event.actorUid, event.eventType,
        JSON.stringify(event.changedFields), event.createdAt,
      ],
    );
  }
}

export class PostgresVaconRepository implements VaconRepository {
  constructor(private readonly pool: Pool) {}

  async transaction<T>(operation: (transaction: VaconTransaction) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await operation(new PostgresVaconTransaction(client));
      await client.query('COMMIT');
      return result;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
