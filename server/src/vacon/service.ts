import {randomUUID} from 'node:crypto';

import {PairingError} from '../pairing/errors.js';
import type {AuthorizedAdmin} from '../pairing/types.js';
import type {VaconRepository} from './repository.js';
import type {
  VaconConnectionState,
  VaconConnectionTestResult,
  VaconDevice,
  VaconDeviceSnapshot,
  VaconTelemetry,
} from './types.js';
import {requireVaconDeviceId, validateVaconDeviceConfiguration} from './validation.js';

const staleAfterMs = 30_000;
const historyLimit = 500;

function requireFacilityId(value: unknown): string {
  const facilityId = typeof value === 'string' ? value.trim() : '';
  if (!facilityId || facilityId.length > 200) throw new PairingError('INVALID_ARGUMENT', 400);
  return facilityId;
}

function connectionFor(device: VaconDevice, telemetry: VaconTelemetry | null, now: Date): VaconConnectionState {
  if (!device.monitoringEnabled) return 'DISABLED';
  if (!telemetry || telemetry.quality === 'UNAVAILABLE' || telemetry.quality === 'FAILED') return 'OFFLINE';
  if (telemetry.quality === 'STALE') return 'STALE';
  return now.getTime() - telemetry.receivedAt.getTime() <= staleAfterMs ? 'ONLINE' : 'STALE';
}

export class VaconService {
  constructor(
    private readonly repository: VaconRepository,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async listDevices(actor: AuthorizedAdmin, facilityIdInput: unknown): Promise<VaconDeviceSnapshot[]> {
    const facilityId = this.authorize(actor, facilityIdInput);
    const now = this.now();
    return this.repository.transaction(async (transaction) => Promise.all(
      (await transaction.listDevices(facilityId)).map(async (device) => {
        const telemetry = await transaction.latestTelemetry(device.deviceId);
        return {...device, telemetry, connection: connectionFor(device, telemetry, now)};
      }),
    ));
  }

  async createDevice(actor: AuthorizedAdmin, facilityIdInput: unknown, input: unknown): Promise<VaconDeviceSnapshot> {
    const facilityId = this.authorize(actor, facilityIdInput);
    const configuration = validateVaconDeviceConfiguration(input);
    const now = this.now();
    const device: VaconDevice = {
      deviceId: randomUUID(),
      facilityId,
      ...configuration,
      createdAt: now,
      updatedAt: now,
    };
    return this.repository.transaction(async (transaction) => {
      await transaction.insertDevice(device);
      await transaction.appendAudit({
        facilityId,
        deviceId: device.deviceId,
        actorUid: actor.uid,
        eventType: 'VACON_DEVICE_CREATED',
        changedFields: ['configuration'],
        createdAt: now,
      });
      return {...device, telemetry: null, connection: connectionFor(device, null, now)};
    });
  }

  async updateDevice(
    actor: AuthorizedAdmin,
    facilityIdInput: unknown,
    deviceIdInput: unknown,
    input: unknown,
  ): Promise<VaconDeviceSnapshot> {
    const facilityId = this.authorize(actor, facilityIdInput);
    const deviceId = requireVaconDeviceId(deviceIdInput);
    const configuration = validateVaconDeviceConfiguration(input);
    const now = this.now();
    return this.repository.transaction(async (transaction) => {
      const existing = await transaction.getDevice(deviceId);
      if (!existing || existing.facilityId !== facilityId) throw new PairingError('VACON_DEVICE_NOT_FOUND', 404);
      const updated: VaconDevice = {...existing, ...configuration, updatedAt: now};
      await transaction.updateDevice(updated);
      await transaction.appendAudit({
        facilityId,
        deviceId,
        actorUid: actor.uid,
        eventType: 'VACON_DEVICE_UPDATED',
        changedFields: Object.keys(configuration),
        createdAt: now,
      });
      const telemetry = await transaction.latestTelemetry(deviceId);
      return {...updated, telemetry, connection: connectionFor(updated, telemetry, now)};
    });
  }

  async telemetryHistory(
    actor: AuthorizedAdmin,
    facilityIdInput: unknown,
    deviceIdInput: unknown,
  ): Promise<readonly VaconTelemetry[]> {
    const facilityId = this.authorize(actor, facilityIdInput);
    const deviceId = requireVaconDeviceId(deviceIdInput);
    return this.repository.transaction(async (transaction) => {
      const device = await transaction.getDevice(deviceId);
      if (!device || device.facilityId !== facilityId) throw new PairingError('VACON_DEVICE_NOT_FOUND', 404);
      return transaction.listTelemetry(deviceId, historyLimit);
    });
  }

  async testConnection(
    actor: AuthorizedAdmin,
    facilityIdInput: unknown,
    deviceIdInput: unknown,
  ): Promise<VaconConnectionTestResult> {
    const facilityId = this.authorize(actor, facilityIdInput);
    const deviceId = requireVaconDeviceId(deviceIdInput);
    const now = this.now();
    return this.repository.transaction(async (transaction) => {
      const device = await transaction.getDevice(deviceId);
      if (!device || device.facilityId !== facilityId) throw new PairingError('VACON_DEVICE_NOT_FOUND', 404);
      // An Edge protocol adapter is deliberately absent from this release. This
      // explicit result prevents the server from ever probing a drive directly.
      await transaction.appendAudit({
        facilityId,
        deviceId,
        actorUid: actor.uid,
        eventType: 'VACON_CONNECTION_TEST_REQUESTED',
        changedFields: [],
        createdAt: now,
      });
      return {deviceId, state: 'UNAVAILABLE', reason: 'EDGE_TRANSPORT_NOT_CONFIGURED', testedAt: now};
    });
  }

  private authorize(actor: AuthorizedAdmin, facilityIdInput: unknown): string {
    const facilityId = requireFacilityId(facilityIdInput);
    if (!actor.allowedSiteIds.includes(facilityId)) throw new PairingError('FORBIDDEN', 403);
    return facilityId;
  }
}
