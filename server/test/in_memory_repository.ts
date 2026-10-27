import type {RateLimitScope} from '../src/pairing/constants.js';
import type {PairingRepository, PairingTransaction} from '../src/pairing/repository.js';
import type {
  AuditEvent,
  CollectorDevice,
  PairingCodeRecord,
  RateLimitRecord,
} from '../src/pairing/types.js';

function clone<T>(value: T): T {
  return structuredClone(value);
}

class InMemoryTransaction implements PairingTransaction {
  constructor(private readonly repository: InMemoryPairingRepository) {}

  async getCollector(collectorId: string): Promise<CollectorDevice | null> {
    const value = this.repository.devices.get(collectorId);
    return value ? clone(value) : null;
  }

  async insertCollector(device: CollectorDevice): Promise<void> {
    this.repository.devices.set(device.collectorId, clone(device));
  }

  async updateCollector(collectorId: string, patch: Partial<CollectorDevice>): Promise<void> {
    const device = this.repository.devices.get(collectorId);
    if (!device) throw new Error('Unknown collector');
    this.repository.devices.set(collectorId, {...device, ...clone(patch)});
  }

  async listCollectorsForSite(siteId: string): Promise<CollectorDevice[]> {
    return [...this.repository.devices.values()]
      .filter((device) => device.siteId === siteId)
      .sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime())
      .map(clone);
  }

  async getCode(codeDigest: string): Promise<PairingCodeRecord | null> {
    const value = this.repository.codes.get(codeDigest);
    return value ? clone(value) : null;
  }

  async listActiveCodes(collectorId: string): Promise<PairingCodeRecord[]> {
    return [...this.repository.codes.values()]
      .filter((code) => code.collectorId === collectorId && code.state === 'ACTIVE')
      .map(clone);
  }

  async insertCode(code: PairingCodeRecord): Promise<void> {
    this.repository.codes.set(code.codeDigest, clone(code));
  }

  async updateCode(codeDigest: string, patch: Partial<PairingCodeRecord>): Promise<void> {
    const code = this.repository.codes.get(codeDigest);
    if (!code) throw new Error('Unknown pairing code');
    this.repository.codes.set(codeDigest, {...code, ...clone(patch)});
  }

  async getRateLimit(scope: RateLimitScope, subjectDigest: string): Promise<RateLimitRecord | null> {
    const value = this.repository.rateLimits.get(`${scope}:${subjectDigest}`);
    return value ? clone(value) : null;
  }

  async upsertRateLimit(record: RateLimitRecord): Promise<void> {
    this.repository.rateLimits.set(`${record.scope}:${record.subjectDigest}`, clone(record));
  }

  async appendAudit(event: AuditEvent): Promise<void> {
    this.repository.audit.push(clone(event));
  }
}

export class InMemoryPairingRepository implements PairingRepository {
  readonly devices = new Map<string, CollectorDevice>();
  readonly codes = new Map<string, PairingCodeRecord>();
  readonly rateLimits = new Map<string, RateLimitRecord>();
  readonly audit: AuditEvent[] = [];
  private queue = Promise.resolve();

  async transaction<T>(operation: (transaction: PairingTransaction) => Promise<T>): Promise<T> {
    let release: () => void = () => undefined;
    const wait = this.queue;
    this.queue = new Promise<void>((resolve) => { release = resolve; });
    await wait;
    try {
      return await operation(new InMemoryTransaction(this));
    } finally {
      release();
    }
  }

  async healthcheck(): Promise<void> {}
}
