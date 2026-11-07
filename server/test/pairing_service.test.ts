import assert from 'node:assert/strict';
import test from 'node:test';

import {normalizePairingCode} from '../src/pairing/crypto.js';
import {PairingError} from '../src/pairing/errors.js';
import {PairingService} from '../src/pairing/service.js';
import type {AuthorizedAdmin} from '../src/pairing/types.js';
import {InMemoryPairingRepository} from './in_memory_repository.js';

const admin: AuthorizedAdmin = {
  uid: 'admin-user',
  organizationId: 'org-1',
  allowedSiteIds: ['facility-1'],
};

function setup(now = new Date('2026-10-27T12:00:00.000Z')): {
  repository: InMemoryPairingRepository;
  service: PairingService;
  clock: {value: Date};
} {
  const clock = {value: now};
  const repository = new InMemoryPairingRepository();
  return {
    repository,
    service: new PairingService(repository, {
      pepper: 'test-pepper-that-is-at-least-thirty-two-characters',
      now: () => clock.value,
    }),
    clock,
  };
}

async function registerAndIssue(service: PairingService): Promise<{
  collectorId: string;
  deviceCredential: string;
  code: string;
}> {
  const registration = await service.registerCollector({collectorVersion: '1.0.0', platform: 'windows'}, 'source-a');
  const issued = await service.issuePairingCode(registration);
  assert.ok(issued.code);
  return {...registration, code: issued.code};
}

test('register returns a 256-bit credential once and repository stores only its digest', async () => {
  const {service, repository} = setup();
  const registration = await service.registerCollector({}, 'source-a');
  assert.match(registration.collectorId, /^[0-9a-f-]{36}$/);
  assert.ok(registration.deviceCredential.length >= 43);
  const stored = repository.devices.get(registration.collectorId);
  assert.ok(stored);
  assert.notEqual(stored.credentialDigest, registration.deviceCredential);
  assert.equal(JSON.stringify([...repository.devices.values(), repository.audit]).includes(registration.deviceCredential), false);
});

test('pairing code has stable format and no plaintext is persisted', async () => {
  const {service, repository} = setup();
  const result = await registerAndIssue(service);
  assert.equal(normalizePairingCode(result.code), result.code.replaceAll('-', ''));
  assert.equal([...repository.codes.values()].some((code) => code.codeDigest === result.code), false);
});

test('wrong collector credential cannot issue a code', async () => {
  const {service} = setup();
  const registered = await service.registerCollector({}, 'source-a');
  await assert.rejects(
    service.issuePairingCode({collectorId: registered.collectorId, deviceCredential: 'wrong'}),
    (error: unknown) => error instanceof PairingError && error.code === 'COLLECTOR_AUTH_FAILED',
  );
});

test('a newer code supersedes the previous code', async () => {
  const {service} = setup();
  const registered = await service.registerCollector({}, 'source-a');
  const first = await service.issuePairingCode(registered);
  const second = await service.issuePairingCode(registered);
  await assert.rejects(
    service.claimCollector({actor: admin, pairingCode: first.code, siteId: 'facility-1', sourceFingerprint: 'operator'}),
    (error: unknown) => error instanceof PairingError && error.code === 'PAIRING_CODE_SUPERSEDED',
  );
  assert.ok(second.code);
});

test('expired code is rejected using the server clock', async () => {
  const {service, clock} = setup();
  const issued = await registerAndIssue(service);
  clock.value = new Date(clock.value.getTime() + 600_001);
  await assert.rejects(
    service.claimCollector({actor: admin, pairingCode: issued.code, siteId: 'facility-1', sourceFingerprint: 'operator'}),
    (error: unknown) => error instanceof PairingError && error.code === 'PAIRING_CODE_EXPIRED',
  );
});

test('two concurrent claims yield one winner', async () => {
  const {service} = setup();
  const issued = await registerAndIssue(service);
  const results = await Promise.allSettled([
    service.claimCollector({actor: admin, pairingCode: issued.code, siteId: 'facility-1', sourceFingerprint: 'operator-1'}),
    service.claimCollector({actor: admin, pairingCode: issued.code, siteId: 'facility-1', sourceFingerprint: 'operator-2'}),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
});

test('claim, status, revoke and reset preserve state rules and audit', async () => {
  const {service, repository} = setup();
  const issued = await registerAndIssue(service);
  const claimed = await service.claimCollector({actor: admin, pairingCode: issued.code, siteId: 'facility-1', sourceFingerprint: 'operator'});
  assert.equal(claimed.state, 'PAIRED');
  assert.equal((await service.getCollectorStatus(issued)).state, 'PAIRED');
  assert.equal((await service.revokeCollector(admin, issued.collectorId, 'facility-1')).state, 'REVOKED');
  assert.equal((await service.resetCollectorForPairing(admin, issued.collectorId, 'facility-1')).state, 'UNPAIRED');
  assert.ok(repository.audit.some((event) => event.eventType === 'COLLECTOR_REVOKED'));
  assert.ok(repository.audit.some((event) => event.eventType === 'COLLECTOR_RESET_FOR_PAIRING'));
});

test('rate limit blocks the sixth registration within ten minutes', async () => {
  const {service} = setup();
  for (let index = 0; index < 5; index += 1) await service.registerCollector({}, 'source-a');
  await assert.rejects(
    service.registerCollector({}, 'source-a'),
    (error: unknown) => error instanceof PairingError && error.code === 'PAIRING_RATE_LIMITED',
  );
});

test('invalid claims consume their own rate limit without leaking a secret', async () => {
  const {service} = setup();
  for (let index = 0; index < 12; index += 1) {
    await assert.rejects(
      service.claimCollector({actor: admin, pairingCode: 'FJ-AAAA-AAAA-AAAA', siteId: 'facility-1', sourceFingerprint: 'operator'}),
      (error: unknown) => error instanceof PairingError && error.code === 'PAIRING_CODE_INVALID',
    );
  }
  await assert.rejects(
    service.claimCollector({actor: admin, pairingCode: 'FJ-AAAA-AAAA-AAAA', siteId: 'facility-1', sourceFingerprint: 'operator'}),
    (error: unknown) => error instanceof PairingError && error.code === 'PAIRING_RATE_LIMITED',
  );
});

test('revoke supersedes any remaining active pairing code', async () => {
  const {service, repository} = setup();
  const registration = await service.registerCollector({}, 'source-a');
  const issued = await service.issuePairingCode(registration);
  await service.claimCollector({actor: admin, pairingCode: issued.code, siteId: 'facility-1', sourceFingerprint: 'operator'});
  repository.codes.set('active-code-for-revoke-test', {
    codeDigest: 'active-code-for-revoke-test',
    collectorId: registration.collectorId,
    state: 'ACTIVE',
    issuedAt: new Date('2026-10-27T12:00:00.000Z'),
    expiresAt: new Date('2026-10-27T12:10:00.000Z'),
    usedAt: null,
    claimedByUid: null,
  });
  await service.revokeCollector(admin, registration.collectorId, 'facility-1');
  assert.equal([...repository.codes.values()].some((code) => code.state === 'ACTIVE'), false);
});

test('only admins explicitly allowed for a site can claim or list it', async () => {
  const {service} = setup();
  const issued = await registerAndIssue(service);
  const unauthorized = {...admin, allowedSiteIds: []};
  await assert.rejects(
    service.claimCollector({actor: unauthorized, pairingCode: issued.code, siteId: 'facility-1', sourceFingerprint: 'operator'}),
    (error: unknown) => error instanceof PairingError && error.code === 'FORBIDDEN',
  );
  await assert.rejects(
    service.listCollectorsForSite(unauthorized, 'facility-1'),
    (error: unknown) => error instanceof PairingError && error.code === 'FORBIDDEN',
  );
});
