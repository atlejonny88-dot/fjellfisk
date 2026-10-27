import {FirebaseAdminAuthorizer} from './firebase_admin_authorizer.js';
import {createHttpApi} from './http_server.js';
import {PairingService} from './pairing/service.js';
import {createPostgresPool, PostgresPairingRepository} from './postgres_pairing_repository.js';
import {readServerConfig} from './config.js';

const config = readServerConfig();
const pool = createPostgresPool(config.databaseUrl);
const pairingService = new PairingService(new PostgresPairingRepository(pool), {
  pepper: config.pairingPepper,
});
const server = createHttpApi({
  pairingService,
  adminAuthorizer: new FirebaseAdminAuthorizer(config.firebaseProjectId),
  log: (message) => console.error(`[fjellfisk-backend] ${message}`),
});

server.listen(config.port, '0.0.0.0', () => {
  console.log(`[fjellfisk-backend] listening on port ${config.port}`);
});

async function shutdown(signal: string): Promise<void> {
  console.log(`[fjellfisk-backend] ${signal} received, shutting down`);
  server.close(async () => {
    await pool.end();
    process.exit(0);
  });
}

process.once('SIGINT', () => void shutdown('SIGINT'));
process.once('SIGTERM', () => void shutdown('SIGTERM'));
