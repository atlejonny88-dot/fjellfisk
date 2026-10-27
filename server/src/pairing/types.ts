import type {CollectorState, PairingCodeState, RateLimitScope} from './constants.js';

export interface CollectorDevice {
  collectorId: string;
  state: CollectorState;
  credentialDigest: string;
  collectorVersion: string | null;
  platform: string | null;
  organizationId: string | null;
  siteId: string | null;
  createdAt: Date;
  lastSeenAt: Date;
  pairedAt: Date | null;
  pairedByUid: string | null;
  revokedAt: Date | null;
}

export interface PairingCodeRecord {
  codeDigest: string;
  collectorId: string;
  state: PairingCodeState;
  issuedAt: Date;
  expiresAt: Date;
  usedAt: Date | null;
  claimedByUid: string | null;
}

export interface AuditEvent {
  eventType: string;
  collectorId: string;
  organizationId?: string | null;
  siteId?: string | null;
  actorUid?: string | null;
  createdAt: Date;
}

export interface RateLimitRecord {
  scope: RateLimitScope;
  subjectDigest: string;
  windowStartedAt: Date;
  requestCount: number;
  updatedAt: Date;
}

export interface CollectorAuthentication {
  collectorId: string;
  deviceCredential: string;
}

export interface AuthorizedAdmin {
  uid: string;
  organizationId: string | null;
  allowedSiteIds: readonly string[];
}

export interface CollectorStatus {
  collectorId: string;
  state: CollectorState;
  organizationId?: string;
  siteId?: string;
  pairedAt?: string;
}

export interface RegistrationResult {
  collectorId: string;
  deviceCredential: string;
  state: 'UNPAIRED';
}

export interface PairingCodeResult extends CollectorStatus {
  code?: string;
  issuedAt?: string;
  expiresAt?: string;
  expiresInSeconds?: number;
}

export interface PublicCollectorSummary {
  collectorId: string;
  state: CollectorState;
  createdAt: string;
  lastSeenAt: string;
  collectorVersion: string | null;
  platform: string | null;
  pairedAt: string | null;
}
