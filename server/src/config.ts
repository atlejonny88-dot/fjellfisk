import {PairingError} from './pairing/errors.js';

export interface ServerConfig {
  databaseUrl: string;
  pairingPepper: string;
  firebaseProjectId: string;
  adminCorsOrigins: readonly string[];
  port: number;
}

function readCorsOrigins(value: string | undefined): string[] {
  if (!value?.trim()) return [];

  const origins = new Set<string>();
  for (const candidate of value.split(',')) {
    const trimmed = candidate.trim();
    if (!trimmed) continue;

    let parsed: URL;
    try {
      parsed = new URL(trimmed);
    } catch {
      throw new PairingError('BACKEND_MISCONFIGURED', 500);
    }
    if (
      (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') ||
      parsed.username ||
      parsed.password ||
      parsed.pathname !== '/' ||
      parsed.search ||
      parsed.hash
    ) {
      throw new PairingError('BACKEND_MISCONFIGURED', 500);
    }
    origins.add(parsed.origin);
  }
  return [...origins];
}

export function readServerConfig(environment = process.env): ServerConfig {
  const databaseUrl = environment.DATABASE_URL;
  const pairingPepper = environment.COLLECTOR_PAIRING_PEPPER;
  const firebaseProjectId = environment.FIREBASE_PROJECT_ID;
  const adminCorsOrigins = readCorsOrigins(environment.ADMIN_CORS_ORIGINS);
  const port = Number(environment.PORT ?? 8080);
  if (!databaseUrl || !pairingPepper || !firebaseProjectId || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new PairingError('BACKEND_MISCONFIGURED', 500);
  }
  return {databaseUrl, pairingPepper, firebaseProjectId, adminCorsOrigins, port};
}
