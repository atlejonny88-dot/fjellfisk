import assert from 'node:assert/strict';
import {readdir, readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import test from 'node:test';

import {PairingService} from '../src/pairing/service.js';
import {PostgresAuthorityRepository} from '../src/postgres_authority_repository.js';
import {createPostgresPool, PostgresPairingRepository} from '../src/postgres_pairing_repository.js';

const databaseUrl = process.env.FJELLFISK_POSTGRES_TEST_URL;

test('PostgreSQL repository enforces one winning claim', {skip: !databaseUrl}, async () => {
  // This URL must point to a dedicated disposable test database, never Pelasyn.
  const pool = createPostgresPool(databaseUrl!);
  try {
    const migrationDirectory = resolve(process.cwd(), 'migrations');
    const files = (await readdir(migrationDirectory)).filter((file) => file.endsWith('.sql')).sort();
    for (const file of files) {
      await pool.query(await readFile(resolve(migrationDirectory, file), 'utf8'));
    }
    await pool.query(
      `TRUNCATE
        collector_authority_bootstrap,
        collector_addon_entitlements,
        collector_facility_memberships,
        collector_facilities,
        collector_users,
        collector_audit_events,
        collector_pairing_codes,
        collector_rate_limits,
        collector_devices`,
    );
    const authority = new PostgresAuthorityRepository(pool);
    await authority.bootstrapInitialAuthority({
      firebaseUid: 'postgres-admin',
      facilityId: 'facility-test',
      facilityName: 'PostgreSQL Test Facility',
      organizationId: 'org-test',
      collectorEntitlement: 'ACTIVE',
    });
    assert.deepEqual(await authority.getAdminAccess('postgres-admin', 'facility-test'), {
      organizationId: 'org-test', collectorEntitled: true,
    });
    await authority.setCollectorEntitlement({
      facilityId: 'facility-test',
      status: 'INACTIVE',
      expiresAt: null,
      updatedByUid: 'postgres-admin',
    });
    assert.deepEqual(await authority.getAdminAccess('postgres-admin', 'facility-test'), {
      organizationId: 'org-test', collectorEntitled: false,
    });
    await authority.setCollectorEntitlement({
      facilityId: 'facility-test',
      status: 'ACTIVE',
      expiresAt: new Date(Date.now() + 60_000),
      updatedByUid: 'postgres-admin',
    });
    assert.deepEqual(await authority.getAdminAccess('postgres-admin', 'facility-test'), {
      organizationId: 'org-test', collectorEntitled: true,
    });
    await assert.rejects(authority.bootstrapInitialAuthority({
      firebaseUid: 'other-admin',
      facilityId: 'another-facility',
      facilityName: 'Another Facility',
      organizationId: null,
      collectorEntitlement: 'INACTIVE',
    }));
    const service = new PairingService(new PostgresPairingRepository(pool), {
      pepper: 'test-pepper-that-is-at-least-thirty-two-characters',
    });
    const registration = await service.registerCollector({platform: 'windows'}, 'postgres-test-source');
    const code = await service.issuePairingCode(registration);
    assert.ok(code.code);
    const actor = {uid: 'postgres-admin', organizationId: 'org-test', allowedSiteIds: ['facility-test']};
    const claims = await Promise.allSettled([
      service.claimCollector({actor, pairingCode: code.code, siteId: 'facility-test', sourceFingerprint: 'a'}),
      service.claimCollector({actor, pairingCode: code.code, siteId: 'facility-test', sourceFingerprint: 'b'}),
    ]);
    assert.equal(claims.filter((claim) => claim.status === 'fulfilled').length, 1);
  } finally {
    await pool.end();
  }
});
