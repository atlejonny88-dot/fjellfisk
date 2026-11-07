import {mkdir, writeFile} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';

import {readServerConfig} from '../src/config.js';
import {createPostgresPool} from '../src/postgres_pairing_repository.js';
import {PostgresVaconEdgeRepository} from '../src/postgres_vacon_edge_repository.js';
import {VaconEdgeProvisioningService} from '../src/vacon/edge_provisioning.js';

function option(name: string): string | null {
  const index = process.argv.indexOf(name);
  return index >= 0 && typeof process.argv[index + 1] === 'string' ? process.argv[index + 1]! : null;
}

function required(name: string): string {
  const value = option(name)?.trim();
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function apiBaseUrl(value: string): string {
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('The Edge API URL must be an exact HTTPS origin.');
  }
  return url.origin;
}

const output = resolve(required('--output'));
const config = readServerConfig();
const pool = createPostgresPool(config.databaseUrl);
try {
  const service = new VaconEdgeProvisioningService(
    new PostgresVaconEdgeRepository(pool), config.vaconEdgeCredentialKey,
  );
  const bundle = option('--rotate-edge')
    ? await service.rotate(required('--rotate-edge'))
    : await service.provision(required('--facility'), required('--name'));
  const edgeConfig = {
    apiBaseUrl: apiBaseUrl(required('--api')),
    edgeId: bundle.edgeId,
    credentialId: bundle.credentialId,
    credential: bundle.credential,
    pollIntervalSeconds: 5,
    commandPollSeconds: 5,
    readTimeoutMs: 3000,
  };
  await mkdir(dirname(output), {recursive: true, mode: 0o700});
  await writeFile(output, `${JSON.stringify(edgeConfig, null, 2)}\n`, {encoding: 'utf8', mode: 0o600, flag: 'wx'});
  console.log(`VACON Edge credential bundle created for edge ${bundle.edgeId}.`);
} finally {
  await pool.end();
}
