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
  assert.match(new URL(databaseUrl!).pathname, /^\/fjellfisk_(?:[a-z0-9]+_)*test(?:_|$)/iu,
    'Refusing destructive integration tests outside an explicitly named disposable test database');
  const pool = createPostgresPool(databaseUrl!);
  try {
    const migrationDirectory = resolve(process.cwd(), 'migrations');
    const files = (await readdir(migrationDirectory)).filter((file) => file.endsWith('.sql')).sort();
    for (const file of files) {
      await pool.query(await readFile(resolve(migrationDirectory, file), 'utf8'));
    }
    await pool.query(
      `TRUNCATE
        collector_sensor_mappings,
        collector_sensors,
        collector_sensor_batches,
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
    await pool.query("INSERT INTO collector_users (firebase_uid, status) VALUES ('test-viewer', 'ACTIVE')");
    await pool.query("INSERT INTO collector_facility_memberships (facility_id, firebase_uid, role, status) VALUES ('facility-test', 'test-viewer', 'VIEWER', 'ACTIVE')");
    assert.equal(await authority.getAdminAccess('test-viewer', 'facility-test'), null);
    assert.ok(await authority.getMemberAccess('test-viewer', 'facility-test'));
    await pool.query("UPDATE collector_users SET status = 'DISABLED' WHERE firebase_uid = 'test-viewer'");
    assert.equal(await authority.getMemberAccess('test-viewer', 'facility-test'), null);
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
    const batch = {batchId: '12345678-1234-4234-8234-123456789012', collectorVersion: '1.0.5', readings: [{
      sensorId: 'pacific-01-probe-01', name: 'Pacific 01 / Probe 01', sourceType: 'Pacific',
      temperatureC: 8.646, oxygenMgL: 13.036, oxygenSaturationPct: 112.144,
      timestampUtc: new Date().toISOString(), health: 'ok',
    }]};
    assert.deepEqual(await service.ingestSensors(registration, batch), {accepted: true});
    assert.deepEqual(await service.ingestSensors(registration, batch), {accepted: false});
    const mapping = {sensorId: 'pacific-01-probe-01', sectionId: 'real-section', sectionName: 'Tunnel', tankId: 'real-tank', tankName: 'K1'};
    await service.saveSensorMappings(actor, 'facility-test', registration.collectorId, [mapping]);
    const snapshot = await service.getSensors(actor, 'facility-test', registration.collectorId);
    assert.equal(snapshot.sensors[0]?.oxygenMgL, 13.036);
    assert.equal(snapshot.sensors[0]?.oxygenSaturationPct, 112.144);
    assert.deepEqual(snapshot.mappings, [mapping]);
    const other = await service.registerCollector({platform: 'windows'}, 'postgres-test-other');
    const otherCode = await service.issuePairingCode(other);
    await service.claimCollector({actor, pairingCode: otherCode.code, siteId: 'facility-test', sourceFingerprint: 'c'});
    await service.ingestSensors(other, {...batch, batchId: '32345678-1234-4234-8234-123456789012'});
    await assert.rejects(service.saveSensorMappings(actor, 'facility-test', other.collectorId, [mapping]),
      (error: unknown) => (error as {code?: string}).code === 'SENSOR_MAPPING_CONFLICT');
    assert.deepEqual((await service.getSensors(actor, 'facility-test', registration.collectorId)).mappings, [mapping]);
    const restarted = new PairingService(new PostgresPairingRepository(pool), {pepper: 'test-pepper-that-is-at-least-thirty-two-characters'});
    assert.deepEqual(await restarted.getSensors(actor, 'facility-test', registration.collectorId), snapshot);
    await service.revokeCollector(actor, registration.collectorId, 'facility-test');
    await assert.rejects(service.ingestSensors(registration, {...batch, batchId: '22345678-1234-4234-8234-123456789012'}));
  } finally {
    await pool.end();
  }
});
