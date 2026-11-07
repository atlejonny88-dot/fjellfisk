export type VaconTelemetryQuality =
  | 'LIVE'
  | 'STALE'
  | 'FAILED'
  | 'UNAVAILABLE'
  | 'SIMULATED';

export type VaconConnectionState = 'ONLINE' | 'STALE' | 'OFFLINE' | 'DISABLED';

export interface VaconDeviceConfiguration {
  displayName: string;
  manufacturer: string;
  model: string;
  ipAddress: string;
  subnetMask: string;
  gateway: string;
  dns: string;
  modbusTcpPort: number;
  modbusUnitId: number;
  minFrequencyHz: number;
  maxFrequencyHz: number;
  edgeServerId: string;
  monitoringEnabled: boolean;
}

export interface VaconDevice extends VaconDeviceConfiguration {
  deviceId: string;
  facilityId: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface VaconTelemetry {
  deviceId: string;
  measuredAt: Date;
  receivedAt: Date;
  quality: VaconTelemetryQuality;
  actualFrequencyHz: number | null;
  referenceFrequencyHz: number | null;
  referenceFrequencyVerified: boolean;
  // The documented default uses RPM here, but this stays false until the
  // installation's configurable process-data mapping has been confirmed.
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

export interface VaconDeviceSnapshot extends VaconDevice {
  connection: VaconConnectionState;
  telemetry: VaconTelemetry | null;
}

export interface VaconAuditEvent {
  facilityId: string;
  deviceId: string | null;
  actorUid: string | null;
  eventType: string;
  changedFields: readonly string[];
  createdAt: Date;
}

export interface VaconConnectionTestResult {
  deviceId: string;
  state: 'UNAVAILABLE';
  reason: 'EDGE_TRANSPORT_NOT_CONFIGURED';
  testedAt: Date;
}
