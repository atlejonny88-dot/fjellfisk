import type {
  AuditEvent,
  CollectorDevice,
  PairingCodeRecord,
  RateLimitRecord,
} from './types.js';
import type {RateLimitScope} from './constants.js';

export interface PairingTransaction {
  getCollector(collectorId: string): Promise<CollectorDevice | null>;
  insertCollector(device: CollectorDevice): Promise<void>;
  updateCollector(collectorId: string, patch: Partial<CollectorDevice>): Promise<void>;
  listCollectorsForSite(siteId: string): Promise<CollectorDevice[]>;
  getCode(codeDigest: string): Promise<PairingCodeRecord | null>;
  listActiveCodes(collectorId: string): Promise<PairingCodeRecord[]>;
  insertCode(code: PairingCodeRecord): Promise<void>;
  updateCode(codeDigest: string, patch: Partial<PairingCodeRecord>): Promise<void>;
  getRateLimit(scope: RateLimitScope, subjectDigest: string): Promise<RateLimitRecord | null>;
  upsertRateLimit(record: RateLimitRecord): Promise<void>;
  appendAudit(event: AuditEvent): Promise<void>;
}

export interface PairingRepository {
  transaction<T>(operation: (transaction: PairingTransaction) => Promise<T>): Promise<T>;
  healthcheck(): Promise<void>;
}
