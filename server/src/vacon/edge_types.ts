import type {VaconDevice, VaconTelemetry, VaconTelemetryQuality} from './types.js';

export interface VaconEdge {
  edgeId: string;
  facilityId: string;
  displayName: string;
  enabled: boolean;
  lastSeenAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface VaconEdgeCredential {
  credentialId: string;
  edgeId: string;
  credentialCiphertext: string;
  active: boolean;
  expiresAt: Date | null;
  createdAt: Date;
}

export type VaconEdgeCommandType = 'TEST_CONNECTION';
export type VaconEdgeCommandState = 'PENDING' | 'DISPATCHED' | 'SUCCEEDED' | 'FAILED' | 'EXPIRED';

export interface VaconEdgeCommand {
  commandId: string;
  facilityId: string;
  edgeId: string;
  deviceId: string;
  commandType: VaconEdgeCommandType;
  state: VaconEdgeCommandState;
  requestedByUid: string | null;
  requestedAt: Date;
  expiresAt: Date;
  completedAt: Date | null;
  resultCode: string | null;
}

export interface VaconEdgeConfiguration {
  pollingIntervalSeconds: number;
  devices: readonly VaconDevice[];
}

export interface VaconTelemetryInput {
  deviceId: string;
  measuredAt: Date;
  quality: VaconTelemetryQuality;
  actualFrequencyHz: number | null;
  referenceFrequencyHz: number | null;
  referenceFrequencyVerified: boolean;
  motorSpeedRpm: number | null;
  motorSpeedVerified: boolean;
  motorCurrentRaw: number | null;
  motorCurrentA: number | null;
  motorCurrentVerified: boolean;
  ready: boolean | null;
  running: boolean | null;
  fault: boolean | null;
  alarm: boolean | null;
  atReference: boolean | null;
  activeFaultCode: string | null;
}

export interface PersistedVaconTelemetry extends VaconTelemetry {
  referenceFrequencyHz: number | null;
  referenceFrequencyVerified: boolean;
}
