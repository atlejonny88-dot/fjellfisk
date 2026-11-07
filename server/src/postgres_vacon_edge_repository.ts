import {Pool, type PoolClient, type QueryResultRow} from 'pg';

import type {VaconDevice} from './vacon/types.js';
import type {
  VaconEdge,
  VaconEdgeCommand,
  VaconEdgeCredential,
  PersistedVaconTelemetry,
} from './vacon/edge_types.js';
import type {
  VaconEdgeProvisioningRepository,
  VaconEdgeProvisioningTransaction,
  VaconEdgeRepository,
  VaconEdgeTransaction,
} from './vacon/edge_repository.js';

interface EdgeRow extends QueryResultRow {
  edge_id: string;
  facility_id: string;
  display_name: string;
  enabled: boolean;
  last_seen_at: Date | null;
  created_at: Date;
  updated_at: Date;
}

interface CredentialRow extends QueryResultRow {
  credential_id: string;
  edge_id: string;
  credential_ciphertext: string;
  active: boolean;
  expires_at: Date | null;
  created_at: Date;
}

interface CommandRow extends QueryResultRow {
  command_id: string;
  facility_id: string;
  edge_id: string;
  device_id: string;
  command_type: 'TEST_CONNECTION';
  state: VaconEdgeCommand['state'];
  requested_by_uid: string | null;
  requested_at: Date;
  expires_at: Date;
  completed_at: Date | null;
  result_code: string | null;
}

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

function asEdge(row: EdgeRow): VaconEdge {
  return {
    edgeId: row.edge_id,
    facilityId: row.facility_id,
    displayName: row.display_name,
    enabled: row.enabled,
    lastSeenAt: row.last_seen_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function asCredential(row: CredentialRow): VaconEdgeCredential {
  return {
    credentialId: row.credential_id,
    edgeId: row.edge_id,
    credentialCiphertext: row.credential_ciphertext,
    active: row.active,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
  };
}

function asCommand(row: CommandRow): VaconEdgeCommand {
  return {
    commandId: row.command_id,
    facilityId: row.facility_id,
    edgeId: row.edge_id,
    deviceId: row.device_id,
    commandType: row.command_type,
    state: row.state,
    requestedByUid: row.requested_by_uid,
    requestedAt: row.requested_at,
    expiresAt: row.expires_at,
    completedAt: row.completed_at,
    resultCode: row.result_code,
  };
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

class PostgresVaconEdgeTransaction implements VaconEdgeTransaction, VaconEdgeProvisioningTransaction {
  constructor(private readonly client: PoolClient) {}

  async getEdge(edgeId: string): Promise<VaconEdge | null> {
    const result = await this.client.query<EdgeRow>('SELECT * FROM vacon_edges WHERE edge_id = $1 FOR UPDATE', [edgeId]);
    return result.rows[0] ? asEdge(result.rows[0]) : null;
  }

  async getCredential(edgeId: string, credentialId: string): Promise<VaconEdgeCredential | null> {
    const result = await this.client.query<CredentialRow>(
      `SELECT * FROM vacon_edge_credentials
       WHERE edge_id = $1 AND credential_id = $2
         AND active = TRUE AND (expires_at IS NULL OR expires_at > NOW())`,
      [edgeId, credentialId],
    );
    return result.rows[0] ? asCredential(result.rows[0]) : null;
  }

  async useNonce(edgeId: string, nonce: string, expiresAt: Date, now: Date): Promise<boolean> {
    await this.client.query('DELETE FROM vacon_edge_request_nonces WHERE expires_at <= $1', [now]);
    const result = await this.client.query(
      `INSERT INTO vacon_edge_request_nonces (edge_id, nonce, expires_at)
       VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
      [edgeId, nonce, expiresAt],
    );
    return result.rowCount === 1;
  }

  async updateLastSeen(edgeId: string, now: Date): Promise<void> {
    await this.client.query('UPDATE vacon_edges SET last_seen_at = $2, updated_at = $2 WHERE edge_id = $1', [edgeId, now]);
  }

  async listDevicesForEdge(facilityId: string, edgeId: string): Promise<VaconDevice[]> {
    const result = await this.client.query<DeviceRow>(
      `SELECT * FROM vacon_devices
       WHERE facility_id = $1 AND edge_server_id = $2 AND monitoring_enabled = TRUE
       ORDER BY display_name, device_id`,
      [facilityId, edgeId],
    );
    return result.rows.map(asDevice);
  }

  async getFacilityDevice(deviceId: string, facilityId: string): Promise<VaconDevice | null> {
    const result = await this.client.query<DeviceRow>(
      'SELECT * FROM vacon_devices WHERE device_id = $1 AND facility_id = $2',
      [deviceId, facilityId],
    );
    return result.rows[0] ? asDevice(result.rows[0]) : null;
  }

  async getDeviceForEdge(deviceId: string, facilityId: string, edgeId: string): Promise<VaconDevice | null> {
    const result = await this.client.query<DeviceRow>(
      'SELECT * FROM vacon_devices WHERE device_id = $1 AND facility_id = $2 AND edge_server_id = $3',
      [deviceId, facilityId, edgeId],
    );
    return result.rows[0] ? asDevice(result.rows[0]) : null;
  }

  async appendTelemetry(telemetry: PersistedVaconTelemetry): Promise<void> {
    await this.client.query(
      `INSERT INTO vacon_telemetry (
        device_id, measured_at, quality, actual_frequency_hz, reference_frequency_hz,
        reference_frequency_verified, motor_speed_rpm, motor_speed_verified,
        motor_current_raw, motor_current_a, motor_current_verified, ready, running,
        fault, alarm, at_reference, active_fault_code
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
      [
        telemetry.deviceId, telemetry.measuredAt, telemetry.quality,
        telemetry.actualFrequencyHz, telemetry.referenceFrequencyHz,
        telemetry.referenceFrequencyVerified, telemetry.motorSpeedRpm,
        telemetry.motorSpeedVerified, telemetry.motorCurrentRaw,
        telemetry.motorCurrentA, telemetry.motorCurrentVerified, telemetry.ready,
        telemetry.running, telemetry.fault, telemetry.alarm, telemetry.atReference,
        telemetry.activeFaultCode,
      ],
    );
  }

  async createCommand(command: VaconEdgeCommand): Promise<void> {
    await this.client.query(
      `INSERT INTO vacon_edge_commands (
        command_id, facility_id, edge_id, device_id, command_type, state,
        requested_by_uid, requested_at, expires_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [
        command.commandId, command.facilityId, command.edgeId, command.deviceId,
        command.commandType, command.state, command.requestedByUid,
        command.requestedAt, command.expiresAt,
      ],
    );
  }

  async takeCommands(edgeId: string, now: Date, limit: number): Promise<VaconEdgeCommand[]> {
    await this.client.query(
      `UPDATE vacon_edge_commands SET state = 'EXPIRED'
       WHERE edge_id = $1 AND state IN ('PENDING', 'DISPATCHED') AND expires_at <= $2`,
      [edgeId, now],
    );
    const result = await this.client.query<CommandRow>(
      `WITH selected AS (
        SELECT command_id FROM vacon_edge_commands
        WHERE edge_id = $1 AND state = 'PENDING' AND expires_at > $2
        ORDER BY requested_at FOR UPDATE SKIP LOCKED LIMIT $3
      )
      UPDATE vacon_edge_commands commands
      SET state = 'DISPATCHED'
      FROM selected
      WHERE commands.command_id = selected.command_id
      RETURNING commands.*`,
      [edgeId, now, limit],
    );
    return result.rows.map(asCommand);
  }

  async getCommand(commandId: string): Promise<VaconEdgeCommand | null> {
    const result = await this.client.query<CommandRow>('SELECT * FROM vacon_edge_commands WHERE command_id = $1 FOR UPDATE', [commandId]);
    return result.rows[0] ? asCommand(result.rows[0]) : null;
  }

  async completeCommand(commandId: string, state: 'SUCCEEDED' | 'FAILED', resultCode: string, now: Date): Promise<void> {
    await this.client.query(
      `UPDATE vacon_edge_commands SET state = $2, result_code = $3, completed_at = $4
       WHERE command_id = $1`,
      [commandId, state, resultCode, now],
    );
  }

  async facilityExists(facilityId: string): Promise<boolean> {
    const result = await this.client.query('SELECT 1 FROM collector_facilities WHERE facility_id = $1', [facilityId]);
    return result.rowCount === 1;
  }

  async insertEdge(edge: VaconEdge): Promise<void> {
    await this.client.query(
      `INSERT INTO vacon_edges (edge_id, facility_id, display_name, enabled, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6)`,
      [edge.edgeId, edge.facilityId, edge.displayName, edge.enabled, edge.createdAt, edge.updatedAt],
    );
  }

  async insertCredential(credential: VaconEdgeCredential): Promise<void> {
    await this.client.query(
      `INSERT INTO vacon_edge_credentials (
        credential_id, edge_id, credential_ciphertext, active, expires_at, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6)`,
      [
        credential.credentialId, credential.edgeId, credential.credentialCiphertext,
        credential.active, credential.expiresAt, credential.createdAt,
      ],
    );
  }

  async deactivateCredentials(edgeId: string, expiresAt: Date): Promise<void> {
    await this.client.query(
      `UPDATE vacon_edge_credentials SET expires_at = $2
       WHERE edge_id = $1 AND active = TRUE AND (expires_at IS NULL OR expires_at > $2)`,
      [edgeId, expiresAt],
    );
  }

  async appendEdgeAudit(event: {
    facilityId: string; deviceId: string | null; actorUid: string | null;
    eventType: string; changedFields: readonly string[]; createdAt: Date;
  }): Promise<void> {
    await this.client.query(
      `INSERT INTO vacon_audit_events (
        facility_id, device_id, actor_uid, event_type, changed_fields, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6)`,
      [event.facilityId, event.deviceId, event.actorUid, event.eventType, JSON.stringify(event.changedFields), event.createdAt],
    );
  }
}

export class PostgresVaconEdgeRepository implements VaconEdgeRepository, VaconEdgeProvisioningRepository {
  constructor(private readonly pool: Pool) {}

  async transaction<T>(operation: (transaction: PostgresVaconEdgeTransaction) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const result = await operation(new PostgresVaconEdgeTransaction(client));
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
