import assert from 'node:assert/strict';
import test from 'node:test';

import {readServerConfig} from '../src/config.js';
import {PairingError} from '../src/pairing/errors.js';

const validEnvironment = {
  DATABASE_URL: 'postgresql://user:password@localhost:5432/fjellfisk',
  COLLECTOR_PAIRING_PEPPER: 'test-pepper-that-is-at-least-thirty-two-characters',
  FIREBASE_PROJECT_ID: 'trolltungaarctictrout',
};

test('server config normalizes a narrow comma-separated admin CORS allowlist', () => {
  const config = readServerConfig({
    ...validEnvironment,
    ADMIN_CORS_ORIGINS: 'https://trolltungaarctictrout.web.app/, http://localhost:51099',
  });

  assert.deepEqual(config.adminCorsOrigins, [
    'https://trolltungaarctictrout.web.app',
    'http://localhost:51099',
  ]);
});

test('server config disables browser CORS when no explicit allowlist is configured', () => {
  assert.deepEqual(readServerConfig(validEnvironment).adminCorsOrigins, []);
});

test('server config rejects wildcard and path-based CORS entries', () => {
  for (const origin of ['*', 'https://trolltungaarctictrout.web.app/admin']) {
    assert.throws(
      () => readServerConfig({...validEnvironment, ADMIN_CORS_ORIGINS: origin}),
      (error: unknown) => error instanceof PairingError && error.code === 'BACKEND_MISCONFIGURED',
    );
  }
});
