import assert from 'node:assert/strict';
import test from 'node:test';

const runFunctionSmokeTest = process.env.FJELLFISK_FUNCTIONS_EMULATOR === '1';
const projectId = process.env.GCLOUD_PROJECT ?? 'trolltungaarctictrout';
const functionBaseUrl = process.env.FUNCTIONS_EMULATOR_HOST ?? '127.0.0.1:5001';
const collectorUrl = `http://${functionBaseUrl}/${projectId}/europe-west1/collectorApi/collector/v1`;

test('Functions emulator serves only the minimal Collector HTTP contract', {skip: !runFunctionSmokeTest}, async () => {
  const registration = await fetch(`${collectorUrl}/register`, {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({collectorVersion: 'emulator-test', platform: 'windows-x86'}),
  });
  assert.equal(registration.status, 201);
  const registered = await registration.json() as {
    collectorId: string;
    deviceCredential: string;
    state: string;
  };
  assert.equal(registered.state, 'UNPAIRED');
  assert.ok(registered.collectorId.length > 20);
  assert.ok(registered.deviceCredential.length >= 40);

  const headers = {
    'x-fjellfisk-collector-id': registered.collectorId,
    'x-fjellfisk-device-credential': registered.deviceCredential,
  };
  const pairingCodeResponse = await fetch(`${collectorUrl}/pairing-code`, {
    method: 'POST',
    headers,
  });
  assert.equal(pairingCodeResponse.status, 200);
  const pairingCode = await pairingCodeResponse.json() as {
    state: string;
    code?: string;
    expiresInSeconds?: number;
  };
  assert.equal(pairingCode.state, 'UNPAIRED');
  assert.match(pairingCode.code ?? '', /^FJ-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}(?:-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{4}){2}$/);
  assert.equal(pairingCode.expiresInSeconds, 600);

  const status = await fetch(`${collectorUrl}/status`, {headers});
  assert.equal(status.status, 200);
  assert.deepEqual(await status.json(), {
    collectorId: registered.collectorId,
    state: 'UNPAIRED',
  });
});
