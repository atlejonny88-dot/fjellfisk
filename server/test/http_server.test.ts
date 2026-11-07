import assert from 'node:assert/strict';
import test from 'node:test';

import {StaticAdminAuthorizer} from '../src/admin_authorizer.js';
import {createHttpApi} from '../src/http_server.js';
import {PairingService} from '../src/pairing/service.js';
import type {VaconEdgeService} from '../src/vacon/edge_service.js';
import type {VaconEdge} from '../src/vacon/edge_types.js';
import {InMemoryPairingRepository} from './in_memory_repository.js';
import {validateSensorBatch, validateSensorMappings} from '../src/pairing/telemetry.js';

test('sensor validation rejects malformed, duplicate and future measurements without swapping units', () => {
  const now = new Date();
  const reading = {sensorId: 'probe-1', name: 'Probe 1', sourceType: 'Pacific',
    temperatureC: 9.52, oxygenMgL: 11.66, oxygenSaturationPct: 101.85,
    timestampUtc: now.toISOString(), health: 'ok'};
  const batch = {batchId: '12345678-1234-4234-8234-123456789012', collectorVersion: '1.0.5', readings: [reading]};
  assert.equal(validateSensorBatch(batch, now).readings[0]?.oxygenMgL, 11.66);
  assert.equal(validateSensorBatch(batch, now).readings[0]?.oxygenSaturationPct, 101.85);
  for (const patch of [{oxygenMgL: '11.66'}, {temperatureC: Infinity}, {oxygenSaturationPct: -1},
    {timestampUtc: 'invalid'}, {timestampUtc: new Date(now.getTime() + 120_000).toISOString()}]) {
    assert.throws(() => validateSensorBatch({...batch, readings: [{...reading, ...patch}]}, now));
  }
  assert.throws(() => validateSensorBatch({...batch, readings: [reading, reading]}, now));
  assert.throws(() => validateSensorBatch({...batch, readings: []}, now));
  assert.throws(() => validateSensorBatch({...batch, batchId: 'not-an-id'}, now));
  const mapping = {sensorId: 'probe-1', sectionId: 'section-1', sectionName: 'Tunnel', tankId: 'tank-1', tankName: 'K1'};
  assert.throws(() => validateSensorMappings([mapping, {...mapping, sensorId: 'probe-2'}]));
});

test('HTTP API keeps collector contract, protects admin routes, and exposes health only', async () => {
  const repository = new InMemoryPairingRepository();
  const service = new PairingService(repository, {pepper: 'test-pepper-that-is-at-least-thirty-two-characters'});
  const api = createHttpApi({
    pairingService: service,
    adminAuthorizer: new StaticAdminAuthorizer({
      uid: 'admin-user', organizationId: 'org-1', allowedSiteIds: ['facility-1'],
    }),
    adminCorsOrigins: ['https://trolltungaarctictrout.web.app', 'http://localhost:51099'],
  });
  await new Promise<void>((resolve) => api.listen(0, '127.0.0.1', resolve));
  const address = api.address();
  assert.ok(address && typeof address !== 'string');
  const baseUrl = `http://127.0.0.1:${address.port}`;
  try {
    const allowedPreflight = await fetch(`${baseUrl}/admin/v1/collectors/claim`, {
      method: 'OPTIONS',
      headers: {origin: 'http://localhost:51099'},
    });
    assert.equal(allowedPreflight.status, 204);
    assert.equal(allowedPreflight.headers.get('access-control-allow-origin'), 'http://localhost:51099');
    assert.equal(allowedPreflight.headers.get('access-control-allow-headers'), 'authorization, content-type');

    const forbiddenPreflight = await fetch(`${baseUrl}/admin/v1/collectors/claim`, {
      method: 'OPTIONS',
      headers: {origin: 'https://not-fjellfisk.example'},
    });
    assert.equal(forbiddenPreflight.status, 403);
    assert.equal(forbiddenPreflight.headers.get('access-control-allow-origin'), null);

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
      headers: {
        'content-type': 'application/json',
        authorization: 'Bearer local-test-admin',
        origin: 'http://localhost:51099',
      },
      body: JSON.stringify({siteId: 'facility-1', pairingCode: issued.code}),
    });
    assert.equal(claimed.status, 200);
    assert.equal(claimed.headers.get('access-control-allow-origin'), 'http://localhost:51099');
    assert.equal((await claimed.json() as {state: string}).state, 'PAIRED');

    const batch = {batchId: '12345678-1234-4234-8234-123456789012', collectorVersion: '1.0.5', readings: [{
      sensorId: 'pacific-01', name: 'Pacific 01 / Probe 01', sourceType: 'Pacific',
      temperatureC: 9.52, oxygenMgL: 11.66, oxygenSaturationPct: 101.85,
      timestampUtc: new Date().toISOString(), health: 'ok',
    }]};
    const sensorUrl = `${baseUrl}/admin/v1/sites/facility-1/collectors/${registered.collectorId}/sensors`;
    const deviceHeaders = {'content-type': 'application/json',
      'x-fjellfisk-collector-id': registered.collectorId,
      'x-fjellfisk-device-credential': registered.deviceCredential};
    const adminHeaders = {'content-type': 'application/json', authorization: 'Bearer local-test-admin'};
    assert.equal((await fetch(`${baseUrl}/collector/v1/measurements`, {
      method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify(batch),
    })).status, 400);
    for (const accepted of [true, false]) {
      const uploaded = await fetch(`${baseUrl}/collector/v1/measurements`, {method: 'POST', headers: deviceHeaders, body: JSON.stringify(batch)});
      assert.equal(uploaded.status, 200);
      assert.deepEqual(await uploaded.json(), {accepted});
    }
    const mapping = {sensorId: 'pacific-01', sectionId: 'section-1', sectionName: 'Tunnel', tankId: 'tank-1', tankName: 'K1'};
    const saved = await fetch(`${baseUrl}/admin/v1/collectors/${registered.collectorId}/mappings`, {
      method: 'POST', headers: adminHeaders, body: JSON.stringify({siteId: 'facility-1', mappings: [mapping]}),
    });
    assert.equal(saved.status, 200);
    const snapshot = await (await fetch(sensorUrl, {headers: adminHeaders})).json() as {sensors: {oxygenMgL: number; oxygenSaturationPct: number}[]; mappings: unknown[]};
    assert.equal(snapshot.sensors[0]?.oxygenMgL, 11.66);
    assert.equal(snapshot.sensors[0]?.oxygenSaturationPct, 101.85);
    assert.deepEqual(snapshot.mappings, [mapping]);
    assert.equal((await fetch(sensorUrl)).status, 401);
    assert.equal((await fetch(sensorUrl.replace('facility-1', 'other-facility'), {headers: adminHeaders})).status, 403);
    repository.sensorEntitled = false;
    assert.equal((await fetch(`${baseUrl}/collector/v1/measurements`, {method: 'POST', headers: deviceHeaders, body: JSON.stringify(batch)})).status, 403);
    repository.sensorEntitled = true;
    await service.revokeCollector({uid: 'admin-user', organizationId: 'org-1', allowedSiteIds: ['facility-1']}, registered.collectorId, 'facility-1');
    assert.equal((await fetch(`${baseUrl}/collector/v1/measurements`, {method: 'POST', headers: deviceHeaders, body: JSON.stringify(batch)})).status, 403);
  } finally {
    await new Promise<void>((resolve, reject) => api.close((error) => error ? reject(error) : resolve()));
  }
});

test('production web origins pass preflight without bypassing admin authentication', async () => {
  const origins = ['https://fjellfisk.web.app', 'https://trolltungaarctictrout.web.app'];
  const api = createHttpApi({
    pairingService: new PairingService(new InMemoryPairingRepository(), {
      pepper: 'test-pepper-that-is-at-least-thirty-two-characters',
    }),
    adminAuthorizer: new StaticAdminAuthorizer({uid: 'admin', organizationId: null, allowedSiteIds: []}),
    adminCorsOrigins: origins,
  });
  await new Promise<void>((resolve) => api.listen(0, '127.0.0.1', resolve));
  const address = api.address();
  assert.ok(address && typeof address !== 'string');
  const url = `http://127.0.0.1:${address.port}/admin/v1/collectors/claim`;
  try {
    for (const origin of origins) {
      const preflight = await fetch(url, {method: 'OPTIONS', headers: {origin}});
      assert.equal(preflight.status, 204);
      assert.equal(preflight.headers.get('access-control-allow-origin'), origin);
      const unauthorized = await fetch(url, {
        method: 'POST',
        headers: {origin, 'content-type': 'application/json'},
        body: JSON.stringify({siteId: 'facility-1', pairingCode: 'test-only'}),
      });
      assert.equal(unauthorized.status, 401);
      assert.equal(unauthorized.headers.get('access-control-allow-origin'), origin);
    }
    const forbidden = await fetch(url, {method: 'OPTIONS', headers: {origin: 'https://untrusted.example'}});
    assert.equal(forbidden.status, 403);
    assert.equal(forbidden.headers.get('access-control-allow-origin'), null);
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

test('Edge HTTP routes are authenticated, telemetry-only, and expose no control route', async () => {
  const calls: {pathname: string; body: unknown}[] = [];
  const edge: VaconEdge = {
    edgeId: 'edge-01', facilityId: 'facility-01', displayName: 'Pelasyn Edge',
    enabled: true, lastSeenAt: null, createdAt: new Date(), updatedAt: new Date(),
  };
  const edgeService = {
    isConfigured: () => true,
    authenticate: async (_headers: unknown, _method: string, pathname: string, body: Buffer) => {
      calls.push({pathname, body: body.length ? JSON.parse(body.toString('utf8')) : null});
      return edge;
    },
    configuration: async () => ({pollingIntervalSeconds: 5, devices: []}),
    ingestTelemetry: async (_edge: VaconEdge, body: unknown) => ({accepted: Array.isArray((body as {readings?: unknown[]}).readings) ? 1 : 0}),
    takeCommands: async () => [],
    completeCommand: async () => {},
  } as unknown as VaconEdgeService;
  const api = createHttpApi({
    pairingService: new PairingService(new InMemoryPairingRepository(), {
      pepper: 'test-pepper-that-is-at-least-thirty-two-characters',
    }),
    vaconEdgeService: edgeService,
    adminAuthorizer: new StaticAdminAuthorizer({uid: 'admin', organizationId: null, allowedSiteIds: []}),
  });
  await new Promise<void>((resolve) => api.listen(0, '127.0.0.1', resolve));
  const address = api.address();
  assert.ok(address && typeof address !== 'string');
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const headers = {
    'x-fjellfisk-edge-id': edge.edgeId,
    'x-fjellfisk-edge-credential-id': 'credential-01',
    'x-fjellfisk-edge-timestamp': `${Date.now()}`,
    'x-fjellfisk-edge-nonce': 'route-test-nonce-01',
    'x-fjellfisk-edge-signature': 'test-signature',
  };
  try {
    const config = await fetch(`${baseUrl}/edge/v1/config`, {headers});
    assert.equal(config.status, 200);
    assert.deepEqual(await config.json(), {pollingIntervalSeconds: 5, devices: []});

    const telemetry = await fetch(`${baseUrl}/edge/v1/telemetry`, {
      method: 'POST', headers: {...headers, 'content-type': 'application/json'},
      body: JSON.stringify({readings: [{deviceId: 'device-01'}]}),
    });
    assert.equal(telemetry.status, 200);
    assert.deepEqual(await telemetry.json(), {accepted: 1});

    const control = await fetch(`${baseUrl}/edge/v1/control`, {method: 'POST', headers});
    assert.equal(control.status, 404);
    assert.deepEqual(calls.map((call) => call.pathname), [
      '/edge/v1/config', '/edge/v1/telemetry', '/edge/v1/control',
    ]);
  } finally {
    await new Promise<void>((resolve, reject) => api.close((error) => error ? reject(error) : resolve()));
  }
});
