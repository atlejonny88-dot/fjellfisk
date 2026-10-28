import {Pool, type PoolClient, type QueryResultRow} from 'pg';

export type CollectorEntitlementStatus = 'ACTIVE' | 'INACTIVE';

export interface AuthorityAdminAccess {
  organizationId: string | null;
  collectorEntitled: boolean;
}

export interface InitialAuthorityBootstrap {
  firebaseUid: string;
  facilityId: string;
  facilityName: string;
  organizationId: string | null;
  collectorEntitlement: CollectorEntitlementStatus;
}

export interface CollectorEntitlementUpdate {
  facilityId: string;
  status: CollectorEntitlementStatus;
  expiresAt: Date | null;
  updatedByUid: string | null;
}

export interface AuthorityRepository {
  getAdminAccess(firebaseUid: string, facilityId: string): Promise<AuthorityAdminAccess | null>;
  bootstrapInitialAuthority(input: InitialAuthorityBootstrap): Promise<void>;
}

interface AdminAccessRow extends QueryResultRow {
  organization_id: string | null;
  collector_entitled: boolean;
}

function assertBootstrapInput(input: InitialAuthorityBootstrap): void {
  if (
    !input.firebaseUid || input.firebaseUid.length > 128 ||
    !input.facilityId || input.facilityId.length > 200 ||
    !input.facilityName || input.facilityName.length > 200
  ) {
    throw new Error('Invalid initial authority bootstrap input');
  }
}

export class PostgresAuthorityRepository implements AuthorityRepository {
  constructor(private readonly pool: Pool) {}

  async getAdminAccess(firebaseUid: string, facilityId: string): Promise<AuthorityAdminAccess | null> {
    const result = await this.pool.query<AdminAccessRow>(
      `SELECT
        facility.organization_id,
        EXISTS (
          SELECT 1
          FROM collector_addon_entitlements entitlement
          WHERE entitlement.facility_id = facility.facility_id
            AND entitlement.addon_key = 'collector'
            AND entitlement.status = 'ACTIVE'
            AND (entitlement.expires_at IS NULL OR entitlement.expires_at > NOW())
        ) AS collector_entitled
      FROM collector_users account
      JOIN collector_facility_memberships membership
        ON membership.firebase_uid = account.firebase_uid
      JOIN collector_facilities facility
        ON facility.facility_id = membership.facility_id
      WHERE account.firebase_uid = $1
        AND account.status = 'ACTIVE'
        AND membership.facility_id = $2
        AND membership.status = 'ACTIVE'
        AND membership.role = 'ADMIN'
        AND facility.status = 'ACTIVE'`,
      [firebaseUid, facilityId],
    );
    const row = result.rows[0];
    return row
      ? {organizationId: row.organization_id, collectorEntitled: row.collector_entitled}
      : null;
  }

  async bootstrapInitialAuthority(input: InitialAuthorityBootstrap): Promise<void> {
    assertBootstrapInput(input);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN ISOLATION LEVEL SERIALIZABLE');
      // A transaction-scoped lock makes the one-time bootstrap deterministic.
      await client.query("SELECT pg_advisory_xact_lock(hashtextextended('collector_authority_bootstrap', 0))");
      const existing = await client.query(
        'SELECT 1 FROM collector_authority_bootstrap WHERE bootstrap_key = TRUE',
      );
      if (existing.rowCount) {
        throw new Error('Collector authority bootstrap has already been completed');
      }
      await this.insertBootstrapRows(client, input);
      await client.query(
        `INSERT INTO collector_authority_bootstrap (bootstrap_key, firebase_uid, facility_id)
         VALUES (TRUE, $1, $2)`,
        [input.firebaseUid, input.facilityId],
      );
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Server-side entitlement mutation for a future commerce/admin workflow.
   * It is deliberately not exposed as a Flutter-facing self-service endpoint.
   */
  async setCollectorEntitlement(input: CollectorEntitlementUpdate): Promise<void> {
    await this.pool.query(
      `INSERT INTO collector_addon_entitlements (
        facility_id, addon_key, status, activated_at, expires_at, updated_by_uid
      ) VALUES (
        $1, 'collector', $2,
        CASE WHEN $2 = 'ACTIVE' THEN NOW() ELSE NULL END,
        $3, $4
      )
      ON CONFLICT (facility_id, addon_key) DO UPDATE SET
        status = EXCLUDED.status,
        activated_at = CASE
          WHEN EXCLUDED.status = 'ACTIVE'
            AND collector_addon_entitlements.status = 'INACTIVE' THEN NOW()
          ELSE collector_addon_entitlements.activated_at
        END,
        expires_at = EXCLUDED.expires_at,
        updated_by_uid = EXCLUDED.updated_by_uid,
        updated_at = NOW()`,
      [input.facilityId, input.status, input.expiresAt, input.updatedByUid],
    );
  }

  private async insertBootstrapRows(client: PoolClient, input: InitialAuthorityBootstrap): Promise<void> {
    await client.query(
      `INSERT INTO collector_users (firebase_uid, status)
       VALUES ($1, 'ACTIVE')`,
      [input.firebaseUid],
    );
    await client.query(
      `INSERT INTO collector_facilities (facility_id, display_name, organization_id, status)
       VALUES ($1, $2, $3, 'ACTIVE')`,
      [input.facilityId, input.facilityName, input.organizationId],
    );
    await client.query(
      `INSERT INTO collector_facility_memberships (facility_id, firebase_uid, role, status)
       VALUES ($1, $2, 'ADMIN', 'ACTIVE')`,
      [input.facilityId, input.firebaseUid],
    );
    await client.query(
      `INSERT INTO collector_addon_entitlements (
        facility_id, addon_key, status, activated_at, updated_by_uid
      ) VALUES ($1, 'collector', $2, CASE WHEN $2 = 'ACTIVE' THEN NOW() ELSE NULL END, $3)`,
      [input.facilityId, input.collectorEntitlement, input.firebaseUid],
    );
  }
}

export function createPostgresAuthorityRepository(pool: Pool): PostgresAuthorityRepository {
  return new PostgresAuthorityRepository(pool);
}
