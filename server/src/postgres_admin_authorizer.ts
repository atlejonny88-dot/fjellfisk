import type {AdminAuthorizer, AdminAuthorizationOptions} from './admin_authorizer.js';
import type {FirebaseIdTokenVerifier} from './firebase_public_token_verifier.js';
import {PairingError} from './pairing/errors.js';
import type {AuthorizedAdmin} from './pairing/types.js';
import type {AuthorityRepository} from './postgres_authority_repository.js';

function bearerToken(authorizationHeader: string | undefined): string {
  const token = authorizationHeader?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) throw new PairingError('UNAUTHENTICATED', 401);
  return token;
}

/**
 * Firebase proves who the caller is. PostgreSQL decides whether that caller is
 * an active facility administrator and, for pairing, has Collector enabled.
 */
export class PostgresAdminAuthorizer implements AdminAuthorizer {
  constructor(
    private readonly tokenVerifier: FirebaseIdTokenVerifier,
    private readonly authorityRepository: AuthorityRepository,
  ) {}

  async authorize(
    authorizationHeader: string | undefined,
    siteId: string,
    options: AdminAuthorizationOptions = {},
  ): Promise<AuthorizedAdmin> {
    let uid: string;
    try {
      uid = (await this.tokenVerifier.verifyIdToken(bearerToken(authorizationHeader))).uid;
    } catch (error) {
      if (error instanceof PairingError) throw error;
      throw new PairingError('UNAUTHENTICATED', 401);
    }

    const access = await this.authorityRepository.getAdminAccess(uid, siteId);
    if (!access) throw new PairingError('FORBIDDEN', 403);
    if (options.requireCollectorEntitlement && !access.collectorEntitled) {
      throw new PairingError('COLLECTOR_ENTITLEMENT_REQUIRED', 403);
    }
    return {uid, organizationId: access.organizationId, allowedSiteIds: [siteId]};
  }
}
