import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';

const {initializeApp, cert} = await import('firebase-admin/app');
const {getFirestore} = await import('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT ?? 'trolltungaarctictrout';
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST ?? '127.0.0.1:5001';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('FIRESTORE_EMULATOR_HOST is required for the local collector E2E test.');
}

const collectorUrl = 'http://' + functionsHost + '/' + projectId + '/europe-west1/collectorApi/collector/v1';
const siteId = 'collector-e2e-site-' + Date.now();
const email = 'collector-e2e-' + Date.now() + '@example.test';

async function json(response) {
  const value = await response.json();
  if (!response.ok) {
    throw new Error('Unexpected emulator response ' + response.status + ': ' + JSON.stringify(value));
  }
  return value;
}

const registration = await json(await fetch(collectorUrl + '/register', {
  method: 'POST',
  headers: {'content-type': 'application/json'},
  body: JSON.stringify({collectorVersion: 'e2e-test', platform: 'windows-x86'}),
}));
assert.equal(registration.state, 'UNPAIRED');

const collectorHeaders = {
  'x-fjellfisk-collector-id': registration.collectorId,
  'x-fjellfisk-device-credential': registration.deviceCredential,
};
const pairingCode = await json(await fetch(collectorUrl + '/pairing-code', {
  method: 'POST',
  headers: collectorHeaders,
}));
assert.equal(pairingCode.state, 'UNPAIRED');
assert.match(pairingCode.code, /^FJ-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}(?:-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}){2}$/);

const auth = await json(await fetch(
  'http://' + authHost + '/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator',
  {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({
      email,
      password: 'Local-Collector-E2E-Only-123!',
      returnSecureToken: true,
    }),
  },
));

const db = getEmulatorFirestore();
await Promise.all([
  db.collection('users').doc(auth.localId).set({role: 'admin', disabled: false}),
  db.collection('facilities').doc(siteId).set({organizationId: 'collector-e2e'}),
]);

const claim = await json(await fetch(
  'http://' + functionsHost + '/' + projectId + '/europe-west1/claimCollector',
  {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: 'Bearer ' + auth.idToken,
    },
    body: JSON.stringify({data: {pairingCode: pairingCode.code, siteId}}),
  },
));
assert.equal(claim.result.state, 'PAIRED');

const paired = await json(await fetch(collectorUrl + '/status', {headers: collectorHeaders}));
assert.equal(paired.state, 'PAIRED');
assert.equal(paired.siteId, siteId);

// No plaintext code or credential is written to this test's output.
console.log('Collector pairing emulator E2E passed: registration, claim, and PAIRED status.');

function getEmulatorFirestore() {
  const {privateKey} = generateKeyPairSync('rsa', {modulusLength: 2048});
  const app = initializeApp({
    credential: cert({
      projectId,
      clientEmail: 'collector-e2e@local.test',
      privateKey: privateKey.export({type: 'pkcs8', format: 'pem'}),
    }),
    projectId,
  });
  return getFirestore(app);
}
