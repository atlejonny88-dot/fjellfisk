import {randomUUID} from 'node:crypto';
import {Pool, type PoolClient, type QueryResultRow} from 'pg';

import type {RateLimitScope} from './pairing/constants.js';
import type {PairingRepository, PairingTransaction} from './pairing/repository.js';
import type {
  AuditEvent,
  CollectorDevice,
  PairingCodeRecord,
  RateLimitRecord,
} from './pairing/types.js';

interface DeviceRow extends QueryResultRow {
  collector_id: string;
  state: CollectorDevice['state'];
  credential_digest: string;
  collector_version: string | null;
  platform: string | null;
  organization_id: string | null;
  site_id: string | null;
  created_at: Date;
  last_seen_at: Date;
  paired_at: Date | null;
  paired_by_uid: string | null;
  revoked_at: Date | null;
}

interface CodeRow extends QueryResultRow {
  code_digest: string;
  collector_id: string;
  state: PairingCodeRecord['state'];
  issued_at: Date;
  expires_at: Date;
  used_at: Date | null;
  claimed_by_uid: string | null;
}

interface RateLimitRow extends QueryResultRow {
  scope: RateLimitScope;
  subject_digest: string;
  window_started_at: Date;
  request_count: number;
  updated_at: Date;
}

function asDevice(row: DeviceRow): CollectorDevice {
  return {
    collectorId: row.collector_id,
    state: row.state,
    credentialDigest: row.credential_digest,
    collectorVersion: row.collector_version,
    platform: row.platform,
    organizationId: row.organization_id,
    siteId: row.site_id,
    createdAt: row.created_at,
    lastSeenAt: row.last_seen_at,
    pairedAt: row.paired_at,
    pairedByUid: row.paired_by_uid,
    revokedAt: row.revoked_at,
  };
}

function asCode(row: CodeRow): PairingCodeRecord {
  return {
    codeDigest: row.code_digest,
    collectorId: row.collector_id,
    state: row.state,
    issuedAt: row.issued_at,
    expiresAt: row.expires_at,
    usedAt: row.used_at,
    claimedByUid: row.claimed_by_uid,
  };
}

function asRateLimit(row: RateLimitRow): RateLimitRecord {
  return {
    scope: row.scope,
    subjectDigest: row.subject_digest,
    windowStartedAt: row.window_started_at,
    requestCount: row.request_count,
    updatedAt: row.updated_at,
  };
}

const collectorColumns: Record<keyof Omit<CollectorDevice, 'collectorId' | 'credentialDigest' | 'createdAt'>, string> = {
  state: 'state',
  collectorVersion: 'collector_version',
  platform: 'platform',
  organizationId: 'organization_id',
  siteId: 'site_id',
  lastSeenAt: 'last_seen_at',
  pairedAt: 'paired_at',
  pairedByUid: 'paired_by_uid',
  revokedAt: 'revoked_at',
};

const codeColumns: Record<keyof Omit<PairingCodeRecord, 'codeDigest' | 'collectorId' | 'issuedAt' | 'expiresAt'>, string> = {
  state: 'state',
  usedAt: 'used_at',
  claimedByUid: 'claimed_by_uid',
};

class PostgresPairingTransaction implements PairingTransaction {
  constructor(private readonly client: PoolClient) {}

  async getCollector(collectorId: string): Promise<CollectorDevice | null> {
    const result = await this.client.query<DeviceRow>(
      'SELECT * FROM collector_devices WHERE collector_id = $1 FOR UPDATE',
      [collectorId],
    );
    return result.rows[0] ? asDevice(result.rows[0]) : null;
  }

  async insertCollector(device: CollectorDevice): Promise<void> {
    await this.client.query(
      `INSERT INTO collector_devices (
        collector_id, state, credential_digest, collector_version, platform,
        organization_id, site_id, created_at, last_seen_at, paired_at,
        paired_by_uid, revoked_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
      [
        device.collectorId, device.state, device.credentialDigest,
        device.collectorVersion, device.platform, device.organizationId,
        device.siteId, device.createdAt, device.lastSeenAt, device.pairedAt,
        device.pairedByUid, device.revokedAt,
      ],
    );
  }

  async updateCollector(collectorId: string, patch: Partial<CollectorDevice>): Promise<void> {
    const entries = Object.entries(patch)
      .filter(([key]) => key in collectorColumns) as [keyof typeof collectorColumns, unknown][];
    if (!entries.length) return;
    const assignments = entries.map(([key], index) => `${collectorColumns[key]} = $${index + 2}`);
    await this.client.query(
      `UPDATE collector_devices SET ${assignments.join(', ')} WHERE collector_id = $1`,
      [collectorId, ...entries.map(([, value]) => value)],
    );
  }

  async listCollectorsForSite(siteId: string): Promise<CollectorDevice[]> {
    const result = await this.client.query<DeviceRow>(
      'SELECT * FROM collector_devices WHERE site_id = $1 ORDER BY created_at DESC FOR UPDATE',
      [siteId],
    );
    return result.rows.map(asDevice);
  }

  async getCode(codeDigest: string): Promise<PairingCodeRecord | null> {
    const result = await this.client.query<CodeRow>(
      'SELECT * FROM collector_pairing_codes WHERE code_digest = $1 FOR UPDATE',
      [codeDigest],
    );
    return result.rows[0] ? asCode(result.rows[0]) : null;
  }

  async listActiveCodes(collectorId: string): Promise<PairingCodeRecord[]> {
    const result = await this.client.query<CodeRow>(
      "SELECT * FROM collector_pairing_codes WHERE collector_id = $1 AND state = 'ACTIVE' FOR UPDATE",
      [collectorId],
    );
    return result.rows.map(asCode);
  }

  async insertCode(code: PairingCodeRecord): Promise<void> {
    await this.client.query(
      `INSERT INTO collector_pairing_codes (
        code_digest, collector_id, state, issued_at, expires_at, used_at, claimed_by_uid
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        code.codeDigest, code.collectorId, code.state, code.issuedAt,
        code.expiresAt, code.usedAt, code.claimedByUid,
      ],
    );
  }

  async updateCode(codeDigest: string, patch: Partial<PairingCodeRecord>): Promise<void> {
    const entries = Object.entries(patch)
      .filter(([key]) => key in codeColumns) as [keyof typeof codeColumns, unknown][];
    if (!entries.length) return;
    const assignments = entries.map(([key], index) => `${codeColumns[key]} = $${index + 2}`);
    await this.client.query(
      `UPDATE collector_pairing_codes SET ${assignments.join(', ')} WHERE code_digest = $1`,
      [codeDigest, ...entries.map(([, value]) => value)],
    );
  }

  async getRateLimit(scope: RateLimitScope, subjectDigest: string): Promise<RateLimitRecord | null> {
    await this.client.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [
      `${scope}:${subjectDigest}`,
    ]);
    const result = await this.client.query<RateLimitRow>(
      'SELECT * FROM collector_rate_limits WHERE scope = $1 AND subject_digest = $2 FOR UPDATE',
      [scope, subjectDigest],
    );
    return result.rows[0] ? asRateLimit(result.rows[0]) : null;
  }

  async upsertRateLimit(record: RateLimitRecord): Promise<void> {
    await this.client.query(
      `INSERT INTO collector_rate_limits (
        scope, subject_digest, window_started_at, request_count, updated_at
      ) VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (scope, subject_digest) DO UPDATE SET
        window_started_at = EXCLUDED.window_started_at,
        request_count = EXCLUDED.request_count,
        updated_at = EXCLUDED.updated_at`,
      [
        record.scope, record.subjectDigest, record.windowStartedAt,
        record.requestCount, record.updatedAt,
      ],
    );
  }

  async appendAudit(event: AuditEvent): Promise<void> {
    await this.client.query(
      `INSERT INTO collector_audit_events (
        event_id, event_type, collector_id, organization_id, site_id, actor_uid, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        randomUUID(), event.eventType, event.collectorId, event.organizationId ?? null,
        event.siteId ?? null, event.actorUid ?? null, event.createdAt,
      ],
    );
  }
}

export class PostgresPairingRepository implements PairingRepository {
  constructor(private readonly pool: Pool) {}

  async transaction<T>(operation: (transaction: PairingTransaction) => Promise<T>): Promise<T> {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      const client = await this.pool.connect();
      try {
        await client.query('BEGIN ISOLATION LEVEL SERIALIZABLE');
        const result = await operation(new PostgresPairingTransaction(client));
        await client.query('COMMIT');
        return result;
      } catch (error) {
        await client.query('ROLLBACK');
        if ((error as {code?: string}).code === '40001' && attempt < 2) continue;
        throw error;
      } finally {
        client.release();
      }
    }
    throw new Error('PostgreSQL transaction retries exhausted');
  }

  async healthcheck(): Promise<void> {
    await this.pool.query('SELECT 1');
  }
}

export function createPostgresPool(databaseUrl: string): Pool {
  return new Pool({
    connectionString: databaseUrl,
    max: 10,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
  });
}
