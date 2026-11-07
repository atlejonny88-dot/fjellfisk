import type {AuthorizedAdmin} from '../pairing/types.js';
import type {VaconDevice} from './types.js';
import type {
  PersistedVaconTelemetry,
  VaconEdge,
  VaconEdgeCommand,
  VaconEdgeCredential,
} from './edge_types.js';

export interface VaconEdgeTransaction {
  getEdge(edgeId: string): Promise<VaconEdge | null>;
  getCredential(edgeId: string, credentialId: string): Promise<VaconEdgeCredential | null>;
  useNonce(edgeId: string, nonce: string, expiresAt: Date, now: Date): Promise<boolean>;
  updateLastSeen(edgeId: string, now: Date): Promise<void>;
  listDevicesForEdge(facilityId: string, edgeId: string): Promise<VaconDevice[]>;
  getFacilityDevice(deviceId: string, facilityId: string): Promise<VaconDevice | null>;
  getDeviceForEdge(deviceId: string, facilityId: string, edgeId: string): Promise<VaconDevice | null>;
  appendTelemetry(telemetry: PersistedVaconTelemetry): Promise<void>;
  createCommand(command: VaconEdgeCommand): Promise<void>;
  takeCommands(edgeId: string, now: Date, limit: number): Promise<VaconEdgeCommand[]>;
  getCommand(commandId: string): Promise<VaconEdgeCommand | null>;
  completeCommand(commandId: string, state: 'SUCCEEDED' | 'FAILED', resultCode: string, now: Date): Promise<void>;
  appendEdgeAudit(event: {
    facilityId: string;
    deviceId: string | null;
    actorUid: string | null;
    eventType: string;
    changedFields: readonly string[];
    createdAt: Date;
  }): Promise<void>;
}

export interface VaconEdgeRepository {
  transaction<T>(operation: (transaction: VaconEdgeTransaction) => Promise<T>): Promise<T>;
}

export interface VaconEdgeProvisioningRepository {
  transaction<T>(operation: (transaction: VaconEdgeProvisioningTransaction) => Promise<T>): Promise<T>;
}

export interface VaconEdgeProvisioningTransaction {
  facilityExists(facilityId: string): Promise<boolean>;
  getEdge(edgeId: string): Promise<VaconEdge | null>;
  insertEdge(edge: VaconEdge): Promise<void>;
  insertCredential(credential: VaconEdgeCredential): Promise<void>;
  deactivateCredentials(edgeId: string, expiresAt: Date): Promise<void>;
  appendEdgeAudit(event: {
    facilityId: string;
    deviceId: string | null;
    actorUid: string | null;
    eventType: string;
    changedFields: readonly string[];
    createdAt: Date;
  }): Promise<void>;
}

export interface VaconEdgeTestRequest {
  actor: AuthorizedAdmin;
  facilityId: string;
  deviceId: string;
}
