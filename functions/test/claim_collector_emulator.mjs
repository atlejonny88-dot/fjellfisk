import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';

const {initializeApp, cert} = await import('firebase-admin/app');
const {getFirestore} = await import('firebase-admin/firestore');

const input = JSON.parse(await new Promise((resolve, reject) => {
  let data = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { data += chunk; });
  process.stdin.on('end', () => resolve(data));
  process.stdin.on('error', reject);
}));
if (typeof input.code !== 'string' || input.code.length === 0) {
  throw new Error('A pairing code is required.');
}
if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('FIRESTORE_EMULATOR_HOST is required.');
}

const projectId = process.env.GCLOUD_PROJECT ?? 'trolltungaarctictrout';
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST ?? '127.0.0.1:5001';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
const siteId = 'collector-coordinator-e2e-' + Date.now();
const email = 'collector-coordinator-e2e-' + Date.now() + '@example.test';

async function json(response) {
  const value = await response.json();
  if (!response.ok) {
    throw new Error('Unexpected emulator response ' + response.status + ': ' + JSON.stringify(value));
  }
  return value;
}

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
  db.collection('facilities').doc(siteId).set({organizationId: 'collector-coordinator-e2e'}),
]);

const claim = await json(await fetch(
  'http://' + functionsHost + '/' + projectId + '/europe-west1/claimCollector',
  {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: 'Bearer ' + auth.idToken,
    },
    body: JSON.stringify({data: {pairingCode: input.code, siteId}}),
  },
));
assert.equal(claim.result.state, 'PAIRED');
console.log('{"state":"PAIRED"}');

function getEmulatorFirestore() {
  const {privateKey} = generateKeyPairSync('rsa', {modulusLength: 2048});
  const app = initializeApp({
    credential: cert({
      projectId,
      clientEmail: 'collector-coordinator-e2e@local.test',
      privateKey: privateKey.export({type: 'pkcs8', format: 'pem'}),
    }),
    projectId,
  });
  return getFirestore(app);
}
