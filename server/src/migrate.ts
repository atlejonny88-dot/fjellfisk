import {readdir, readFile} from 'node:fs/promises';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

import {readServerConfig} from './config.js';
import {createPostgresPool} from './postgres_pairing_repository.js';

async function migrationDirectory(): Promise<string> {
  const moduleDirectory = dirname(fileURLToPath(import.meta.url));
  const candidates = [
    resolve(moduleDirectory, '../../migrations'),
    resolve(process.cwd(), 'migrations'),
  ];
  for (const candidate of candidates) {
    try {
      await readdir(candidate);
      return candidate;
    } catch {
      // Try the next known location.
    }
  }
  throw new Error('Migration directory not found');
}

const pool = createPostgresPool(readServerConfig().databaseUrl);
const directory = await migrationDirectory();
const files = (await readdir(directory)).filter((file) => file.endsWith('.sql')).sort();
const client = await pool.connect();
try {
  await client.query('CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW())');
  for (const file of files) {
    const applied = await client.query('SELECT 1 FROM schema_migrations WHERE version = $1', [file]);
    if (applied.rowCount) continue;
    await client.query('BEGIN');
    try {
      await client.query(await readFile(resolve(directory, file), 'utf8'));
      await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
      await client.query('COMMIT');
      console.log(`[fjellfisk-backend] applied migration ${file}`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    }
  }
} finally {
  client.release();
  await pool.end();
}
