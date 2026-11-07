import assert from 'node:assert/strict';
import {createServer} from 'node:net';
import test from 'node:test';

import {
  EdgeApiClient,
  EdgeError,
  ReadOnlyModbusClient,
  VaconEdgeRunner,
  buildReadRequest,
  decodeVacon100Flow,
  edgeSignature,
  parseEdgeConfig,
} from '../src/edge.mjs';

const edgeConfig = Object.freeze({
  apiBaseUrl: 'https://api.example.test',
  edgeId: 'edge-01',
  credentialId: 'credential-01',
  credential: 'credential-value-not-a-real-secret',
  pollIntervalSeconds: 5,
  commandPollSeconds: 5,
  readTimeoutMs: 500,
});

const device = Object.freeze({
  deviceId: 'b591ab8c-5950-42d0-99dd-faca672a9907',
  model: 'VACON 100 FLOW',
  ipAddress: '127.0.0.1',
  modbusTcpPort: 502,
  modbusUnitId: 255,
});

test('production Edge config requires HTTPS and refuses local HTTP', () => {
  assert.throws(() => parseEdgeConfig({...edgeConfig, apiBaseUrl: 'http://localhost:8080'}), EdgeError);
  assert.deepEqual(parseEdgeConfig(edgeConfig), edgeConfig);
});

test('VACON process-data request is FC04 and uses zero-based PDU 2100', () => {
  const request = buildReadRequest(0x1234, 255);
  assert.equal(request.readUInt8(7), 0x04);
  assert.equal(request.readUInt16BE(8), 2100);
  assert.equal(request.readUInt16BE(10), 11);
});

test('the verified 2104 actual frequency maps to 13.00 Hz without claiming RPM/current scaling', () => {
  const registers = [0x0023, 0, 0, 1300, 388, 42, 0, 0, 0, 0, 0];
  const value = decodeVacon100Flow(registers, new Date('2026-11-07T10:00:00Z'));
  assert.equal(value.actualFrequencyHz, 13);
  assert.equal(value.motorSpeedRpm, 388);
  assert.equal(value.motorSpeedVerified, false);
  assert.equal(value.motorCurrentA, null);
  assert.equal(value.motorCurrentVerified, false);
  assert.equal(value.running, true);
});

test('read-only client makes one FC04 exchange and rejects unsupported profiles', async () => {
  const server = createServer((socket) => {
    socket.once('data', (request) => {
      assert.equal(request.readUInt8(7), 0x04);
      const response = Buffer.alloc(31);
      request.copy(response, 0, 0, 6);
      response.writeUInt16BE(25, 4);
      response.writeUInt8(255, 6);
      response.writeUInt8(0x04, 7);
      response.writeUInt8(22, 8);
      const registers = [0x0023, 0, 0, 1300, 388, 42, 0, 0, 0, 0, 0];
      registers.forEach((value, index) => response.writeUInt16BE(value, 9 + index * 2));
      socket.end(response);
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  assert.ok(address && typeof address !== 'string');
  try {
    const client = new ReadOnlyModbusClient();
    const reading = await client.read({...device, modbusTcpPort: address.port}, 500);
    assert.equal(reading.actualFrequencyHz, 13);
    await assert.rejects(
      () => client.read({...device, model: 'Unknown inverter', modbusTcpPort: address.port}, 500),
      /unsupported-model-profile/,
    );
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
});

test('Edge client signs the exact request and never exposes a Modbus destination through its API', async () => {
  let observed;
  const client = new EdgeApiClient(edgeConfig, async (_url, init) => {
    observed = init;
    return new Response(JSON.stringify({devices: []}), {status: 200, headers: {'content-type': 'application/json'}});
  });
  await client.get('/edge/v1/config');
  assert.equal(observed.headers['x-fjellfisk-edge-id'], 'edge-01');
  assert.match(observed.headers['x-fjellfisk-edge-signature'], /^[A-Za-z0-9_-]+$/);
  const expected = edgeSignature(
    edgeConfig.credential,
    observed.headers['x-fjellfisk-edge-timestamp'],
    'GET',
    '/edge/v1/config',
    Buffer.alloc(0),
    observed.headers['x-fjellfisk-edge-nonce'],
  );
  assert.equal(observed.headers['x-fjellfisk-edge-signature'], expected);
});

test('runner reports a failed read rather than emitting fabricated live telemetry', async () => {
  const uploads = [];
  const api = {
    async get(path) {
      if (path === '/edge/v1/config') return {devices: [device]};
      if (path === '/edge/v1/commands') return {commands: []};
      throw new Error('unexpected request');
    },
    async post(path, payload) { uploads.push({path, payload}); return {accepted: payload.readings?.length ?? 0}; },
  };
  const reader = {async read() { throw new EdgeError('timeout'); }};
  const runner = new VaconEdgeRunner({config: edgeConfig, api, reader, logger: {info: async () => {}, failure: async () => {}, readFailure: async () => {}}});
  await runner.runOnce();
  const reading = uploads[0].payload.readings[0];
  assert.equal(reading.quality, 'FAILED');
  assert.equal(reading.actualFrequencyHz, null);
  assert.equal(reading.motorSpeedRpm, null);
});

test('runner reads multiple configured drives sequentially', async () => {
  let activeReads = 0;
  let maximumConcurrentReads = 0;
  const api = {
    async get(path) {
      if (path === '/edge/v1/config') return {devices: [device, {...device, deviceId: 'b591ab8c-5950-42d0-99dd-faca672a9908'}]};
      if (path === '/edge/v1/commands') return {commands: []};
      throw new Error('unexpected request');
    },
    async post(_path, payload) { return {accepted: payload.readings?.length ?? 0}; },
  };
  const reader = {
    async read() {
      activeReads += 1;
      maximumConcurrentReads = Math.max(maximumConcurrentReads, activeReads);
      await new Promise((resolve) => setTimeout(resolve, 5));
      activeReads -= 1;
      return decodeVacon100Flow([0x0003, 0, 0, 1300, 388, 42, 0, 0, 0, 0, 0]);
    },
  };
  const runner = new VaconEdgeRunner({config: edgeConfig, api, reader, logger: {info: async () => {}, failure: async () => {}, readFailure: async () => {}}});
  await runner.runOnce();
  assert.equal(maximumConcurrentReads, 1);
});
