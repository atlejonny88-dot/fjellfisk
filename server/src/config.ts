import {PairingError} from './pairing/errors.js';

export interface ServerConfig {
  databaseUrl: string;
  pairingPepper: string;
  firebaseProjectId: string;
  port: number;
}

export function readServerConfig(environment = process.env): ServerConfig {
  const databaseUrl = environment.DATABASE_URL;
  const pairingPepper = environment.COLLECTOR_PAIRING_PEPPER;
  const firebaseProjectId = environment.FIREBASE_PROJECT_ID;
  const port = Number(environment.PORT ?? 8080);
  if (!databaseUrl || !pairingPepper || !firebaseProjectId || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new PairingError('BACKEND_MISCONFIGURED', 500);
  }
  return {databaseUrl, pairingPepper, firebaseProjectId, port};
}
