import {randomUUID} from 'node:crypto';

import {PairingError} from '../pairing/errors.js';
import type {AuthorizedAdmin} from '../pairing/types.js';
import {
  decryptEdgeCredential,
  edgeBodyDigest,
  edgeRequestSignature,
  safeSignatureEquals,
} from './edge_crypto.js';
import type {VaconEdgeRepository} from './edge_repository.js';
import type {
  PersistedVaconTelemetry,
  VaconEdge,
  VaconEdgeCommand,
  VaconEdgeConfiguration,
  VaconTelemetryInput,
} from './edge_types.js';
import type {VaconDevice, VaconTelemetryQuality} from './types.js';
import {requireVaconDeviceId} from './validation.js';

const maxClockSkewMs = 5 * 60_000;
const commandLifetimeMs = 2 * 60_000;
const maxTelemetryPerRequest = 50;
const maxCommandBatch = 20;
const supportedQualities = new Set<VaconTelemetryQuality>(['LIVE', 'STALE', 'FAILED', 'UNAVAILABLE']);
const safeResultCodes = new Set([
  'ok', 'timeout', 'com-error', 'modbus-error', 'invalid-read', 'read-error',
  'unsupported-model-profile', 'device-not-configured',
]);

export interface EdgeRequestHeaders {
  edgeId: string | undefined;
  credentialId: string | undefined;
  timestamp: string | undefined;
  nonce: string | undefined;
  signature: string | undefined;
}

export interface EdgeCommandResult {
  commandId: string;
  succeeded: boolean;
  resultCode: string;
}

function requireText(value: unknown, maxLength: number): string {
  const text = typeof value === 'string' ? value.trim() : '';
  if (!text || text.length > maxLength) throw new PairingError('INVALID_ARGUMENT', 400);
  return text;
}

function optionalText(value: unknown, maxLength: number): string | null {
  if (value === null || value === undefined) return null;
  return requireText(value, maxLength);
}

function optionalFiniteNumber(value: unknown, min: number, max: number): number | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) {
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
  return value;
}

function optionalInteger(value: unknown, min: number, max: number): number | null {
  const number = optionalFiniteNumber(value, min, max);
  if (number !== null && !Number.isInteger(number)) throw new PairingError('INVALID_ARGUMENT', 400);
  return number;
}

function optionalBoolean(value: unknown): boolean | null {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'boolean') throw new PairingError('INVALID_ARGUMENT', 400);
  return value;
}

function parseMeasuredAt(value: unknown, now: Date): Date {
  const parsed = typeof value === 'string' ? new Date(value) : null;
  if (!parsed || Number.isNaN(parsed.getTime()) || parsed.getTime() > now.getTime() + maxClockSkewMs ||
      parsed.getTime() < now.getTime() - 24 * 60 * 60_000) {
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
  return parsed;
}

function parseTelemetry(value: unknown, now: Date): VaconTelemetryInput {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new PairingError('INVALID_ARGUMENT', 400);
  const input = value as Record<string, unknown>;
  const quality = requireText(input.quality, 16) as VaconTelemetryQuality;
  if (!supportedQualities.has(quality)) throw new PairingError('INVALID_ARGUMENT', 400);
  const telemetry: VaconTelemetryInput = {
    deviceId: requireVaconDeviceId(input.deviceId),
    measuredAt: parseMeasuredAt(input.measuredAt, now),
    quality,
    actualFrequencyHz: optionalFiniteNumber(input.actualFrequencyHz, 0, 1_000),
    referenceFrequencyHz: optionalFiniteNumber(input.referenceFrequencyHz, 0, 1_000),
    referenceFrequencyVerified: input.referenceFrequencyVerified === true,
    motorSpeedRpm: optionalFiniteNumber(input.motorSpeedRpm, 0, 100_000),
    motorSpeedVerified: input.motorSpeedVerified === true,
    motorCurrentRaw: optionalInteger(input.motorCurrentRaw, 0, 65_535),
    motorCurrentA: optionalFiniteNumber(input.motorCurrentA, 0, 100_000),
    motorCurrentVerified: input.motorCurrentVerified === true,
    ready: optionalBoolean(input.ready),
    running: optionalBoolean(input.running),
    fault: optionalBoolean(input.fault),
    alarm: optionalBoolean(input.alarm),
    atReference: optionalBoolean(input.atReference),
    activeFaultCode: optionalText(input.activeFaultCode, 120),
  };
  if (quality !== 'LIVE' && telemetry.actualFrequencyHz !== null) throw new PairingError('INVALID_ARGUMENT', 400);
  if (telemetry.referenceFrequencyVerified && telemetry.referenceFrequencyHz === null) {
    throw new PairingError('INVALID_ARGUMENT', 400);
  }
  if (telemetry.motorCurrentVerified && telemetry.motorCurrentA === null) throw new PairingError('INVALID_ARGUMENT', 400);
  return telemetry;
}

function asPersistedTelemetry(input: VaconTelemetryInput, receivedAt: Date): PersistedVaconTelemetry {
  return {...input, receivedAt};
}

function requireFacility(actor: AuthorizedAdmin, input: unknown): string {
  const facilityId = requireText(input, 200);
  if (!actor.allowedSiteIds.includes(facilityId)) throw new PairingError('FORBIDDEN', 403);
  return facilityId;
}

/**
 * Authentication and ingest boundary for a facility-local, read-only Edge.
 * The Edge is always the network client: the backend never dials a drive.
 */
export class VaconEdgeService {
  constructor(
    private readonly repository: VaconEdgeRepository,
    private readonly credentialEncryptionKey: Buffer | null,
    private readonly now: () => Date = () => new Date(),
  ) {}

  isConfigured(): boolean {
    return this.credentialEncryptionKey !== null;
  }

  async authenticate(
    headers: EdgeRequestHeaders,
    method: string,
    pathname: string,
    body: Buffer,
  ): Promise<VaconEdge> {
    const key = this.credentialEncryptionKey;
    if (!key) throw new PairingError('VACON_EDGE_NOT_CONFIGURED', 503);
    const edgeId = requireText(headers.edgeId, 128);
    const credentialId = requireText(headers.credentialId, 128);
    const timestamp = requireText(headers.timestamp, 32);
    const nonce = requireText(headers.nonce, 160);
    const signature = requireText(headers.signature, 256);
    if (!/^[A-Za-z0-9_-]{16,160}$/.test(nonce)) throw new PairingError('UNAUTHENTICATED', 401);
    const timestampMs = Number(timestamp);
    const now = this.now();
    if (!Number.isSafeInteger(timestampMs) || Math.abs(now.getTime() - timestampMs) > maxClockSkewMs) {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    return this.repository.transaction(async (transaction) => {
      const edge = await transaction.getEdge(edgeId);
      const credential = await transaction.getCredential(edgeId, credentialId);
      const plaintextCredential = credential && decryptEdgeCredential(credential.credentialCiphertext, key);
      if (!edge?.enabled || !credential || !plaintextCredential) throw new PairingError('UNAUTHENTICATED', 401);
      const expected = edgeRequestSignature(
        plaintextCredential, timestamp, method, pathname, edgeBodyDigest(body), nonce,
      );
      if (!safeSignatureEquals(signature, expected)) throw new PairingError('UNAUTHENTICATED', 401);
      const accepted = await transaction.useNonce(edgeId, nonce, new Date(now.getTime() + maxClockSkewMs), now);
      if (!accepted) throw new PairingError('UNAUTHENTICATED', 401);
      await transaction.updateLastSeen(edgeId, now);
      return edge;
    });
  }

  async configuration(edge: VaconEdge): Promise<VaconEdgeConfiguration> {
    return this.repository.transaction(async (transaction) => ({
      pollingIntervalSeconds: 5,
      devices: await transaction.listDevicesForEdge(edge.facilityId, edge.edgeId),
    }));
  }

  async ingestTelemetry(edge: VaconEdge, body: unknown): Promise<{accepted: number}> {
    const now = this.now();
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new PairingError('INVALID_ARGUMENT', 400);
    const readings = (body as Record<string, unknown>).readings;
    if (!Array.isArray(readings) || readings.length === 0 || readings.length > maxTelemetryPerRequest) {
      throw new PairingError('INVALID_ARGUMENT', 400);
    }
    const parsed = readings.map((reading) => parseTelemetry(reading, now));
    const uniqueDeviceIds = new Set(parsed.map((item) => item.deviceId));
    if (uniqueDeviceIds.size !== parsed.length) throw new PairingError('INVALID_ARGUMENT', 400);
    return this.repository.transaction(async (transaction) => {
      for (const reading of parsed) {
        const device = await transaction.getDeviceForEdge(reading.deviceId, edge.facilityId, edge.edgeId);
        if (!device) throw new PairingError('VACON_DEVICE_NOT_FOUND', 404);
        await transaction.appendTelemetry(asPersistedTelemetry(reading, now));
      }
      return {accepted: parsed.length};
    });
  }

  async takeCommands(edge: VaconEdge): Promise<readonly VaconEdgeCommand[]> {
    return this.repository.transaction((transaction) => transaction.takeCommands(edge.edgeId, this.now(), maxCommandBatch));
  }

  async completeCommand(edge: VaconEdge, commandIdInput: unknown, body: unknown): Promise<void> {
    const commandId = requireText(commandIdInput, 128);
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new PairingError('INVALID_ARGUMENT', 400);
    const input = body as Record<string, unknown>;
    const succeeded = input.succeeded === true;
    const resultCode = requireText(input.resultCode, 80);
    if (!safeResultCodes.has(resultCode)) throw new PairingError('INVALID_ARGUMENT', 400);
    const now = this.now();
    await this.repository.transaction(async (transaction) => {
      const command = await transaction.getCommand(commandId);
      if (!command || command.edgeId !== edge.edgeId || command.facilityId !== edge.facilityId ||
          command.state !== 'DISPATCHED' || command.expiresAt <= now) {
        throw new PairingError('INVALID_ARGUMENT', 400);
      }
      await transaction.completeCommand(commandId, succeeded ? 'SUCCEEDED' : 'FAILED', resultCode, now);
      await transaction.appendEdgeAudit({
        facilityId: edge.facilityId,
        deviceId: command.deviceId,
        actorUid: null,
        eventType: succeeded ? 'VACON_CONNECTION_TEST_SUCCEEDED' : 'VACON_CONNECTION_TEST_FAILED',
        changedFields: [],
        createdAt: now,
      });
    });
  }

  async requestConnectionTest(
    actor: AuthorizedAdmin,
    facilityIdInput: unknown,
    deviceIdInput: unknown,
  ): Promise<{deviceId: string; state: 'PENDING'; reason: 'EDGE_TEST_REQUESTED'; requestId: string; testedAt: Date}> {
    const facilityId = requireFacility(actor, facilityIdInput);
    const deviceId = requireVaconDeviceId(deviceIdInput);
    const now = this.now();
    return this.repository.transaction(async (transaction) => {
      // The device lookup is facility-bound; a test can never escape the
      // current admin's facility by supplying another device id.
      const device = await transaction.getFacilityDevice(deviceId, facilityId);
      if (!device) throw new PairingError('VACON_DEVICE_NOT_FOUND', 404);
      const command: VaconEdgeCommand = {
        commandId: randomUUID(),
        facilityId,
        edgeId: device.edgeServerId,
        deviceId,
        commandType: 'TEST_CONNECTION',
        state: 'PENDING',
        requestedByUid: actor.uid,
        requestedAt: now,
        expiresAt: new Date(now.getTime() + commandLifetimeMs),
        completedAt: null,
        resultCode: null,
      };
      const edge = await transaction.getEdge(command.edgeId);
      if (!edge?.enabled || edge.facilityId !== facilityId) throw new PairingError('VACON_EDGE_NOT_CONFIGURED', 409);
      await transaction.createCommand(command);
      await transaction.appendEdgeAudit({
        facilityId,
        deviceId,
        actorUid: actor.uid,
        eventType: 'VACON_CONNECTION_TEST_REQUESTED',
        changedFields: [],
        createdAt: now,
      });
      return {
        deviceId,
        state: 'PENDING' as const,
        reason: 'EDGE_TEST_REQUESTED' as const,
        requestId: command.commandId,
        testedAt: now,
      };
    });
  }

}
