import type {VaconAuditEvent, VaconDevice, VaconTelemetry} from './types.js';

export interface VaconTransaction {
  listDevices(facilityId: string): Promise<VaconDevice[]>;
  getDevice(deviceId: string): Promise<VaconDevice | null>;
  insertDevice(device: VaconDevice): Promise<void>;
  updateDevice(device: VaconDevice): Promise<void>;
  listTelemetry(deviceId: string, limit: number): Promise<VaconTelemetry[]>;
  latestTelemetry(deviceId: string): Promise<VaconTelemetry | null>;
  appendAudit(event: VaconAuditEvent): Promise<void>;
}

export interface VaconRepository {
  transaction<T>(operation: (transaction: VaconTransaction) => Promise<T>): Promise<T>;
}
