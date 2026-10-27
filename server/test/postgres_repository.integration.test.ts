import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import test from 'node:test';

import {PairingService} from '../src/pairing/service.js';
import {createPostgresPool, PostgresPairingRepository} from '../src/postgres_pairing_repository.js';

const databaseUrl = process.env.FJELLFISK_POSTGRES_TEST_URL;

test('PostgreSQL repository enforces one winning claim', {skip: !databaseUrl}, async () => {
  // This URL must point to a dedicated disposable test database, never Pelasyn.
  const pool = createPostgresPool(databaseUrl!);
  try {
    const migration = await readFile(resolve(process.cwd(), 'migrations', '001_collector_pairing.sql'), 'utf8');
    await pool.query(migration);
    await pool.query('TRUNCATE collector_audit_events, collector_pairing_codes, collector_rate_limits, collector_devices');
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
