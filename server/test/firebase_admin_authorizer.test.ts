import assert from 'node:assert/strict';
import test from 'node:test';

import {
  FirebaseAdminAuthorizer,
  type FirebaseAuthorizationDataSource,
  type FirebaseAuthorizationDocument,
} from '../src/firebase_admin_authorizer.js';
import {PairingError} from '../src/pairing/errors.js';

function document(data: Record<string, unknown> | undefined): FirebaseAuthorizationDocument {
  return {
    exists: data !== undefined,
    data: () => data,
  };
}

function dataSource({
  verify = async () => ({uid: 'admin-uid'}),
  user = document({role: 'admin', disabled: false}),
  facility = document({organizationId: 'org-1'}),
}: {
  verify?: (token: string) => Promise<{uid: string}>;
  user?: FirebaseAuthorizationDocument;
  facility?: FirebaseAuthorizationDocument;
} = {}): FirebaseAuthorizationDataSource {
  return {
    verifyIdToken: verify,
    getUser: async () => user,
    getFacility: async () => facility,
  };
}

test('Firebase authorizer verifies the token and reads only the user and requested facility', async () => {
  const reads: string[] = [];
  const authorizer = new FirebaseAdminAuthorizer('trolltungaarctictrout', {
    verifyIdToken: async (token) => {
      assert.equal(token, 'verified-token');
      return {uid: 'admin-uid'};
    },
    getUser: async (uid) => {
      reads.push(`users/${uid}`);
      return document({role: 'admin', disabled: false});
    },
    getFacility: async (siteId) => {
      reads.push(`facilities/${siteId}`);
      return document({organizationId: 'org-1'});
    },
  });

  const actor = await authorizer.authorize('Bearer verified-token', 'facility-1');
  assert.deepEqual(actor, {
    uid: 'admin-uid',
    organizationId: 'org-1',
    allowedSiteIds: ['facility-1'],
  });
  assert.deepEqual(reads.sort(), ['facilities/facility-1', 'users/admin-uid']);
});

test('Firebase authorizer rejects missing or invalid Firebase ID tokens', async () => {
  const authorizer = new FirebaseAdminAuthorizer('trolltungaarctictrout', dataSource({
    verify: async () => { throw new Error('invalid token'); },
  }));

  for (const authorization of [undefined, 'Basic credentials', 'Bearer invalid']) {
    await assert.rejects(
      authorizer.authorize(authorization, 'facility-1'),
      (error: unknown) => error instanceof PairingError && error.code === 'UNAUTHENTICATED',
    );
  }
});

test('Firebase authorizer rejects a missing facility, missing user, disabled user, and non-admin role', async () => {
  const scenarios = [
    {user: document({role: 'admin', disabled: false}), facility: document(undefined), code: 'SITE_NOT_FOUND'},
    {user: document(undefined), facility: document({}), code: 'FORBIDDEN'},
    {user: document({role: 'admin', disabled: true}), facility: document({}), code: 'FORBIDDEN'},
    {user: document({role: 'ansatt', disabled: false}), facility: document({}), code: 'FORBIDDEN'},
  ] as const;

  for (const scenario of scenarios) {
    const authorizer = new FirebaseAdminAuthorizer(
      'trolltungaarctictrout',
      dataSource({user: scenario.user, facility: scenario.facility}),
    );
    await assert.rejects(
      authorizer.authorize('Bearer valid-token', 'facility-1'),
      (error: unknown) => error instanceof PairingError && error.code === scenario.code,
    );
  }
});
