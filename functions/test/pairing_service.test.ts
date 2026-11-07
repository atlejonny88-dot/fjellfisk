import assert from 'node:assert/strict';
import test, {after, before} from 'node:test';
import {generateKeyPairSync, randomUUID} from 'node:crypto';
import {cert, initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore, type Firestore} from 'firebase-admin/firestore';

import {COLLECTIONS, type RateLimits} from '../src/pairing/constants.js';
import {PairingError} from '../src/pairing/errors.js';
import {PairingService} from '../src/pairing/service.js';

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = `fjellfisk-pairing-${randomUUID().replaceAll('-', '')}`;
let db: Firestore;
let app: ReturnType<typeof initializeApp>;
let currentTime = new Date('2026-10-10T09:00:00.000Z');
const testPepper = 'test-only-pairing-pepper-not-for-production';

function service(rateLimits?: RateLimits): PairingService {
  return new PairingService(db, {
    pepper: testPepper,
    now: () => currentTime,
    rateLimits,
  });
}

function createEphemeralEmulatorCredential() {
  const {privateKey} = generateKeyPairSync('rsa', {modulusLength: 2048});
  return cert({
    projectId,
    clientEmail: 'pairing-tests@local.test',
    privateKey: privateKey.export({type: 'pkcs8', format: 'pem'}).toString(),
  });
}

async function expectPairingError(
  action: () => Promise<unknown>,
  code: string,
): Promise<void> {
  await assert.rejects(action, (error: unknown) =>
    error instanceof PairingError && error.code === code,
  );
}

async function seedSiteAndUsers(): Promise<void> {
  await db.doc('facilities/site-a').set({name: 'Testanlegg', organizationId: 'org-a'});
  await db.doc('users/admin').set({role: 'admin', disabled: false});
  await db.doc('users/admin-rate').set({role: 'admin', disabled: false});
  await db.doc('users/employee').set({role: 'ansatt', disabled: false});
  await db.doc('users/reader').set({role: 'leser', disabled: false});
  await db.doc('users/disabled-admin').set({role: 'admin', disabled: true});
}

before(async () => {
  if (!hasEmulator) {
    return;
  }
  app = initializeApp({
    credential: createEphemeralEmulatorCredential(),
    projectId,
  }, `pairing-tests-${projectId}`);
  db = getFirestore(app);
  await seedSiteAndUsers();
});

after(async () => {
  if (hasEmulator) {
    await deleteApp(app);
  }
});

test('registration stores only a digest and starts unpaired', {skip: !hasEmulator}, async () => {
  const result = await service().registerCollector({collectorVersion: '1.0.1', platform: 'windows-x86'}, 'registration-a');
  assert.equal(result.state, 'UNPAIRED');
  assert.ok(result.deviceCredential.length >= 40);

  const stored = (await db.collection(COLLECTIONS.devices).doc(result.collectorId).get()).data()!;
  assert.equal(stored.state, 'UNPAIRED');
  assert.equal(stored.deviceCredential, undefined);
  assert.equal(stored.credentialDigest === result.deviceCredential, false);
  assert.equal(stored.siteId, null);
});

test('collector authentication rejects a wrong credential', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'auth-a');
  await expectPairingError(
    () => service().getCollectorStatus({collectorId: registered.collectorId, deviceCredential: 'not-the-right-credential-value-at-all'}),
    'COLLECTOR_AUTH_FAILED',
  );
});

test('one Collector credential cannot authenticate another Collector', {skip: !hasEmulator}, async () => {
  const first = await service().registerCollector({}, 'cross-auth-a');
  const second = await service().registerCollector({}, 'cross-auth-b');
  await expectPairingError(
    () => service().getCollectorStatus({
      collectorId: second.collectorId,
      deviceCredential: first.deviceCredential,
    }),
    'COLLECTOR_AUTH_FAILED',
  );
});

test('new pairing code supersedes the older active code and keeps plaintext out of Firestore', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'rotate-a');
  const auth = {collectorId: registered.collectorId, deviceCredential: registered.deviceCredential};
  const first = await service().issuePairingCode(auth);
  const second = await service().issuePairingCode(auth);
  assert.notEqual(first.code, second.code);
  assert.equal(second.expiresInSeconds, 600);

  await expectPairingError(
    () => service().claimCollector({actorUid: 'admin', pairingCode: first.code, siteId: 'site-a', sourceFingerprint: 'claim-a'}),
    'PAIRING_CODE_SUPERSEDED',
  );
  const codes = await db.collection(COLLECTIONS.pairingCodes).where('collectorId', '==', registered.collectorId).get();
  assert.equal(codes.docs.some((document) => JSON.stringify(document.data()).includes(first.code!)), false);
  assert.equal(codes.docs.some((document) => document.data().state === 'SUPERSEDED'), true);
});

test('only an active admin can atomically claim one code for the selected site', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'claim-a');
  const auth = {collectorId: registered.collectorId, deviceCredential: registered.deviceCredential};
  const code = await service().issuePairingCode(auth);
  await expectPairingError(
    () => service().claimCollector({actorUid: 'employee', pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'employee'}),
    'FORBIDDEN',
  );
  const claimed = await service().claimCollector({actorUid: 'admin', pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'admin'});
  assert.deepEqual(claimed, {
    collectorId: registered.collectorId,
    state: 'PAIRED',
    organizationId: 'org-a',
    siteId: 'site-a',
    pairedAt: currentTime.toISOString(),
  });
  const status = await service().getCollectorStatus(auth);
  assert.equal(status.siteId, 'site-a');
  assert.equal(status.organizationId, 'org-a');
  const listed = await service().listCollectorsForSite('admin', 'site-a');
  const publicCollector = listed.find((item) => item.collectorId === registered.collectorId);
  assert.equal(publicCollector?.state, 'PAIRED');
  assert.equal('credentialDigest' in (publicCollector ?? {}), false);
  await expectPairingError(
    () => service().listCollectorsForSite('reader', 'site-a'),
    'FORBIDDEN',
  );
  assert.deepEqual(await service().issuePairingCode(auth), {
    collectorId: registered.collectorId,
    state: 'PAIRED',
    organizationId: 'org-a',
    siteId: 'site-a',
    pairedAt: currentTime.toISOString(),
  });
  await expectPairingError(
    () => service().claimCollector({actorUid: 'admin', pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'again'}),
    'PAIRING_CODE_USED',
  );
});

test('concurrent double claim creates exactly one pairing', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'concurrent-a');
  const auth = {collectorId: registered.collectorId, deviceCredential: registered.deviceCredential};
  const code = await service().issuePairingCode(auth);
  const results = await Promise.allSettled([
    service().claimCollector({actorUid: 'admin', pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'concurrent-1'}),
    service().claimCollector({actorUid: 'admin', pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'concurrent-2'}),
  ]);
  assert.equal(results.filter((result) => result.status === 'fulfilled').length, 1);
  assert.equal(results.filter((result) => result.status === 'rejected').length, 1);
});

test('unauthenticated and disabled callers cannot claim a Collector', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'authorization-a');
  const code = await service().issuePairingCode({collectorId: registered.collectorId, deviceCredential: registered.deviceCredential});
  await expectPairingError(
    () => service().claimCollector({actorUid: null, pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'anonymous'}),
    'UNAUTHENTICATED',
  );
  await expectPairingError(
    () => service().claimCollector({actorUid: 'disabled-admin', pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'disabled'}),
    'FORBIDDEN',
  );
});

test('a claim requires an existing facility/site', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'missing-site-a');
  const code = await service().issuePairingCode({collectorId: registered.collectorId, deviceCredential: registered.deviceCredential});
  await expectPairingError(
    () => service().claimCollector({actorUid: 'admin', pairingCode: code.code, siteId: 'site-does-not-exist', sourceFingerprint: 'missing-site'}),
    'SITE_NOT_FOUND',
  );
});

test('expired code is rejected using server time', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'expiry-a');
  const code = await service().issuePairingCode({collectorId: registered.collectorId, deviceCredential: registered.deviceCredential});
  currentTime = new Date(currentTime.getTime() + 600001);
  await expectPairingError(
    () => service().claimCollector({actorUid: 'admin', pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'expired'}),
    'PAIRING_CODE_EXPIRED',
  );
  currentTime = new Date('2026-10-10T09:00:00.000Z');
});

test('revoke invalidates active codes, protects status and requires explicit reset', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'revoke-a');
  const auth = {collectorId: registered.collectorId, deviceCredential: registered.deviceCredential};
  const code = await service().issuePairingCode(auth);
  await service().claimCollector({actorUid: 'admin', pairingCode: code.code, siteId: 'site-a', sourceFingerprint: 'revoke-claim'});
  await expectPairingError(
    () => service().revokeCollector({actorUid: 'employee', collectorId: registered.collectorId, siteId: 'site-a'}),
    'FORBIDDEN',
  );
  await service().revokeCollector({actorUid: 'admin', collectorId: registered.collectorId, siteId: 'site-a'});
  assert.deepEqual(await service().getCollectorStatus(auth), {collectorId: registered.collectorId, state: 'REVOKED'});
  assert.deepEqual(await service().issuePairingCode(auth), {collectorId: registered.collectorId, state: 'REVOKED'});
  await service().resetForPairing({actorUid: 'admin', collectorId: registered.collectorId, siteId: 'site-a'});
  assert.deepEqual(await service().getCollectorStatus(auth), {collectorId: registered.collectorId, state: 'UNPAIRED'});
  const reissued = await service().issuePairingCode(auth);
  assert.equal(reissued.state, 'UNPAIRED');
  assert.ok(reissued.code);
});

test('rate limits block registration, code issuance and brute-force claim abuse', {skip: !hasEmulator}, async () => {
  const limited: RateLimits = {
    registration: {limit: 1, windowSeconds: 600},
    pairingCode: {limit: 1, windowSeconds: 600},
    claim: {limit: 1, windowSeconds: 600},
    claimSource: {limit: 1, windowSeconds: 600},
  };
  await service(limited).registerCollector({}, 'limited-registration');
  await expectPairingError(
    () => service(limited).registerCollector({}, 'limited-registration'),
    'PAIRING_RATE_LIMITED',
  );

  const codeLimitedCollector = await service(limited).registerCollector({}, 'limited-code-registration');
  const codeLimitedAuth = {
    collectorId: codeLimitedCollector.collectorId,
    deviceCredential: codeLimitedCollector.deviceCredential,
  };
  await service(limited).issuePairingCode(codeLimitedAuth);
  await expectPairingError(
    () => service(limited).issuePairingCode(codeLimitedAuth),
    'PAIRING_RATE_LIMITED',
  );

  await expectPairingError(
    () => service(limited).claimCollector({
      actorUid: 'admin-rate',
      pairingCode: 'FJ-ABCD-EFGH-JKMN',
      siteId: 'site-a',
      sourceFingerprint: 'limited-claim-source',
    }),
    'PAIRING_CODE_INVALID',
  );
  await expectPairingError(
    () => service(limited).claimCollector({
      actorUid: 'admin-rate',
      pairingCode: 'FJ-ABCD-EFGH-JKMN',
      siteId: 'site-a',
      sourceFingerprint: 'limited-claim-source',
    }),
    'PAIRING_RATE_LIMITED',
  );
});

test('audit records each state-changing pairing event without secrets', {skip: !hasEmulator}, async () => {
  const registered = await service().registerCollector({}, 'audit-a');
  const auth = {collectorId: registered.collectorId, deviceCredential: registered.deviceCredential};
  const first = await service().issuePairingCode(auth);
  const second = await service().issuePairingCode(auth);
  await service().claimCollector({actorUid: 'admin', pairingCode: second.code, siteId: 'site-a', sourceFingerprint: 'audit-claim'});
  await service().revokeCollector({actorUid: 'admin', collectorId: registered.collectorId, siteId: 'site-a'});
  await service().resetForPairing({actorUid: 'admin', collectorId: registered.collectorId, siteId: 'site-a'});

  const audit = await db.collection(COLLECTIONS.auditEvents)
    .where('collectorId', '==', registered.collectorId)
    .get();
  const eventTypes = new Set(audit.docs.map((document) => document.data().eventType));
  for (const eventType of [
    'COLLECTOR_REGISTERED',
    'PAIRING_CODE_ISSUED',
    'PAIRING_CODE_SUPERSEDED',
    'PAIRING_CODE_CLAIMED',
    'COLLECTOR_PAIRED',
    'COLLECTOR_REVOKED',
    'COLLECTOR_RESET_FOR_PAIRING',
  ]) {
    assert.equal(eventTypes.has(eventType), true);
  }
  const serializedAudit = JSON.stringify(audit.docs.map((document) => document.data()));
  assert.equal(serializedAudit.includes(first.code!), false);
  assert.equal(serializedAudit.includes(registered.deviceCredential), false);
});
