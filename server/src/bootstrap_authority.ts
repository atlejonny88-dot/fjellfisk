import {createPostgresPool} from './postgres_pairing_repository.js';
import {
  createPostgresAuthorityRepository,
  type CollectorEntitlementStatus,
} from './postgres_authority_repository.js';

interface BootstrapArguments {
  firebaseUid: string;
  facilityId: string;
  facilityName: string;
  organizationId: string | null;
  collectorEntitlement: CollectorEntitlementStatus;
}

function readArgument(name: string): string | undefined {
  const index = process.argv.indexOf(`--${name}`);
  const value = index < 0 ? undefined : process.argv[index + 1];
  return value?.startsWith('--') ? undefined : value;
}

function readBootstrapArguments(): BootstrapArguments {
  const firebaseUid = readArgument('firebase-uid');
  const facilityId = readArgument('facility-id');
  const facilityName = readArgument('facility-name');
  const organizationId = readArgument('organization-id') ?? null;
  const collectorEntitlement = readArgument('collector-entitlement') ?? 'INACTIVE';
  if (
    !firebaseUid || !facilityId || !facilityName ||
    (collectorEntitlement !== 'ACTIVE' && collectorEntitlement !== 'INACTIVE')
  ) {
    throw new Error(
      'Usage: --firebase-uid <uid> --facility-id <id> --facility-name <name> ' +
      '[--organization-id <id>] [--collector-entitlement ACTIVE|INACTIVE]',
    );
  }
  return {firebaseUid, facilityId, facilityName, organizationId, collectorEntitlement};
}

async function main(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  const bootstrapSecret = process.env.COLLECTOR_BOOTSTRAP_SECRET;
  if (!databaseUrl || !bootstrapSecret || bootstrapSecret.length < 32) {
    throw new Error('DATABASE_URL and a 32-character COLLECTOR_BOOTSTRAP_SECRET are required');
  }
  const input = readBootstrapArguments();
  const pool = createPostgresPool(databaseUrl);
  try {
    await createPostgresAuthorityRepository(pool).bootstrapInitialAuthority(input);
    console.log('[fjellfisk-backend] initial Collector authority bootstrap completed');
  } finally {
    await pool.end();
  }
}

await main();
