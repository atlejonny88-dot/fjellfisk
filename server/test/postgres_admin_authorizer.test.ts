import assert from 'node:assert/strict';
import test from 'node:test';

import type {FirebaseIdTokenVerifier} from '../src/firebase_public_token_verifier.js';
import {PairingError} from '../src/pairing/errors.js';
import {PostgresAdminAuthorizer} from '../src/postgres_admin_authorizer.js';
import type {AuthorityRepository} from '../src/postgres_authority_repository.js';

const tokenVerifier: FirebaseIdTokenVerifier = {
  verifyIdToken: async (token) => {
    if (token !== 'valid-token') throw new Error('invalid token');
    return {uid: 'test-admin-user'};
  },
};

function repository(access: Awaited<ReturnType<AuthorityRepository['getAdminAccess']>>): AuthorityRepository {
  return {
    getAdminAccess: async () => access,
    bootstrapInitialAuthority: async () => {},
  };
}

test('PostgreSQL authorizer trusts a verified UID only after active database membership', async () => {
  const authorizer = new PostgresAdminAuthorizer(tokenVerifier, repository({
    organizationId: 'org-1', collectorEntitled: true,
  }));

  assert.deepEqual(await authorizer.authorize('Bearer valid-token', 'facility-1'), {
    uid: 'test-admin-user', organizationId: 'org-1', allowedSiteIds: ['facility-1'],
  });
});

test('PostgreSQL authorizer rejects missing or invalid identity tokens', async () => {
  const authorizer = new PostgresAdminAuthorizer(tokenVerifier, repository({
    organizationId: null, collectorEntitled: true,
  }));

  for (const authorization of [undefined, 'Basic credentials', 'Bearer invalid-token']) {
    await assert.rejects(
      authorizer.authorize(authorization, 'facility-1'),
      (error: unknown) => error instanceof PairingError && error.code === 'UNAUTHENTICATED',
    );
  }
});

test('PostgreSQL authorizer does not trust a Firebase token without database authority', async () => {
  const authorizer = new PostgresAdminAuthorizer(tokenVerifier, repository(null));
  await assert.rejects(
    authorizer.authorize('Bearer valid-token', 'facility-1'),
    (error: unknown) => error instanceof PairingError && error.code === 'FORBIDDEN',
  );
});

test('claim authorization requires an active Collector entitlement', async () => {
  const authorizer = new PostgresAdminAuthorizer(tokenVerifier, repository({
    organizationId: 'org-1', collectorEntitled: false,
  }));
  await assert.rejects(
    authorizer.authorize('Bearer valid-token', 'facility-1', {requireCollectorEntitlement: true}),
    (error: unknown) => error instanceof PairingError && error.code === 'COLLECTOR_ENTITLEMENT_REQUIRED',
  );
});
