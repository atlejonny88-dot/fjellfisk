import assert from 'node:assert/strict';
import test from 'node:test';

import {PairingError} from '../src/pairing/errors.js';
import type {AuthorizedAdmin} from '../src/pairing/types.js';
import type {VaconRepository, VaconTransaction} from '../src/vacon/repository.js';
import {VaconService} from '../src/vacon/service.js';
import type {VaconAuditEvent, VaconDevice, VaconTelemetry} from '../src/vacon/types.js';

const actor: AuthorizedAdmin = {
  uid: 'admin-1',
  organizationId: 'organization-1',
  allowedSiteIds: ['facility-1'],
};

const configuration = {
  displayName: 'Sirkulasjonspumpe 1',
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
  edgeServerId: 'edge-oxygen-01',
  monitoringEnabled: true,
};

class InMemoryVaconRepository implements VaconRepository, VaconTransaction {
  readonly devices = new Map<string, VaconDevice>();
  readonly telemetry = new Map<string, VaconTelemetry[]>();
  readonly audit: VaconAuditEvent[] = [];

  async transaction<T>(operation: (transaction: VaconTransaction) => Promise<T>): Promise<T> {
    return operation(this);
  }

  async listDevices(facilityId: string): Promise<VaconDevice[]> {
    return [...this.devices.values()].filter((device) => device.facilityId === facilityId);
  }

  async getDevice(deviceId: string): Promise<VaconDevice | null> {
    return this.devices.get(deviceId) ?? null;
  }

  async insertDevice(device: VaconDevice): Promise<void> {
    this.devices.set(device.deviceId, device);
  }

  async updateDevice(device: VaconDevice): Promise<void> {
    this.devices.set(device.deviceId, device);
  }

  async listTelemetry(deviceId: string, limit: number): Promise<VaconTelemetry[]> {
    return (this.telemetry.get(deviceId) ?? []).slice(0, limit);
  }

  async latestTelemetry(deviceId: string): Promise<VaconTelemetry | null> {
    return (this.telemetry.get(deviceId) ?? [])[0] ?? null;
  }

  async appendAudit(event: VaconAuditEvent): Promise<void> {
    this.audit.push(event);
  }
}

test('VACON configuration is facility-bound, validated and audits field names only', async () => {
  const repository = new InMemoryVaconRepository();
  const now = new Date('2026-11-07T08:00:00Z');
  const service = new VaconService(repository, () => now);

  const created = await service.createDevice(actor, 'facility-1', configuration);
  assert.equal(created.facilityId, 'facility-1');
  assert.equal(created.connection, 'OFFLINE');
  assert.equal(repository.audit[0]?.eventType, 'VACON_DEVICE_CREATED');
  assert.deepEqual(repository.audit[0]?.changedFields, ['configuration']);
  await assert.rejects(
    service.createDevice(actor, 'facility-2', configuration),
    (error: unknown) => error instanceof PairingError && error.code === 'FORBIDDEN',
  );
  await assert.rejects(
    service.createDevice(actor, 'facility-1', {...configuration, maxFrequencyHz: 0}),
    (error: unknown) => error instanceof PairingError && error.code === 'INVALID_ARGUMENT',
  );
  await assert.rejects(
    service.createDevice(actor, 'facility-1', {...configuration, ipAddress: '192.168.30.999'}),
    (error: unknown) => error instanceof PairingError && error.code === 'INVALID_ARGUMENT',
  );
});

test('VACON configuration updates keep the stable ID and existing telemetry', async () => {
  const repository = new InMemoryVaconRepository();
  const now = new Date('2026-11-07T08:00:00Z');
  const service = new VaconService(repository, () => now);
  const created = await service.createDevice(actor, 'facility-1', configuration);
  const telemetry: VaconTelemetry = {
    deviceId: created.deviceId,
    measuredAt: now,
    receivedAt: now,
    quality: 'LIVE',
    actualFrequencyHz: 13,
        referenceFrequencyHz: null,
        referenceFrequencyVerified: false,
    motorSpeedRpm: 1300,
    motorSpeedVerified: true,
    motorCurrentRaw: 17,
    motorCurrentA: null,
    motorCurrentVerified: false,
    ready: true,
    running: true,
    fault: false,
    alarm: false,
    atReference: true,
    activeFaultCode: null,
  };
  repository.telemetry.set(created.deviceId, [telemetry]);

  const updated = await service.updateDevice(actor, 'facility-1', created.deviceId, {
    ...configuration,
    displayName: 'Sirkulasjonspumpe 1 - oppdatert',
    monitoringEnabled: false,
  });

  assert.equal(updated.deviceId, created.deviceId);
  assert.equal(updated.displayName, 'Sirkulasjonspumpe 1 - oppdatert');
  assert.equal(updated.connection, 'DISABLED');
  assert.equal((await service.telemetryHistory(actor, 'facility-1', created.deviceId))[0]?.actualFrequencyHz, 13);
  assert.deepEqual(repository.audit.at(-1)?.changedFields, Object.keys({
    ...configuration,
    displayName: 'Sirkulasjonspumpe 1 - oppdatert',
    monitoringEnabled: false,
  }));
});

test('VACON stale and failed telemetry never claims an online live connection', async () => {
  const repository = new InMemoryVaconRepository();
  const now = new Date('2026-11-07T08:00:00Z');
  const service = new VaconService(repository, () => now);
  const created = await service.createDevice(actor, 'facility-1', configuration);
  repository.telemetry.set(created.deviceId, [{
    deviceId: created.deviceId,
    measuredAt: now,
    receivedAt: now,
    quality: 'STALE',
    actualFrequencyHz: 13,
      referenceFrequencyHz: null,
      referenceFrequencyVerified: false,
    motorSpeedRpm: 1300,
    motorSpeedVerified: false,
    motorCurrentRaw: 0,
    motorCurrentA: null,
    motorCurrentVerified: false,
    ready: true,
    running: true,
    fault: false,
    alarm: false,
    atReference: true,
    activeFaultCode: null,
  }]);
  assert.equal((await service.listDevices(actor, 'facility-1'))[0]?.connection, 'STALE');
  repository.telemetry.get(created.deviceId)![0] = {
    ...repository.telemetry.get(created.deviceId)![0]!, quality: 'FAILED',
  };
  assert.equal((await service.listDevices(actor, 'facility-1'))[0]?.connection, 'OFFLINE');
});

test('VACON connection testing is an audited Edge request and never probes Modbus from the backend', async () => {
  const repository = new InMemoryVaconRepository();
  const service = new VaconService(repository, () => new Date('2026-11-07T08:00:00Z'));
  const created = await service.createDevice(actor, 'facility-1', configuration);

  const result = await service.testConnection(actor, 'facility-1', created.deviceId);
  assert.deepEqual(result.state, 'UNAVAILABLE');
  assert.equal(result.reason, 'EDGE_TRANSPORT_NOT_CONFIGURED');
  assert.equal(repository.audit.at(-1)?.eventType, 'VACON_CONNECTION_TEST_REQUESTED');
});
