import {PairingError} from './pairing/errors.js';
import type {AuthorizedAdmin} from './pairing/types.js';

export interface AdminAuthorizationOptions {
  requireCollectorEntitlement?: boolean;
}

export interface AdminAuthorizer {
  authorize(
    authorizationHeader: string | undefined,
    siteId: string,
    options?: AdminAuthorizationOptions,
  ): Promise<AuthorizedAdmin>;
}

/** Test-only authorizer for the HTTP contract tests. */
export class StaticAdminAuthorizer implements AdminAuthorizer {
  constructor(private readonly actor: AuthorizedAdmin) {}

  async authorize(
    authorizationHeader: string | undefined,
    siteId: string,
    _options?: AdminAuthorizationOptions,
  ): Promise<AuthorizedAdmin> {
    if (authorizationHeader !== 'Bearer local-test-admin') {
      throw new PairingError('UNAUTHENTICATED', 401);
    }
    if (!this.actor.allowedSiteIds.includes(siteId)) {
      throw new PairingError('FORBIDDEN', 403);
    }
    return this.actor;
  }
}
