import assert from 'node:assert/strict';
import test from 'node:test';

import {StaticAdminAuthorizer} from '../src/firebase_admin_authorizer.js';
import {createHttpApi} from '../src/http_server.js';
import {PairingService} from '../src/pairing/service.js';
import {InMemoryPairingRepository} from './in_memory_repository.js';

test('HTTP API keeps collector contract, protects admin routes, and exposes health only', async () => {
  const repository = new InMemoryPairingRepository();
  const service = new PairingService(repository, {pepper: 'test-pepper-that-is-at-least-thirty-two-characters'});
  const api = createHttpApi({
    pairingService: service,
    adminAuthorizer: new StaticAdminAuthorizer({
      uid: 'admin-user', organizationId: 'org-1', allowedSiteIds: ['facility-1'],
    }),
  });
  await new Promise<void>((resolve) => api.listen(0, '127.0.0.1', resolve));
  const address = api.address();
  assert.ok(address && typeof address !== 'string');
  const baseUrl = `http://127.0.0.1:${address.port}`;
  try {
    const health = await fetch(`${baseUrl}/health`);
    assert.deepEqual(await health.json(), {status: 'ok', database: 'ok'});

    const registration = await fetch(`${baseUrl}/collector/v1/register`, {
      method: 'POST', headers: {'content-type': 'application/json'},
      body: JSON.stringify({collectorVersion: '1.0.0', platform: 'windows'}),
    });
    assert.equal(registration.status, 201);
    const registered = await registration.json() as {collectorId: string; deviceCredential: string};

    const noAuth = await fetch(`${baseUrl}/admin/v1/sites/facility-1/collectors`);
    assert.equal(noAuth.status, 401);

    const issuedResponse = await fetch(`${baseUrl}/collector/v1/pairing-code`, {
      method: 'POST',
      headers: {
        'x-fjellfisk-collector-id': registered.collectorId,
        'x-fjellfisk-device-credential': registered.deviceCredential,
      },
    });
    const issued = await issuedResponse.json() as {code: string};
    assert.ok(issued.code);

    const claimed = await fetch(`${baseUrl}/admin/v1/collectors/claim`, {
      method: 'POST',
      headers: {'content-type': 'application/json', authorization: 'Bearer local-test-admin'},
      body: JSON.stringify({siteId: 'facility-1', pairingCode: issued.code}),
    });
    assert.equal(claimed.status, 200);
    assert.equal((await claimed.json() as {state: string}).state, 'PAIRED');
  } finally {
    await new Promise<void>((resolve, reject) => api.close((error) => error ? reject(error) : resolve()));
  }
});

test('health endpoint reports database degradation without an internal exception', async () => {
  const repository = new InMemoryPairingRepository();
  repository.healthcheck = async () => { throw new Error('database unavailable'); };
  const api = createHttpApi({
    pairingService: new PairingService(repository, {pepper: 'test-pepper-that-is-at-least-thirty-two-characters'}),
    adminAuthorizer: new StaticAdminAuthorizer({uid: 'admin', organizationId: null, allowedSiteIds: []}),
  });
  await new Promise<void>((resolve) => api.listen(0, '127.0.0.1', resolve));
  const address = api.address();
  assert.ok(address && typeof address !== 'string');
  try {
    const response = await fetch(`http://127.0.0.1:${address.port}/health`);
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), {status: 'degraded', database: 'unavailable'});
  } finally {
    await new Promise<void>((resolve, reject) => api.close((error) => error ? reject(error) : resolve()));
  }
});
