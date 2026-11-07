import assert from 'node:assert/strict';
import test from 'node:test';

import {PairingError} from '../src/pairing/errors.js';
import type {AuthorizedAdmin} from '../src/pairing/types.js';
import {encryptEdgeCredential, edgeBodyDigest, edgeRequestSignature} from '../src/vacon/edge_crypto.js';
import type {VaconEdgeRepository, VaconEdgeTransaction} from '../src/vacon/edge_repository.js';
import {VaconEdgeService} from '../src/vacon/edge_service.js';
import type {
  PersistedVaconTelemetry,
  VaconEdge,
  VaconEdgeCommand,
  VaconEdgeCredential,
} from '../src/vacon/edge_types.js';
import type {VaconAuditEvent, VaconDevice} from '../src/vacon/types.js';

const now = new Date('2026-11-07T10:00:00Z');
const key = Buffer.alloc(32, 7);
const credential = 'read-only-edge-credential';
const edge: VaconEdge = {
  edgeId: 'edge-01',
  facilityId: 'facility-01',
  displayName: 'Teknisk rom',
  enabled: true,
  lastSeenAt: null,
  createdAt: now,
  updatedAt: now,
};
const device: VaconDevice = {
  deviceId: 'device-01',
  facilityId: edge.facilityId,
  displayName: 'Sirkulasjonspumpe',
  manufacturer: 'Danfoss',
  model: 'VACON 100 FLOW',
  ipAddress: '192.168.30.50',
  subnetMask: '255.255.255.0',
  gateway: '192.168.30.1',
  dns: '192.168.30.1',
  modbusTcpPort: 502,
  modbusUnitId: 255,
  minFrequencyHz: 0,
  maxFrequencyHz: 50,
  edgeServerId: edge.edgeId,
  monitoringEnabled: true,
  createdAt: now,
  updatedAt: now,
};
const actor: AuthorizedAdmin = {
  uid: 'admin-01',
  organizationId: 'organization-01',
  allowedSiteIds: [edge.facilityId],
};

class InMemoryEdgeRepository implements VaconEdgeRepository, VaconEdgeTransaction {
  readonly edges = new Map([[edge.edgeId, {...edge}]]);
  readonly credentials = new Map<string, VaconEdgeCredential>([
    ['credential-01', {
      credentialId: 'credential-01',
      edgeId: edge.edgeId,
      credentialCiphertext: encryptEdgeCredential(credential, key),
      active: true,
      expiresAt: null,
      createdAt: now,
    }],
  ]);
  readonly nonces = new Set<string>();
  readonly devices = new Map([[device.deviceId, {...device}]]);
  readonly telemetry: PersistedVaconTelemetry[] = [];
  readonly commands = new Map<string, VaconEdgeCommand>();
  readonly audit: VaconAuditEvent[] = [];

  async transaction<T>(operation: (transaction: VaconEdgeTransaction) => Promise<T>): Promise<T> {
    return operation(this);
  }

  async getEdge(edgeId: string): Promise<VaconEdge | null> {
    return this.edges.get(edgeId) ?? null;
  }

  async getCredential(edgeId: string, credentialId: string): Promise<VaconEdgeCredential | null> {
    const value = this.credentials.get(credentialId);
    return value?.edgeId === edgeId && value.active ? value : null;
  }

  async useNonce(edgeId: string, nonce: string): Promise<boolean> {
    const value = `${edgeId}:${nonce}`;
    if (this.nonces.has(value)) return false;
    this.nonces.add(value);
    return true;
  }

  async updateLastSeen(edgeId: string, seenAt: Date): Promise<void> {
    const value = this.edges.get(edgeId);
    if (value) this.edges.set(edgeId, {...value, lastSeenAt: seenAt, updatedAt: seenAt});
  }

  async listDevicesForEdge(facilityId: string, edgeId: string): Promise<VaconDevice[]> {
    return [...this.devices.values()].filter((item) =>
      item.facilityId === facilityId && item.edgeServerId === edgeId && item.monitoringEnabled,
    );
  }

  async getFacilityDevice(deviceId: string, facilityId: string): Promise<VaconDevice | null> {
    const value = this.devices.get(deviceId);
    return value?.facilityId === facilityId ? value : null;
  }

  async getDeviceForEdge(deviceId: string, facilityId: string, edgeId: string): Promise<VaconDevice | null> {
    const value = await this.getFacilityDevice(deviceId, facilityId);
    return value?.edgeServerId === edgeId ? value : null;
  }

  async appendTelemetry(value: PersistedVaconTelemetry): Promise<void> {
    this.telemetry.push(value);
  }

  async createCommand(value: VaconEdgeCommand): Promise<void> {
    this.commands.set(value.commandId, value);
  }

  async takeCommands(edgeId: string, current: Date): Promise<VaconEdgeCommand[]> {
    const commands = [...this.commands.values()].filter((command) =>
      command.edgeId === edgeId && command.state === 'PENDING' && command.expiresAt > current,
    );
    for (const command of commands) {
      this.commands.set(command.commandId, {...command, state: 'DISPATCHED'});
    }
    return commands.map((command) => ({...command, state: 'DISPATCHED'}));
  }

  async getCommand(commandId: string): Promise<VaconEdgeCommand | null> {
    return this.commands.get(commandId) ?? null;
  }

  async completeCommand(
    commandId: string,
    state: 'SUCCEEDED' | 'FAILED',
    resultCode: string,
    completedAt: Date,
  ): Promise<void> {
    const command = this.commands.get(commandId);
    if (command) this.commands.set(commandId, {...command, state, resultCode, completedAt});
  }

  async appendEdgeAudit(event: VaconAuditEvent): Promise<void> {
    this.audit.push(event);
  }
}

function headers(method: string, pathname: string, body: Buffer, nonce: string) {
  const timestamp = `${now.getTime()}`;
  return {
    edgeId: edge.edgeId,
    credentialId: 'credential-01',
    timestamp,
    nonce,
    signature: edgeRequestSignature(credential, timestamp, method, pathname, edgeBodyDigest(body), nonce),
  };
}

test('Edge accepts a correctly signed request once and blocks an exact replay', async () => {
  const repository = new InMemoryEdgeRepository();
  const service = new VaconEdgeService(repository, key, () => now);
  const requestHeaders = headers('GET', '/edge/v1/config', Buffer.alloc(0), 'nonce-test-request-01');

  assert.equal((await service.authenticate(requestHeaders, 'GET', '/edge/v1/config', Buffer.alloc(0))).edgeId, edge.edgeId);
  assert.equal(repository.edges.get(edge.edgeId)?.lastSeenAt?.toISOString(), now.toISOString());
  await assert.rejects(
    service.authenticate(requestHeaders, 'GET', '/edge/v1/config', Buffer.alloc(0)),
    (error: unknown) => error instanceof PairingError && error.code === 'UNAUTHENTICATED',
  );
});

test('Edge persists signed read-only telemetry and records a failed read without invented values', async () => {
  const repository = new InMemoryEdgeRepository();
  const service = new VaconEdgeService(repository, key, () => now);
  const authenticated = await service.authenticate(
    headers('POST', '/edge/v1/telemetry', Buffer.alloc(0), 'nonce-telemetry-request-01'),
    'POST',
    '/edge/v1/telemetry',
    Buffer.alloc(0),
  );
  const result = await service.ingestTelemetry(authenticated, {
    readings: [{
      deviceId: device.deviceId,
      measuredAt: now.toISOString(),
      quality: 'LIVE',
      actualFrequencyHz: 13,
      referenceFrequencyHz: null,
      referenceFrequencyVerified: false,
      motorSpeedRpm: 1300,
      motorSpeedVerified: false,
      motorCurrentRaw: 388,
      motorCurrentA: null,
      motorCurrentVerified: false,
      ready: true,
      running: true,
      fault: false,
      alarm: false,
      atReference: false,
      activeFaultCode: null,
    }],
  });
  assert.equal(result.accepted, 1);
  assert.equal(repository.telemetry[0]?.actualFrequencyHz, 13);
  assert.equal(repository.telemetry[0]?.motorCurrentVerified, false);

  await service.ingestTelemetry(authenticated, {
    readings: [{
      deviceId: device.deviceId,
      measuredAt: now.toISOString(),
      quality: 'FAILED',
      actualFrequencyHz: null,
      referenceFrequencyHz: null,
      referenceFrequencyVerified: false,
      motorSpeedRpm: null,
      motorSpeedVerified: false,
      motorCurrentRaw: null,
      motorCurrentA: null,
      motorCurrentVerified: false,
      ready: null,
      running: null,
      fault: null,
      alarm: null,
      atReference: null,
      activeFaultCode: null,
    }],
  });
  assert.equal(repository.telemetry[1]?.quality, 'FAILED');
  assert.equal(repository.telemetry[1]?.actualFrequencyHz, null);
});

test('connection tests are dispatched only to the assigned Edge and never execute a backend Modbus action', async () => {
  const repository = new InMemoryEdgeRepository();
  const service = new VaconEdgeService(repository, key, () => now);
  const result = await service.requestConnectionTest(actor, edge.facilityId, device.deviceId);
  assert.equal(result.state, 'PENDING');
  assert.equal(result.reason, 'EDGE_TEST_REQUESTED');

  const commands = await service.takeCommands(edge);
  assert.equal(commands.length, 1);
  assert.equal(commands[0]?.commandType, 'TEST_CONNECTION');
  assert.equal(repository.commands.get(result.requestId)?.state, 'DISPATCHED');

  await service.completeCommand(edge, result.requestId, {succeeded: true, resultCode: 'ok'});
  assert.equal(repository.commands.get(result.requestId)?.state, 'SUCCEEDED');
  assert.equal(repository.audit.at(-1)?.eventType, 'VACON_CONNECTION_TEST_SUCCEEDED');
});
