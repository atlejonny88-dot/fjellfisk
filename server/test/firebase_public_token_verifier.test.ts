import assert from 'node:assert/strict';
import test from 'node:test';

import {FirebasePublicTokenVerifier} from '../src/firebase_public_token_verifier.js';

test('public Firebase verifier accepts a valid Firebase subject without an Admin credential', async () => {
  let verifiedForProject = '';
  const verifier = new FirebasePublicTokenVerifier('fjellfisk-project', async (_token, projectId) => {
    verifiedForProject = projectId;
    return {sub: 'firebase-uid', user_id: 'firebase-uid'};
  });

  assert.deepEqual(await verifier.verifyIdToken('signed-token'), {uid: 'firebase-uid'});
  assert.equal(verifiedForProject, 'fjellfisk-project');
});

test('public Firebase verifier rejects missing, oversized and mismatched identity claims', async () => {
  for (const payload of [
    {},
    {sub: 'x'.repeat(129)},
    {sub: 'firebase-uid', user_id: 'another-uid'},
  ]) {
    const verifier = new FirebasePublicTokenVerifier('fjellfisk-project', async () => payload);
    await assert.rejects(verifier.verifyIdToken('signed-token'));
  }
});
